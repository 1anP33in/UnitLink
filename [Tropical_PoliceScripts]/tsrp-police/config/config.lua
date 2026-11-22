Config = {}

---------------------------------------------------------------------
-- General
---------------------------------------------------------------------
Config.Enabled = true  -- false = duty, 911 and panic requests are refused
Config.Debug   = false -- extra console output

---------------------------------------------------------------------
-- TSRP Core framework
--   enabled = true : duty access uses TSRP character permissions
--                    (config/permissions.lua), a character must be
--                    loaded to go on duty, names come from the active
--                    character and duty hours are tracked per character.
--   enabled = false: standalone mode, plain FiveM ACE permissions.
---------------------------------------------------------------------
Config.Framework = {
    enabled          = true,
    resource         = 'tsrp-core',
    clockOutOnUnload = true, -- switching / unloading a character ends its duty session
}

-- Standalone mode only: identifier stored with duty records (never sent to
-- clients). With the framework, records use the character id instead.
-- license | discord | fivem | steam   (falls back to license)
Config.IdentifierType = 'license'

-- Name shown on the roster, 911 calls and logs (runs SERVER side).
-- With the framework this is the active character's name; this function
-- is the fallback (standalone mode / no character).
Config.GetPlayerDisplayName = function(source)
    return GetPlayerName(source)
end

---------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------
Config.Commands = {
    duty   = 'duty',   -- duty menu (also: /duty on <dept> <callsign>, /duty off)
    roster = 'police', -- on-duty roster
    calls  = 'calls',  -- active 911 calls (Accept / Deny / Set Waypoint buttons)
    call   = '911',    -- civilians: /911 <message>
    panic  = 'panic',
}

---------------------------------------------------------------------
-- Keybinds (FiveM key names). '' = no default key; players can still
-- bind it in Settings > Key Bindings > FiveM.
---------------------------------------------------------------------
Config.Keybinds = {
    duty     = 'F6',
    calls    = '',
    panic    = '',
    accept   = 'Y', -- newest pending 911 call
    deny     = 'J', -- newest pending 911 call
    waypoint = 'U', -- newest panic (if recent) or newest pending call
}

---------------------------------------------------------------------
-- Callsigns
---------------------------------------------------------------------
Config.Callsign = {
    -- 'global'     = a callsign can only be used once on the whole server
    -- 'department' = the same callsign can be used once per department
    duplicateScope = 'global',
}

---------------------------------------------------------------------
-- 911
---------------------------------------------------------------------
Config.Emergency = {
    enabled         = true,
    minLength       = 5,     -- characters
    maxLength       = 250,
    cooldown        = 60,    -- seconds between calls per player
    maxActiveCalls  = 25,    -- new calls are refused while this many are open
    callLifetime    = 1200,  -- seconds before an open call expires
    firstCallId     = 1001,  -- call ids continue across restarts (server KVP)
    notifyDuration  = 30000, -- ms the call card stays on screen
    priority        = 2,     -- tsrp-ui priority (1 = flashing / most urgent)
    announceAccepts = true,  -- tell other units when someone accepts
}

---------------------------------------------------------------------
-- Panic
---------------------------------------------------------------------
Config.Panic = {
    enabled        = true,
    cooldown       = 30,    -- seconds per officer (separate from 911 cooldowns)
    notifyDuration = 20000, -- ms
    areaBlipTime   = 120,   -- seconds the red area blip stays on the map
    blipFlashTime  = 60,    -- seconds the officer's own blip flashes
    waypointWindow = 60,    -- seconds the waypoint key targets the panic instead of calls
}

---------------------------------------------------------------------
-- Roster
---------------------------------------------------------------------
Config.Roster = {
    onDutyOnly = true, -- only on-duty units can open /police
}

---------------------------------------------------------------------
-- Rate limits for network events (ms between requests per player)
---------------------------------------------------------------------
Config.RateLimits = {
    duty       = 1500, -- clock in / out / department change
    state      = 500,  -- duty menu state
    status     = 750,  -- status / blip visibility changes
    roster     = 1000,
    call       = 3000, -- /911 submissions (the cooldown above still applies)
    callAction = 400,  -- accept / deny / waypoint / cancel / close
    calls      = 1000, -- /calls list refresh
    panic      = 1500,
}

---------------------------------------------------------------------
-- Duty hours storage
--   'kvp'    : server KVP store (recommended, survives restarts, no setup)
--   'json'   : JSON files in tsrp-police/data/ (easy to read / back up)
--   'memory' : nothing saved; totals reset on every restart
---------------------------------------------------------------------
Config.Persistence = {
    mode               = 'kvp',
    restoreOnRestart   = true, -- put players back on duty after a resource restart
    restoreWindow      = 300,  -- seconds; older interrupted sessions are closed instead
    checkpointInterval = 60,   -- seconds between active-session checkpoints (crash recovery)
    keepRecords        = 500,  -- most recent finished sessions kept
}

---------------------------------------------------------------------
-- Logging (webhook URLs live in config/webhooks.lua, server only)
---------------------------------------------------------------------
Config.Logging = {
    console            = true,
    includeIdentifiers = false, -- add the stored identifier to webhook embeds
    events = {
        clock_in = true, clock_out = true, department_change = true,
        permission_denied = true, callsign_conflict = true,
        call_submitted = true, call_accepted = true, call_cancelled = true,
        call_closed = true, call_expired = true, panic = true,
        session_restored = true, session_interrupted = true,
    },
}

---------------------------------------------------------------------
-- TSRP-UI integration
---------------------------------------------------------------------
Config.UI = {
    resource      = 'tsrp-ui',
    dispatchStyle = 'police', -- tsrp-ui department style for 911 cards (police | safr)
    panicStyle    = 'police',
}
