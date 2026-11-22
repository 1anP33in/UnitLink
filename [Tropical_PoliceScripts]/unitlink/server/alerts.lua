---------------------------------------------------------------------
-- Alerts: BOLOs and safety flags (ul_alerts) + warrants (ul_records)
---------------------------------------------------------------------
local function inList(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end

UL.handle('alerts', nil, function(o)
    local alerts = UL.DB.query([[SELECT id, type, title, body, subject_char, subject_name, plate, created_by,
        UNIX_TIMESTAMP(created_at) AS at FROM ul_alerts WHERE active = 1 ORDER BY id DESC LIMIT 200]])
    if not alerts then return false, 'Database error.' end
    local warrantRows = UL.DB.query([[SELECT id, status, subject_char, subject_name, officer_label, reviewed_by, data,
        UNIX_TIMESTAMP(created_at) AS at FROM ul_records WHERE type = 'warrant' AND status IN ('active', 'pending')
        ORDER BY id DESC LIMIT 200]]) or {}
    local warrants, pending = {}, {}
    for _, w in ipairs(warrantRows) do
        local d = UL.decode(w.data, {})
        w.number = UL.recordNo('warrant', w.id)
        w.warrantType, w.severity, w.charges, w.narrative = d.warrantType, d.severity, d.charges or {}, d.narrative
        w.data = nil
        if w.status == 'active' then
            warrants[#warrants + 1] = w
        elseif o.supervisor then
            pending[#pending + 1] = w
        end
    end
    return true, { alerts = alerts, warrants = warrants, pending = pending, canReview = o.supervisor }
end)

UL.handle('addAlert', nil, function(o, p)
    if not inList(Config.AlertTypes, p.type) then return false, 'Pick an alert type.' end
    local title = UL.clean(p.title, 120)
    if not title or #title < 3 then return false, 'Give the alert a title.' end
    local body = UL.cleanText(p.body, 1000) or ''
    local subjectId = UL.int(p.subject)
    local subject = subjectId and Bridge.character(subjectId) or nil
    if subjectId and not subject then return false, 'That person does not exist.' end
    local plate = UL.clean(p.plate, 12)
    plate = plate and plate ~= '' and plate:upper() or nil
    local id = UL.DB.insert([[INSERT INTO ul_alerts (type, title, body, subject_char, subject_name, plate, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?)]],
        { p.type, title, body, subject and subjectId or nil, subject and (subject.firstname .. ' ' .. subject.lastname) or nil, plate, o.label })
    if not id then return false, 'Database error.' end
    UL.pushAll('alertsChanged', {})
    for _, u in ipairs(Bridge.units()) do
        if u.source ~= o.src then UL.notify(u.source, ('New %s: **%s** (%s)'):format(p.type, title, o.callsign), 'warning') end
    end
    return true, { id = id }
end)

UL.handle('removeAlert', nil, function(o, p)
    local changed = UL.DB.update('UPDATE ul_alerts SET active = 0, removed_by = ? WHERE id = ? AND active = 1', { o.label, UL.int(p.id) or 0 })
    if not changed or changed == 0 then return false, 'Alert not found.' end
    UL.pushAll('alertsChanged', {})
    return true
end)
