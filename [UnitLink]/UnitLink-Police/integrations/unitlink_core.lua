---------------------------------------------------------------------
-- UnitLink Core adapter (server only)
--
-- Every call from UnitLink-Police to the framework goes through this file.
-- Integration contract (checked against UnitLink-Core 1.0.0 server/api.lua):
--   exports HasPermission(src, node)   -> boolean, uses the ACTIVE character
--   exports IsPlayerLoaded(src)        -> boolean
--   exports GetCharacterId(src)        -> number | nil
--   exports GetCharacter(src)          -> { id, firstname, lastname, fullname, ... } | nil
--   local events (AddEventHandler, never net events):
--     unitlink-core:server:characterUnloaded  (src, characterId, reason)
--     unitlink-core:server:permissionsUpdated (characterId, src | nil)
--     unitlink-core:server:groupsChanged      (groupName, action)
--
-- If UnitLink-Core is not running, permission checks FAIL CLOSED (nobody can
-- go on duty) and a warning is printed once.
---------------------------------------------------------------------
Framework = {}

local RESOURCE = Config.Framework.resource
local warned = false

function Framework.enabled()
    return Config.Framework.enabled == true
end

function Framework.active()
    if not Framework.enabled() then return false end
    local state = GetResourceState(RESOURCE)
    if state == 'started' then
        warned = false
        return true
    end
    if not warned then
        warned = true
        print(('^1[UnitLink-Police] framework "%s" is %s. Duty access is blocked until it starts.^7'):format(RESOURCE, state))
    end
    return false
end

local function call(name, ...)
    if not Framework.active() then return false end
    local args = table.pack(...)
    local ok, result = pcall(function()
        local core = exports[RESOURCE]
        return core[name](core, table.unpack(args, 1, args.n))
    end)
    if not ok then
        print(('^1[UnitLink-Police] UnitLink-Core export %s failed: %s^7'):format(name, tostring(result)))
        return false
    end
    return true, result
end

function Framework.hasPermission(src, node)
    local ok, allowed = call('HasPermission', src, node)
    return ok and allowed == true
end

function Framework.isLoaded(src)
    local ok, loaded = call('IsPlayerLoaded', src)
    return ok and loaded == true
end

function Framework.characterId(src)
    local ok, id = call('GetCharacterId', src)
    return ok and tonumber(id) or nil
end

function Framework.characterName(src)
    local ok, char = call('GetCharacter', src)
    if ok and type(char) == 'table' then
        return char.fullname or ((char.firstname or '') .. ' ' .. (char.lastname or ''))
    end
end

---------------------------------------------------------------------
-- Framework lifecycle -> duty
---------------------------------------------------------------------
if Framework.enabled() then
    -- Character switched / unloaded: that character's duty session ends
    AddEventHandler('unitlink-core:server:characterUnloaded', function(src, _, reason)
        src = tonumber(src)
        if src and Config.Framework.clockOutOnUnload and Duty.isOnDuty(src) then
            Duty.clockOut(src, 'character_' .. tostring(reason or 'unload'))
            if GetPlayerName(src) then
                Police.notify(src, 'You were taken off duty because your character changed.', 'info', 'Duty')
            end
        end
    end)

    -- Groups / overrides changed: make sure on-duty units still have access
    AddEventHandler('unitlink-core:server:permissionsUpdated', function(_, src)
        src = tonumber(src)
        if src then Duty.revalidate(src) else Duty.revalidateAll() end
    end)

    AddEventHandler('unitlink-core:server:groupsChanged', function()
        Duty.revalidateAll()
    end)

    -- Framework stopped or restarted: nobody keeps an unverifiable session
    AddEventHandler('onResourceStop', function(res)
        if res == RESOURCE then
            for src in pairs(Duty.all()) do
                Duty.clockOut(src, 'framework_stopped')
            end
        end
    end)
end
