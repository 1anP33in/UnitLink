---------------------------------------------------------------------
-- Civilian Portal (/civ). No duty needed: every request acts on the
-- player's ACTIVE civilian profile (standalone) or character (Core).
--   dashboard: licenses, warrants, citations (fines never charge
--   anything, they just expire), arrests, medical history, vehicles,
--   businesses, applications, 911 / service request tracking
--   911: police (UnitLink-Police), fire / EMS (SAFR), DOT service requests
--   applications: licenses, vehicle registration, business licenses
-- Admins approve applications in the Admin Dashboard (server/admin.lua).
---------------------------------------------------------------------
Civ = {}
local C = Config.Civ
local inList = UL.inList
local function civ(action, fn) UL.civHandlers[action] = fn end
local LICENSES = { drivers = "Driver's License", firearm = 'Firearm License', pilot = 'Pilot License' }
local APP_LABEL = { drivers = "Driver's License", firearm = 'Firearm License', pilot = 'Pilot License', vehicle = 'Vehicle Registration', business = 'Business License' }

local function fullName(c) return ('%s %s'):format(c.firstname, c.lastname) end

-- the active profile or nil, error
local function me(src)
    local c = Identity.active(src)
    if not c then return nil, Identity.mode() == 'core' and 'No character loaded.' or 'Create or pick a civilian profile first.' end
    return c
end

---------------------------------------------------------------------
-- Licenses
---------------------------------------------------------------------
local function licenseStatus(civId, key)
    local raw = Identity.getLicenses(civId)
    local v = type(raw) == 'table' and raw[key] or nil
    if type(v) == 'table' then return tostring(v.status or 'none'):upper() end
    if type(v) == 'string' then return v:upper() end
    return tostring(Config.Licenses.defaults[key] or 'none'):upper()
end

function Civ.setLicense(civId, key, status)
    local raw = Identity.getLicenses(civId)
    raw = type(raw) == 'table' and raw or {}
    local cur = raw[key]
    if type(cur) == 'table' then cur.status = status
    else cur = { status = status, points = 0 } end
    raw[key] = cur
    return Identity.setLicenses(civId, raw)
end

---------------------------------------------------------------------
-- Applications: validation + approval (approval is shared with admin.lua)
---------------------------------------------------------------------
local function cleanPlate(v)
    v = UL.clean(v, 8)
    if not v then return nil end
    v = v:upper()
    if #v < 2 or not v:match('^[A-Z0-9 ]+$') then return nil end
    return v
end

-- Turns an approved application into the real thing. Returns ok, err.
function Civ.approve(app)
    local d = type(app.data) == 'table' and app.data or UL.decode(app.data, {})
    if LICENSES[app.type] then
        return Civ.setLicense(app.civ_id, app.type, 'valid') and true or false, 'Could not update the license.'
    elseif app.type == 'vehicle' then
        if (UL.DB.scalar('SELECT COUNT(*) FROM ul_civ_vehicles WHERE plate = ?', { d.plate }) or 0) > 0 then return false, 'Plate ' .. tostring(d.plate) .. ' is already registered.' end
        return UL.DB.insert('INSERT INTO ul_civ_vehicles (civ_id, plate, model, color) VALUES (?, ?, ?, ?)', { app.civ_id, d.plate, d.model, d.color }) ~= nil, 'Database error.'
    elseif app.type == 'business' then
        return UL.DB.insert('INSERT INTO ul_civ_businesses (civ_id, name, type) VALUES (?, ?, ?)', { app.civ_id, d.name, d.btype }) ~= nil, 'Database error.'
    end
    return false, 'Unknown application.'
end

