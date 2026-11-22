---------------------------------------------------------------------
-- Records: person search, state returns, citations, arrests, reports,
-- warrants. People come from tsrp-core (read only); records are UnitLink's.
---------------------------------------------------------------------
local PREFIX = { citation = 'C-', arrest = 'A-', report = 'R-', warrant = 'W-' }
local LAWS = {}
for _, l in ipairs(Config.Laws) do LAWS[l.code] = l end
local function inList(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end

function UL.recordNo(type, id) return (PREFIX[type] or '#') .. tostring(id) end

local function fullName(c) return ('%s %s'):format(c.firstname, c.lastname) end

---------------------------------------------------------------------
-- Licenses (tsrp-core metadata)
---------------------------------------------------------------------
local function licenses(charId)
    local raw = Bridge.metadata(charId, Config.Licenses.metadataKey)
    local d = Config.Licenses.defaults
    local function one(k)
        local v = type(raw) == 'table' and raw[k] or nil
        if type(v) == 'table' then return { status = tostring(v.status or d[k] or 'none'):upper(), points = tonumber(v.points) or 0 } end
        if type(v) == 'string' then return { status = v:upper(), points = 0 } end
        return { status = tostring(d[k] or 'none'):upper(), points = 0 }
    end
    return { drivers = one('drivers'), firearm = one('firearm'), pilot = one('pilot') }, raw
end

local function addPoints(charId, points)
    if points <= 0 then return nil end
    local lic, raw = licenses(charId)
    raw = type(raw) == 'table' and raw or {}
    local drivers = type(raw.drivers) == 'table' and raw.drivers or { status = lic.drivers.status:lower() }
    drivers.points = (tonumber(drivers.points) or 0) + points
    local suspended = false
    if drivers.points >= Config.Licenses.suspendAt and tostring(drivers.status):lower() == 'valid' then
        drivers.status = 'suspended'
        suspended = true
    end
    raw.drivers = drivers
    Bridge.setMetadata(charId, Config.Licenses.metadataKey, raw)
    return drivers.points, suspended
end

---------------------------------------------------------------------
-- Flags for a list of characters: WANTED + active alert types
---------------------------------------------------------------------
local function flagsFor(ids)
    local flags = {}
    if #ids == 0 then return flags end
    local ph = string.rep('?', #ids, ',')
    for _, r in ipairs(UL.DB.query("SELECT DISTINCT subject_char FROM ul_records WHERE type = 'warrant' AND status = 'active' AND subject_char IN (" .. ph .. ")", ids) or {}) do
        flags[r.subject_char] = { 'WANTED' }
    end
    for _, r in ipairs(UL.DB.query('SELECT DISTINCT subject_char, type FROM ul_alerts WHERE active = 1 AND subject_char IN (' .. ph .. ')', ids) or {}) do
        flags[r.subject_char] = flags[r.subject_char] or {}
        table.insert(flags[r.subject_char], r.type)
    end
    return flags
end

---------------------------------------------------------------------
-- Name search
---------------------------------------------------------------------
UL.handle('searchPeople', nil, function(o, p)
    local q = UL.clean(p.q, 64)
    if not q or #q < 2 then return false, 'Enter at least 2 characters.' end
    local rows = Bridge.searchCharacters(q)
    if not rows then return false, 'Character records are unavailable (tsrp-core).' end
    local ids = {}
    for _, r in ipairs(rows) do ids[#ids + 1] = r.id end
    local flags = flagsFor(ids)
    local list = {}
    for _, r in ipairs(rows) do
        list[#list + 1] = {
            id = r.id, first = r.firstname, last = r.lastname, dob = r.dateofbirth,
            gender = r.gender, nationality = r.nationality, height = r.height, flags = flags[r.id] or {},
        }
    end
    return true, list
end)

---------------------------------------------------------------------
-- State return (full check on one person, logged)
---------------------------------------------------------------------
UL.handle('runReturn', nil, function(o, p)
    local id = UL.int(p.id)
    local c = id and Bridge.character(id)
    if not c then return false, 'No record found.' end
    local lic = licenses(id)

    local warrants = UL.DB.query([[SELECT id, data, officer_label, reviewed_by, UNIX_TIMESTAMP(created_at) AS at FROM ul_records
        WHERE type = 'warrant' AND status = 'active' AND subject_char = ? ORDER BY id DESC]], { id }) or {}
    for _, w in ipairs(warrants) do
        local d = UL.decode(w.data, {})
        w.number = UL.recordNo('warrant', w.id)
        w.warrantType = d.warrantType
        w.charges = d.charges or {}
        w.data = nil
    end
    local alerts = UL.DB.query('SELECT id, type, title, body FROM ul_alerts WHERE active = 1 AND subject_char = ? ORDER BY id DESC', { id }) or {}
    local counts = UL.DB.query('SELECT type, COUNT(*) AS n FROM ul_records WHERE subject_char = ? GROUP BY type', { id }) or {}
    local history = { citation = 0, arrest = 0, report = 0, warrant = 0 }
    for _, r in ipairs(counts) do history[r.type] = r.n end
    local records = UL.DB.query([[SELECT id, type, status, officer_label, data, UNIX_TIMESTAMP(created_at) AS at FROM ul_records
        WHERE subject_char = ? ORDER BY id DESC LIMIT 25]], { id }) or {}
    for _, r in ipairs(records) do
        local d = UL.decode(r.data, {})
        r.number = UL.recordNo(r.type, r.id)
        r.summary = (#(d.charges or {}) > 0) and table.concat((function() local t = {} for _, ch in ipairs(d.charges) do t[#t + 1] = ch.code .. ' ' .. ch.offense end return t end)(), '; ') or (d.incidentType or d.warrantType or '')
        r.data = nil
    end

    local hit = #warrants > 0
    local callId = UL.int(p.callId)
    if not callId and o.calls[1] then callId = o.calls[1] end
    UL.DB.insert('INSERT INTO ul_returns (officer_char, subject_char, subject_name, call_id, hit, result) VALUES (?, ?, ?, ?, ?, ?)',
        { o.charId, id, fullName(c):sub(1, 64), callId, hit and 1 or 0, hit and 'HIT · WANTED' or (#alerts > 0 and 'ALERT ON FILE' or 'NO HITS') })

    return true, {
        person = { id = c.id, first = c.firstname, last = c.lastname, dob = c.dateofbirth, gender = c.gender, nationality = c.nationality, height = c.height },
        licenses = lic, warrants = warrants, alerts = alerts, history = history, records = records,
        suspendAt = Config.Licenses.suspendAt, runBy = o.label, runAt = os.time(),
    }
end)

UL.handle('returnsLog', nil, function(o)
    local rows = UL.DB.query([[SELECT subject_char, subject_name, call_id, hit, result, UNIX_TIMESTAMP(created_at) AS at FROM ul_returns
        WHERE officer_char = ? AND created_at > (NOW() - INTERVAL 12 HOUR) ORDER BY id DESC LIMIT 100]], { o.charId })
    if not rows then return false, 'Database error.' end
    return true, rows
end)

---------------------------------------------------------------------
-- File a record
--   payload: { type, subject, callId, location, narrative, court, booking,
--              incidentType, warrantType, severity, involved, notes, charges = {codes} }
---------------------------------------------------------------------
UL.handle('submitRecord', nil, function(o, p)
    local rtype = p.type
    if not PREFIX[rtype] then return false, 'Invalid record type.' end

    local subjectId = UL.int(p.subject)
    local subject = subjectId and Bridge.character(subjectId) or nil
    if rtype ~= 'report' and not subject then return false, 'Select a subject.' end

    local charges, points = {}, 0
    if type(p.charges) == 'table' then
        for i, code in ipairs(p.charges) do
            if i > 20 then break end
            local law = LAWS[code]
            if law then
                charges[#charges + 1] = { code = law.code, offense = law.offense, class = law.class, points = law.points or 0 }
                points = points + (law.points or 0)
            end
        end
    end
    if (rtype == 'citation' or rtype == 'arrest') and #charges == 0 then return false, 'Add at least one charge.' end
    if rtype == 'citation' then
        for _, ch in ipairs(charges) do
            if ch.class == 'F' then return false, 'Felonies must be filed as an arrest report.' end
        end
    end

    local data = {
        charges = charges,
        location = UL.clean(p.location, 120),
        narrative = UL.cleanText(p.narrative, 4000),
        notes = UL.cleanText(p.notes, 1000),
        involved = UL.clean(p.involved, 300),
    }
    if rtype == 'citation' and type(p.court) == 'string' and p.court:match('^%d%d%d%d%-%d%d%-%d%d$') then data.court = p.court end
    if rtype == 'arrest' then data.booking = inList(Config.Bookings, p.booking) and p.booking or Config.Bookings[1] end
    if rtype == 'report' then data.incidentType = inList(Config.ReportTypes, p.incidentType) and p.incidentType or Config.ReportTypes[1] end
    if rtype == 'warrant' then
        data.warrantType = inList(Config.WarrantTypes, p.warrantType) and p.warrantType or Config.WarrantTypes[1]
        data.severity = p.severity == 'MISDEMEANOR' and 'MISDEMEANOR' or 'FELONY'
        if not data.narrative or #data.narrative < 20 then return false, 'Probable cause must be at least 20 characters.' end
    end
    if (rtype == 'arrest' or rtype == 'report') and (not data.narrative or #data.narrative < 20) then
        return false, 'Narrative must be at least 20 characters.'
    end

    local status, reviewedBy = 'filed', nil
    if rtype == 'warrant' then
        if Config.WarrantsNeedApproval and not o.supervisor then
            status = 'pending'
        else
            status, reviewedBy = 'active', o.label
        end
    end

    local callId = UL.int(p.callId)
    local id = UL.DB.insert([[INSERT INTO ul_records (type, status, subject_char, subject_name, officer_char, officer_label, call_id, data, reviewed_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        { rtype, status, subjectId, subject and fullName(subject):sub(1, 64) or nil, o.charId, o.label, callId, UL.json(data), reviewedBy })
    if not id then return false, 'Database error. The record was not saved.' end
    local number = UL.recordNo(rtype, id)

    local extra = nil
    if rtype == 'citation' and subject then
        local total, suspended = addPoints(subjectId, points)
        if total then
            extra = suspended and ('License SUSPENDED (%d points).'):format(total) or ('Driver points now %d/%d.'):format(total, Config.Licenses.suspendAt)
        end
    end
    if callId and Bridge.call(callId) then
        UL.note(callId, o.label, ('(SYSTEM) %s %s filed%s'):format(rtype:upper(), number, subject and (' for ' .. fullName(subject):upper()) or ''), true, o.charId)
    end
    if rtype == 'warrant' then
        UL.pushAll('alertsChanged', {})
        if status == 'pending' then
            for _, u in ipairs(Bridge.units()) do
                if u.source ~= o.src and Bridge.isSupervisor(u.source) then
                    UL.notify(u.source, ('Warrant **%s** for %s needs approval.'):format(number, fullName(subject)), 'warning')
                end
            end
        end
    end
    return true, { number = number, status = status, note = extra }
end)

UL.handle('myRecords', nil, function(o)
    local rows = UL.DB.query([[SELECT id, type, status, subject_name, call_id, UNIX_TIMESTAMP(created_at) AS at FROM ul_records
        WHERE officer_char = ? ORDER BY id DESC LIMIT 50]], { o.charId })
    if not rows then return false, 'Database error.' end
    for _, r in ipairs(rows) do r.number = UL.recordNo(r.type, r.id) end
    return true, rows
end)

UL.handle('getRecord', nil, function(o, p)
    local r = UL.DB.single([[SELECT id, type, status, subject_char, subject_name, officer_label, call_id, data, reviewed_by,
        UNIX_TIMESTAMP(created_at) AS at FROM ul_records WHERE id = ?]], { UL.int(p.id) or 0 })
    if not r then return false, 'Record not found.' end
    r.number = UL.recordNo(r.type, r.id)
    r.data = UL.decode(r.data, {})
    return true, r
end)

---------------------------------------------------------------------
-- Warrants: approve / deny (supervisors), serve (any unit)
---------------------------------------------------------------------
UL.handle('reviewWarrant', { supervisor = true }, function(o, p)
    local id = UL.int(p.id)
    local r = id and UL.DB.single("SELECT id, status, officer_char, subject_name FROM ul_records WHERE id = ? AND type = 'warrant'", { id })
    if not r or r.status ~= 'pending' then return false, 'That warrant is not waiting for approval.' end
    local status = p.approve == true and 'active' or 'denied'
    UL.DB.update('UPDATE ul_records SET status = ?, reviewed_by = ? WHERE id = ?', { status, o.label, id })
    UL.pushAll('alertsChanged', {})
    return true, { status = status }
end)

UL.handle('serveWarrant', nil, function(o, p)
    local id = UL.int(p.id)
    local changed = id and UL.DB.update("UPDATE ul_records SET status = 'served', reviewed_by = COALESCE(reviewed_by, ?) WHERE id = ? AND type = 'warrant' AND status = 'active'", { o.label, id })
    if not changed or changed == 0 then return false, 'That warrant is not active.' end
    UL.pushAll('alertsChanged', {})
    return true
end)
