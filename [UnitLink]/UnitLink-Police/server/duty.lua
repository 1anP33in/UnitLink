---------------------------------------------------------------------
-- Server-authoritative duty sessions.
-- The client only ever *requests* things; every rule is checked here.
---------------------------------------------------------------------
Duty = {}

local S = Police.Status
local sessions = {}       -- [source] = session
local callsignOwners = {} -- [scopeKey] = source

local function ownerKey(dept, callsign)
    if Config.Callsign.duplicateScope == 'department' then return dept .. '|' .. callsign end
    return callsign
end

function Duty.get(src) return sessions[src] end
function Duty.all() return sessions end
function Duty.isOnDuty(src) return sessions[src] ~= nil end

-- Iterate on-duty units, optionally only departments whose type has `flag`
function Duty.each(flag, fn)
    for src, s in pairs(sessions) do
        if not flag or Utils.deptHas(s.department, flag) then fn(src, s) end
    end
end

function Duty.count(flag)
    local n = 0
    Duty.each(flag, function() n = n + 1 end)
    return n
end

---------------------------------------------------------------------
-- Validation (ACE, department, callsign format, callsign uniqueness)
-- Returns true, callsign  |  false, message, code, callsign
---------------------------------------------------------------------
local function callsignMessage(code, dept, cs)
    local rules = (Config.Departments[dept] or {}).callsign or {}
    if code == 'callsign_length' then return Police.errorText(code, rules.minLength or 2, rules.maxLength or 10) end
    if code == 'callsign_format' then return Police.errorText(code, rules.example or '?') end
    if code == 'callsign_taken' then return Police.errorText(code, cs) end
    return Police.errorText(code)
end

local function validate(src, dept, rawCallsign, ignoreOwner)
    if not Config.Enabled then return false, Police.errorText('disabled'), 'disabled' end
    if type(dept) ~= 'string' or not Config.Departments[dept] then
        return false, Police.errorText('invalid_department'), 'invalid_department'
    end
    if not Permissions.hasCharacter(src) then
        return false, Police.errorText('no_character'), 'no_character'
    end
    if not Permissions.canUseDepartment(src, dept) then
        return false, Police.errorText('not_authorized'), 'not_authorized'
    end
    local ok, cs = Utils.validateCallsign(rawCallsign, Config.Departments[dept].callsign)
    if not ok then return false, callsignMessage(cs, dept), cs end
    local owner = callsignOwners[ownerKey(dept, cs)]
    if owner and owner ~= ignoreOwner and sessions[owner] then
        return false, callsignMessage('callsign_taken', dept, cs), 'callsign_taken', cs
    end
    return true, cs
end

local function logRejection(src, code, dept, rawCallsign, cs)
    if code == 'not_authorized' or code == 'invalid_department' then
        Log.event('permission_denied', {
            Log.player(src),
            { name = 'Department', value = tostring(dept), inline = true },
        }, 'Tried to go on duty without access')
    elseif code == 'callsign_taken' then
        local owner = sessions[callsignOwners[ownerKey(dept, cs)]]
        Log.event('callsign_conflict', {
            Log.player(src),
            { name = 'Callsign', value = cs, inline = true },
            { name = 'In use by', value = owner and ('%s (ID %d)'):format(owner.name, owner.source) or '?', inline = true },
        })
    end
end

---------------------------------------------------------------------
-- Clock in / out
---------------------------------------------------------------------
-- opts: restore (bool), startedAt (epoch), blipVisible (bool)
function Duty.clockIn(src, dept, rawCallsign, opts)
    opts = opts or {}
    if sessions[src] then return false, Police.errorText('already_on_duty'), 'already_on_duty' end

    local ok, result, code, cs = validate(src, dept, rawCallsign)
    if not ok then
        if not opts.restore then logRejection(src, code, dept, rawCallsign, cs) end
        return false, result, code
    end

    local s = {
        source = src,
        identifier = Police.identifier(src),
        name = Police.displayName(src),
        department = dept,
        callsign = result,
        startedAt = opts.startedAt or os.time(),
        status = S.AVAILABLE,
        manualStatus = false, -- true while the officer picked Busy / Unavailable
        blipVisible = opts.blipVisible ~= false,
        calls = {},           -- [callId] = true while responding
    }
    sessions[src] = s
    callsignOwners[ownerKey(dept, s.callsign)] = src

    Police.emit('clockIn', s, opts)
    if not opts.restore and not opts.silent then Log.event('clock_in', Log.officer(s)) end
    Duty.pushState(src)
    Police.emit('rosterChanged')
    return true, s
end

