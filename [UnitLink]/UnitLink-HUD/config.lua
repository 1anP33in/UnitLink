Config = {}

-- Logo in the top right. 'accent' is drawn in coral after 'name'.
Config.Logo = { name = 'UNIT', accent = 'LINK', subtitle = 'ROLEPLAY' }

-- 'mph' or 'kmh'
Config.SpeedUnit = 'mph'

-- Turn parts of the HUD on or off. There is no money display: this HUD is
-- built for servers with no money.
Config.Show = {
    logo = true,
    job = true,
    playerId = true,
    health = true,
    armor = true,
    stamina = true,
    hunger = true,   -- only shows when Config.Needs.Enabled = true
    thirst = true,   -- only shows when Config.Needs.Enabled = true
    compass = true,
    street = true,
    weapon = true,
    voice = true,
    clock = true,
    vehicle = true,
    minimapOnFoot = false, -- false = the GTA minimap only shows in a vehicle
}

-- How often the HUD refreshes, in milliseconds.
Config.Rates = { foot = 200, vehicle = 80, street = 500 }

-- /hud opens the HUD settings (size, minimap, compass). Saved per player.
Config.Settings = { command = 'hud', minScale = 50, maxScale = 150, step = 5 }

-- Hide the HUD (cinematic mode). Players can rebind the key in Settings > Key Bindings > FiveM.
-- H is not the default because GTA uses it for headlights.
Config.Toggle = { command = 'togglehud', key = 'F7', letterbox = true }

-- UnitLink-UI notifications for things that happen in game.
Config.Notify = {
    seatbelt = true,   -- buckled / unbuckled
    eject = true,      -- thrown through the windshield
    hudToggle = true,  -- HUD hidden / shown
    needs = true,      -- hungry / thirsty warnings (only if Config.Needs.Enabled)
    hazards = true,    -- hazard lights on / off
    duty = true,       -- job line changed after going on or off duty
}

-- Standalone servers: the HUD shows as soon as the player spawns.
-- If UnitLink-Core is running, it waits until a character has spawned
-- (hidden on character select).
Config.RequireSpawn = true

-- GTA HUD parts to hide every frame, because this HUD replaces them:
-- 2 weapon icon, 3 cash, 4 MP cash, 6 vehicle name, 7 area name, 8 vehicle class, 9 street name, 13 cash change
Config.HideNative = { 2, 3, 4, 6, 7, 8, 9, 13 }

-----------------------------------------------------------------------
-- Job line. Changes when the player goes on or off duty with
-- UnitLink-Police:
--   off duty : CIV · Civilian · <their /civ profile name>
--   on duty  : <DEPT> · <title> · <callsign>      e.g.  SASP · Trooper · 1A-01
-- Supervisors (ACE unitlink.<dept>.supervisor) show `supervisorTitle`.
-- Departments not listed use their UnitLink-Police short name and the default color.
-----------------------------------------------------------------------
Config.Jobs = {
    sasp = { color = '#3c8fd6', title = 'Trooper',     supervisorTitle = 'Sergeant' },
    bcso = { color = '#c9a14a', title = 'Deputy',      supervisorTitle = 'Sergeant' },
    lsp  = { color = '#5ab8ff', title = 'Officer',     supervisorTitle = 'Sergeant' },
    dhs  = { color = '#9aa7b4', title = 'Agent',       supervisorTitle = 'Supervisor' },
    safr = { color = '#ff6b5e', title = 'Firefighter', supervisorTitle = 'Captain' },
    dot  = { color = '#f59e0b', title = 'Technician',  supervisorTitle = 'Supervisor' },
    faa  = { color = '#b88cff', title = 'Inspector',   supervisorTitle = 'Supervisor' },
}
Config.JobDefaultColor = '#7fb2ff'
Config.DefaultJob = { chip = 'CIV', grade = 'Civilian', color = '#b7c9c6' }
-- Off duty, show the active /civ profile name after "Civilian".
Config.ShowCivilianName = true

