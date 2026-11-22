---------------------------------------------------------------------
-- UnitLink server core
--   * one request pipeline for every CAD action (validated, rate limited,
--     access checked, errors never leak to the client)
--   * pushes live updates to tablets that are open
--   * database helper + automatic table install
---------------------------------------------------------------------
UL = { handlers = {}, viewers = {} }

local RES = GetCurrentResourceName()

---------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------
function UL.trim(s)
    return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- Clean player text: no control chars / GTA ~codes~ / angle brackets, capped
function UL.clean(s, max)
    if type(s) ~= 'string' then return nil end
    s = UL.trim(s:gsub('%c', ' '):gsub('[~<>]', ''):gsub('[ \t]+', ' '))
    if max and #s > max then s = s:sub(1, max) end
    return s
end

-- Multi-line text (narratives): keeps line breaks
function UL.cleanText(s, max)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('\r', ''):gsub('[\0-\9\11-\31]', ' '):gsub('[~<>]', '')
    s = UL.trim(s)
    if max and #s > max then s = s:sub(1, max) end
    return s
end

function UL.int(v)
    v = tonumber(v)
    if not v or v ~= v or v % 1 ~= 0 then return nil end
    return math.floor(v)
end

function UL.json(v)
    local ok, s = pcall(json.encode, v)
    return ok and s or '{}'
end

function UL.decode(s, default)
    if type(s) ~= 'string' or s == '' then return default end
    local ok, v = pcall(json.decode, s)
    return ok and v or default
end

function UL.log(msg)
    print(('[unitlink] %s'):format(msg))
end

---------------------------------------------------------------------
-- Database (oxmysql). Every call is protected; nil = database error.
---------------------------------------------------------------------
UL.DB = {}
local function dbCall(kind, query, params)
    local ok, result = pcall(MySQL[kind].await, query, params or {})
    if not ok then
        UL.log('^1database error: ' .. tostring(result) .. '^7')
        return nil
    end
    return result
end
function UL.DB.query(q, p) return dbCall('query', q, p) end
function UL.DB.single(q, p) return dbCall('single', q, p) end
function UL.DB.scalar(q, p) return dbCall('scalar', q, p) end
function UL.DB.insert(q, p) return dbCall('insert', q, p) end
function UL.DB.update(q, p) return dbCall('update', q, p) end

UL.ready = false
MySQL.ready(function() CreateThread(function()
    if Config.AutoInstallSql then
        local sql = LoadResourceFile(RES, 'sql/install.sql') or ''
        sql = sql:gsub('%-%-[^\n]*', '')
        for statement in sql:gmatch('[^;]+') do
            if statement:find('%S') then UL.DB.query(statement) end
        end
    end
    local ok = UL.DB.scalar('SELECT COUNT(*) FROM ul_records') ~= nil
    UL.ready = ok
    if ok then
        UL.log('^2database ready^7')
    else
        UL.log('^1ul_ tables are missing. Run sql/install.sql or set Config.AutoInstallSql = true.^7')
    end
end) end)

---------------------------------------------------------------------
-- Rate limiting
---------------------------------------------------------------------
local stamps = {}
local function limited(src)
    local now = GetGameTimer()
    if stamps[src] and now - stamps[src] < (Config.RateLimitMs or 250) then return true end
    stamps[src] = now
    return false
end

---------------------------------------------------------------------
-- Access: who is asking? (fresh every request, never trusted from client)
-- Returns officer table or nil, error
---------------------------------------------------------------------
function UL.officer(src)
    local unit = Bridge.unit(src)
    if not unit then return nil, 'You must be on duty to use ' .. Config.Name .. '.' end
    if Config.AccessFlag and not (unit.flags and unit.flags[Config.AccessFlag]) then
        return nil, 'Your department does not have CAD access.'
    end
    local charId = Bridge.characterId(src)
    if not charId then return nil, 'No character loaded.' end
    local first, last = unit.name:match('^(%S+)%s+(.+)$')
    local short = last and (last:upper() .. ',' .. first:sub(1, 1):upper()) or unit.name:upper()
    return {
        src = src, charId = charId, callsign = unit.callsign, name = unit.name, short = short,
        dept = unit.departmentShort, status = unit.status, calls = unit.calls,
        label = ('%s (%s)'):format(short, unit.callsign),
        supervisor = Bridge.isSupervisor(src),
    }
end

---------------------------------------------------------------------
-- Request pipeline
--   UL.handle(action, { supervisor = bool }, function(officer, payload) return ok, data end)
---------------------------------------------------------------------
function UL.handle(action, opts, fn)
    UL.handlers[action] = { fn = fn, supervisor = opts and opts.supervisor }
end

RegisterNetEvent('unitlink:server:req', function(reqId, action, payload)
    local src = source
    if type(reqId) ~= 'number' or type(action) ~= 'string' then return end
    local function reply(ok, data)
        TriggerClientEvent('unitlink:client:res', src, reqId, ok == true, data)
    end
    local h = UL.handlers[action]
    if not h then return reply(false, 'Unknown request.') end
    if limited(src) then return reply(false, 'Slow down.') end
    if not UL.ready and action ~= 'open' then return reply(false, 'CAD database is not ready.') end

    local officer, err = UL.officer(src)
    if not officer then return reply(false, err) end
    if h.supervisor and not officer.supervisor then return reply(false, 'Supervisors only.') end

    local ok, success, data = pcall(h.fn, officer, type(payload) == 'table' and payload or {})
    if not ok then
        UL.log('^1error in "' .. action .. '": ' .. tostring(success) .. '^7')
        return reply(false, 'Server error. Try again.')
    end
    reply(success, data)
end)

---------------------------------------------------------------------
-- Open / close tracking + live pushes
---------------------------------------------------------------------
function UL.push(src, kind, data)
    TriggerClientEvent('unitlink:client:push', src, kind, data)
end

function UL.pushAll(kind, data)
    for src in pairs(UL.viewers) do UL.push(src, kind, data) end
end

RegisterNetEvent('unitlink:server:closed', function()
    UL.viewers[source] = nil
end)

AddEventHandler('playerDropped', function()
    UL.viewers[source] = nil
    stamps[source] = nil
end)

-- Notify through tsrp-ui (falls back to chat-less silence if tsrp-ui is down)
function UL.notify(target, message, kind)
    if GetResourceState('tsrp-ui') ~= 'started' then return end
    pcall(function()
        exports['tsrp-ui']:Notify(target, { type = kind or 'info', title = Config.Name, message = message, duration = 4000 })
    end)
end

-- Signal 100 (shared state)
UL.signal100 = false
