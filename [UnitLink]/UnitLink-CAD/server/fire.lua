---------------------------------------------------------------------
-- SAFR: Fire & Rescue CAD (server)
--
-- Incidents live in memory while active and in ul_fire_incidents always.
-- Units are the on-duty UnitLink-Police members whose department type has
-- Config.Fire.accessFlag; SAFR keeps their status (AVAIL, ENRT, ONSCN, TRANS,
-- ATHSP, BUSY, OOS) and apparatus here, separate from police statuses.
-- Every request goes through UL.handle (kind = 'fire'), so it is checked
-- again on the server: on duty, SAFR access, rate limit, supervisor.
---------------------------------------------------------------------
Fire = { incidents = {}, units = {}, viewers = {}, apparatusOOS = {}, mayday = nil }
local F = Config.Fire
if not F or not F.enabled then return end

local STATUS, ONCALL = {}, {}
for _, s in ipairs(F.statuses) do STATUS[s.code] = s; if s.onCall then ONCALL[s.code] = true end end
local TYPES = {}
for t, natures in pairs(F.types) do TYPES[t] = {}; for _, n in ipairs(natures) do TYPES[t][n] = true end end
local APPARATUS = {}
for _, a in ipairs(F.apparatus) do APPARATUS[a.id] = a end
local function inList(list, v) for _, x in ipairs(list or {}) do if x == v then return true end end return false end
local LISTS = {
    severities = F.severities, conditions = F.conditions, hospitals = F.hospitals,
    ['hospitals+'] = (function() local t = {} for _, h in ipairs(F.hospitals) do t[#t + 1] = h end t[#t + 1] = 'REFUSED TRANSPORT'; t[#t + 1] = 'NOT TRANSPORTED' return t end)(),
}
local FORMS = {}
for _, f in ipairs(F.forms) do FORMS[f.key] = f end

local dirty = true
local function markDirty() dirty = true end

---------------------------------------------------------------------
-- Units
---------------------------------------------------------------------
local function isFire(u) return u and u.flags and u.flags[F.accessFlag] == true end

local function shortName(name)
    local first, last = tostring(name):match('^(%S+)%s+(.+)$')
    return last and (last:upper() .. ',' .. first:sub(1, 1):upper()) or tostring(name):upper()
end

local function unitState(src)
    local s = Fire.units[src]
    if not s then s = { status = 'AVAIL', apparatus = nil, incidents = {} }; Fire.units[src] = s end
    return s
end

local function fireUnits()
    local list, seen = {}, {}
    for _, u in ipairs(Bridge.units()) do
        if isFire(u) then
            seen[u.source] = true
            local s = unitState(u.source)
            local ids = {}
            for id in pairs(s.incidents) do if Fire.incidents[id] then ids[#ids + 1] = id end end
            table.sort(ids)
            local app = s.apparatus and APPARATUS[s.apparatus]
            list[#list + 1] = {
                source = u.source, name = shortName(u.name), fullName = u.name, callsign = u.callsign, dept = u.departmentShort,
                status = s.status, apparatus = s.apparatus, station = app and app.station or nil, incidents = ids,
                coords = Bridge.coords(u.source),
            }
        end
    end
    -- units that went off duty: take them off their incidents
    for src, s in pairs(Fire.units) do
        if not seen[src] then
            for id in pairs(s.incidents) do
                local inc = Fire.incidents[id]
                if inc then inc.units[src] = nil; Fire.note(id, 'SYSTEM', ('(SYSTEM) %s went off duty and was cleared'):format(s.callsign or 'Unit'), true) end
            end
            Fire.units[src] = nil
        else
            -- remember the callsign for the message above
            for _, u in ipairs(list) do if u.source == src then s.callsign = u.callsign break end end
        end
    end
    return list
end
Fire.unitsList = fireUnits

local function unitBySrc(src)
    for _, u in ipairs(fireUnits()) do if u.source == src then return u end end
end

---------------------------------------------------------------------
-- Incidents
---------------------------------------------------------------------
-- umap: [source] = police unit (built once per board); nil = look up now
local function unitMap()
    local m = {}
    for _, u in ipairs(Bridge.units()) do m[u.source] = u end
    return m
end

local function view(inc, umap)
    umap = umap or unitMap()
    local us = {}
    for src in pairs(inc.units) do
        local s = Fire.units[src]
        local u = umap[src]
        if s and u then us[#us + 1] = { src = src, callsign = u.callsign, status = s.status, name = u.name, apparatus = s.apparatus } end
    end
    table.sort(us, function(a, b) return a.callsign < b.callsign end)
    return {
        id = inc.id, type = inc.type, nature = inc.nature, priority = inc.priority, street = inc.street,
        coords = inc.coords, caller = inc.caller, callback = inc.callback, message = inc.message,
        patients = inc.patients, origin = inc.origin, createdAt = inc.createdAt, units = us,
    }
end

function Fire.board()
    local units = fireUnits()
    local umap = unitMap()
    local list = {}
    for _, inc in pairs(Fire.incidents) do list[#list + 1] = view(inc, umap) end
    table.sort(list, function(a, b) if a.priority ~= b.priority then return a.priority < b.priority end return a.id < b.id end)
    local apparatus = {}
    for _, a in ipairs(F.apparatus) do
        local crew = {}
        for _, u in ipairs(units) do if u.apparatus == a.id then crew[#crew + 1] = u.callsign end end
        apparatus[#apparatus + 1] = { id = a.id, type = a.type, station = a.station, oos = Fire.apparatusOOS[a.id] == true, crew = crew }
    end
    return { incidents = list, units = units, apparatus = apparatus, mayday = Fire.mayday, now = os.time() }
end

function Fire.note(id, author, body, system)
    body = tostring(body):sub(1, 500)
    UL.DB.insert('INSERT INTO ul_fire_notes (incident_id, author, body, is_system) VALUES (?, ?, ?, ?)', { id, author, body, system and 1 or 0 })
    Fire.pushAll('fireNote', { id = id, note = { at = os.time(), author = author, body = body, system = system == true } })
end

function Fire.pushAll(kind, data)
    for src in pairs(Fire.viewers) do UL.push(src, kind, data) end
end

-- notify every on-duty SAFR unit (and optionally everyone on duty)
local function notifyUnits(message, kind, everyone)
    for _, u in ipairs(Bridge.units()) do
        if everyone or isFire(u) then UL.notify(u.source, message, kind) end
    end
end

local function persist(inc)
    UL.DB.update('UPDATE ul_fire_incidents SET type = ?, nature = ?, priority = ?, patients = ? WHERE id = ?',
        { inc.type, inc.nature, inc.priority, inc.patients, inc.id })
end

local function attach(src, id, label)
    local inc = Fire.incidents[id]
    local s = unitState(src)
    if not inc then return false, 'That incident is closed.' end
    if inc.units[src] then return true end
    inc.units[src] = true
    s.incidents[id] = true
    s.status = 'ENRT'
    Fire.note(id, 'SYSTEM', ('(SYSTEM) %s attached'):format(label), true)
    markDirty()
    return true
end

local function detach(src, id, label, why)
    local inc = Fire.incidents[id]
    local s = Fire.units[src]
    if inc then inc.units[src] = nil end
    if s then
        s.incidents[id] = nil
        if not next(s.incidents) and ONCALL[s.status] then s.status = 'AVAIL' end
    end
    if inc then Fire.note(id, 'SYSTEM', ('(SYSTEM) %s %s'):format(label, why or 'cleared'), true) end
    markDirty()
end

local function newIncident(data)
    local id = UL.DB.insert([[INSERT INTO ul_fire_incidents (type, nature, priority, street, pos_x, pos_y, pos_z, caller, callback, message, patients, origin)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], { data.type, data.nature, data.priority, data.street, data.coords.x, data.coords.y, data.coords.z,
        data.caller, data.callback, data.message, data.patients or 0, data.origin })
    if not id then return nil end
    local inc = { id = id, type = data.type, nature = data.nature, priority = data.priority, street = data.street, coords = data.coords,
        caller = data.caller, callback = data.callback, message = data.message, patients = data.patients or 0, origin = data.origin,
        createdAt = os.time(), units = {} }
    Fire.incidents[id] = inc
    markDirty()
    return inc
end

local function coordsOf(src)
    local c = Bridge.coords(src)
    return c and { x = c.x, y = c.y, z = c.z } or { x = 0.0, y = 0.0, z = 0.0 }
end

-- reload active incidents after a restart
CreateThread(function()
    while not UL.ready do Wait(500) end
    local rows = UL.DB.query([[SELECT id, type, nature, priority, street, pos_x, pos_y, pos_z, caller, callback, message, patients, origin,
        UNIX_TIMESTAMP(created_at) AS at FROM ul_fire_incidents WHERE status = 'active']]) or {}
    for _, r in ipairs(rows) do
        Fire.incidents[r.id] = { id = r.id, type = r.type, nature = r.nature, priority = r.priority, street = r.street,
            coords = { x = r.pos_x, y = r.pos_y, z = r.pos_z }, caller = r.caller, callback = r.callback, message = r.message,
            patients = r.patients, origin = r.origin, createdAt = r.at, units = {} }
    end
    if #rows > 0 then UL.log(('SAFR: %d active incidents restored'):format(#rows)) end
end)

-- board pushes: on change (debounced) and every 5s for positions
CreateThread(function()
    local since = 0
    while true do
        Wait(400)
        since = since + 400
        if next(Fire.viewers) and (dirty or since >= 5000) then
            dirty, since = false, 0
            local board = Fire.board()
            for src in pairs(Fire.viewers) do
                local o = UL.officer(src)
                if o and o.kind == 'fire' then UL.push(src, 'fireBoard', board)
                else Fire.viewers[src] = nil; UL.push(src, 'forceClose', 'You no longer have SAFR CAD access.') end
            end
        end
    end
end)

RegisterNetEvent('unitlink:server:closed', function() Fire.viewers[source] = nil end)
AddEventHandler('playerDropped', function() Fire.viewers[source] = nil end)

---------------------------------------------------------------------
-- Open
---------------------------------------------------------------------
function Fire.open(o)
    Fire.viewers[o.src] = true
    local s = unitState(o.src)
    UL.DB.query([[INSERT INTO ul_fire_members (member_id, name, callsign, last_seen) VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE name = VALUES(name), callsign = VALUES(callsign), last_seen = CURRENT_TIMESTAMP]], { o.charId, o.name:sub(1, 64), o.callsign })
    local forms = UL.formsForUi(F.forms, LISTS)
    return true, {
        kind = 'fire', name = Config.Name,
        me = { src = o.src, callsign = o.callsign, short = o.short, name = o.name, dept = o.dept, supervisor = o.supervisor, apparatus = s.apparatus },
        statuses = F.statuses, types = F.types, typeOrder = F.typeOrder, dispositions = F.dispositions, hospitals = F.hospitals,
        severities = F.severities, conditions = F.conditions, stations = F.stations, certifications = F.certifications,
        mutualAidTo = F.mutualAidTo, forms = forms, minNarrative = F.minNarrative, board = Fire.board(),
    }
end

local function H(action, opts, fn) opts = opts or {}; opts.kind = 'fire'; UL.handle(action, opts, fn) end

H('fire.board', nil, function() return true, Fire.board() end)

---------------------------------------------------------------------
-- Status / apparatus
---------------------------------------------------------------------
H('fire.setStatus', nil, function(o, p)
    local code = tostring(p.code or '')
    if not STATUS[code] then return false, 'Unknown status.' end
    local s = unitState(o.src)
    if ONCALL[code] and not next(s.incidents) then return false, 'Attach to an incident first.' end
    if s.status == code then return true end
    s.status = code
    for id in pairs(s.incidents) do Fire.note(id, o.label, ('(SYSTEM) %s status: %s (%s)'):format(o.callsign, code, STATUS[code].label:upper()), true) end
    markDirty()
    return true
end)

H('fire.setApparatus', nil, function(o, p)
    local id = p.id
    local s = unitState(o.src)
    if id == nil or id == '' then s.apparatus = nil; markDirty(); return true end
    if not APPARATUS[id] then return false, 'Unknown apparatus.' end
    if Fire.apparatusOOS[id] then return false, id .. ' is out of service.' end
    s.apparatus = id
    markDirty()
    return true
end)

---------------------------------------------------------------------
-- Incidents
---------------------------------------------------------------------
local function validType(t, nature)
    if not TYPES[t] then return false end
    return nature == nil or TYPES[t][nature] == true
end

H('fire.create', nil, function(o, p)
    local t = tostring(p.type or '')
    if not TYPES[t] then return false, 'Pick a call type.' end
    local nature = TYPES[t][p.nature] and p.nature or F.types[t][1]
    local pri = UL.int(p.priority)
    if not pri or pri < 1 or pri > 3 then pri = 2 end
    local inc = newIncident({ type = t, nature = nature, priority = pri, street = UL.clean(p.street, 120), coords = coordsOf(o.src),
        caller = o.label, callback = 'RADIO', message = UL.clean(p.notes, 500), origin = 'cad' })
    if not inc then return false, 'Database error. The incident was not created.' end
    Fire.note(inc.id, 'SYSTEM', ('(SYSTEM) Incident created by %s'):format(o.label), true)
    if inc.message and inc.message ~= '' then Fire.note(inc.id, o.label, inc.message, false) end
    if p.attach ~= false then attach(o.src, inc.id, o.callsign) end
    UL.activity(o, ('Created SAFR incident #%d (%s)'):format(inc.id, nature))
    return true, { id = inc.id }
end)

H('fire.get', nil, function(o, p)
    local id = UL.int(p.id)
    if not id then return false, 'Invalid incident.' end
    local live = Fire.incidents[id]
    local closed = nil
    local x, y
    if live then x, y = live.coords.x, live.coords.y
    else
        closed = UL.DB.single([[SELECT id, type, nature, priority, street, pos_x, pos_y, caller, callback, message, patients, origin, disposition, units, closed_by,
            UNIX_TIMESTAMP(created_at) AS createdAt, UNIX_TIMESTAMP(closed_at) AS closedAt FROM ul_fire_incidents WHERE id = ?]], { id })
        if not closed then return false, 'Incident not found.' end
        x, y = closed.pos_x, closed.pos_y
    end
    local notes = UL.DB.query('SELECT author, body, is_system, UNIX_TIMESTAMP(created_at) AS at FROM ul_fire_notes WHERE incident_id = ? ORDER BY id LIMIT 300', { id }) or {}
    for _, n in ipairs(notes) do n.system = n.is_system == 1 or n.is_system == true; n.is_system = nil end
    local patients = UL.DB.query([[SELECT id, subject_char, name, injury, severity, treatment, destination, pt_condition AS cond, created_by,
        UNIX_TIMESTAMP(created_at) AS at FROM ul_fire_patients WHERE incident_id = ? ORDER BY id]], { id }) or {}
    local r = F.nearbyMeters or 60
    local history = UL.DB.query([[SELECT id, type, nature, disposition, units, UNIX_TIMESTAMP(closed_at) AS at FROM ul_fire_incidents
        WHERE status = 'closed' AND id <> ? AND pos_x BETWEEN ? AND ? AND pos_y BETWEEN ? AND ? ORDER BY id DESC LIMIT 25]], { id, x - r, x + r, y - r, y + r }) or {}
    return true, { incident = live and view(live) or nil, closed = closed, notes = notes, patients = patients, history = history }
end)

H('fire.update', nil, function(o, p)
    local inc = Fire.incidents[UL.int(p.id) or 0]
    if not inc then return false, 'That incident is closed.' end
    if p.type ~= nil and p.type ~= inc.type then
        if not TYPES[p.type] then return false, 'Unknown call type.' end
        Fire.note(inc.id, o.label, ('(SYSTEM) Type: %s → %s'):format(inc.type, p.type), true)
        inc.type = p.type
        inc.nature = TYPES[p.type][inc.nature] and inc.nature or F.types[p.type][1]
    end
    if p.nature ~= nil and p.nature ~= inc.nature then
        if not validType(inc.type, p.nature) then return false, 'That nature does not match the call type.' end
        Fire.note(inc.id, o.label, ('(SYSTEM) Nature: %s → %s'):format(inc.nature, p.nature), true)
        inc.nature = p.nature
    end
    if p.priority ~= nil then
        local pri = UL.int(p.priority)
        if not pri or pri < 1 or pri > 3 then return false, 'Priority is 1 to 3.' end
        if pri ~= inc.priority then Fire.note(inc.id, o.label, ('(SYSTEM) Priority: %d → %d'):format(inc.priority, pri), true); inc.priority = pri end
    end
    if p.patients ~= nil then
        local n = UL.int(p.patients)
        if not n or n < 0 or n > 50 then return false, 'Patient count is 0 to 50.' end
        if n ~= inc.patients then Fire.note(inc.id, o.label, ('(SYSTEM) Patient count: %d → %d'):format(inc.patients, n), true); inc.patients = n end
    end
    persist(inc)
    markDirty()
    return true
end)

H('fire.assign', nil, function(o, p) return attach(o.src, UL.int(p.id) or 0, o.callsign) end)

H('fire.detach', nil, function(o, p)
    local id = UL.int(p.id) or 0
    local s = Fire.units[o.src]
    if not s or not s.incidents[id] then return false, 'You are not on that incident.' end
    detach(o.src, id, o.callsign)
    return true
end)

H('fire.note', nil, function(o, p)
    local id = UL.int(p.id) or 0
    if not Fire.incidents[id] then return false, 'That incident is closed.' end
    local body = UL.cleanText(p.body, 500)
    if not body or #body == 0 then return false, 'Type a note first.' end
    Fire.note(id, o.label, body, false)
    return true
end)

H('fire.close', nil, function(o, p)
    local id = UL.int(p.id) or 0
    local inc = Fire.incidents[id]
    if not inc then return false, 'That incident is already closed.' end
    if not inc.units[o.src] and not o.supervisor then return false, 'Only units on the incident or a supervisor can close it.' end
    local dispo = inList(F.dispositions, p.disposition) and p.disposition or F.dispositions[1]
    local signs = {}
    for _, u in ipairs(view(inc).units) do signs[#signs + 1] = u.callsign end
    UL.DB.update([[UPDATE ul_fire_incidents SET status = 'closed', disposition = ?, units = ?, closed_by = ?, closed_at = CURRENT_TIMESTAMP,
        type = ?, nature = ?, priority = ?, patients = ? WHERE id = ?]], { dispo, table.concat(signs, ', '):sub(1, 255), o.label, inc.type, inc.nature, inc.priority, inc.patients, id })
    for src in pairs(inc.units) do
        local s = Fire.units[src]
        if s then s.incidents[id] = nil; if not next(s.incidents) and ONCALL[s.status] then s.status = 'AVAIL' end end
    end
    Fire.incidents[id] = nil
    Fire.note(id, 'SYSTEM', ('(SYSTEM) Closed by %s: %s'):format(o.label, dispo), true)
    Fire.pushAll('fireClosed', { id = id, by = o.callsign, disposition = dispo })
    UL.activity(o, ('Closed SAFR incident #%d (%s)'):format(id, dispo))
    markDirty()
    return true
end)

H('fire.waypoint', nil, function(o, p)
    local inc = Fire.incidents[UL.int(p.id) or 0]
    if not inc then return false, 'That incident is closed.' end
    return true, { coords = inc.coords }
end)

H('fire.history', nil, function()
    local rows = UL.DB.query([[SELECT id, type, nature, priority, street, caller, units, disposition, closed_by,
        UNIX_TIMESTAMP(created_at) AS createdAt, UNIX_TIMESTAMP(closed_at) AS closedAt FROM ul_fire_incidents
        WHERE status = 'closed' ORDER BY id DESC LIMIT 100]])
    if not rows then return false, 'Database error.' end
    return true, rows
end)

---------------------------------------------------------------------
-- Patients
---------------------------------------------------------------------
H('fire.addPatient', nil, function(o, p)
    local id = UL.int(p.id) or 0
    local inc = Fire.incidents[id]
    if not inc then return false, 'That incident is closed.' end
    local subject = UL.int(p.subject)
    local person = subject and Identity.get(subject) or nil
    if subject and not person then return false, 'That person was not found.' end
    local injury = UL.clean(p.injury, 200)
    if not injury or #injury < 3 then return false, 'Describe the injury or illness.' end
    if not inList(F.severities, p.severity) then return false, 'Pick a severity.' end
    if not inList(F.conditions, p.condition) then return false, 'Pick a condition.' end
    if not inList(LISTS['hospitals+'], p.destination) then return false, 'Pick a destination.' end
    local name = person and ('%s %s'):format(person.firstname, person.lastname) or 'UNKNOWN PATIENT'
    local pid = UL.DB.insert([[INSERT INTO ul_fire_patients (incident_id, subject_char, name, injury, severity, treatment, destination, pt_condition, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { id, person and subject or nil, name:sub(1, 64), injury, p.severity, UL.cleanText(p.treatment, 500), p.destination, p.condition, o.label })
    if not pid then return false, 'Database error. The patient was not saved.' end
    local count = UL.DB.scalar('SELECT COUNT(*) FROM ul_fire_patients WHERE incident_id = ?', { id }) or 0
    if count > inc.patients then inc.patients = count; persist(inc) end
    Fire.note(id, o.label, ('(SYSTEM) Patient: %s · %s · %s'):format(name:upper(), p.severity, p.destination), true)
    UL.activity(o, ('Added patient %s to #%d'):format(name, id))
    markDirty()
    return true, { id = pid }
end)

H('fire.searchPeople', nil, function(o, p)
    local q = UL.clean(p.q, 64)
    if not q or #q < 2 then return false, 'Enter at least 2 characters.' end
    local rows = Identity.search(q)
    if not rows then return false, 'Person records are unavailable right now.' end
    local list = {}
    for _, r in ipairs(rows) do
        list[#list + 1] = { id = r.id, first = r.firstname, last = r.lastname, dob = r.dateofbirth, gender = r.gender, nationality = r.nationality, height = r.height,
            visits = UL.DB.scalar('SELECT COUNT(*) FROM ul_fire_patients WHERE subject_char = ?', { r.id }) or 0 }
    end
    return true, list
end)

H('fire.patientHistory', nil, function(o, p)
    local id = UL.int(p.id)
    local c = id and Identity.get(id)
    if not c then return false, 'No record found.' end
    local visits = UL.DB.query([[SELECT p.id, p.incident_id, p.injury, p.severity, p.treatment, p.destination, p.pt_condition AS cond, p.created_by,
        UNIX_TIMESTAMP(p.created_at) AS at, i.nature FROM ul_fire_patients p LEFT JOIN ul_fire_incidents i ON i.id = p.incident_id
        WHERE p.subject_char = ? ORDER BY p.id DESC LIMIT 50]], { id }) or {}
    return true, { person = { id = c.id, first = c.firstname, last = c.lastname, dob = c.dateofbirth, gender = c.gender, nationality = c.nationality, height = c.height }, visits = visits }
end)

H('fire.recentPatients', nil, function()
    local rows = UL.DB.query([[SELECT id, incident_id, subject_char, name, severity, destination, created_by, UNIX_TIMESTAMP(created_at) AS at
        FROM ul_fire_patients ORDER BY id DESC LIMIT 25]])
    if not rows then return false, 'Database error.' end
    return true, rows
end)

---------------------------------------------------------------------
-- Reports
---------------------------------------------------------------------
local function incidentExists(id)
    return Fire.incidents[id] ~= nil or (UL.DB.scalar('SELECT COUNT(*) FROM ul_fire_incidents WHERE id = ?', { id }) or 0) > 0
end

H('fire.submitReport', nil, function(o, p)
    local form = FORMS[p.form]
    if not form then return false, 'Unknown report type.' end
    local data, meta = UL.validateForm(form, p.data, { lists = LISTS, minNarrative = F.minNarrative, incidentExists = incidentExists })
    if not data then return false, meta end
    local subject, subjectName, incId = meta.subject, meta.subjectName, meta.incident
    local id = UL.DB.insert([[INSERT INTO ul_fire_reports (form, incident_id, subject_char, subject_name, author_char, author_label, data)
        VALUES (?, ?, ?, ?, ?, ?, ?)]], { form.key, incId, subject, subjectName, o.charId, o.label, UL.json(data) })
    if not id then return false, 'Database error. The report was not saved.' end
    local prefix = ({ pcr = 'PCR', fireinc = 'FIR', rescue = 'RES', mvc = 'MVC', hazmat = 'HAZ', transport = 'TRN' })[form.key] or 'RPT'
    local number = ('%s-%d'):format(prefix, id)
    -- a patient care / transport report on an incident also records the patient
    if (form.key == 'pcr' or form.key == 'transport') and subject and incId then
        local exists = (UL.DB.scalar('SELECT COUNT(*) FROM ul_fire_patients WHERE incident_id = ? AND subject_char = ?', { incId, subject }) or 0) > 0
        if not exists then
            UL.DB.insert([[INSERT INTO ul_fire_patients (incident_id, subject_char, name, injury, severity, treatment, destination, pt_condition, created_by)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { incId, subject, subjectName:sub(1, 64), (data.complaint or ('See ' .. number)):sub(1, 200),
                data.severity or 'MODERATE', data.treatment, data.destination, data.condition, o.label })
        end
    end
    if incId and Fire.incidents[incId] then Fire.note(incId, o.label, ('(SYSTEM) %s %s filed'):format(form.label:upper(), number), true) end
    UL.activity(o, ('Filed %s (%s)'):format(number, form.label))
    return true, { number = number }
end)

H('fire.myReports', nil, function(o)
    local rows = UL.DB.query([[SELECT id, form, incident_id, subject_name, UNIX_TIMESTAMP(created_at) AS at FROM ul_fire_reports
        WHERE author_char = ? ORDER BY id DESC LIMIT 50]], { o.charId })
    if not rows then return false, 'Database error.' end
    return true, rows
end)

H('fire.getReport', nil, function(o, p)
    local r = UL.DB.single([[SELECT id, form, incident_id, subject_char, subject_name, author_label, data, UNIX_TIMESTAMP(created_at) AS at
        FROM ul_fire_reports WHERE id = ?]], { UL.int(p.id) or 0 })
    if not r then return false, 'Report not found.' end
    r.data = UL.decode(r.data, {})
    return true, r
end)

---------------------------------------------------------------------
-- Alerts: mutual aid, announcements, mayday
---------------------------------------------------------------------
H('fire.alerts', nil, function()
    return true, {
        mutualAid = UL.DB.query('SELECT id, from_station, to_dept, need, status, created_by, UNIX_TIMESTAMP(created_at) AS at FROM ul_fire_mutual_aid ORDER BY id DESC LIMIT 20') or {},
        announcements = UL.DB.query('SELECT id, title, body, created_by, UNIX_TIMESTAMP(created_at) AS at FROM ul_fire_announcements ORDER BY id DESC LIMIT 10') or {},
        mayday = Fire.mayday,
    }
end)

H('fire.mutualAid', nil, function(o, p)
    local from = nil
    for _, st in ipairs(F.stations) do if st.name == p.from then from = st.name end end
    if not from then return false, 'Pick a station.' end
    if not inList(F.mutualAidTo, p.to) then return false, 'Pick a department.' end
    local need = UL.clean(p.need, 300)
    if not need or #need < 5 then return false, 'Say what you need.' end
    UL.DB.insert('INSERT INTO ul_fire_mutual_aid (from_station, to_dept, need, created_by) VALUES (?, ?, ?, ?)', { from, p.to, need, o.label })
    for _, u in ipairs(Bridge.units()) do
        if u.departmentShort == p.to or isFire(u) then UL.notify(u.source, ('**Mutual aid · SAFR %s:** %s'):format(from, need), 'warning') end
    end
    Fire.pushAll('fireAlerts', {})
    return true
end)

H('fire.mutualAidFill', nil, function(o, p)
    local n = UL.DB.update("UPDATE ul_fire_mutual_aid SET status = 'FILLED' WHERE id = ? AND status = 'OPEN'", { UL.int(p.id) or 0 }) or 0
    if n == 0 then return false, 'That request is not open.' end
    Fire.pushAll('fireAlerts', {})
    return true
end)

H('fire.announce', { supervisor = true }, function(o, p)
    local title = UL.clean(p.title, 80)
    if not title or #title < 3 then return false, 'Give it a title.' end
    local body = UL.cleanText(p.body, 600)
    UL.DB.insert('INSERT INTO ul_fire_announcements (title, body, created_by) VALUES (?, ?, ?)', { title, body, o.label })
    notifyUnits(('**%s**%s'):format(title, body and body ~= '' and (' · ' .. body) or ''), 'announce')
    Fire.pushAll('fireAlerts', {})
    return true
end)

H('fire.mayday', nil, function(o, p)
    if Fire.mayday then return false, 'A MAYDAY is already active.' end
    local s = unitState(o.src)
    Fire.mayday = { unit = o.callsign, name = o.name, src = o.src, location = UL.clean(p.street, 120) or 'UNKNOWN', detail = UL.clean(p.detail, 200), at = os.time(), apparatus = s.apparatus }
    for id in pairs(s.incidents) do Fire.note(id, o.label, ('*** MAYDAY *** %s: %s'):format(o.callsign, Fire.mayday.detail or 'no details'), true) end
    notifyUnits(('**MAYDAY · %s** at %s%s'):format(o.callsign, Fire.mayday.location, Fire.mayday.detail and (' · ' .. Fire.mayday.detail) or ''), 'error', F.maydayAll)
    UL.log(('MAYDAY declared by %s'):format(o.label))
    UL.activity(o, 'Declared MAYDAY')
    markDirty()
    Fire.pushAll('fireAlerts', {})
    return true
end)

H('fire.maydayClear', nil, function(o)
    if not Fire.mayday then return false, 'No MAYDAY is active.' end
    if Fire.mayday.src ~= o.src and not o.supervisor then return false, 'Only the unit that called it or a supervisor can clear the MAYDAY.' end
    notifyUnits(('MAYDAY cleared: **%s** accounted for (PAR).'):format(Fire.mayday.unit), 'success', F.maydayAll)
    Fire.mayday = nil
    markDirty()
    Fire.pushAll('fireAlerts', {})
    return true
end)

---------------------------------------------------------------------
-- Management: roster, certifications, apparatus
---------------------------------------------------------------------
H('fire.roster', nil, function()
    local rows = UL.DB.query('SELECT member_id, name, callsign, certs, UNIX_TIMESTAMP(last_seen) AS seen FROM ul_fire_members ORDER BY name LIMIT 200') or {}
    local onDuty = {}
    for _, u in ipairs(fireUnits()) do
        local id = Identity.officerId(u.source)
        if id then onDuty[id] = u end
    end
    for _, r in ipairs(rows) do
        r.certs = UL.decode(r.certs, {})
        local u = onDuty[r.member_id]
        if u then r.onDuty = { callsign = u.callsign, status = u.status, apparatus = u.apparatus } end
    end
    return true, rows
end)

H('fire.setCerts', { supervisor = true }, function(o, p)
    local id = UL.int(p.member)
    if not id then return false, 'Pick a member.' end
    local certs = {}
    for _, c in ipairs(type(p.certs) == 'table' and p.certs or {}) do if inList(F.certifications, c) then certs[#certs + 1] = c end end
    local n = UL.DB.update('UPDATE ul_fire_members SET certs = ? WHERE member_id = ?', { UL.json(certs), id }) or 0
    if n == 0 then return false, 'Member not found.' end
    return true
end)

H('fire.apparatusOOS', { supervisor = true }, function(o, p)
    local id = p.id
    if not APPARATUS[id] then return false, 'Unknown apparatus.' end
    Fire.apparatusOOS[id] = p.oos == true or nil
    if p.oos == true then
        for src, s in pairs(Fire.units) do if s.apparatus == id then s.apparatus = nil end end
    end
    markDirty()
    return true
end)

---------------------------------------------------------------------
-- Civilians: /911fire and /911ems
---------------------------------------------------------------------
local lastCall = {}
-- Shared by /911fire, /911ems and the Civilian Portal. Returns ok, message, incident id.
function Fire.civCall(src, kind, message, street)
    if not UL.ready then return false, 'Dispatch is not ready.' end
    kind = kind == 'fire' and 'fire' or 'medical'
    local now = os.time()
    if lastCall[src] and now - lastCall[src] < (F.callCooldown or 60) then
        return false, ('Please wait %d seconds before calling again.'):format((F.callCooldown or 60) - (now - lastCall[src]))
    end
    message = UL.clean(message, 300)
    if not message or #message < 3 then
        return false, ('Describe the emergency: /%s <what is happening>'):format(kind == 'fire' and F.commands.fire or F.commands.medical)
    end
    lastCall[src] = now
    local caller = Identity.activeName(src) or GetPlayerName(src) or ('Caller ' .. src)
    local inc = newIncident({
        type = kind == 'fire' and 'FIRE' or 'MEDICAL', nature = kind == 'fire' and 'REPORTED FIRE' or 'MEDICAL EMERGENCY',
        priority = kind == 'fire' and 1 or 2, street = UL.clean(street, 120), coords = coordsOf(src),
        caller = caller:sub(1, 64), callback = ('555-%04d'):format(src % 10000), message = message, origin = '911',
    })
    if not inc then return false, 'Your call could not be placed. Try again.' end
    Fire.note(inc.id, 'SYSTEM', ('911 CALL RECEIVED FROM %s: %s'):format(caller:upper(), message), true)
    local targets = {}
    for _, u in ipairs(Bridge.units()) do if isFire(u) then targets[#targets + 1] = u.source end end
    if #targets > 0 and GetResourceState('UnitLink-UI') == 'started' then
        pcall(function()
            exports['UnitLink-UI']:Dispatch(targets, { dept = 'safr', code = tostring(inc.id), title = inc.nature, message = message, priority = inc.priority, location = inc.street or 'See CAD' })
        end)
    end
    return true, #targets > 0 and 'Fire & Rescue has your call. Stay where you are if it is safe.'
        or 'No Fire & Rescue units are on duty right now. Your call has been logged.', inc.id, #targets > 0
end

RegisterNetEvent('unitlink:server:fire911', function(kind, message, street)
    local src = source
    local ok, msg, _, covered = Fire.civCall(src, kind, message, street)
    UL.notify(src, msg, not ok and 'error' or covered and 'success' or 'warning')
end)

AddEventHandler('playerDropped', function() lastCall[source] = nil end)

exports('GetFireIncidents', function() local t = {} for _, inc in pairs(Fire.incidents) do t[#t + 1] = view(inc) end return t end)
