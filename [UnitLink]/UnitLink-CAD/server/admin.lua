---------------------------------------------------------------------
-- Admin Dashboard (/cadadmin)
-- Who can open it: ACE only (Config.Admin.ace, default unitlink.admin).
-- Departments and permissions are READ ONLY here (they live in
-- UnitLink-Police config and server.cfg). What admins can change:
--   civilian applications, civilian licenses / vehicles, laws & fines,
--   a short list of settings. Changes are saved in ul_settings, applied
--   live and again on every restart. Every change is written to ul_audit.
---------------------------------------------------------------------
UL.adminHandlers = {}
local function A(action, fn) UL.adminHandlers[action] = fn end
local APP_LABEL = { drivers = "Driver's License", firearm = 'Firearm License', pilot = 'Pilot License', vehicle = 'Vehicle Registration', business = 'Business License' }

---------------------------------------------------------------------
-- Settings: each one is a Config value admins may change in game
---------------------------------------------------------------------
local function ref(path)
    local t = Config
    for i = 1, #path - 1 do t[path[i]] = t[path[i]] or {}; t = t[path[i]] end
    return t, path[#path]
end
local SETTINGS = {
    { key = 'fines.enabled',          label = 'Show fines on citations',               group = 'Fines',     type = 'bool', path = { 'Fines', 'enabled' } },
    { key = 'fines.expireDays',       label = 'Fines expire after (days)',             group = 'Fines',     type = 'int', min = 1, max = 90, path = { 'Fines', 'expireDays' } },
    { key = 'licenses.suspendAt',     label = "Suspend driver's license at (points)", group = 'Police',    type = 'int', min = 1, max = 50, path = { 'Licenses', 'suspendAt' } },
    { key = 'police.warrantApproval', label = 'Warrants need supervisor approval',     group = 'Police',    type = 'bool', path = { 'WarrantsNeedApproval' } },
    { key = 'police.signal100',       label = 'Only supervisors start Signal 100',     group = 'Police',    type = 'bool', path = { 'Signal100SupervisorOnly' } },
    { key = 'fire.minNarrative',      label = 'SAFR report narrative minimum (chars)', group = 'SAFR',      type = 'int', min = 0, max = 500, path = { 'Fire', 'minNarrative' } },
    { key = 'dot.minNarrative',       label = 'DOT report narrative minimum (chars)',  group = 'DOT',       type = 'int', min = 0, max = 500, path = { 'Dot', 'minNarrative' } },
    { key = 'civ.maxProfiles',        label = 'Civilian profiles per player',          group = 'Civilians', type = 'int', min = 1, max = 20, path = { 'Civ', 'maxProfiles' } },
    { key = 'civ.maxVehicles',        label = 'Vehicles per civilian',                 group = 'Civilians', type = 'int', min = 0, max = 50, path = { 'Civ', 'maxVehicles' } },
    { key = 'civ.maxBusinesses',      label = 'Businesses per civilian',               group = 'Civilians', type = 'int', min = 0, max = 20, path = { 'Civ', 'maxBusinesses' } },
    { key = 'civ.callCooldown',       label = 'Portal 911 / request cooldown (sec)',   group = 'Civilians', type = 'int', min = 0, max = 600, path = { 'Civ', 'callCooldown' } },
    { key = 'approval.drivers',       label = "Driver's license needs approval",       group = 'Applications', type = 'bool', path = { 'Civ', 'approval', 'drivers' } },
    { key = 'approval.firearm',       label = 'Firearm license needs approval',        group = 'Applications', type = 'bool', path = { 'Civ', 'approval', 'firearm' } },
    { key = 'approval.pilot',         label = 'Pilot license needs approval',          group = 'Applications', type = 'bool', path = { 'Civ', 'approval', 'pilot' } },
    { key = 'approval.vehicle',       label = 'Vehicle registration needs approval',   group = 'Applications', type = 'bool', path = { 'Civ', 'approval', 'vehicle' } },
    { key = 'approval.business',      label = 'Business license needs approval',       group = 'Applications', type = 'bool', path = { 'Civ', 'approval', 'business' } },
}
local BY_KEY = {}
for _, s in ipairs(SETTINGS) do BY_KEY[s.key] = s end

local function getSetting(s) local t, k = ref(s.path); return t[k] end
local function coerce(s, v)
    if s.type == 'bool' then return v == true or v == 'true' or v == 1 end
    local n = UL.int(v)
    if not n or n < s.min or n > s.max then return nil end
    return n
end

-- laws: original values, so "reset" works
local LAW_DEFAULTS = {}
for _, l in ipairs(Config.Laws) do LAW_DEFAULTS[l.code] = { fine = l.fine or 0, points = l.points or 0 } end
local function lawByCode(code) for _, l in ipairs(Config.Laws) do if l.code == code then return l end end end

local function saveSetting(key, value, who)
    UL.DB.query('INSERT INTO ul_settings (skey, svalue, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE svalue = VALUES(svalue), updated_by = VALUES(updated_by)',
        { key, UL.json(value), who })
end

-- apply saved values on start
CreateThread(function()
    while not UL.ready do Wait(500) end
    for _, r in ipairs(UL.DB.query('SELECT skey, svalue FROM ul_settings') or {}) do
        local v = UL.decode(r.svalue, nil)
        if r.skey == 'laws' and type(v) == 'table' then
            for code, o in pairs(v) do
                local l = lawByCode(code)
                if l and type(o) == 'table' then l.fine, l.points = tonumber(o.fine) or l.fine, tonumber(o.points) or l.points end
            end
        elseif BY_KEY[r.skey] and v ~= nil then
            local s = BY_KEY[r.skey]
            local c = coerce(s, v)
            if c ~= nil then local t, k = ref(s.path); t[k] = c end
        end
    end
end)

---------------------------------------------------------------------
-- Open / overview
---------------------------------------------------------------------
local function overview()
    local units = Bridge.units()
    local depts = {}
    for _, d in ipairs(Bridge.departments()) do d.onDuty = 0; depts[#depts + 1] = d end
    for _, u in ipairs(units) do for _, d in ipairs(depts) do if d.key == u.department then d.onDuty = d.onDuty + 1 end end end
    local n = function(q, p) return UL.DB.scalar(q, p) or 0 end
    local fireActive, dotOpen = 0, 0
    for _ in pairs(Fire and Fire.incidents or {}) do fireActive = fireActive + 1 end
    for _ in pairs(Dot and Dot.orders or {}) do dotOpen = dotOpen + 1 end
    return {
        onDuty = #units, departments = depts,
        policeCalls = #Bridge.calls(), fireActive = fireActive, dotOpen = dotOpen,
        pendingApps = n("SELECT COUNT(*) FROM ul_civ_applications WHERE status = 'PENDING'"),
        civilians = n('SELECT COUNT(*) FROM ul_civilians WHERE deleted = 0'),
        vehicles = n('SELECT COUNT(*) FROM ul_civ_vehicles'),
        bolos = n('SELECT COUNT(*) FROM ul_bolos WHERE active = 1'),
        warrants = n("SELECT COUNT(*) FROM ul_records WHERE type = 'warrant' AND status = 'active'"),
        records24 = n('SELECT COUNT(*) FROM ul_records WHERE created_at > NOW() - INTERVAL 24 HOUR'),
        employees = n('SELECT COUNT(*) FROM ul_employees'),
        recentAudit = UL.DB.query('SELECT admin, area, change_text, UNIX_TIMESTAMP(created_at) AS at FROM ul_audit ORDER BY id DESC LIMIT 8') or {},
    }
end

A('admin.open', function(src, who)
    return true, { name = Config.Name, who = who, identity = Identity.mode(), ace = (Config.Admin and Config.Admin.ace) or 'unitlink.admin', overview = overview(),
        licenseStatuses = { 'VALID', 'SUSPENDED', 'REVOKED', 'EXPIRED', 'NONE' }, vehicleStatuses = { 'VALID', 'STOLEN', 'IMPOUNDED' } }
end)
A('admin.overview', function() return true, overview() end)

---------------------------------------------------------------------
-- Applications
---------------------------------------------------------------------
A('admin.apps', function(src, who, p)
    local status = ({ PENDING = 'PENDING', APPROVED = 'APPROVED', DENIED = 'DENIED' })[p.status] or 'PENDING'
    local rows = UL.DB.query([[SELECT id, civ_id, civ_name, type, data, status, reason, reviewed_by, UNIX_TIMESTAMP(created_at) AS at FROM ul_civ_applications
        WHERE status = ? ORDER BY id ]] .. (status == 'PENDING' and 'ASC' or 'DESC') .. ' LIMIT 150', { status })
    if not rows then return false, 'Database error.' end
    for _, r in ipairs(rows) do r.data = UL.decode(r.data, {}); r.label = APP_LABEL[r.type] or r.type end
    return true, rows
end)

A('admin.review', function(src, who, p)
    local app = UL.DB.single("SELECT id, civ_id, civ_name, type, data FROM ul_civ_applications WHERE id = ? AND status = 'PENDING'", { UL.int(p.id) or 0 })
    if not app then return false, 'That application was already decided.' end
    local reason = UL.clean(p.reason, 255)
    if p.approve then
        local ok, err = Civ.approve(app)
        if not ok then return false, err end
        UL.DB.update("UPDATE ul_civ_applications SET status = 'APPROVED', reviewed_by = ?, reason = ?, reviewed_at = CURRENT_TIMESTAMP WHERE id = ?", { who, reason or '', app.id })
    else
        if not reason or #reason < 3 then return false, 'Give a reason for denying it.' end
        UL.DB.update("UPDATE ul_civ_applications SET status = 'DENIED', reviewed_by = ?, reason = ?, reviewed_at = CURRENT_TIMESTAMP WHERE id = ?", { who, reason, app.id })
    end
    UL.audit(who, 'applications', ('%s %s #%d for %s'):format(p.approve and 'Approved' or 'Denied', APP_LABEL[app.type] or app.type, app.id, app.civ_name))
    return true
end)

---------------------------------------------------------------------
-- Civilians: licenses, points, vehicles
---------------------------------------------------------------------
local function licenseView(id)
    local raw = Identity.getLicenses(id)
    local out = {}
    for _, k in ipairs({ 'drivers', 'firearm', 'pilot' }) do
        local v = type(raw) == 'table' and raw[k] or nil
        local status = type(v) == 'table' and v.status or type(v) == 'string' and v or Config.Licenses.defaults[k] or 'none'
        out[#out + 1] = { key = k, label = APP_LABEL[k], status = tostring(status):upper(), points = type(v) == 'table' and tonumber(v.points) or 0 }
    end
    return out
end

A('admin.civilians', function(src, who, p)
    local q = UL.clean(p.q, 48) or ''
    local rows = #q >= 2 and Identity.search(q) or UL.DB.query('SELECT id, firstname, lastname, dateofbirth, gender, nationality, height FROM ul_civilians WHERE deleted = 0 ORDER BY id DESC LIMIT 25')
    if not rows then return false, 'Database error.' end
    local out = {}
    for _, c in ipairs(rows) do out[#out + 1] = { id = c.id, name = ('%s %s'):format(c.firstname, c.lastname), dob = c.dateofbirth, gender = c.gender } end
    return true, out
end)

A('admin.civilian', function(src, who, p)
    local c = Identity.get(UL.int(p.id) or 0)
    if not c then return false, 'Civilian not found.' end
    return true, {
        id = c.id, name = ('%s %s'):format(c.firstname, c.lastname), dob = c.dateofbirth, gender = c.gender, nationality = c.nationality,
        licenses = licenseView(c.id), suspendAt = Config.Licenses.suspendAt,
        vehicles = UL.DB.query('SELECT id, plate, model, color, status FROM ul_civ_vehicles WHERE civ_id = ? ORDER BY id', { c.id }) or {},
        businesses = UL.DB.query('SELECT id, name, type, status FROM ul_civ_businesses WHERE civ_id = ? ORDER BY id', { c.id }) or {},
        records = UL.DB.scalar('SELECT COUNT(*) FROM ul_records WHERE subject_char = ?', { c.id }) or 0,
    }
end)

A('admin.setLicense', function(src, who, p)
    local c = Identity.get(UL.int(p.id) or 0)
    if not c then return false, 'Civilian not found.' end
    if not APP_LABEL[p.key] or p.key == 'vehicle' or p.key == 'business' then return false, 'Unknown license.' end
    local status = tostring(p.status or ''):upper()
    if not UL.inList({ 'VALID', 'SUSPENDED', 'REVOKED', 'EXPIRED', 'NONE' }, status) then return false, 'Unknown status.' end
    local points = UL.int(p.points)
    if p.points ~= nil and (not points or points < 0 or points > 99) then return false, 'Points are 0 to 99.' end
    local raw = Identity.getLicenses(c.id)
    raw = type(raw) == 'table' and raw or {}
    local cur = type(raw[p.key]) == 'table' and raw[p.key] or { points = 0 }
    cur.status = status:lower()
    if points then cur.points = points end
    raw[p.key] = cur
    if not Identity.setLicenses(c.id, raw) then return false, 'Could not save.' end
    UL.audit(who, 'civilians', ('%s %s: %s%s'):format(c.firstname .. ' ' .. c.lastname, APP_LABEL[p.key], status, points and (' · ' .. points .. ' pts') or ''))
    return true
end)

A('admin.setVehicle', function(src, who, p)
    local status = tostring(p.status or ''):upper()
    if not UL.inList({ 'VALID', 'STOLEN', 'IMPOUNDED' }, status) then return false, 'Unknown status.' end
    local v = UL.DB.single('SELECT id, plate FROM ul_civ_vehicles WHERE id = ?', { UL.int(p.id) or 0 })
    if not v then return false, 'Vehicle not found.' end
    UL.DB.update('UPDATE ul_civ_vehicles SET status = ? WHERE id = ?', { status, v.id })
    UL.audit(who, 'vehicles', ('%s set to %s'):format(v.plate, status))
    return true
end)

---------------------------------------------------------------------
-- Laws & fines (fine amounts and license points; no money is ever charged)
---------------------------------------------------------------------
A('admin.laws', function()
    local list = {}
    for _, l in ipairs(Config.Laws) do
        local d = LAW_DEFAULTS[l.code] or {}
        list[#list + 1] = { code = l.code, offense = l.offense, class = l.class, fine = l.fine or 0, points = l.points or 0,
            changed = (l.fine or 0) ~= (d.fine or 0) or (l.points or 0) ~= (d.points or 0), defaultFine = d.fine, defaultPoints = d.points }
    end
    return true, { laws = list, symbol = Config.Fines and Config.Fines.symbol or '$' }
end)

A('admin.setLaw', function(src, who, p)
    local l = lawByCode(p.code)
    if not l then return false, 'Unknown law.' end
    local d = LAW_DEFAULTS[l.code]
    local fine, points
    if p.reset then fine, points = d.fine, d.points
    else
        fine, points = UL.int(p.fine), UL.int(p.points)
        if not fine or fine < 0 or fine > 1000000 then return false, 'Fine must be 0 or more.' end
        if not points or points < 0 or points > 50 then return false, 'Points are 0 to 50.' end
    end
    local old = ('%s / %d pts'):format(tostring(l.fine or 0), l.points or 0)
    l.fine, l.points = fine, points
    local saved = UL.decode(UL.DB.scalar("SELECT svalue FROM ul_settings WHERE skey = 'laws'"), {}) or {}
    if fine == d.fine and points == d.points then saved[l.code] = nil else saved[l.code] = { fine = fine, points = points } end
    if next(saved) == nil then UL.DB.update("DELETE FROM ul_settings WHERE skey = 'laws'") else saveSetting('laws', saved, who) end
    UL.audit(who, 'laws', ('%s %s: %s → %d / %d pts'):format(l.code, l.offense, old, fine, points))
    return true
end)

---------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------
A('admin.settings', function()
    local out = {}
    for _, s in ipairs(SETTINGS) do out[#out + 1] = { key = s.key, label = s.label, group = s.group, type = s.type, min = s.min, max = s.max, value = getSetting(s) } end
    return true, out
end)

A('admin.setSetting', function(src, who, p)
    local s = BY_KEY[p.key]
    if not s then return false, 'Unknown setting.' end
    local v = coerce(s, p.value)
    if v == nil then return false, ('%s must be %d to %d.'):format(s.label, s.min or 0, s.max or 0) end
    local old = getSetting(s)
    local t, k = ref(s.path)
    t[k] = v
    saveSetting(s.key, v, who)
    UL.audit(who, 'settings', ('%s: %s → %s'):format(s.label, tostring(old), tostring(v)))
    return true
end)

---------------------------------------------------------------------
-- Permissions (READ ONLY): who online has which UnitLink ACE
---------------------------------------------------------------------
A('admin.perms', function()
    local nodes = { { node = (Config.Admin and Config.Admin.ace) or 'unitlink.admin', label = 'ADMIN' } }
    for _, d in ipairs(Bridge.departments()) do
        if d.duty then nodes[#nodes + 1] = { node = d.duty, label = d.short } end
        if d.supervisor then nodes[#nodes + 1] = { node = d.supervisor, label = d.short .. ' SUP' } end
    end
    local players = {}
    for _, s in ipairs(GetPlayers()) do
        local n = tonumber(s)
        local has = {}
        for i, nd in ipairs(nodes) do has[i] = IsPlayerAceAllowed(n, nd.node) == true end
        players[#players + 1] = { src = n, name = GetPlayerName(n), has = has, civ = Identity.activeName and Identity.activeName(n) or nil }
    end
    table.sort(players, function(a, b) return a.src < b.src end)
    return true, { nodes = nodes, players = players }
end)

---------------------------------------------------------------------
-- Activity + audit
---------------------------------------------------------------------
A('admin.activity', function(src, who, p)
    local q = UL.clean(p.q, 48) or ''
    q = UL.trim((q:gsub('[%%_]', '')))
    local like = '%' .. q .. '%'
    local rows = UL.DB.query([[SELECT name, callsign, dept, action, UNIX_TIMESTAMP(created_at) AS at FROM ul_activity
        WHERE name LIKE ? OR callsign LIKE ? OR dept LIKE ? OR action LIKE ? ORDER BY id DESC LIMIT 200]], { like, like, like, like })
    if not rows then return false, 'Database error.' end
    return true, rows
end)

A('admin.audit', function()
    local rows = UL.DB.query('SELECT admin, area, change_text, UNIX_TIMESTAMP(created_at) AS at FROM ul_audit ORDER BY id DESC LIMIT 200')
    if not rows then return false, 'Database error.' end
    return true, rows
end)
