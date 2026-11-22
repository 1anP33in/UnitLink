Config = {}

---------------------------------------------------------------------
-- General
---------------------------------------------------------------------
Config.Scale           = 1.0        -- size of every component
Config.Accent          = '#2dd4bf'  -- lagoon teal (matches UnitLink-Core)
Config.HideInPauseMenu = true
Config.Sounds          = true

-- /uitest <component> shows each component in game. Turn off on a live server if you like.
Config.TestCommand = true

-- Layer order between resources' screens. UnitLink-UI sits above the HUD (which uses 0)
-- so notifications and menus are never hidden behind it.
Config.ZIndex = 100

---------------------------------------------------------------------
-- Notifications
---------------------------------------------------------------------
Config.Notify = {
    position        = 'top-right', -- top-right | top-left | bottom-right | bottom-left | center-top
    offset          = { x = 24, y = 24 },
    maxVisible      = 5,
    defaultDuration = 5000,        -- ms. 0 or less = stays until removed

    -- sound = { soundName, soundSet } or false
    types = {
        success  = { title = 'Success',      color = '#22c38a', icon = 'check',    sound = { 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET' } },
        error    = { title = 'Error',        color = '#ef4b5a', icon = 'x',        sound = { 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET' } },
        warning  = { title = 'Warning',      color = '#f5a524', icon = 'warning',  sound = { 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET' } },
        info     = { title = 'Info',         color = '#3ba7ff', icon = 'info',     sound = { 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET' } },
        announce = { title = 'Announcement', color = '#ffffff', icon = 'announce', sound = { 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET' }, tag = 'Server Announcement', duration = 10000 },
        sms      = { title = 'New Message',  color = '#a77bf3', icon = 'sms',      sound = { 'Text_Arrive_Tone', 'Phone_SoundSet_Default' }, duration = 7000 },
    },

    -- Police / SAFR styles
    --   strip : 'lightbar' (two halves) | 'stripes' (hazard) | 'solid' (whole bar switches color)
    departments = {
        police = { label = 'POLICE', icon = 'badge', tint = 'rgba(9, 18, 42, 0.92)',  strip = 'lightbar', colors = { '#2f6bff', '#ef4b5a' } },
        safr   = { label = 'SAFR',   icon = 'fire',  tint = 'rgba(38, 13, 10, 0.92)', strip = 'stripes',  colors = { '#ef4b5a', '#ffb020' } },
    },

    flash = {
        enabled     = true,
        maxPriority = 2,   -- flash this priority and higher (1 = highest)
        speed       = 500, -- ms per flash cycle
        strip       = true,
        edge        = true,
        glow        = true,
    },

    -- 1 = highest. Keep them in order.
    priorities = {
        { label = 'Priority 1', short = 'P1', color = '#ef4b5a', pulse = true,  duration = 15000, sound = { '5_SEC_WARNING', 'HUD_MINI_GAME_SOUNDSET' } },
        { label = 'Priority 2', short = 'P2', color = '#f5a524', pulse = false, duration = 12000, sound = { 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET' } },
        { label = 'Priority 3', short = 'P3', color = '#3ba7ff', pulse = false, duration = 10000, sound = { 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET' } },
    },
    defaultPriority = 2,

    priorityIndicator = { pips = true, chip = true },
}

---------------------------------------------------------------------
-- Progress bar
---------------------------------------------------------------------
Config.Progress = {
    position      = 'bottom', -- bottom | center
    cancelControl = 73,       -- INPUT_VEH_DUCK (X)
    cancelKey     = 'X',      -- label shown on the bar
}

---------------------------------------------------------------------
-- Alert + input dialogs
---------------------------------------------------------------------
Config.Dialog = {
    backdrop = true, -- darken the screen behind dialogs
}

---------------------------------------------------------------------
-- Context menu
---------------------------------------------------------------------
Config.Context = {
    position = 'right', -- right | left
}

---------------------------------------------------------------------
-- List menu (keyboard only, player can still move)
---------------------------------------------------------------------
Config.List = {
    position = 'top-left', -- top-left | top-right | bottom-left | bottom-right
}

---------------------------------------------------------------------
-- Radial menu
---------------------------------------------------------------------
Config.Radial = {
    enabled = true,
    command = 'unitlink_radial',
    key     = 'Z', -- default key, players can rebind in FiveM key bindings
}

---------------------------------------------------------------------
-- Text UI
---------------------------------------------------------------------
Config.TextUI = {
    position = 'right-center', -- right-center | left-center | top-center | bottom-center
}

---------------------------------------------------------------------
-- Mini games
---------------------------------------------------------------------
Config.SkillCheck = {
    baseSpeed = 200,     -- degrees per second at speed 1.0
    keys      = { 'E' }, -- default keys (random per round)
    presets = {
        easy   = { zone = 50, speed = 1.0 },
        medium = { zone = 40, speed = 1.3 },
        hard   = { zone = 25, speed = 1.75 },
    },
}

Config.SignalBreach = {
    keys           = { 'W', 'A', 'S', 'D' },
    speedUp        = 1.15, -- speed multiplier after each node
    shrink         = 0.85, -- window size multiplier after each node
    failOnWrongKey = true,
    maxSweeps      = 4,    -- passes over the track before the node fails
    presets = {
        easy   = { nodes = 3, window = 26, speed = 55 }, -- window = % of track, speed = % per second
        medium = { nodes = 4, window = 20, speed = 70 },
        hard   = { nodes = 5, window = 14, speed = 90 },
    },
}

Config.PatternLock = {
    presets = {
        easy   = { grid = 3, length = 4, showSpeed = 550, timeout = 7000, rounds = 1 },
        medium = { grid = 3, length = 5, showSpeed = 420, timeout = 6000, rounds = 1 },
        hard   = { grid = 4, length = 6, showSpeed = 320, timeout = 5000, rounds = 1 },
    },
}
