---------------------------------------------------------------------
-- 911 calls. All state lives here; clients only send requests
-- (submit / accept / deny / waypoint / cancel / close) that are validated.
--
-- Other server resources (UnitLink CAD) use the exports at the bottom
-- and listen to these LOCAL server events (never net events):
--   unitlink-police:server:callCreated  (call)
--   unitlink-police:server:callUpdated  (call, action)
--   unitlink-police:server:callClosed   (callId, reason, closedByCallsign)
---------------------------------------------------------------------
Calls = {}

local CS = Police.CallStatus
local calls = {}       -- [id] = call
local lastCallAt = {}  -- [source] = os.time() of their last 911

local KVP_LAST_ID = 'unitlink_police:lastCallId'
local lastId = math.max(GetResourceKvpInt(KVP_LAST_ID), (Config.Emergency.firstCallId or 1001) - 1)

local function nextId()
    lastId = lastId + 1
    SetResourceKvpInt(KVP_LAST_ID, lastId)
    return lastId
end

local function openCount()
    local n = 0
    for _ in pairs(calls) do n = n + 1 end
    return n
end

---------------------------------------------------------------------
-- What units see (only sent to on-duty units with receives911)
---------------------------------------------------------------------
local function unitsView(call)
    local list = {}
    for _, src in ipairs(call.order) do
        local u = call.units[src]
        if u then list[#list + 1] = { src = src, callsign = u.callsign, department = u.short } end
    end
    return list
end

local function view(call)
    return {
        id = call.id, callerName = call.callerName, message = call.message,
        nature = call.nature, priority = call.priority, origin = call.origin,
        coords = call.coords, street = call.street,
        time = os.date('%H:%M', call.createdAt), createdAt = call.createdAt,
        status = call.status, units = unitsView(call),
    }
end

local function recipients(fn) Duty.each('receives911', fn) end

local function broadcast(event, ...)
    local args = table.pack(...)
    recipients(function(src) Police.toClient(src, event, table.unpack(args, 1, args.n)) end)
end

-- Tell other resources (UnitLink) about a change
local function external(event, ...)
    TriggerEvent('unitlink-police:server:' .. event, ...)
end

local function refreshStatus(call)
    call.status = next(call.units) and CS.ACTIVE or CS.PENDING
end

local function callFields(call)
    return {
        { name = 'Call', value = '#' .. call.id, inline = true },
        { name = 'Caller', value = call.caller and ('%s (ID %d)'):format(call.callerName, call.caller) or call.callerName, inline = true },
        { name = 'Location', value = call.street, inline = true },
    }
end

local function updated(call, actor)
    broadcast('callUpdate', view(call), actor)
    external('callUpdated', view(call), actor and actor.action or 'updated')
end

---------------------------------------------------------------------
-- Assignments
---------------------------------------------------------------------
local function assign(src, call)
    if call.units[src] then return false end
    local s = Duty.get(src)
    call.units[src] = { callsign = s.callsign, short = Config.Departments[s.department].short, acceptedAt = os.time() }
    call.order[#call.order + 1] = src
    call.denied[src] = nil
    s.calls[call.id] = true
    refreshStatus(call)
    Duty.markResponding(src)

    local fields = callFields(call)
    for _, f in ipairs(Log.officer(s, 'Unit ')) do fields[#fields + 1] = f end
    Log.event('call_accepted', fields)
    updated(call, { action = 'accepted', callsign = s.callsign, src = src })
    return true
end

local function unassign(src, call, reason)
    if not call.units[src] then return false end
    local u = call.units[src]
    call.units[src] = nil
    for i, id in ipairs(call.order) do
        if id == src then table.remove(call.order, i) break end
    end
    local s = Duty.get(src)
    if s then
        s.calls[call.id] = nil
        Duty.refreshStatus(src)
    end
    refreshStatus(call)

    local fields = callFields(call)
    fields[#fields + 1] = { name = 'Unit', value = u.callsign .. ' · ' .. u.short, inline = true }
    fields[#fields + 1] = { name = 'Reason', value = reason, inline = true }
    Log.event('call_cancelled', fields)
    updated(call, { action = 'cancelled', callsign = u.callsign, src = src })
    return true
end

function Calls.close(call, reason, bySrc)
    if not calls[call.id] then return end
    calls[call.id] = nil
    for src in pairs(call.units) do
        local s = Duty.get(src)
        if s then
            s.calls[call.id] = nil
            Duty.refreshStatus(src)
        end
    end
    local by = bySrc and Duty.get(bySrc)
    local fields = callFields(call)
    fields[#fields + 1] = { name = 'Open for', value = Utils.formatDuration(os.time() - call.createdAt), inline = true }
    if by then fields[#fields + 1] = { name = 'Closed by', value = by.callsign, inline = true } end
    Log.event(reason == 'expired' and 'call_expired' or 'call_closed', fields)
    broadcast('callRemoved', call.id, reason, by and by.callsign or nil)
    external('callClosed', call.id, reason, by and by.callsign or nil)
end

local function canClose(src, call)
    local s = Duty.get(src)
    if not s then return false end
    return call.units[src] ~= nil or Permissions.isSupervisor(src, s.department) or Permissions.isAdmin(src)
end

---------------------------------------------------------------------
-- Create a call (911 or CAD). Returns the call.
--   opts: caller (src|nil), callerName, message, coords, street,
--         nature, priority, origin ('911'|'cad'), quiet (no popup cards)
---------------------------------------------------------------------
local function createCall(opts)
    local now = os.time()
    local call = {
        id = nextId(),
        caller = opts.caller,
        callerName = opts.callerName or 'Unknown',
        message = opts.message or '',
        nature = opts.nature or '911 CALL',
        priority = math.max(1, math.min(3, math.floor(tonumber(opts.priority) or Config.Emergency.priority or 2))),
        origin = opts.origin or '911',
        coords = opts.coords,
        -- street text is for logs / fallback; units resolve the street from coords themselves
        street = (opts.street and opts.street ~= '') and opts.street or 'Unknown location',
        createdAt = now,
        expiresAt = now + Config.Emergency.callLifetime,
        status = CS.PENDING,
        units = {}, order = {}, denied = {},
    }
    calls[call.id] = call

    local fields = callFields(call)
    fields[#fields + 1] = Log.coords(call.coords)
    Log.event('call_submitted', fields, call.message)

    -- quiet calls (e.g. self-initiated traffic stops) are stored without popping cards
    broadcast(opts.quiet and 'callUpdate' or 'callNew', view(call))
    -- second argument: the caller's server id (local server event only, never sent to clients)
    external('callCreated', view(call), call.caller)
    return call
end

---------------------------------------------------------------------
-- /911 submission
---------------------------------------------------------------------
Police.net('submitCall', 'call', function(src, message, street)
    local E = Config.Emergency
    if not Config.Enabled or not E.enabled then
        return Police.notify(src, '911 is not available right now.', 'error', '911')
    end

    message = Utils.sanitize(message, E.maxLength + 1)
    if not message or Utils.length(message) < (E.minLength or 1) then
        return Police.notify(src, ('Describe your emergency: **/%s [what is happening]**'):format(Config.Commands.call), 'error', '911')
    end
    if Utils.length(message) > E.maxLength then
        return Police.notify(src, ('Keep your call under %d characters.'):format(E.maxLength), 'error', '911')
    end

    local now = os.time()
    local wait = (lastCallAt[src] or 0) + E.cooldown - now
    if wait > 0 then
        return Police.notify(src, ('Please wait **%ds** before calling again.'):format(wait), 'warning', '911')
    end
    if openCount() >= E.maxActiveCalls then
        return Police.notify(src, 'All dispatch lines are busy. Try again shortly.', 'error', '911')
    end

    local coords = Police.coords(src)
    if not coords then
        return Police.notify(src, 'Your location could not be found. Try again.', 'error', '911')
    end

    lastCallAt[src] = now
    local call = createCall({
        caller = src, callerName = Police.displayName(src), message = message,
        coords = coords, street = Utils.sanitize(street, 80), origin = '911',
    })

    local sent = Duty.count('receives911')
    if sent > 0 then
        Police.notify(src, ('Your call **#%d** was sent. Help is on the way.'):format(call.id), 'success', '911')
    else
        Police.notify(src, ('Your call **#%d** was logged, but no units are on duty right now.'):format(call.id), 'warning', '911')
    end
end)

---------------------------------------------------------------------
-- Unit actions: accept | deny | waypoint | cancel | close
---------------------------------------------------------------------
Police.net('callAction', 'callAction', function(src, action, id)
    id = tonumber(id)
    if type(action) ~= 'string' or not id then return end
    local s = Duty.get(src)
    if not s or not Utils.deptHas(s.department, 'receives911') then
        return Police.notify(src, Police.errorText('no_access'), 'error', '911')
    end
    local call = calls[id]
    if not call then
        Police.toClient(src, 'callRemoved', id, 'gone')
        return Police.notify(src, ('Call #%d is no longer open.'):format(id), 'warning', '911')
    end

    if action == 'accept' then
        if assign(src, call) then
            Police.notify(src, ('Responding to **#%d**.'):format(id), 'success', '911', 3000)
        end
    elseif action == 'waypoint' then
        assign(src, call)
        Police.toClient(src, 'setWaypoint', call.coords, ('#%d'):format(id))
    elseif action == 'deny' then
        if call.units[src] then return end -- responding units cancel instead
        call.denied[src] = true
        Police.toClient(src, 'callDenied', id)
    elseif action == 'cancel' then
        if unassign(src, call, 'cancelled') then
            Police.notify(src, ('No longer responding to **#%d**.'):format(id), 'info', '911', 3000)
        end
    elseif action == 'close' then
        if not canClose(src, call) then
            return Police.notify(src, 'Only responding units or supervisors can close a call.', 'error', '911')
        end
        Calls.close(call, 'closed', src)
    end
end)

-- Full list for /calls (and after clocking in)
local function sendSnapshot(src)
    local list = {}
    for _, call in pairs(calls) do
        local v = view(call)
        v.denied = call.denied[src] == true
        list[#list + 1] = v
    end
    table.sort(list, function(a, b) return a.id > b.id end)
    Police.toClient(src, 'callsSnapshot', list)
end

Police.net('requestCalls', 'calls', function(src)
    local s = Duty.get(src)
    if not s or not Utils.deptHas(s.department, 'receives911') then return end
    sendSnapshot(src)
end)

---------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------
Police.on('clockIn', function(s)
    if Utils.deptHas(s.department, 'receives911') then sendSnapshot(s.source) end
end)

-- Clock-out / disconnect: drop the officer from every call
Police.on('clockOut', function(s)
    for id in pairs(s.calls) do
        local call = calls[id]
        if call then unassign(s.source, call, s.endReason) end
    end
    for _, call in pairs(calls) do call.denied[s.source] = nil end
end)

Police.on('playerDropped', function(src) lastCallAt[src] = nil end)

-- Expire old calls
CreateThread(function()
    while true do
        Wait(10000)
        local now = os.time()
        for _, call in pairs(calls) do
            if now >= call.expiresAt then Calls.close(call, 'expired') end
        end
    end
end)

---------------------------------------------------------------------
-- Server exports for trusted resources (UnitLink CAD).
-- The calling resource is responsible for checking WHO asked; these
-- still enforce duty / department / close rules for the acting unit.
-- All return true | false, errorText unless noted.
---------------------------------------------------------------------
local function unitOk(src)
    src = tonumber(src)
    local s = src and Duty.get(src)
    if not s or not Utils.deptHas(s.department, 'receives911') then return nil, Police.errorText('not_on_duty') end
    return src, s
end

-- List of open calls (newest first)
exports('GetCalls', function()
    local list = {}
    for _, call in pairs(calls) do list[#list + 1] = view(call) end
    table.sort(list, function(a, b) return a.id > b.id end)
    return list
end)

exports('GetCall', function(id)
    local call = calls[tonumber(id) or -1]
    return call and view(call) or nil
end)

-- data: { nature, message, priority, street, coords = {x,y,z}? }
-- coords default to the unit's own position. The creating unit is attached.
-- Returns callId | nil, errorText
exports('CreateCall', function(bySrc, data)
    local src, s = unitOk(bySrc)
    if not src then return nil, s end
    if type(data) ~= 'table' then return nil, 'Invalid call data.' end
    if openCount() >= Config.Emergency.maxActiveCalls then return nil, 'Too many open calls.' end
    local coords = Police.coords(src)
    if type(data.coords) == 'table' and tonumber(data.coords.x) and tonumber(data.coords.y) then
        coords = { x = tonumber(data.coords.x) + 0.0, y = tonumber(data.coords.y) + 0.0, z = (tonumber(data.coords.z) or 0) + 0.0 }
    end
    if not coords then return nil, 'Location unavailable.' end
    local call = createCall({
        caller = nil, callerName = ('%s (%s)'):format(s.callsign, s.name),
        message = Utils.sanitize(data.message, Config.Emergency.maxLength) or '',
        nature = Utils.sanitize(data.nature, 40) or 'SELF-INITIATED',
        priority = data.priority, origin = 'cad',
        street = Utils.sanitize(data.street, 80), coords = coords, quiet = data.quiet ~= false,
    })
    assign(src, call)
    return call.id
end)

-- fields: { nature?, priority?, message? }
exports('UpdateCall', function(bySrc, id, fields)
    local src, s = unitOk(bySrc)
    if not src then return false, s end
    local call = calls[tonumber(id) or -1]
    if not call then return false, 'Call is no longer open.' end
    if type(fields) ~= 'table' then return false, 'Invalid fields.' end
    local changed = false
    if fields.nature ~= nil then
        local n = Utils.sanitize(fields.nature, 40)
        if n and n ~= '' and n ~= call.nature then call.nature = n; changed = true end
    end
    if fields.priority ~= nil then
        local p = math.floor(tonumber(fields.priority) or 0)
        if p >= 1 and p <= 3 and p ~= call.priority then call.priority = p; changed = true end
    end
    if fields.message ~= nil then
        local m = Utils.sanitize(fields.message, Config.Emergency.maxLength)
        if m and m ~= call.message then call.message = m; changed = true end
    end
    if changed then updated(call, { action = 'edited', callsign = s.callsign, src = src }) end
    return true
end)

exports('AssignUnit', function(unitSrc, id)
    local src, err = unitOk(unitSrc)
    if not src then return false, err end
    local call = calls[tonumber(id) or -1]
    if not call then return false, 'Call is no longer open.' end
    if call.units[src] then return true end
    return assign(src, call)
end)

exports('UnassignUnit', function(unitSrc, id)
    local src, err = unitOk(unitSrc)
    if not src then return false, err end
    local call = calls[tonumber(id) or -1]
    if not call then return false, 'Call is no longer open.' end
    return unassign(src, call, 'cancelled')
end)

exports('CloseCall', function(bySrc, id)
    local src, err = unitOk(bySrc)
    if not src then return false, err end
    local call = calls[tonumber(id) or -1]
    if not call then return false, 'Call is no longer open.' end
    if not canClose(src, call) then return false, 'Only responding units or supervisors can close a call.' end
    Calls.close(call, 'closed', src)
    return true
end)
