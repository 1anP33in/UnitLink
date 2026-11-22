---------------------------------------------------------------------
-- DOT: Work Orders (server)
--
-- Work orders live in memory while open and in ul_dot_orders always.
-- Units are on-duty UnitLink-Police members whose department type has
-- Config.Dot.accessFlag. DOT keeps their status (AVAIL, ENRT, ONSCN, WORK,
-- BUSY, UNAV) and assigned vehicle here. Every request goes through
-- UL.handle (kind = 'dot'): on duty, DOT access, rate limit, supervisor.
---------------------------------------------------------------------
Dot = { orders = {}, units = {}, viewers = {} }
local D = Config.Dot
if not D or not D.enabled then return end

local STATUS, ONCALL = {}, {}
for _, s in ipairs(D.statuses) do STATUS[s.code] = s; if s.onCall then ONCALL[s.code] = true end end
local CAT = {}
for _, c in ipairs(D.categories) do CAT[c] = true end
local FLEET, EQUIP = {}, {}
for _, v in ipairs(D.fleet) do FLEET[v.id] = v end
for _, e in ipairs(D.equipment) do EQUIP[e.id] = e end
local ASSETS = {}
for _, v in ipairs(D.fleet) do ASSETS[#ASSETS + 1] = v.id end
for _, e in ipairs(D.equipment) do ASSETS[#ASSETS + 1] = e.item end
local LISTS = { directions = D.directions, closureReasons = D.closureReasons, assets = ASSETS }
local FORMS = {}
for _, f in ipairs(D.forms) do FORMS[f.key] = f end
local inList = UL.inList

local dirty = true
local function markDirty() dirty = true end

local function isDot(u) return u and u.flags and u.flags[D.accessFlag] == true end
local function shortName(name)
    local first, last = tostring(name):match('^(%S+)%s+(.+)$')
    return last and (last:upper() .. ',' .. first:sub(1, 1):upper()) or tostring(name):upper()
end
local function unitState(src)
    local s = Dot.units[src]
    if not s then s = { status = 'AVAIL', vehicle = nil, orders = {} }; Dot.units[src] = s end
    return s
end
local function unitMap()
    local m = {}
    for _, u in ipairs(Bridge.units()) do m[u.source] = u end
    return m
end

function Dot.pushAll(kind, data) for src in pairs(Dot.viewers) do UL.push(src, kind, data) end end

function Dot.note(id, author, body, system)
    body = tostring(body):sub(1, 500)
    UL.DB.insert('INSERT INTO ul_dot_notes (order_id, author, body, is_system) VALUES (?, ?, ?, ?)', { id, author, body, system and 1 or 0 })
    Dot.pushAll('dotNote', { id = id, note = { at = os.time(), author = author, body = body, system = system == true } })
end

local function dotUnits()
    local list, seen = {}, {}
    for _, u in ipairs(Bridge.units()) do
        if isDot(u) then
            seen[u.source] = true
            local s = unitState(u.source)
            s.callsign = u.callsign
            local ids = {}
            for id in pairs(s.orders) do if Dot.orders[id] then ids[#ids + 1] = id end end
            table.sort(ids)
            list[#list + 1] = { source = u.source, name = shortName(u.name), fullName = u.name, callsign = u.callsign, dept = u.departmentShort,
                status = s.status, vehicle = s.vehicle, orders = ids, coords = Bridge.coords(u.source) }
        end
    end
    for src, s in pairs(Dot.units) do
        if not seen[src] then
            for id in pairs(s.orders) do
                local o = Dot.orders[id]
                if o then o.units[src] = nil; Dot.note(id, 'SYSTEM', ('(SYSTEM) %s went off duty and was cleared'):format(s.callsign or 'Unit'), true) end
            end
            Dot.units[src] = nil
        end
    end
    return list
end

local function view(o, umap)
    umap = umap or unitMap()
    local us = {}
    for src in pairs(o.units) do
        local s, u = Dot.units[src], umap[src]
        if s and u then us[#us + 1] = { src = src, callsign = u.callsign, status = s.status, name = u.name, vehicle = s.vehicle } end
    end
    table.sort(us, function(a, b) return a.callsign < b.callsign end)
    return { id = o.id, category = o.category, description = o.description, priority = o.priority, status = o.status, street = o.street,
        coords = o.coords, requester = o.requester, origin = o.origin, equipment = o.equipment, completion = o.completion,
        createdAt = o.createdAt, units = us }
end

function Dot.board()
    local units = dotUnits()
    local umap = unitMap()
    local list = {}
    for _, o in pairs(Dot.orders) do list[#list + 1] = view(o, umap) end
    table.sort(list, function(a, b) if a.priority ~= b.priority then return a.priority < b.priority end return a.id < b.id end)
    return { orders = list, units = units, now = os.time() }
end

local function persist(o)
    UL.DB.update('UPDATE ul_dot_orders SET category = ?, description = ?, priority = ?, status = ?, equipment = ?, completion = ? WHERE id = ?',
        { o.category, o.description, o.priority, o.status, UL.json(o.equipment), o.completion, o.id })
end

local function coordsOf(src)
    local c = Bridge.coords(src)
    return c and { x = c.x, y = c.y, z = c.z } or { x = 0.0, y = 0.0, z = 0.0 }
end

-- shared by the tablet, the Civilian Portal (service requests) and other resources
function Dot.newOrder(d)
    local id = UL.DB.insert([[INSERT INTO ul_dot_orders (category, description, priority, status, street, pos_x, pos_y, pos_z, requester, requester_char, origin, equipment)
        VALUES (?, ?, ?, 'OPEN', ?, ?, ?, ?, ?, ?, ?, ?)]], { d.category, d.description, d.priority, d.street, d.coords.x, d.coords.y, d.coords.z,
        d.requester, d.requesterChar, d.origin or 'cad', UL.json(d.equipment or {}) })
    if not id then return nil end
    local o = { id = id, category = d.category, description = d.description, priority = d.priority, status = 'OPEN', street = d.street, coords = d.coords,
        requester = d.requester, requesterChar = d.requesterChar, origin = d.origin or 'cad', equipment = d.equipment or {}, completion = nil,
        createdAt = os.time(), units = {} }
    Dot.orders[id] = o
    markDirty()
    return o
end

local function attach(src, id, callsign)
    local o = Dot.orders[id]
    if not o then return false, 'That work order is closed.' end
    if o.units[src] then return true end
    local s = unitState(src)
    o.units[src] = true
    s.orders[id] = true
    s.status = 'ENRT'
    if o.status == 'OPEN' then o.status = 'ASSIGNED'; persist(o) end
    Dot.note(id, 'SYSTEM', ('(SYSTEM) %s attached'):format(callsign), true)
    markDirty()
    return true
end

local function detach(src, id, callsign)
    local o, s = Dot.orders[id], Dot.units[src]
    if o then o.units[src] = nil end
    if s then s.orders[id] = nil; if not next(s.orders) and ONCALL[s.status] then s.status = 'AVAIL' end end
    if o then
        if not next(o.units) and o.status == 'ASSIGNED' then o.status = 'OPEN'; persist(o) end
        Dot.note(id, 'SYSTEM', ('(SYSTEM) %s cleared'):format(callsign), true)
    end
    markDirty()
end

CreateThread(function()
    while not UL.ready do Wait(500) end
    for _, r in ipairs(UL.DB.query([[SELECT id, category, description, priority, status, street, pos_x, pos_y, pos_z, requester, requester_char, origin, equipment,
        completion, UNIX_TIMESTAMP(created_at) AS at FROM ul_dot_orders WHERE status <> 'CLOSED']]) or {}) do
        Dot.orders[r.id] = { id = r.id, category = r.category, description = r.description, priority = r.priority, status = r.status, street = r.street,
            coords = { x = r.pos_x, y = r.pos_y, z = r.pos_z }, requester = r.requester, requesterChar = r.requester_char, origin = r.origin,
            equipment = UL.decode(r.equipment, {}), completion = r.completion, createdAt = r.at, units = {} }
    end
end)

CreateThread(function()
    local since = 0
    while true do
        Wait(400)
        since = since + 400
        if next(Dot.viewers) and (dirty or since >= 5000) then
            dirty, since = false, 0
            local board = Dot.board()
            for src in pairs(Dot.viewers) do
                local o = UL.officer(src)
                if o and o.kind == 'dot' then UL.push(src, 'dotBoard', board)
                else Dot.viewers[src] = nil; UL.push(src, 'forceClose', 'You no longer have DOT CAD access.') end
            end
        end
    end
end)
RegisterNetEvent('unitlink:server:closed', function() Dot.viewers[source] = nil end)
AddEventHandler('playerDropped', function() Dot.viewers[source] = nil end)

---------------------------------------------------------------------
-- Open
---------------------------------------------------------------------
function Dot.open(o)
    Dot.viewers[o.src] = true
    local s = unitState(o.src)
    UL.DB.query([[INSERT INTO ul_dot_members (member_id, name, callsign, last_seen) VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE name = VALUES(name), callsign = VALUES(callsign), last_seen = CURRENT_TIMESTAMP]], { o.charId, o.name:sub(1, 64), o.callsign })
    return true, {
        kind = 'dot', name = Config.Name,
        me = { src = o.src, callsign = o.callsign, short = o.short, name = o.name, dept = o.dept, supervisor = o.supervisor, vehicle = s.vehicle },
        statuses = D.statuses, categories = D.categories, filters = D.filters, orderStatuses = D.orderStatuses, dispositions = D.dispositions,
        fleet = D.fleet, equipment = D.equipment, closureReasons = D.closureReasons, directions = D.directions, certifications = D.certifications,
        forms = UL.formsForUi(D.forms, LISTS), minNarrative = D.minNarrative, board = Dot.board(),
    }
end

local function H(action, opts, fn) opts = opts or {}; opts.kind = 'dot'; UL.handle(action, opts, fn) end

H('dot.board', nil, function() return true, Dot.board() end)

H('dot.setStatus', nil, function(o, p)
    local code = tostring(p.code or '')
    if not STATUS[code] then return false, 'Unknown status.' end
    local s = unitState(o.src)
    if ONCALL[code] and not next(s.orders) then return false, 'Attach to a work order first.' end
    if s.status == code then return true end
    s.status = code
    for id in pairs(s.orders) do
        local ord = Dot.orders[id]
        if code == 'WORK' and ord and ord.status ~= 'IN PROGRESS' then ord.status = 'IN PROGRESS'; persist(ord) end
        Dot.note(id, o.label, ('(SYSTEM) %s status: %s (%s)'):format(o.callsign, code, STATUS[code].label:upper()), true)
    end
    markDirty()
    return true
end)

H('dot.create', nil, function(o, p)
    if not CAT[p.category] then return false, 'Pick a category.' end
    local desc = UL.clean(p.description, 500)
    if not desc or #desc < 5 then return false, 'Describe the job.' end
    local pri = UL.int(p.priority)
    if not pri or pri < 1 or pri > 3 then pri = 3 end
    local ord = Dot.newOrder({ category = p.category, description = desc, priority = pri, street = UL.clean(p.street, 120), coords = coordsOf(o.src),
        requester = o.label, origin = 'cad' })
    if not ord then return false, 'Database error. The work order was not created.' end
    Dot.note(ord.id, 'SYSTEM', ('(SYSTEM) Work order created by %s'):format(o.label), true)
    if p.attach ~= false then attach(o.src, ord.id, o.callsign) end
    UL.activity(o, ('Created WO-%d (%s)'):format(ord.id, ord.category))
    return true, { id = ord.id }
end)

H('dot.get', nil, function(o, p)
    local id = UL.int(p.id)
    if not id then return false, 'Invalid work order.' end
    local live, closed = Dot.orders[id], nil
    local x, y
    if live then x, y = live.coords.x, live.coords.y
    else
        closed = UL.DB.single([[SELECT id, category, description, priority, status, street, pos_x, pos_y, requester, origin, equipment, completion,
            disposition, units, closed_by, UNIX_TIMESTAMP(created_at) AS createdAt, UNIX_TIMESTAMP(closed_at) AS closedAt FROM ul_dot_orders WHERE id = ?]], { id })
        if not closed then return false, 'Work order not found.' end
        closed.equipment = UL.decode(closed.equipment, {})
        x, y = closed.pos_x, closed.pos_y
    end
    local notes = UL.DB.query('SELECT author, body, is_system, UNIX_TIMESTAMP(created_at) AS at FROM ul_dot_notes WHERE order_id = ? ORDER BY id LIMIT 300', { id }) or {}
    for _, n in ipairs(notes) do n.system = n.is_system == 1 or n.is_system == true; n.is_system = nil end
    local r = D.nearbyMeters or 60
    local history = UL.DB.query([[SELECT id, category, disposition, units, UNIX_TIMESTAMP(closed_at) AS at FROM ul_dot_orders
        WHERE status = 'CLOSED' AND id <> ? AND pos_x BETWEEN ? AND ? AND pos_y BETWEEN ? AND ? ORDER BY id DESC LIMIT 25]], { id, x - r, x + r, y - r, y + r }) or {}
    return true, { order = live and view(live) or nil, closed = closed, notes = notes, history = history }
end)

H('dot.update', nil, function(o, p)
    local ord = Dot.orders[UL.int(p.id) or 0]
    if not ord then return false, 'That work order is closed.' end
    if p.category ~= nil and p.category ~= ord.category then
        if not CAT[p.category] then return false, 'Unknown category.' end
        Dot.note(ord.id, o.label, ('(SYSTEM) Category: %s → %s'):format(ord.category, p.category), true); ord.category = p.category
    end
    if p.status ~= nil and p.status ~= ord.status then
        if not inList(D.orderStatuses, p.status) then return false, 'Unknown job status.' end
        Dot.note(ord.id, o.label, ('(SYSTEM) Job status: %s → %s'):format(ord.status, p.status), true); ord.status = p.status
    end
    if p.priority ~= nil then
        local pri = UL.int(p.priority)
        if not pri or pri < 1 or pri > 3 then return false, 'Priority is 1 to 3.' end
        if pri ~= ord.priority then Dot.note(ord.id, o.label, ('(SYSTEM) Priority: %d → %d'):format(ord.priority, pri), true); ord.priority = pri end
    end
    if p.description ~= nil then
        local d = UL.clean(p.description, 500)
        if not d or #d < 5 then return false, 'Describe the job.' end
        if d ~= ord.description then ord.description = d; Dot.note(ord.id, o.label, '(SYSTEM) Description edited', true) end
    end
    if p.completion ~= nil then ord.completion = UL.cleanText(p.completion, 2000) end
    persist(ord)
    markDirty()
    return true
end)

H('dot.equipment', nil, function(o, p)
    local ord = Dot.orders[UL.int(p.id) or 0]
    if not ord then return false, 'That work order is closed.' end
    if p.add then
        local item = UL.clean(p.add, 60)
        if not item or #item < 2 then return false, 'Name the equipment.' end
        if #ord.equipment >= 15 then return false, 'Up to 15 items.' end
        ord.equipment[#ord.equipment + 1] = item
        Dot.note(ord.id, o.label, '(SYSTEM) Equipment added: ' .. item, true)
    elseif p.remove then
        local i = UL.int(p.remove)
        local item = i and table.remove(ord.equipment, i)
        if not item then return false, 'Not on the list.' end
        Dot.note(ord.id, o.label, '(SYSTEM) Equipment removed: ' .. item, true)
    end
    persist(ord)
    markDirty()
    return true
end)

H('dot.assign', nil, function(o, p) return attach(o.src, UL.int(p.id) or 0, o.callsign) end)
H('dot.detach', nil, function(o, p)
    local id = UL.int(p.id) or 0
    local s = Dot.units[o.src]
    if not s or not s.orders[id] then return false, 'You are not on that work order.' end
    detach(o.src, id, o.callsign)
    return true
end)

H('dot.note', nil, function(o, p)
    local id = UL.int(p.id) or 0
    if not Dot.orders[id] then return false, 'That work order is closed.' end
    local body = UL.cleanText(p.body, 500)
    if not body or #body == 0 then return false, 'Type a note first.' end
    Dot.note(id, o.label, body, false)
    return true
end)

H('dot.complete', nil, function(o, p)
    local id = UL.int(p.id) or 0
    local ord = Dot.orders[id]
    if not ord then return false, 'That work order is already closed.' end
    if not ord.units[o.src] and not o.supervisor then return false, 'Only units on the job or a supervisor can complete it.' end
    local done = UL.cleanText(p.completion or ord.completion, 2000)
    if not done or #done < (D.minNarrative or 20) then return false, ('Completion notes must be at least %d characters.'):format(D.minNarrative or 20) end
    local dispo = inList(D.dispositions, p.disposition) and p.disposition or D.dispositions[1]
    local signs = {}
    for _, u in ipairs(view(ord).units) do signs[#signs + 1] = u.callsign end
    UL.DB.update([[UPDATE ul_dot_orders SET status = 'CLOSED', completion = ?, disposition = ?, units = ?, closed_by = ?, closed_at = CURRENT_TIMESTAMP,
        category = ?, description = ?, priority = ?, equipment = ? WHERE id = ?]], { done, dispo, table.concat(signs, ', '):sub(1, 255), o.label,
        ord.category, ord.description, ord.priority, UL.json(ord.equipment), id })
    for src in pairs(ord.units) do
        local s = Dot.units[src]
        if s then s.orders[id] = nil; if not next(s.orders) and ONCALL[s.status] then s.status = 'AVAIL' end end
    end
    Dot.orders[id] = nil
    Dot.note(id, 'SYSTEM', ('(SYSTEM) Completed by %s: %s'):format(o.label, dispo), true)
    Dot.pushAll('dotClosed', { id = id, by = o.callsign, disposition = dispo })
    UL.activity(o, ('Completed WO-%d (%s)'):format(id, dispo))
    markDirty()
    return true
end)

H('dot.waypoint', nil, function(o, p)
    local ord = Dot.orders[UL.int(p.id) or 0]
    if not ord then return false, 'That work order is closed.' end
    return true, { coords = ord.coords }
end)

H('dot.history', nil, function()
    local rows = UL.DB.query([[SELECT id, category, description, priority, street, requester, units, disposition, closed_by,
        UNIX_TIMESTAMP(created_at) AS createdAt, UNIX_TIMESTAMP(closed_at) AS closedAt FROM ul_dot_orders
        WHERE status = 'CLOSED' ORDER BY id DESC LIMIT 100]])
    if not rows then return false, 'Database error.' end
    return true, rows
end)

---------------------------------------------------------------------
-- Fleet, equipment, maintenance
---------------------------------------------------------------------
local function fleetState()
    local state = {}
    for _, r in ipairs(UL.DB.query('SELECT vehicle, assigned, status, UNIX_TIMESTAMP(last_service) AS service FROM ul_dot_fleet') or {}) do state[r.vehicle] = r end
    local list = {}
    for _, v in ipairs(D.fleet) do
        local st = state[v.id] or {}
        list[#list + 1] = { id = v.id, type = v.type, assigned = st.assigned, status = st.status or 'AVAILABLE', service = st.service }
    end
    return list
end

-- Never pass nil inside a params table (Lua drops it and the placeholders
-- shift), so "nobody assigned" is written as a literal NULL instead.
local function setFleet(vehicle, assigned, status, serviced)
    local who = assigned and '?' or 'NULL'
    local svc = serviced and ', last_service = CURRENT_TIMESTAMP' or ''
    local params = { vehicle }
    if assigned then params[#params + 1] = assigned end
    params[#params + 1] = status
    UL.DB.query(('INSERT INTO ul_dot_fleet (vehicle, assigned, status%s) VALUES (?, %s, ?%s) ON DUPLICATE KEY UPDATE assigned = VALUES(assigned), status = VALUES(status)%s')
        :format(serviced and ', last_service' or '', who, serviced and ', CURRENT_TIMESTAMP' or '', svc), params)
end

H('dot.fleet', nil, function()
    local equipment = {}
    for _, e in ipairs(D.equipment) do
        local out = UL.DB.query('SELECT id, qty, who, UNIX_TIMESTAMP(created_at) AS at FROM ul_dot_checkouts WHERE item = ? AND returned = 0 ORDER BY id', { e.id }) or {}
        local used = 0
        for _, c in ipairs(out) do used = used + c.qty end
        equipment[#equipment + 1] = { id = e.id, item = e.item, qty = e.qty, available = e.qty - used, out = out }
    end
    local maintenance = UL.DB.query('SELECT id, asset, work, status, logged_by, UNIX_TIMESTAMP(created_at) AS at FROM ul_dot_maintenance ORDER BY id DESC LIMIT 50') or {}
    return true, { fleet = fleetState(), equipment = equipment, maintenance = maintenance }
end)

H('dot.fleetAssign', nil, function(o, p)
    if not FLEET[p.vehicle] then return false, 'Unknown vehicle.' end
    local cur = {}
    for _, v in ipairs(fleetState()) do if v.id == p.vehicle then cur = v end end
    if cur.status == 'OUT OF SERVICE' then return false, p.vehicle .. ' is out of service.' end
    local who = UL.clean(p.assigned, 64)
    setFleet(p.vehicle, who, who and 'IN USE' or 'AVAILABLE')
    if p.self then unitState(o.src).vehicle = p.vehicle; markDirty() end
    UL.activity(o, ('Assigned %s to %s'):format(p.vehicle, who or 'nobody'))
    return true
end)

H('dot.fleetService', nil, function(o, p)
    if not FLEET[p.vehicle] then return false, 'Unknown vehicle.' end
    if p.oos then
        setFleet(p.vehicle, nil, 'OUT OF SERVICE')
        for _, s in pairs(Dot.units) do if s.vehicle == p.vehicle then s.vehicle = nil end end
    else
        setFleet(p.vehicle, nil, 'AVAILABLE', true)
    end
    UL.activity(o, ('%s %s'):format(p.vehicle, p.oos and 'out of service' or 'back in service'))
    markDirty()
    return true
end)

H('dot.setVehicle', nil, function(o, p)
    local s = unitState(o.src)
    if p.vehicle == nil or p.vehicle == '' then s.vehicle = nil; markDirty(); return true end
    if not FLEET[p.vehicle] then return false, 'Unknown vehicle.' end
    for _, v in ipairs(fleetState()) do if v.id == p.vehicle and v.status == 'OUT OF SERVICE' then return false, p.vehicle .. ' is out of service.' end end
    s.vehicle = p.vehicle
    setFleet(p.vehicle, o.name, 'IN USE')
    markDirty()
    return true
end)

H('dot.checkout', nil, function(o, p)
    local e = EQUIP[p.item]
    if not e then return false, 'Unknown item.' end
    local qty = UL.int(p.qty)
    local used = UL.DB.scalar('SELECT COALESCE(SUM(qty), 0) FROM ul_dot_checkouts WHERE item = ? AND returned = 0', { e.id }) or 0
    if not qty or qty < 1 or qty > e.qty - used then return false, ('Pick 1 to %d.'):format(e.qty - used) end
    UL.DB.insert('INSERT INTO ul_dot_checkouts (item, qty, who) VALUES (?, ?, ?)', { e.id, qty, o.label })
    UL.activity(o, ('Checked out %s x%d'):format(e.item, qty))
    return true
end)

H('dot.return', nil, function(o, p)
    local n = UL.DB.update('UPDATE ul_dot_checkouts SET returned = 1 WHERE id = ? AND returned = 0', { UL.int(p.id) or 0 }) or 0
    if n == 0 then return false, 'Already returned.' end
    return true
end)

H('dot.maintAdd', nil, function(o, p)
    if not inList(ASSETS, p.asset) then return false, 'Pick a vehicle or item.' end
    local work = UL.clean(p.work, 255)
    if not work or #work < 3 then return false, 'Describe the work.' end
    local status = p.status == 'DONE' and 'DONE' or 'OPEN'
    UL.DB.insert('INSERT INTO ul_dot_maintenance (asset, work, status, logged_by) VALUES (?, ?, ?, ?)', { p.asset, work, status, o.label })
    if FLEET[p.asset] and status == 'DONE' then
        local cur = 'AVAILABLE'
        for _, v in ipairs(fleetState()) do if v.id == p.asset and v.status == 'IN USE' then cur = 'IN USE' end end
        setFleet(p.asset, nil, cur, true)
    end
    return true
end)

H('dot.maintDone', nil, function(o, p)
    local r = UL.DB.single("SELECT id, asset FROM ul_dot_maintenance WHERE id = ? AND status = 'OPEN'", { UL.int(p.id) or 0 })
    if not r then return false, 'Already done.' end
    UL.DB.update("UPDATE ul_dot_maintenance SET status = 'DONE' WHERE id = ?", { r.id })
    if FLEET[r.asset] then setFleet(r.asset, nil, 'AVAILABLE', true) end
    return true
end)

---------------------------------------------------------------------
-- Reports
---------------------------------------------------------------------
local function orderExists(id)
    return Dot.orders[id] ~= nil or (UL.DB.scalar('SELECT COUNT(*) FROM ul_dot_orders WHERE id = ?', { id }) or 0) > 0
end

H('dot.submitReport', nil, function(o, p)
    local form = FORMS[p.form]
    if not form then return false, 'Unknown report type.' end
    local data, meta = UL.validateForm(form, p.data, { lists = LISTS, minNarrative = D.minNarrative, incidentExists = orderExists })
    if not data then return false, meta end
    local id = UL.DB.insert('INSERT INTO ul_dot_reports (form, order_id, author_char, author_label, data) VALUES (?, ?, ?, ?, ?)',
        { form.key, meta.incident, o.charId, o.label, UL.json(data) })
    if not id then return false, 'Database error. The report was not saved.' end
    local prefix = ({ hazard = 'RHZ', recovery = 'VRR', closure = 'RCR', inspection = 'RIN', maintdone = 'MCR', damage = 'EDR' })[form.key] or 'RPT'
    local number, extra = ('%s-%d'):format(prefix, id), nil
    if form.key == 'closure' then
        local status = o.supervisor and 'ACTIVE' or 'REQUESTED'
        UL.DB.insert('INSERT INTO ul_dot_closures (road, direction, reason, until_text, detour, status, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { data.road, data.direction, data.reason, UL.clean(data['until'], 48), data.detour, status, o.label })
        extra = status == 'ACTIVE' and 'closure is active' or 'waiting for a supervisor'
        if status == 'ACTIVE' then for _, u in ipairs(Bridge.units()) do UL.notify(u.source, ('**Road closed:** %s (%s)'):format(data.road, data.reason), 'warning') end end
        Dot.pushAll('dotAlerts', {})
    elseif form.key == 'hazard' and tostring(data.severity):find('^HIGH') then
        for _, u in ipairs(Bridge.units()) do UL.notify(u.source, ('**Major highway hazard:** %s · %s'):format(data.htype or 'HAZARD', data.location), 'warning') end
        extra = 'broadcast to every on-duty unit'
    elseif form.key == 'damage' and tostring(data.serviceable):find('^NO') then
        UL.DB.insert('INSERT INTO ul_dot_maintenance (asset, work, status, logged_by) VALUES (?, ?, ?, ?)', { data.asset, (data.desc or 'Damage reported'):sub(1, 255), 'OPEN', o.label })
        if FLEET[data.asset] then setFleet(data.asset, nil, 'OUT OF SERVICE') end
        extra = 'taken out of service'
    end
    if meta.incident and Dot.orders[meta.incident] then Dot.note(meta.incident, o.label, ('(SYSTEM) %s %s filed'):format(form.label:upper(), number), true) end
    UL.activity(o, ('Filed %s (%s)'):format(number, form.label))
    return true, { number = number, note = extra }
end)

H('dot.myReports', nil, function(o)
    local rows = UL.DB.query('SELECT id, form, order_id, UNIX_TIMESTAMP(created_at) AS at FROM ul_dot_reports WHERE author_char = ? ORDER BY id DESC LIMIT 50', { o.charId })
    if not rows then return false, 'Database error.' end
    return true, rows
end)

H('dot.getReport', nil, function(o, p)
    local r = UL.DB.single('SELECT id, form, order_id, author_label, data, UNIX_TIMESTAMP(created_at) AS at FROM ul_dot_reports WHERE id = ?', { UL.int(p.id) or 0 })
    if not r then return false, 'Report not found.' end
    r.data = UL.decode(r.data, {})
    return true, r
end)

---------------------------------------------------------------------
-- Road alerts: closures, announcements
---------------------------------------------------------------------
H('dot.alerts', nil, function()
    return true, {
        closures = UL.DB.query([[SELECT id, road, direction, reason, until_text, detour, status, created_by, UNIX_TIMESTAMP(created_at) AS at
            FROM ul_dot_closures WHERE status <> 'REOPENED' ORDER BY id DESC LIMIT 50]]) or {},
        announcements = UL.DB.query('SELECT id, title, body, created_by, UNIX_TIMESTAMP(created_at) AS at FROM ul_dot_announcements ORDER BY id DESC LIMIT 10') or {},
    }
end)

H('dot.closureApprove', { supervisor = true }, function(o, p)
    local r = UL.DB.single("SELECT id, road, reason FROM ul_dot_closures WHERE id = ? AND status = 'REQUESTED'", { UL.int(p.id) or 0 })
    if not r then return false, 'That closure is not waiting for approval.' end
    UL.DB.update("UPDATE ul_dot_closures SET status = 'ACTIVE' WHERE id = ?", { r.id })
    for _, u in ipairs(Bridge.units()) do UL.notify(u.source, ('**Road closed:** %s (%s)'):format(r.road, r.reason), 'warning') end
    UL.activity(o, 'Approved road closure: ' .. r.road)
    Dot.pushAll('dotAlerts', {})
    return true
end)

H('dot.closureReopen', nil, function(o, p)
    local r = UL.DB.single("SELECT id, road, status FROM ul_dot_closures WHERE id = ? AND status <> 'REOPENED'", { UL.int(p.id) or 0 })
    if not r then return false, 'That road is already open.' end
    if r.status == 'ACTIVE' and not o.supervisor then return false, 'Supervisors reopen active closures.' end
    UL.DB.update("UPDATE ul_dot_closures SET status = 'REOPENED' WHERE id = ?", { r.id })
    if r.status == 'ACTIVE' then for _, u in ipairs(Bridge.units()) do UL.notify(u.source, ('**Road reopened:** %s'):format(r.road), 'success') end end
    Dot.pushAll('dotAlerts', {})
    return true
end)

H('dot.announce', { supervisor = true }, function(o, p)
    local title = UL.clean(p.title, 80)
    if not title or #title < 3 then return false, 'Give it a title.' end
    local body = UL.cleanText(p.body, 600)
    UL.DB.insert('INSERT INTO ul_dot_announcements (title, body, created_by) VALUES (?, ?, ?)', { title, body, o.label })
    for _, u in ipairs(Bridge.units()) do
        if isDot(u) then UL.notify(u.source, ('**%s**%s'):format(title, body and body ~= '' and (' · ' .. body) or ''), 'announce') end
    end
    Dot.pushAll('dotAlerts', {})
    return true
end)

---------------------------------------------------------------------
-- Roster / certifications
---------------------------------------------------------------------
H('dot.roster', nil, function()
    local rows = UL.DB.query('SELECT member_id, name, callsign, certs, UNIX_TIMESTAMP(last_seen) AS seen FROM ul_dot_members ORDER BY name LIMIT 200') or {}
    local onDuty = {}
    for _, u in ipairs(dotUnits()) do local id = Identity.officerId(u.source); if id then onDuty[id] = u end end
    for _, r in ipairs(rows) do
        r.certs = UL.decode(r.certs, {})
        local u = onDuty[r.member_id]
        if u then r.onDuty = { callsign = u.callsign, status = u.status, vehicle = u.vehicle } end
    end
    return true, rows
end)

H('dot.setCerts', { supervisor = true }, function(o, p)
    local id = UL.int(p.member)
    if not id then return false, 'Pick a member.' end
    local certs = {}
    for _, c in ipairs(type(p.certs) == 'table' and p.certs or {}) do if inList(D.certifications, c) then certs[#certs + 1] = c end end
    local n = UL.DB.update('UPDATE ul_dot_members SET certs = ? WHERE member_id = ?', { UL.json(certs), id }) or 0
    if n == 0 then return false, 'Member not found.' end
    return true
end)

exports('CreateWorkOrder', function(data)
    if type(data) ~= 'table' or not CAT[data.category] then return nil end
    local o = Dot.newOrder({ category = data.category, description = tostring(data.description or ''):sub(1, 500), priority = tonumber(data.priority) or 3,
        street = data.street, coords = data.coords or { x = 0.0, y = 0.0, z = 0.0 }, requester = data.requester, origin = 'agency' })
    return o and o.id or nil
end)