local function validateApp(c, t, p)
    local pending = UL.DB.scalar("SELECT COUNT(*) FROM ul_civ_applications WHERE civ_id = ? AND type = ? AND status = 'PENDING'", { c.id, t }) or 0
    if LICENSES[t] then
        if pending > 0 then return nil, 'You already applied. Wait for a decision.' end
        local st = licenseStatus(c.id, t)
        if st == 'VALID' then return nil, 'You already hold a valid ' .. LICENSES[t] .. '.' end
        if st == 'SUSPENDED' or st == 'REVOKED' then return nil, ('Your %s is %s. Only an admin can restore it.'):format(LICENSES[t], st:lower()) end
        return {}
    elseif t == 'vehicle' then
        local plate = cleanPlate(p.plate)
        if not plate then return nil, 'Plates are 2 to 8 letters / numbers.' end
        local model = UL.clean(p.model, 40)
        if not model or #model < 2 then return nil, 'Enter the vehicle model.' end
        if not inList(C.vehicleColors, p.color) then return nil, 'Pick a color.' end
        local owned = UL.DB.scalar('SELECT COUNT(*) FROM ul_civ_vehicles WHERE civ_id = ?', { c.id }) or 0
        if owned + pending >= (C.maxVehicles or 6) then return nil, ('You can register up to %d vehicles.'):format(C.maxVehicles or 6) end
        if (UL.DB.scalar('SELECT COUNT(*) FROM ul_civ_vehicles WHERE plate = ?', { plate }) or 0) > 0 then return nil, 'That plate is taken.' end
        return { plate = plate, model = model:upper(), color = p.color }
    elseif t == 'business' then
        local name = UL.clean(p.name, 64)
        if not name or #name < 3 then return nil, 'Enter the business name.' end
        if not inList(C.businessTypes, p.btype) then return nil, 'Pick a business type.' end
        local owned = UL.DB.scalar("SELECT COUNT(*) FROM ul_civ_businesses WHERE civ_id = ? AND status = 'ACTIVE'", { c.id }) or 0
        if owned + pending >= (C.maxBusinesses or 3) then return nil, ('You can own up to %d businesses.'):format(C.maxBusinesses or 3) end
        return { name = name, btype = p.btype }
    end
    return nil, 'Pick an application.'
end

---------------------------------------------------------------------
-- 911 / service request tracking
---------------------------------------------------------------------
local pendingPolice, lastRequest = {}, {}

-- UnitLink-Police tells us the call number for a civilian's 911 call
AddEventHandler('unitlink-police:server:callCreated', function(call, callerSrc)
    local p = callerSrc and pendingPolice[callerSrc]
    if not p or type(call) ~= 'table' then return end
    pendingPolice[callerSrc] = nil
    if os.time() - p.at > 30 then return end
    UL.DB.update('UPDATE ul_civ_calls SET ref_id = ? WHERE id = ?', { tonumber(call.id), p.row })
end)
AddEventHandler('playerDropped', function() pendingPolice[source], lastRequest[source] = nil, nil end)

local function trackStatus(r)
    if r.service == 'POLICE' then
        if not r.ref_id then return os.time() - r.at > 60 and 'NOT PLACED' or 'SENDING', '' end
        local c = Bridge.call(r.ref_id)
        if not c then return 'CLOSED', '' end
        local n = 0
        for _ in pairs(type(c.units) == 'table' and c.units or {}) do n = n + 1 end
        return n > 0 and 'UNITS ASSIGNED' or 'WAITING FOR UNITS', n > 0 and (n .. ' unit' .. (n > 1 and 's' or '')) or ''
    elseif r.service == 'FIRE' or r.service == 'EMS' then
        local inc = Fire and Fire.incidents and Fire.incidents[r.ref_id]
        if not inc then return 'CLOSED', '' end
        local n = 0
        for _ in pairs(inc.units or {}) do n = n + 1 end
        return n > 0 and 'UNITS ASSIGNED' or 'WAITING FOR UNITS', n > 0 and (n .. ' unit' .. (n > 1 and 's' or '')) or ''
    elseif r.service == 'DOT' then
        local o = Dot and Dot.orders and Dot.orders[r.ref_id]
        if not o then return 'COMPLETED', '' end
        return o.status, ''
    end
    return '-', ''
end

local function cooldown(src)
    local now = os.time()
    local wait = (lastRequest[src] or 0) + (C.callCooldown or 60) - now
    if wait > 0 then return ('Please wait %d seconds.'):format(wait) end
    lastRequest[src] = now
end

