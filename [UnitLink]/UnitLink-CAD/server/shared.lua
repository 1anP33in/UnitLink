---------------------------------------------------------------------
-- Shared tools: every department tablet (police, SAFR, DOT) has a
-- Tools window with the same features:
--   global search, messages, shared BOLOs, incident links,
--   activity log, employee profiles.
-- All requests are kind = 'any' (on duty in any UnitLink department).
---------------------------------------------------------------------
local T = Config.Tools or {}
if T.enabled == false then return end
local inList = UL.inList

local function H(action, opts, fn) opts = opts or {}; opts.kind = 'any'; UL.handle(action, opts, fn) end
local LINK_TYPES = { call = true, fire = true, dot = true }
local LINK_PREFIX = { call = '#', fire = 'F-', dot = 'WO-' }

-- on-duty units with their member id (for messages)
local function onDuty()
    local list = {}
    for _, u in ipairs(Bridge.units()) do
        list[#list + 1] = { src = u.source, id = Identity.officerId(u.source), name = u.name, callsign = u.callsign, dept = u.departmentShort }
    end
    return list
end

H('tools.open', nil, function(o)
    local units = {}
    for _, u in ipairs(onDuty()) do units[#units + 1] = { id = u.id, name = u.name, callsign = u.callsign, dept = u.dept } end
    local depts, seen = {}, {}
    for _, u in ipairs(units) do if u.dept and not seen[u.dept] then seen[u.dept] = true; depts[#depts + 1] = u.dept end end
    table.sort(depts)
    return true, { me = { id = o.charId, kind = o.kind, dept = o.dept, label = o.label, supervisor = o.supervisor }, units = units, depts = depts, boloTypes = T.boloTypes or {} }
end)

---------------------------------------------------------------------
-- Global search
---------------------------------------------------------------------
H('tools.search', nil, function(o, p)
    local q = UL.clean(p.q, 48)
    if not q or #q < 2 then return false, 'Type at least 2 characters.' end
    local term = UL.trim((q:gsub('[%%_]', '')))
    if #term < 2 then return false, 'Type at least 2 characters.' end
    local like = '%' .. term .. '%'
    local num = tonumber((q:gsub('^[A-Za-z]+%-?', '')))
    local out = { people = {}, vehicles = {}, calls = {}, fire = {}, dot = {}, records = {}, bolos = {} }

    for _, c in ipairs(Identity.search(q) or {}) do
        out.people[#out.people + 1] = { id = c.id, name = ('%s %s'):format(c.firstname, c.lastname), dob = c.dateofbirth, gender = c.gender }
    end
    out.vehicles = UL.DB.query([[SELECT v.plate, v.model, v.color, v.status, CONCAT(c.firstname, ' ', c.lastname) AS owner FROM ul_civ_vehicles v
        LEFT JOIN ul_civilians c ON c.id = v.civ_id WHERE v.plate LIKE ? OR v.model LIKE ? OR CONCAT(c.firstname, ' ', c.lastname) LIKE ? ORDER BY v.plate LIMIT 15]], { like, like, like }) or {}

    -- police calls: live ones, then history
    for _, c in ipairs(Bridge.calls()) do
        local hay = (tostring(c.id) .. ' ' .. tostring(c.nature) .. ' ' .. tostring(c.street or c.address or '')):lower()
        if hay:find(term:lower(), 1, true) then
            out.calls[#out.calls + 1] = { id = c.id, nature = c.nature, street = c.street or c.address, status = 'ACTIVE' }
        end
    end
    for _, r in ipairs(UL.DB.query([[SELECT call_id AS id, nature, address AS street, close_reason FROM ul_call_history
        WHERE call_id = ? OR nature LIKE ? OR address LIKE ? ORDER BY call_id DESC LIMIT 15]], { num or -1, like, like }) or {}) do
        out.calls[#out.calls + 1] = { id = r.id, nature = r.nature, street = r.street, status = 'CLOSED · ' .. tostring(r.close_reason) }
    end
    out.fire = UL.DB.query([[SELECT id, type, nature, street, status, disposition FROM ul_fire_incidents
        WHERE id = ? OR nature LIKE ? OR street LIKE ? ORDER BY id DESC LIMIT 15]], { num or -1, like, like }) or {}
    out.dot = UL.DB.query([[SELECT id, category, description, street, status FROM ul_dot_orders
        WHERE id = ? OR category LIKE ? OR description LIKE ? OR street LIKE ? ORDER BY id DESC LIMIT 15]], { num or -1, like, like, like }) or {}
    -- records (citations, arrests, warrants) are police information
    if o.kind == 'leo' then
        for _, r in ipairs(UL.DB.query([[SELECT id, type, status, subject_name FROM ul_records WHERE id = ? OR subject_name LIKE ? ORDER BY id DESC LIMIT 15]], { num or -1, like }) or {}) do
            out.records[#out.records + 1] = { id = r.id, number = UL.recordNo(r.type, r.id), type = r.type, status = r.status, subject = r.subject_name }
        end
    end
    out.bolos = UL.DB.query('SELECT id, type, title, plate, dept FROM ul_bolos WHERE active = 1 AND (title LIKE ? OR body LIKE ? OR plate LIKE ?) ORDER BY id DESC LIMIT 15', { like, like, like }) or {}
    return true, out
end)

---------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------
H('tools.messages', nil, function(o)
    local days = tonumber(T.messageDays) or 3
    local rows = UL.DB.query([[SELECT id, from_id, from_label, from_dept, to_kind, to_value, to_label, body, UNIX_TIMESTAMP(created_at) AS at FROM ul_messages
        WHERE created_at > NOW() - INTERVAL ]] .. math.floor(days * 24) .. [[ HOUR AND (to_kind = 'all' OR (to_kind = 'dept' AND to_value = ?) OR (to_kind = 'member' AND to_value = ?) OR from_id = ?)
        ORDER BY id DESC LIMIT 100]], { o.dept, tostring(o.charId), o.charId })
    if not rows then return false, 'Database error.' end
    for _, r in ipairs(rows) do r.mine = r.from_id == o.charId end
    return true, rows
end)

H('tools.send', nil, function(o, p)
    local body = UL.cleanText(p.body, 500)
    if not body or #body < 1 then return false, 'Type a message.' end
    local kind, value, label = 'all', nil, 'ALL UNITS'
    local units = onDuty()
    local targets = {}
    local to = tostring(p.to or 'all')
    if to == 'all' then
        for _, u in ipairs(units) do targets[#targets + 1] = u end
    elseif to:sub(1, 5) == 'dept:' then
        kind, value = 'dept', to:sub(6, 17)
        label = value
        for _, u in ipairs(units) do if u.dept == value then targets[#targets + 1] = u end end
        if #targets == 0 then return false, 'Nobody from ' .. value .. ' is on duty.' end
    elseif to:sub(1, 7) == 'member:' then
        local id = UL.int(to:sub(8))
        for _, u in ipairs(units) do if u.id == id then targets[#targets + 1] = u; label = ('%s (%s)'):format(u.name, u.callsign) end end
        if #targets == 0 then return false, 'That unit is not on duty.' end
        kind, value = 'member', tostring(id)
    else
        return false, 'Pick who gets it.'
    end
    local id = UL.DB.insert('INSERT INTO ul_messages (from_id, from_label, from_dept, to_kind, to_value, to_label, body) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { o.charId, o.label, o.dept, kind, value, label:sub(1, 64), body })
    if not id then return false, 'Database error.' end
    local msg = { id = id, from_label = o.label, from_dept = o.dept, to_kind = kind, to_value = value, to_label = label, body = body, at = os.time() }
    for _, u in ipairs(targets) do
        if u.src ~= o.src then
            UL.push(u.src, 'toolsMessage', msg)
            UL.notify(u.src, ('**Message from %s:** %s'):format(o.label, body:sub(1, 120)), 'info')
        end
    end
    return true, { id = id }
end)

---------------------------------------------------------------------
-- Shared BOLOs (every department sees them)
---------------------------------------------------------------------
H('tools.bolos', nil, function()
    local rows = UL.DB.query('SELECT id, type, title, body, plate, dept, created_by, UNIX_TIMESTAMP(created_at) AS at FROM ul_bolos WHERE active = 1 ORDER BY id DESC LIMIT 100')
    if not rows then return false, 'Database error.' end
    return true, rows
end)

H('tools.addBolo', nil, function(o, p)
    if not inList(T.boloTypes or {}, p.type) then return false, 'Pick a BOLO type.' end
    local title = UL.clean(p.title, 120)
    if not title or #title < 3 then return false, 'Give the BOLO a title.' end
    local plate = UL.clean(p.plate, 12)
    plate = plate and plate ~= '' and plate:upper() or nil
    local id = UL.DB.insert('INSERT INTO ul_bolos (type, title, body, plate, dept, created_by) VALUES (?, ?, ?, ?, ?, ?)',
        { p.type, title, UL.cleanText(p.body, 1000) or '', plate, o.dept, o.label })
    if not id then return false, 'Database error.' end
    for _, u in ipairs(Bridge.units()) do
        UL.push(u.source, 'toolsBolo', {})
        if u.source ~= o.src then UL.notify(u.source, ('**BOLO (%s):** %s%s'):format(p.type, title, plate and (' · ' .. plate) or ''), 'warning') end
    end
    UL.activity(o, 'Posted BOLO: ' .. title)
    return true, { id = id }
end)

H('tools.clearBolo', nil, function(o, p)
    local n = UL.DB.update('UPDATE ul_bolos SET active = 0, cleared_by = ? WHERE id = ? AND active = 1', { o.label, UL.int(p.id) or 0 }) or 0
    if n == 0 then return false, 'BOLO not found.' end
    for _, u in ipairs(Bridge.units()) do UL.push(u.source, 'toolsBolo', {}) end
    return true
end)

---------------------------------------------------------------------
-- Incident links: tie a police call, SAFR incident and DOT work order together
---------------------------------------------------------------------
local function exists(t, id)
    if t == 'call' then return Bridge.call(id) ~= nil or (UL.DB.scalar('SELECT COUNT(*) FROM ul_call_history WHERE call_id = ?', { id }) or 0) > 0 end
    if t == 'fire' then return (UL.DB.scalar('SELECT COUNT(*) FROM ul_fire_incidents WHERE id = ?', { id }) or 0) > 0 end
    if t == 'dot' then return (UL.DB.scalar('SELECT COUNT(*) FROM ul_dot_orders WHERE id = ?', { id }) or 0) > 0 end
    return false
end

H('tools.links', nil, function(o, p)
    local t, id = tostring(p.type or ''), UL.int(p.id)
    if not LINK_TYPES[t] or not id then return false, 'Pick an incident.' end
    local rows = UL.DB.query([[SELECT id, a_type, a_id, b_type, b_id, created_by FROM ul_links WHERE (a_type = ? AND a_id = ?) OR (b_type = ? AND b_id = ?) ORDER BY id]], { t, id, t, id }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local ot, oid = r.b_type, r.b_id
        if r.b_type == t and r.b_id == id then ot, oid = r.a_type, r.a_id end
        out[#out + 1] = { id = r.id, type = ot, ref = oid, label = (LINK_PREFIX[ot] or '#') .. oid, by = r.created_by }
    end
    return true, out
end)

H('tools.link', nil, function(o, p)
    local a, b = type(p.a) == 'table' and p.a or {}, type(p.b) == 'table' and p.b or {}
    local at, ai, bt, bi = tostring(a.type or ''), UL.int(a.id), tostring(b.type or ''), UL.int(b.id)
    if not LINK_TYPES[at] or not LINK_TYPES[bt] or not ai or not bi then return false, 'Pick both incidents.' end
    if at == bt and ai == bi then return false, 'Pick two different incidents.' end
    if not exists(at, ai) then return false, (LINK_PREFIX[at] .. ai) .. ' does not exist.' end
    if not exists(bt, bi) then return false, (LINK_PREFIX[bt] .. bi) .. ' does not exist.' end
    -- store in a fixed order so A-B and B-A are the same link
    if at > bt or (at == bt and ai > bi) then at, ai, bt, bi = bt, bi, at, ai end
    if (UL.DB.scalar('SELECT COUNT(*) FROM ul_links WHERE a_type = ? AND a_id = ? AND b_type = ? AND b_id = ?', { at, ai, bt, bi }) or 0) > 0 then
        return false, 'Already linked.'
    end
    UL.DB.insert('INSERT INTO ul_links (a_type, a_id, b_type, b_id, created_by) VALUES (?, ?, ?, ?, ?)', { at, ai, bt, bi, o.label })
    UL.activity(o, ('Linked %s%d and %s%d'):format(LINK_PREFIX[at], ai, LINK_PREFIX[bt], bi))
    return true
end)

H('tools.unlink', nil, function(o, p)
    local n = UL.DB.update('DELETE FROM ul_links WHERE id = ?', { UL.int(p.id) or 0 }) or 0
    if n == 0 then return false, 'Link not found.' end
    return true
end)

---------------------------------------------------------------------
-- Activity + employee profiles
---------------------------------------------------------------------
H('tools.activity', nil, function(o, p)
    local rows
    if p.scope == 'dept' then
        if not o.supervisor then return false, 'Supervisors only.' end
        rows = UL.DB.query('SELECT name, callsign, dept, action, UNIX_TIMESTAMP(created_at) AS at FROM ul_activity WHERE dept = ? ORDER BY id DESC LIMIT 150', { o.dept })
    else
        rows = UL.DB.query('SELECT name, callsign, dept, action, UNIX_TIMESTAMP(created_at) AS at FROM ul_activity WHERE member_id = ? ORDER BY id DESC LIMIT 150', { o.charId })
    end
    if not rows then return false, 'Database error.' end
    return true, rows
end)

H('tools.profiles', nil, function(o, p)
    local q = UL.clean(p.q, 32) or ''
    q = UL.trim((q:gsub('[%%_]', '')))
    local like = '%' .. q .. '%'
    local rows = UL.DB.query([[SELECT member_id, name, callsign, dept, kind, UNIX_TIMESTAMP(last_seen) AS seen FROM ul_employees
        WHERE name LIKE ? OR callsign LIKE ? OR dept LIKE ? ORDER BY dept, name LIMIT 150]], { like, like, like })
    if not rows then return false, 'Database error.' end
    local live = {}
    for _, u in ipairs(onDuty()) do if u.id then live[u.id] = u end end
    for _, r in ipairs(rows) do
        local u = live[r.member_id]
        r.onDuty = u ~= nil
        local certs = nil
        if r.kind == 'fire' then certs = UL.DB.scalar('SELECT certs FROM ul_fire_members WHERE member_id = ?', { r.member_id })
        elseif r.kind == 'dot' then certs = UL.DB.scalar('SELECT certs FROM ul_dot_members WHERE member_id = ?', { r.member_id }) end
        r.certs = UL.decode(certs, {})
    end
    return true, rows
end)

H('tools.profile', nil, function(o, p)
    local id = UL.int(p.id)
    if not id then return false, 'Pick an employee.' end
    local e = UL.DB.single('SELECT member_id, name, callsign, dept, kind, UNIX_TIMESTAMP(last_seen) AS seen FROM ul_employees WHERE member_id = ?', { id })
    if not e then return false, 'Employee not found.' end
    -- activity of others: supervisors of that department only
    if id == o.charId or (o.supervisor and e.dept == o.dept) then
        e.activity = UL.DB.query('SELECT action, UNIX_TIMESTAMP(created_at) AS at FROM ul_activity WHERE member_id = ? ORDER BY id DESC LIMIT 40', { id }) or {}
    end
    return true, e
end)