function Duty.clockOut(src, reason)
    local s = sessions[src]
    if not s then return false, Police.errorText('not_on_duty') end
    sessions[src] = nil
    local key = ownerKey(s.department, s.callsign)
    if callsignOwners[key] == src then callsignOwners[key] = nil end

    s.endedAt = os.time()
    s.duration = math.max(0, s.endedAt - s.startedAt)
    s.endReason = reason or 'clock_out'

    Police.emit('clockOut', s, s.endReason) -- dispatch clears assignments, roster removes blips, persistence records
    if s.endReason ~= 'department_change' then
        local fields = Log.officer(s)
        fields[#fields + 1] = { name = 'Duration', value = Utils.formatDuration(s.duration), inline = true }
        fields[#fields + 1] = { name = 'Reason', value = s.endReason, inline = true }
        Log.event('clock_out', fields)
    end
    if GetPlayerName(src) then Duty.pushState(src) end
    Police.emit('rosterChanged')
    return true, s
end

function Duty.changeDepartment(src, dept, rawCallsign)
    local s = sessions[src]
    if not s then return false, Police.errorText('not_on_duty') end
    local ok, result, code, cs = validate(src, dept, rawCallsign, src)
    if not ok then
        logRejection(src, code, dept, rawCallsign, cs)
        return false, result
    end
    if dept == s.department and result == s.callsign then return false, Police.errorText('nothing_changed') end

    local old = { department = s.department, callsign = s.callsign }
    local visible = s.blipVisible
    Duty.clockOut(src, 'department_change')
    local ok2, ns = Duty.clockIn(src, dept, result, { silent = true, blipVisible = visible })
    if not ok2 then return false, ns end

    local fields = Log.officer(ns)
    fields[#fields + 1] = { name = 'From', value = ('%s (%s)'):format(old.callsign, Config.Departments[old.department].short), inline = true }
    Log.event('department_change', fields)
    return true, ns
end

---------------------------------------------------------------------
-- Response status
---------------------------------------------------------------------
local function applyStatus(s, status)
    if s.status == status then return end
    s.status = status
    Police.emit('statusChanged', s)
    Police.emit('rosterChanged')
    Duty.pushState(s.source)
end

-- Officer picks a status by hand (Available / Busy / Unavailable)
function Duty.setManualStatus(src, status)
    local s = sessions[src]
    if not s or not Police.ManualStatuses[status] then return false end
    if status == S.AVAILABLE then
        s.manualStatus = false
        -- can't be "available" while assigned to a call: stay Responding
        applyStatus(s, next(s.calls) and S.RESPONDING or S.AVAILABLE)
    else
        s.manualStatus = true
        applyStatus(s, status)
    end
    return true
end

-- Called after call assignments change
function Duty.refreshStatus(src)
    local s = sessions[src]
    if not s then return end
    if next(s.calls) then
        -- keep On Scene while still on a call; otherwise Responding
        if not s.manualStatus and s.status ~= S.ONSCENE then applyStatus(s, S.RESPONDING) end
    elseif s.status == S.RESPONDING or s.status == S.ONSCENE then
        applyStatus(s, S.AVAILABLE)
    end
end

-- Any status, used by the CAD. Responding / On Scene only while on a call.
function Duty.setUnitStatus(src, status)
    local s = sessions[src]
    if not s or type(status) ~= 'string' then return false end
    if Police.ManualStatuses[status] then return Duty.setManualStatus(src, status) end
    if (status == S.RESPONDING or status == S.ONSCENE) and next(s.calls) then
        s.manualStatus = false
        applyStatus(s, status)
        return true
    end
    return false
end

-- Accepting a call always switches to Responding
function Duty.markResponding(src)
    local s = sessions[src]
    if not s then return end
    s.manualStatus = false
    applyStatus(s, S.RESPONDING)
end

---------------------------------------------------------------------
-- State sent to the officer's own client (never other players' identifiers)
---------------------------------------------------------------------
function Duty.stateFor(src, withMenuData)
    local s = sessions[src]
    local view = { onDuty = s ~= nil, enabled = Config.Enabled, onDutyCount = Duty.count('roster') }
    if s then
        local d = Config.Departments[s.department]
        local calls = 0
        for _ in pairs(s.calls) do calls = calls + 1 end
        view.department = s.department
        view.departmentShort = d.short
        view.departmentName = d.name
        view.callsign = s.callsign
        view.elapsed = os.time() - s.startedAt
        view.status = s.status
        view.manualStatus = s.manualStatus
        view.blipVisible = s.blipVisible
        view.activeCalls = calls
        view.flags = Utils.deptFlags(s.department)
        view.supervisor = Permissions.isSupervisor(src, s.department)
    end
    if withMenuData then
        view.hasCharacter = Permissions.hasCharacter(src)
        view.authorized = Permissions.authorizedDepartments(src)
        view.totals = Persistence.totalsFor(Police.identifier(src))
        view.canHideBlip = Config.Blips.allowHide == true
    end
    return view
end

function Duty.pushState(src, withMenuData)
    Police.toClient(src, 'dutyState', Duty.stateFor(src, withMenuData))
end

---------------------------------------------------------------------
-- Network requests from the duty menu
---------------------------------------------------------------------
local function reply(src, ok, message)
    Police.notify(src, message, ok and 'success' or 'error', 'Duty')
end

Police.net('requestState', 'state', function(src)
    Duty.pushState(src, true)
end)

Police.net('clockIn', 'duty', function(src, dept, callsign)
    if type(dept) ~= 'string' or type(callsign) ~= 'string' or #callsign > 32 then return end
    local ok, result = Duty.clockIn(src, dept, callsign)
    if ok then
        reply(src, true, ('On duty as **%s** · %s'):format(result.callsign, Config.Departments[dept].short))
    else
        reply(src, false, result)
    end
end)

Police.net('clockOut', 'duty', function(src)
    local ok, s = Duty.clockOut(src, 'clock_out')
    if ok then
        reply(src, true, ('Off duty. Session: **%s**'):format(Utils.formatDuration(s.duration)))
    else
        reply(src, false, s)
    end
end)

Police.net('changeDepartment', 'duty', function(src, dept, callsign)
    if type(dept) ~= 'string' or type(callsign) ~= 'string' or #callsign > 32 then return end
    local ok, result = Duty.changeDepartment(src, dept, callsign)
    if ok then
        reply(src, true, ('Now on duty as **%s** · %s'):format(result.callsign, Config.Departments[dept].short))
    else
        reply(src, false, result)
    end
end)

Police.net('setStatus', 'status', function(src, status)
    if type(status) ~= 'string' then return end
    if not Duty.setManualStatus(src, status) then return end
    Police.notify(src, ('Status: **%s**'):format(Utils.statusLabel(sessions[src].status)), 'info', 'Duty', 2500)
end)

Police.net('setBlipVisible', 'status', function(src, visible)
    local s = sessions[src]
    if not s or type(visible) ~= 'boolean' or not Config.Blips.allowHide then return end
    if s.blipVisible == visible then return end
    s.blipVisible = visible
    Police.emit('blipVisibilityChanged', s)
    Duty.pushState(src, true)
    Police.notify(src, visible and 'Your blip is **visible** to other units.' or 'Your blip is **hidden** from other units.', 'info', 'Duty', 3000)
end)

---------------------------------------------------------------------
-- Re-check access for on-duty units (called when framework permissions,
-- groups or characters change). Anyone who lost access is clocked out.
---------------------------------------------------------------------
function Duty.revalidate(src)
    local s = sessions[src]
    if not s then return end
    if Permissions.hasCharacter(src) and Permissions.canUseDepartment(src, s.department) then return end
    Duty.clockOut(src, 'permission_removed')
    if GetPlayerName(src) then
        Police.notify(src, ('You no longer have access to %s and were taken off duty.'):format(Config.Departments[s.department].short), 'warning', 'Duty')
    end
end

function Duty.revalidateAll()
    local list = {}
    for src in pairs(sessions) do list[#list + 1] = src end
    for _, src in ipairs(list) do Duty.revalidate(src) end
end

---------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------
Police.on('playerDropped', function(src)
    if sessions[src] then Duty.clockOut(src, 'disconnect') end
end)

---------------------------------------------------------------------
-- Server exports for other resources
---------------------------------------------------------------------
local function publicView(s)
    if not s then return nil end
    return {
        source = s.source, name = s.name, callsign = s.callsign, department = s.department,
        status = s.status, startedAt = s.startedAt, blipVisible = s.blipVisible,
    }
end

exports('IsOnDuty', function(src) return sessions[tonumber(src)] ~= nil end)
exports('GetOfficer', function(src) return publicView(sessions[tonumber(src)]) end)
exports('GetOnDutyOfficers', function()
    local list = {}
    for _, s in pairs(sessions) do list[#list + 1] = publicView(s) end
    return list
end)
exports('ClockOut', function(src, reason) return (Duty.clockOut(tonumber(src), reason or 'external')) end)

---------------------------------------------------------------------
-- CAD exports (UnitLink)
---------------------------------------------------------------------
-- Every on-duty unit, with status and the calls it is on
exports('GetUnits', function()
    local list = {}
    for src, s in pairs(sessions) do
        local callIds = {}
        for id in pairs(s.calls) do callIds[#callIds + 1] = id end
        table.sort(callIds)
        local d = Config.Departments[s.department]
        list[#list + 1] = {
            source = src, name = s.name, callsign = s.callsign,
            department = s.department, departmentShort = d.short, type = d.type,
            status = s.status, calls = callIds, startedAt = s.startedAt,
            flags = Utils.deptFlags(s.department),
        }
    end
    table.sort(list, function(a, b) return a.callsign < b.callsign end)
    return list
end)

-- status: available | responding | onscene | busy | unavailable
exports('SetUnitStatus', function(src, status)
    return Duty.setUnitStatus(tonumber(src), status)
end)

-- Supervisor of their own department, or the cross-department override
exports('IsSupervisor', function(src)
    src = tonumber(src)
    local s = src and sessions[src]
    if not s then return false end
    return Permissions.isSupervisor(src, s.department) or Permissions.isAdmin(src)
end)

-- Let other resources know the roster / statuses changed (local event)
Police.on('rosterChanged', function()
    TriggerEvent('unitlink-police:server:unitsChanged')
end)