---------------------------------------------------------------------
-- Dashboard
---------------------------------------------------------------------
local function dashboard(c)
    local id = c.id
    local now = os.time()
    local recs = UL.DB.query([[SELECT id, type, status, officer_label, data, UNIX_TIMESTAMP(created_at) AS at FROM ul_records
        WHERE subject_char = ? AND (type IN ('citation', 'arrest') OR (type = 'warrant' AND status = 'active')) ORDER BY id DESC LIMIT 100]], { id }) or {}
    local citations, arrests, warrants = {}, {}, {}
    for _, r in ipairs(recs) do
        local d = UL.decode(r.data, {})
        local charges = {}
        for _, ch in ipairs(d.charges or {}) do charges[#charges + 1] = type(ch) == 'table' and (ch.offense or ch.code) or tostring(ch) end
        local row = { number = UL.recordNo(r.type, r.id), at = r.at, officer = r.officer_label, charges = charges, status = tostring(r.status):upper() }
        if r.type == 'citation' then
            if Config.Fines and Config.Fines.enabled and (tonumber(d.fine) or 0) > 0 then
                local expires = tonumber(d.fineExpires) or (r.at + Config.Fines.expireDays * 86400)
                row.fine, row.fineExpires, row.fineStatus = tonumber(d.fine), expires, now < expires and 'OUTSTANDING' or 'EXPIRED'
            end
            citations[#citations + 1] = row
        elseif r.type == 'arrest' then
            row.booking = d.booking
            arrests[#arrests + 1] = row
        else
            row.warrantType = d.warrantType
            warrants[#warrants + 1] = row
        end
    end
    local calls = UL.DB.query('SELECT id, service, ref_id, message, street, UNIX_TIMESTAMP(created_at) AS at FROM ul_civ_calls WHERE civ_id = ? ORDER BY id DESC LIMIT 25', { id }) or {}
    for _, r in ipairs(calls) do r.status, r.units = trackStatus(r) end
    local licenses = {}
    local raw = Identity.getLicenses(id)
    for _, k in ipairs({ 'drivers', 'firearm', 'pilot' }) do
        local v = type(raw) == 'table' and raw[k] or nil
        licenses[#licenses + 1] = { key = k, label = LICENSES[k], status = licenseStatus(id, k), points = type(v) == 'table' and tonumber(v.points) or 0 }
    end
    return {
        profile = { id = id, name = fullName(c), dob = c.dateofbirth, gender = c.gender, nationality = c.nationality, height = c.height },
        licenses = licenses, suspendAt = Config.Licenses.suspendAt,
        citations = citations, arrests = arrests, warrants = warrants,
        medical = UL.DB.query([[SELECT incident_id, injury, severity, destination, pt_condition, UNIX_TIMESTAMP(created_at) AS at FROM ul_fire_patients
            WHERE subject_char = ? ORDER BY id DESC LIMIT 25]], { id }) or {},
        vehicles = UL.DB.query('SELECT id, plate, model, color, status, UNIX_TIMESTAMP(created_at) AS at FROM ul_civ_vehicles WHERE civ_id = ? ORDER BY id', { id }) or {},
        businesses = UL.DB.query("SELECT id, name, type, status, UNIX_TIMESTAMP(created_at) AS at FROM ul_civ_businesses WHERE civ_id = ? ORDER BY id", { id }) or {},
        applications = UL.DB.query('SELECT id, type, data, status, reason, reviewed_by, UNIX_TIMESTAMP(created_at) AS at FROM ul_civ_applications WHERE civ_id = ? ORDER BY id DESC LIMIT 30', { id }) or {},
        calls = calls,
    }
end

civ('civ.portal', function(src, owner)
    local okList, list = UL.civHandlers['civ.list'](src, owner)
    if not okList then return false, list end
    local c = Identity.active(src)
    list.dash = c and dashboard(c) or nil
    if list.dash then for _, a in ipairs(list.dash.applications) do a.data = UL.decode(a.data, {}); a.label = APP_LABEL[a.type] or a.type end end
    local services = {}
    for i, s in ipairs(C.serviceRequests or {}) do services[#services + 1] = { id = i, label = s.label } end
    list.cfg = {
        name = Config.Name, services = services, colors = C.vehicleColors, businessTypes = C.businessTypes, approval = C.approval,
        fines = { enabled = Config.Fines and Config.Fines.enabled == true, symbol = Config.Fines and Config.Fines.symbol or '$', expireDays = Config.Fines and Config.Fines.expireDays or 0 },
        fire = Config.Fire and Config.Fire.enabled == true, dot = Config.Dot and Config.Dot.enabled == true,
        maxVehicles = C.maxVehicles, maxBusinesses = C.maxBusinesses,
    }
    return true, list
end)

---------------------------------------------------------------------
-- 911 and service requests
---------------------------------------------------------------------
civ('civ.call', function(src, owner, p)
    local c, err = me(src)
    if not c then return false, err end
    local service = ({ POLICE = 'POLICE', FIRE = 'FIRE', EMS = 'EMS' })[p.service]
    if not service then return false, 'Pick a service.' end
    if service ~= 'POLICE' and not (Config.Fire and Config.Fire.enabled) then return false, 'Fire & Rescue is not available on this server.' end
    local message = UL.clean(p.message, 300)
    if not message or #message < 5 then return false, 'Describe what is happening.' end
    local street = UL.clean(p.street, 120)
    if service == 'POLICE' then
        local wait = cooldown(src)
        if wait then return false, wait end
        local row = UL.DB.insert('INSERT INTO ul_civ_calls (civ_id, service, message, street) VALUES (?, ?, ?, ?)', { c.id, service, message, street })
        pendingPolice[src] = { row = row, at = os.time() }
        -- the client now sends it to UnitLink-Police (/911), which needs the caller's own event
        return true, { police = true, message = message }
    end
    local ok, msg, incId = Fire.civCall(src, service == 'FIRE' and 'fire' or 'medical', message, street)
    if not ok then return false, msg end
    UL.DB.insert('INSERT INTO ul_civ_calls (civ_id, service, ref_id, message, street) VALUES (?, ?, ?, ?, ?)', { c.id, service, incId, message, street })
    return true, { message = msg, ref = incId }
end)

civ('civ.service', function(src, owner, p)
    local c, err = me(src)
    if not c then return false, err end
    if not (Dot and Dot.newOrder and Config.Dot and Config.Dot.enabled) then return false, 'DOT is not available on this server.' end
    local s = (C.serviceRequests or {})[UL.int(p.type) or 0]
    if not s then return false, 'Pick what you are reporting.' end
    local desc = UL.clean(p.message, 300)
    if not desc or #desc < 5 then return false, 'Describe the problem and where it is.' end
    local wait = cooldown(src)
    if wait then return false, wait end
    local pos = Bridge.coords(src)
    local o = Dot.newOrder({ category = s.category, description = ('%s: %s'):format(s.label:upper(), desc), priority = 3, street = UL.clean(p.street, 120),
        coords = pos and { x = pos.x, y = pos.y, z = pos.z } or { x = 0.0, y = 0.0, z = 0.0 }, requester = fullName(c), requesterChar = c.id, origin = '311' })
    if not o then return false, 'Your request could not be sent. Try again.' end
    Dot.note(o.id, 'SYSTEM', ('(SYSTEM) Service request from %s'):format(fullName(c)), true)
    for _, u in ipairs(Bridge.units()) do
        if u.flags and u.flags[Config.Dot.accessFlag] then UL.notify(u.source, ('**New service request WO-%d:** %s'):format(o.id, s.label), 'info') end
    end
    UL.DB.insert('INSERT INTO ul_civ_calls (civ_id, service, ref_id, message, street) VALUES (?, ?, ?, ?, ?)', { c.id, 'DOT', o.id, desc, UL.clean(p.street, 120) })
    return true, { ref = o.id }
end)

---------------------------------------------------------------------
-- Applications, vehicles, businesses
---------------------------------------------------------------------
civ('civ.apply', function(src, owner, p)
    local c, err = me(src)
    if not c then return false, err end
    local t = tostring(p.type or '')
    if not APP_LABEL[t] then return false, 'Pick an application.' end
    local data, why = validateApp(c, t, type(p.data) == 'table' and p.data or {})
    if not data then return false, why end
    local needs = C.approval == nil or C.approval[t] ~= false
    local app = { civ_id = c.id, type = t, data = data }
    if not needs then
        local ok, e = Civ.approve(app)
        if not ok then return false, e end
    end
    if needs then
        UL.DB.insert("INSERT INTO ul_civ_applications (civ_id, civ_name, type, data, status) VALUES (?, ?, ?, ?, 'PENDING')", { c.id, fullName(c), t, UL.json(data) })
    else
        UL.DB.insert([[INSERT INTO ul_civ_applications (civ_id, civ_name, type, data, status, reviewed_by, reviewed_at)
            VALUES (?, ?, ?, ?, 'APPROVED', 'AUTOMATIC', CURRENT_TIMESTAMP)]], { c.id, fullName(c), t, UL.json(data) })
    end
    if needs then
        for _, s in ipairs(GetPlayers()) do
            local n = tonumber(s)
            if n and IsPlayerAceAllowed(n, Config.Admin and Config.Admin.ace or 'unitlink.admin') then UL.notify(n, ('New %s application from %s'):format(APP_LABEL[t], fullName(c)), 'info') end
        end
    end
    return true, { pending = needs, label = APP_LABEL[t] }
end)

civ('civ.vehicleStatus', function(src, owner, p)
    local c, err = me(src)
    if not c then return false, err end
    local v = UL.DB.single('SELECT id, plate, model, color, status FROM ul_civ_vehicles WHERE id = ? AND civ_id = ?', { UL.int(p.id) or 0, c.id })
    if not v then return false, 'That vehicle is not yours.' end
    local status = p.status == 'STOLEN' and 'STOLEN' or 'VALID'
    if v.status == 'IMPOUNDED' then return false, 'Impounded vehicles are released by the police.' end
    if v.status == status then return true end
    UL.DB.update('UPDATE ul_civ_vehicles SET status = ? WHERE id = ?', { status, v.id })
    if status == 'STOLEN' then
        -- every department sees it on the shared BOLO board
        UL.DB.insert('INSERT INTO ul_bolos (type, title, body, plate, dept, created_by) VALUES (?, ?, ?, ?, ?, ?)',
            { 'VEHICLE', ('Stolen %s %s'):format(v.color, v.model), 'Reported stolen by the owner, ' .. fullName(c) .. '.', v.plate, 'CIV', fullName(c):sub(1, 64) })
        for _, u in ipairs(Bridge.units()) do UL.push(u.source, 'toolsBolo', {}); UL.notify(u.source, ('**Stolen vehicle:** %s %s · %s'):format(v.color, v.model, v.plate), 'warning') end
    else
        UL.DB.update("UPDATE ul_bolos SET active = 0, cleared_by = ? WHERE plate = ? AND dept = 'CIV' AND active = 1", { fullName(c):sub(1, 64), v.plate })
    end
    return true
end)

civ('civ.vehicleRemove', function(src, owner, p)
    local c, err = me(src)
    if not c then return false, err end
    local n = UL.DB.update("DELETE FROM ul_civ_vehicles WHERE id = ? AND civ_id = ? AND status <> 'IMPOUNDED'", { UL.int(p.id) or 0, c.id }) or 0
    if n == 0 then return false, 'That vehicle cannot be removed.' end
    return true
end)

civ('civ.businessClose', function(src, owner, p)
    local c, err = me(src)
    if not c then return false, err end
    local n = UL.DB.update("UPDATE ul_civ_businesses SET status = 'CLOSED' WHERE id = ? AND civ_id = ? AND status = 'ACTIVE'", { UL.int(p.id) or 0, c.id }) or 0
    if n == 0 then return false, 'That business is not yours.' end
    return true
end)

civ('civ.cancelApp', function(src, owner, p)
    local c, err = me(src)
    if not c then return false, err end
    local n = UL.DB.update("DELETE FROM ul_civ_applications WHERE id = ? AND civ_id = ? AND status = 'PENDING'", { UL.int(p.id) or 0, c.id }) or 0
    if n == 0 then return false, 'Nothing to cancel.' end
    return true
end)
