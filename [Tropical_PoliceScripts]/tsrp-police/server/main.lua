---------------------------------------------------------------------
-- Server core: internal events, rate limiting, player helpers,
-- validated net-event registration, config checks.
---------------------------------------------------------------------
local listeners = {}

-- Internal event bus so modules stay decoupled
-- (duty emits clockIn / clockOut, dispatch / roster / persistence listen).
function Police.on(name, fn)
    listeners[name] = listeners[name] or {}
    table.insert(listeners[name], fn)
end

function Police.emit(name, ...)
    for _, fn in ipairs(listeners[name] or {}) do
        local ok, err = pcall(fn, ...)
        if not ok then print(('^1[tsrp-police] "%s" handler error: %s^7'):format(name, tostring(err))) end
    end
end

---------------------------------------------------------------------
-- Rate limiting (per player, per action)
---------------------------------------------------------------------
local stamps = {}

function Police.rateLimited(src, key, ms)
    local now = GetGameTimer()
    local mine = stamps[src]
    if not mine then mine = {}; stamps[src] = mine end
    local last = mine[key]
    if last and now - last < ms then return true end
    mine[key] = now
    return false
end

---------------------------------------------------------------------
-- Player helpers
---------------------------------------------------------------------
function Police.isPlayer(src)
    return type(src) == 'number' and src > 0 and GetPlayerName(src) ~= nil
end

local function findIdentifier(src, kind)
    local prefix = kind .. ':'
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, #prefix) == prefix then return id end
    end
end

-- Key for duty records. Framework mode: the active character, so every
-- character has its own duty hours. Standalone: the account identifier.
function Police.identifier(src)
    if Framework.enabled() then
        local charId = Framework.characterId(src)
        if charId then return 'char:' .. charId end
    end
    return findIdentifier(src, Config.IdentifierType) or findIdentifier(src, 'license') or ('unknown:' .. tostring(src))
end

function Police.displayName(src)
    if Framework.enabled() then
        local charName = Utils.sanitize(Framework.characterName(src), 48)
        if charName and charName ~= '' then return charName end
    end
    local ok, name = pcall(Config.GetPlayerDisplayName, src)
    name = ok and Utils.sanitize(name, 48) or nil
    if not name or name == '' then name = Utils.sanitize(GetPlayerName(src) or '', 48) end
    if not name or name == '' then name = 'Player ' .. tostring(src) end
    return name
end

-- Server-authoritative position (needs OneSync, which is the FiveM default)
function Police.coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 }
end

function Police.notify(src, message, kind, title, duration)
    TsrpUI.notify(src, message, kind, title, duration)
end

function Police.toClient(src, event, ...)
    TriggerClientEvent('tsrp-police:client:' .. event, src, ...)
end

---------------------------------------------------------------------
-- Validated net events: rejects non-players and rate-limited spam
-- before the handler sees anything.
---------------------------------------------------------------------
function Police.net(name, rateKey, handler)
    RegisterNetEvent('tsrp-police:server:' .. name, function(...)
        local src = source
        if not Police.isPlayer(src) then return end
        if rateKey and Police.rateLimited(src, rateKey, Config.RateLimits[rateKey] or 1000) then return end
        handler(src, ...)
    end)
end

AddEventHandler('playerDropped', function(reason)
    local src = source
    Police.emit('playerDropped', src, reason)
    stamps[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then Police.emit('shutdown') end
end)

---------------------------------------------------------------------
-- Config sanity checks (warn, never crash)
---------------------------------------------------------------------
CreateThread(function()
    for key, dept in pairs(Config.Departments) do
        if not Config.DepartmentTypes[dept.type] then
            print(('^3[tsrp-police] department "%s" has unknown type "%s"^7'):format(key, tostring(dept.type)))
        end
        local perm = Config.Permissions.departments[key]
        if not perm or not perm.node then
            print(('^3[tsrp-police] department "%s" has no permission node in config/permissions.lua - nobody can use it^7'):format(key))
        end
    end
    if GetConvar('onesync', 'off') == 'off' then
        print('^1[tsrp-police] OneSync is off. Blips, 911 and panic locations need OneSync.^7')
    end
end)