-----------------------------------------------------------------------
-- Hunger and thirst. OFF by default (no food economy on a no-money server).
-- When on, values are saved per account on the server (no framework needed).
-- Food and drink scripts call (server side):
--   exports['UnitLink-HUD']:AddHunger(source, 25)
--   exports['UnitLink-HUD']:AddThirst(source, 30)
-----------------------------------------------------------------------
Config.Needs = {
    Enabled = false,
    HungerPerMinute = 0.35,   -- about 4.75 hours from full to empty
    ThirstPerMinute = 0.5,    -- about 3.3 hours from full to empty
    StartValue = 100,
    SaveEveryMinutes = 5,
    DamageAtZero = 2,         -- health lost every 10 seconds while hunger or thirst is 0 (0 = off)
}

-----------------------------------------------------------------------
-- Seatbelt
-----------------------------------------------------------------------
Config.Seatbelt = {
    Enabled = true,
    key = 'B',
    EjectEnabled = true,
    EjectMinSpeed = 45,   -- in Config.SpeedUnit; crashes slower than this never throw you out
    EjectDrop = 0.45,     -- fraction of speed lost in one check that counts as a crash
    EjectDamage = 25,
    LockExitWhileBuckled = true,
}

-----------------------------------------------------------------------
-- Turn signals (driver only). Synced to other players.
-----------------------------------------------------------------------
Config.Indicators = { Enabled = true, left = 'LEFT', right = 'RIGHT', hazards = 'UP' }

-----------------------------------------------------------------------
-- Weapon names shown above the ammo count. Anything missing shows as "Weapon".
-----------------------------------------------------------------------
Config.WeaponNames = {
    WEAPON_PISTOL = 'Pistol', WEAPON_PISTOL_MK2 = 'Pistol Mk II', WEAPON_COMBATPISTOL = 'Combat Pistol',
    WEAPON_APPISTOL = 'AP Pistol', WEAPON_PISTOL50 = 'Pistol .50', WEAPON_HEAVYPISTOL = 'Heavy Pistol',
    WEAPON_SNSPISTOL = 'SNS Pistol', WEAPON_VINTAGEPISTOL = 'Vintage Pistol', WEAPON_REVOLVER = 'Revolver',
    WEAPON_STUNGUN = 'Taser', WEAPON_FLAREGUN = 'Flare Gun',
    WEAPON_MICROSMG = 'Micro SMG', WEAPON_SMG = 'SMG', WEAPON_SMG_MK2 = 'SMG Mk II', WEAPON_COMBATPDW = 'Combat PDW',
    WEAPON_ASSAULTRIFLE = 'Assault Rifle', WEAPON_CARBINERIFLE = 'Carbine Rifle', WEAPON_CARBINERIFLE_MK2 = 'Carbine Rifle Mk II',
    WEAPON_SPECIALCARBINE = 'Special Carbine', WEAPON_BULLPUPRIFLE = 'Bullpup Rifle',
    WEAPON_PUMPSHOTGUN = 'Pump Shotgun', WEAPON_PUMPSHOTGUN_MK2 = 'Pump Shotgun Mk II', WEAPON_SAWNOFFSHOTGUN = 'Sawed-Off Shotgun',
    WEAPON_BEANBAG = 'Beanbag Shotgun',
    WEAPON_SNIPERRIFLE = 'Sniper Rifle', WEAPON_MARKSMANRIFLE = 'Marksman Rifle',
    WEAPON_KNIFE = 'Knife', WEAPON_NIGHTSTICK = 'Nightstick', WEAPON_FLASHLIGHT = 'Flashlight', WEAPON_BAT = 'Bat',
    WEAPON_CROWBAR = 'Crowbar', WEAPON_HAMMER = 'Hammer', WEAPON_HATCHET = 'Hatchet', WEAPON_SWITCHBLADE = 'Switchblade',
    WEAPON_FIREEXTINGUISHER = 'Fire Extinguisher', WEAPON_PETROLCAN = 'Jerry Can',
    WEAPON_FLARE = 'Flare', WEAPON_SMOKEGRENADE = 'Smoke Grenade', WEAPON_BZGAS = 'Tear Gas',
}
