---------------------------------------------------------------------
-- Calls + units: live board, call record, notes, history.
-- Call state is owned by UnitLink-Police; UnitLink adds notes / history.
---------------------------------------------------------------------
local CODE_TO_STATUS, STATUS_TO_CODE = {}, {}
for _, s in ipairs(Config.Statuses) do
    CODE_TO_STATUS[s.code] = s.status
    STATUS_TO_CODE[s.status] = s.code
end

local NATURES = {}
for _, n in ipairs(Config.Natures) do NATURES[n] = true end

local lastView = {} -- [callId] = latest call view (used for history on close)
local dirty = true

local function markDirty() dirty = true end
UL.markDirty = markDirty

---------------------------------------------------------------------
-- Notes
---------------------------------------------------------------------
function UL.note(callId, author, body, system, charId)
    UL.DB.insert('INSERT INTO ul_call_notes (call_id, author, author_char, body, is_system) VALUES (?, ?, ?, ?, ?)',
        { callId, author, charId, body:sub(1, 500), system and 1 or 0 })
    UL.pushAll('note', { callId = callId, note = { at = os.time(), author = author, body = body, system = system == true } })
end

---------------------------------------------------------------------
-- Board (calls + units)
---------------------------------------------------------------------
local function shortName(name)
    local first, last = tostring(name):match('^(%S+)%s+(.+)$')
    return last and (last:upper() .. ',' .. first:sub(1, 1):upper()) or tostring(name):upper()
end

function UL.board()
    local calls = Bridge.calls()
    for _, c in ipairs(calls) do lastView[c.id] = c end
    local units = {}
    for _, u in ipairs(Bridge.units()) do
        units[#units + 1] = {
            source = u.source, name = shortName(u.name), callsign = u.callsign,
            dept = u.departmentShort, type = u.type,
            code = STATUS_TO_CODE[u.status] or 'UNAV', calls = u.calls,
            coords = Bridge.coords(u.source),
        }
    end
    return { calls = calls, units = units, signal100 = UL.signal100, now = os.time() }
end

-- Push the board to open tablets: on changes (debounced) and every 5s for positions
CreateThread(function()
    local sinceFull = 0
    while true do
        Wait(400)
        sinceFull = sinceFull + 400
        if next(UL.viewers) and (dirty or sinceFull >= 5000) then
            dirty, sinceFull = false, 0
            local board = UL.board()
            for src in pairs(UL.viewers) do
                local o = UL.officer(src)
                if o and o.kind == 'leo' then
                    UL.push(src, 'board', board)
                else
                    UL.viewers[src] = nil
                    UL.push(src, 'forceClose', 'You no longer have CAD access.')
                end
            end
        end
    end
end)

---------------------------------------------------------------------
-- UnitLink-Police events (local server events)
---------------------------------------------------------------------
AddEventHandler('unitlink-police:server:callCreated', function(c)
    if type(c) ~= 'table' or not c.id then return end
    lastView[c.id] = c
    if c.origin == '911' then
        UL.note(c.id, 'SYSTEM', ('911 CALL RECEIVED FROM %s: %s'):format(tostring(c.callerName):upper(), c.message or ''), true)
    else
        UL.note(c.id, 'SYSTEM', ('(SYSTEM) Call created by %s'):format(c.callerName or '?'), true)
        if c.message and c.message ~= '' then UL.note(c.id, 'SYSTEM', c.message, true) end
    end
    markDirty()
end)

AddEventHandler('unitlink-police:server:callUpdated', function(c, action)
    if type(c) ~= 'table' or not c.id then return end
    local prev = lastView[c.id]
    lastView[c.id] = c
    if prev and (action == 'accepted' or action == 'cancelled') then
        local before, after = {}, {}
        for _, u in ipairs(prev.units or {}) do before[u.src] = u.callsign end
        for _, u in ipairs(c.units or {}) do after[u.src] = u.callsign end
        for src, cs in pairs(after) do
            if not before[src] then UL.note(c.id, 'SYSTEM', ('(SYSTEM) %s attached to call'):format(cs), true) end
        end
        for src, cs in pairs(before) do
            if not after[src] then UL.note(c.id, 'SYSTEM', ('(SYSTEM) %s cleared from call'):format(cs), true) end
        end
    end
    markDirty()
end)

