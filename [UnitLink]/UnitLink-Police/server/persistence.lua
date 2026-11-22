---------------------------------------------------------------------
-- Duty hours storage + restart recovery.
--
-- Data kept (per mode below):
--   totals : identifier -> { name, seconds, sessions, lastCallsign, lastDepartment, lastSeen }
--   recent : last N finished sessions (identifier, callsign, department, start, end, duration, reason)
--   active : identifier -> open session checkpoint (for crash / restart recovery)
--
-- Modes (Config.Persistence.mode):
--   kvp    : server KVP store. Survives restarts and server reboots. No setup.
--   json   : files in UnitLink-Police/data/. Survives restarts. Human readable.
--   memory : RAM only. Lost on resource restart / server reboot. Totals shown
--            in game are labelled "since restart" so nobody is misled.
---------------------------------------------------------------------
Persistence = {}

local RESOURCE = GetCurrentResourceName()
local mode = Config.Persistence.mode
local memory = {}

local backends = {
    memory = {
        load = function(key) return memory[key] end,
        save = function(key, value) memory[key] = value end,
    },
    kvp = {
        load = function(key)
            local raw = GetResourceKvpString('unitlink_police:' .. key)
            if not raw then return nil end
            local ok, value = pcall(json.decode, raw)
            return ok and value or nil
        end,
        save = function(key, value) SetResourceKvp('unitlink_police:' .. key, json.encode(value)) end,
    },
    json = {
        load = function(key)
            local raw = LoadResourceFile(RESOURCE, ('data/%s.json'):format(key))
            if not raw or raw == '' then return nil end
            local ok, value = pcall(json.decode, raw)
            return ok and value or nil
        end,
        save = function(key, value)
            local ok = SaveResourceFile(RESOURCE, ('data/%s.json'):format(key), json.encode(value, { indent = true }), -1)
            if not ok then print('^1[UnitLink-Police] could not write data/' .. key .. '.json (does the data folder exist?)^7') end
        end,
    },
}

if not backends[mode] then
    print(('^3[UnitLink-Police] unknown persistence mode "%s", using kvp^7'):format(tostring(mode)))
    mode = 'kvp'
end
local store = backends[mode]

local function safeLoad(key, default)
    local ok, value = pcall(store.load, key)
    if ok and type(value) == 'table' then return value end
    return default
end

local function safeSave(key, value)
    local ok, err = pcall(store.save, key, value)
    if not ok then print(('^1[UnitLink-Police] saving %s failed: %s^7'):format(key, tostring(err))) end
end

local totals = safeLoad('totals', {})
local recent = safeLoad('recent', {})
local active = safeLoad('active', {})

function Persistence.mode() return mode end
function Persistence.isPersistent() return mode ~= 'memory' end

function Persistence.totalsFor(identifier)
    local t = totals[identifier] or {}
    return { seconds = t.seconds or 0, sessions = t.sessions or 0, persistent = mode ~= 'memory' }
end

-- Store a finished session (also used for interrupted ones)
local function record(entry)
    local t = totals[entry.identifier] or { seconds = 0, sessions = 0 }
    t.seconds = (t.seconds or 0) + entry.duration
    t.sessions = (t.sessions or 0) + 1
    t.name = entry.name
    t.lastCallsign = entry.callsign
    t.lastDepartment = entry.department
    t.lastSeen = entry.endedAt
    totals[entry.identifier] = t

    table.insert(recent, 1, {
        identifier = entry.identifier, name = entry.name, callsign = entry.callsign, department = entry.department,
        startedAt = entry.startedAt, endedAt = entry.endedAt, duration = entry.duration, reason = entry.reason,
    })
    while #recent > (Config.Persistence.keepRecords or 500) do table.remove(recent) end

    safeSave('totals', totals)
    safeSave('recent', recent)
end

local function checkpoint(s, extra)
    local entry = {
        source = s.source, name = s.name, callsign = s.callsign, department = s.department,
        startedAt = s.startedAt, lastSeen = os.time(), blipVisible = s.blipVisible,
    }
    if extra then for k, v in pairs(extra) do entry[k] = v end end
    active[s.identifier] = entry
end

---------------------------------------------------------------------
-- Duty listeners
---------------------------------------------------------------------
Police.on('clockIn', function(s)
    checkpoint(s)
    safeSave('active', active)
end)

Police.on('clockOut', function(s)
    active[s.identifier] = nil
    safeSave('active', active)
    record({
        identifier = s.identifier, name = s.name, callsign = s.callsign, department = s.department,
        startedAt = s.startedAt, endedAt = s.endedAt, duration = s.duration, reason = s.endReason,
    })
end)

-- Crash safety: refresh lastSeen so an unexpected stop loses at most one interval
CreateThread(function()
    while true do
        Wait(math.max(10, Config.Persistence.checkpointInterval or 60) * 1000)
        if next(Duty.all()) then
            for _, s in pairs(Duty.all()) do checkpoint(s) end
            safeSave('active', active)
        end
    end
end)

-- Resource stopping: mark open sessions so the next start can restore them
Police.on('shutdown', function()
    local now = os.time()
    for _, s in pairs(Duty.all()) do checkpoint(s, { stoppedAt = now }) end
    safeSave('active', active)
end)

---------------------------------------------------------------------
-- Startup recovery
--   Restorable: stopped cleanly within restoreWindow AND the player is still
--   connected AND still passes ACE + callsign checks -> back on duty with the
--   original start time.
--   Everything else is closed as "interrupted" using the last known time.
---------------------------------------------------------------------
local function finalizeInterrupted(identifier, e)
    local endedAt = e.stoppedAt or e.lastSeen or e.startedAt
    local duration = math.max(0, (endedAt or 0) - (e.startedAt or endedAt or 0))
    record({
        identifier = identifier, name = e.name or '?', callsign = e.callsign or '?', department = e.department or '?',
        startedAt = e.startedAt or endedAt, endedAt = endedAt, duration = duration, reason = 'interrupted',
    })
    Log.event('session_interrupted', {
        { name = 'Officer', value = tostring(e.name), inline = true },
        { name = 'Callsign', value = tostring(e.callsign), inline = true },
        { name = 'Recorded', value = Utils.formatDuration(duration), inline = true },
    }, 'Session closed after a restart or crash')
end

CreateThread(function()
    Wait(1500) -- let every module register first
    local pending = active
    active = {}
    safeSave('active', active)
    if not next(pending) then return end

    local online = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src then online[Police.identifier(src)] = src end
    end

    local now = os.time()
    for identifier, e in pairs(pending) do
        local src = online[identifier]
        local restorable = Config.Persistence.restoreOnRestart and mode ~= 'memory'
            and e.stoppedAt and now - e.stoppedAt <= (Config.Persistence.restoreWindow or 300)
            and src ~= nil and not Duty.isOnDuty(src)
        local restored = false
        if restorable then
            restored = Duty.clockIn(src, e.department, e.callsign, { restore = true, startedAt = e.startedAt, blipVisible = e.blipVisible })
        end
        if restored then
            Log.event('session_restored', Log.officer(Duty.get(src)), 'Back on duty after a resource restart')
            Police.notify(src, ('Back on duty as **%s** after a restart.'):format(e.callsign), 'info', 'Duty')
        else
            finalizeInterrupted(identifier, e)
        end
    end
end)
