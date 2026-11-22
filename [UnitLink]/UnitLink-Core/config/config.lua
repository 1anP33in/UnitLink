-- UnitLink Core: general configuration (shared with clients, so keep secrets out of here).
-- Server-only settings live in config/database.lua, bootstrap.lua, permissions.lua,
-- groups.lua, spawn.lua and logging.lua.

Config = Config or {}

Config.ServerName = 'San Andreas RP'
Config.ServerShortName = 'UnitLink'
Config.Locale = 'en'
Config.Debug = false

-- Account identifier used to own characters. 'license' is the Rockstar license and is
-- the only identifier FiveM guarantees for every player.
Config.IdentifierType = 'license'

-- Chat commands. Set an entry to false to disable that command.
Config.Commands = {
    Admin = 'ulcore',                       -- /ulcore, /ulcore players, /ulcore character ... (see README)
    SwitchCharacter = 'switchcharacter',  -- requires unitlink.character.switch on the active character
    Appearance = 'appearance',            -- requires unitlink.appearance.edit on the active character
}

-- Character selection scene. Each player is moved into their own routing bucket while
-- selecting/creating, so other players never see the preview ped.
Config.Selection = {
    PedCoords = vector4(-1037.74, -2738.04, 20.17, 329.39),
    CameraOffset = vector3(0.0, 2.6, 0.55),  -- relative to the ped (forward, up)
    CameraFov = 38.0,
    PrivateBucketBase = 50000,               -- bucket = base + server id
}

-- Appearance (illenium-appearance) integration.
Config.Appearance = {
    Resource = 'illenium-appearance',
    Models = { male = 'mp_m_freemode_01', female = 'mp_f_freemode_01' },
    -- Where the appearance editor opens for brand-new characters.
    CreatorCoords = vector4(-1037.74, -2738.04, 20.17, 329.39),
    -- Sections offered when a new character is created.
    NewCharacterSections = {
        ped = false, headBlend = true, faceFeatures = true, headOverlays = true,
        components = true, props = true, tattoos = true,
    },
    -- Sections offered by /appearance and OpenAppearanceEditor() when none are passed.
    EditSections = {
        ped = false, headBlend = false, faceFeatures = false, headOverlays = true,
        components = true, props = true, tattoos = false,
    },
    DisabledComponents = {}, -- e.g. { bodyArmor = true, decals = true }
    DisabledProps = {},      -- e.g. { ear = true }
}

-- Very small death handler, because UnitLink Core turns spawnmanager auto-spawn off.
-- Replace it with your EMS/death resource later by setting Enabled = false.
Config.Death = {
    Enabled = true,
    RespawnDelaySeconds = 10,
}

-- Loading screen hand-off. UnitLink Core closes the loading screen once character
-- selection is ready. HCRP-Loading listens for this event and fades out nicely.
Config.LoadingScreen = {
    ShutdownEvent = 'hickory_loadscreen:shutdown',
    ForceShutdownAfterMs = 2500,
}

-- Notifications. When UnitLink-UI is running, UnitLink Core's in-game notifications
-- use UnitLink-UI cards (same look as UnitLink-Police and other UnitLink scripts).
-- If it isn't running, UnitLink Core falls back to its own toast.
Config.UI = {
    NotifyResource = 'UnitLink-UI',
    NotifyTitle = 'San Andreas RP',
}