AddEventHandler('unitlink-police:server:callClosed', function(id, reason, by)
    id = tonumber(id)
    if not id then return end
    local c = lastView[id]
    lastView[id] = nil
    if c then
        local unitList = {}
        for _, u in ipairs(c.units or {}) do unitList[#unitList + 1] = u.callsign end
        UL.DB.insert([[INSERT INTO ul_call_history (call_id, nature, priority, address, caller, units, pos_x, pos_y, close_reason, closed_by, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?))
            ON DUPLICATE KEY UPDATE close_reason = VALUES(close_reason), closed_by = VALUES(closed_by), closed_at = CURRENT_TIMESTAMP]],
            { id, c.nature or '911 CALL', c.priority or 2, (c.street or ''):sub(1, 120), (c.callerName or ''):sub(1, 64),
              table.concat(unitList, ', '):sub(1, 255), c.coords and c.coords.x or 0, c.coords and c.coords.y or 0,
              tostring(reason or 'closed'):sub(1, 24), by, c.createdAt or os.time() })
    end
    UL.note(id, 'SYSTEM', ('(SYSTEM) Call %s%s'):format(reason == 'expired' and 'expired' or 'closed', by and (' by ' .. by) or ''), true)
    UL.pushAll('callClosed', { id = id, reason = reason, by = by })
    markDirty()
end)

AddEventHandler('unitlink-police:server:unitsChanged', markDirty)

---------------------------------------------------------------------
-- Requests
---------------------------------------------------------------------
UL.handle('open', { kind = 'any' }, function(o)
    if o.kind == 'fire' then return Fire.open(o) end
    UL.viewers[o.src] = true
    local statuses = {}
    for _, s in ipairs(Config.Statuses) do statuses[#statuses + 1] = { code = s.code, label = s.label } end
    local laws = {}
    for _, l in ipairs(Config.Laws) do laws[#laws + 1] = { code = l.code, offense = l.offense, class = l.class, points = l.points or 0, fine = l.fine or 0, note = l.note, aliases = l.aliases } end
    return true, {
        name = Config.Name,
        me = { callsign = o.callsign, short = o.short, name = o.name, dept = o.dept, charId = o.charId, supervisor = o.supervisor },
        statuses = statuses, natures = Config.Natures, laws = laws,
        reportTypes = Config.ReportTypes, bookings = Config.Bookings, warrantTypes = Config.WarrantTypes, alertTypes = Config.AlertTypes,
        suspendAt = Config.Licenses.suspendAt, warrantsNeedApproval = Config.WarrantsNeedApproval,
        fines = { enabled = Config.Fines and Config.Fines.enabled == true, expireDays = Config.Fines and Config.Fines.expireDays or 0, symbol = Config.Fines and Config.Fines.symbol or '$' },
        identity = Identity.mode(),
        board = UL.board(),
    }
end)

UL.handle('board', nil, function() return true, UL.board() end)

UL.handle('getCall', nil, function(o, p)
    local id = UL.int(p.id)
    if not id then return false, 'Invalid call.' end
    local c = Bridge.call(id)
    local closed = nil
    if not c then
        closed = UL.DB.single([[SELECT call_id AS id, nature, priority, address AS street, caller AS callerName, units, close_reason, closed_by,
            UNIX_TIMESTAMP(created_at) AS createdAt, UNIX_TIMESTAMP(closed_at) AS closedAt, pos_x, pos_y FROM ul_call_history WHERE call_id = ?]], { id })
        if not closed then return false, 'Call not found.' end
    end
    local notes = UL.DB.query('SELECT author, body, is_system, UNIX_TIMESTAMP(created_at) AS at FROM ul_call_notes WHERE call_id = ? ORDER BY id LIMIT 300', { id }) or {}
    for _, n in ipairs(notes) do n.system = n.is_system == 1 or n.is_system == true; n.is_system = nil end
    local x = c and c.coords and c.coords.x or (closed and closed.pos_x) or 0
    local y = c and c.coords and c.coords.y or (closed and closed.pos_y) or 0
    local history = UL.DB.query([[SELECT call_id, nature, close_reason, units, UNIX_TIMESTAMP(closed_at) AS at FROM ul_call_history
        WHERE call_id <> ? AND pos_x BETWEEN ? AND ? AND pos_y BETWEEN ? AND ? ORDER BY closed_at DESC LIMIT 15]],
        { id, x - 60, x + 60, y - 60, y + 60 }) or {}
    local returns = UL.DB.query('SELECT subject_name, result, hit, UNIX_TIMESTAMP(created_at) AS at FROM ul_returns WHERE call_id = ? ORDER BY id DESC LIMIT 50', { id }) or {}
    return true, { call = c, closed = closed, notes = notes, history = history, returns = returns }
end)

UL.handle('addNote', nil, function(o, p)
    local id = UL.int(p.id)
    local body = UL.clean(p.body, 500)
    if not id or not body or body == '' then return false, 'Type a comment first.' end
    if not Bridge.call(id) then return false, 'Call is closed.' end
    UL.note(id, o.label, body, false, o.charId)
    return true
end)

UL.handle('assign', nil, function(o, p)
    local ok, err = Bridge.assign(o.src, UL.int(p.id))
    if not ok then return false, err or 'Could not attach.' end
    markDirty()
    return true
end)

UL.handle('detach', nil, function(o, p)
    local ok, err = Bridge.unassign(o.src, UL.int(p.id))
    if not ok then return false, err or 'Could not detach.' end
    markDirty()
    return true
end)

UL.handle('setStatus', nil, function(o, p)
    local status = CODE_TO_STATUS[p.code]
    if not status then return false, 'Invalid status.' end
    if (p.code == 'ENRT' or p.code == 'ARRVD') and #o.calls == 0 then return false, 'Attach to a call first.' end
    if not Bridge.setStatus(o.src, status) then return false, 'Status could not be changed.' end
    if p.code == 'ENRT' or p.code == 'ARRVD' then
        for _, callId in ipairs(o.calls) do UL.note(callId, o.label, ('(SYSTEM) Status updated: %s'):format(p.code), true, o.charId) end
    end
    markDirty()
    return true
end)

UL.handle('createCall', nil, function(o, p)
    local nature = NATURES[p.nature] and p.nature or 'SELF-INITIATED'
    local priority = UL.int(p.priority) or 3
    local id, err = Bridge.createCall(o.src, {
        nature = nature, priority = priority,
        message = UL.clean(p.notes, 250) or '', street = UL.clean(p.street, 80),
    })
    if not id then return false, err or 'Could not create the call.' end
    markDirty()
    return true, { id = id }
end)

UL.handle('updateCall', nil, function(o, p)
    local id = UL.int(p.id)
    local before = id and Bridge.call(id)
    if not before then return false, 'Call is closed.' end
    local fields = {}
    if p.nature ~= nil then
        if not NATURES[p.nature] then return false, 'Invalid nature.' end
        fields.nature = p.nature
    end
    if p.priority ~= nil then fields.priority = UL.int(p.priority) end
    local ok, err = Bridge.updateCall(o.src, id, fields)
    if not ok then return false, err end
    if fields.nature and fields.nature ~= before.nature then
        UL.note(id, o.label, ('(SYSTEM) Nature updated: %s → %s'):format(before.nature, fields.nature), true, o.charId)
    end
    if fields.priority and fields.priority ~= before.priority then
        UL.note(id, o.label, ('(SYSTEM) Priority updated: %d → %d'):format(before.priority, fields.priority), true, o.charId)
    end
    markDirty()
    return true
end)

UL.handle('closeCall', nil, function(o, p)
    local ok, err = Bridge.closeCall(o.src, UL.int(p.id))
    if not ok then return false, err or 'Could not close the call.' end
    return true
end)

UL.handle('waypoint', nil, function(o, p)
    local c = Bridge.call(UL.int(p.id))
    if not c or not c.coords then return false, 'Call location unknown.' end
    return true, { coords = c.coords }
end)

UL.handle('callHistory', nil, function()
    local rows = UL.DB.query([[SELECT call_id, nature, priority, address, caller, units, close_reason, closed_by,
        UNIX_TIMESTAMP(created_at) AS createdAt, UNIX_TIMESTAMP(closed_at) AS closedAt FROM ul_call_history ORDER BY closed_at DESC LIMIT 100]])
    if not rows then return false, 'Database error.' end
    return true, rows
end)

UL.handle('signal100', nil, function(o, p)
    if Config.Signal100SupervisorOnly and not o.supervisor then return false, 'Only supervisors can set Signal 100.' end
    UL.signal100 = p.on == true
    UL.pushAll('signal100', { on = UL.signal100, by = o.callsign })
    for _, u in ipairs(Bridge.units()) do
        UL.notify(u.source, UL.signal100 and ('**SIGNAL 100** set by %s. Emergency radio traffic only.'):format(o.callsign)
            or ('Signal 100 cleared by %s.'):format(o.callsign), UL.signal100 and 'warning' or 'info')
    end
    return true
end)
