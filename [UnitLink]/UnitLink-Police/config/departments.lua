---------------------------------------------------------------------
-- Departments (keys match the UnitLink Core department ids in
-- UnitLink-Core/config/groups.lua -> Config.Departments)
-- Add a department here + its permission node in config/permissions.lua.
--
--   order     : sort order in menus and the roster
--   short     : short label (roster, blips, notifications)
--   name      : full display name
--   type      : key into Config.DepartmentTypes below
--   blipColor : GTA blip color id (https://docs.fivem.net/docs/game-references/blips/#blip-colors)
--   callsign  : validation rules
--       pattern    Lua pattern the (uppercased) callsign must match, or nil
--       example    shown to the player when the format is wrong
--       minLength / maxLength
--       uppercase  convert to upper case before checking (default true)
--   Callsigns may only ever contain letters, numbers and '-'.
---------------------------------------------------------------------
Config.Departments = {
    sasp = {
        order = 1, short = 'SASP', name = 'San Andreas State Police', type = 'leo', blipColor = 38,
        callsign = { pattern = '^%d%u%-%d%d$', example = '1A-01', minLength = 5, maxLength = 5 },
    },
    bcso = {
        order = 2, short = 'BCSO', name = "Blaine County Sheriff's Office", type = 'leo', blipColor = 25,
        callsign = { pattern = '^%d%u%-%d%d$', example = '2B-04', minLength = 5, maxLength = 5 },
    },
    lsp = {
        order = 3, short = 'LSP', name = 'Los Santos Police', type = 'leo', blipColor = 3,
        callsign = { pattern = '^%d%u%-%d%d$', example = '3L-01', minLength = 5, maxLength = 5 },
    },
    dhs = {
        order = 4, short = 'DHS', name = 'Department of Homeland Security', type = 'leo', blipColor = 40,
        callsign = { pattern = '^%d%u%-%d%d$', example = '4H-01', minLength = 5, maxLength = 5 },
    },
    safr = {
        order = 5, short = 'SAFR', name = 'San Andreas Fire & Rescue', type = 'fire', blipColor = 1,
        callsign = { pattern = '^%u+%-%d+$', example = 'E-12', minLength = 3, maxLength = 8 },
    },
    faa = {
        order = 6, short = 'FAA', name = 'Federal Aviation Administration', type = 'aviation', blipColor = 2,
        callsign = { pattern = '^%u+%-%d+$', example = 'FAA-1', minLength = 3, maxLength = 8 },
    },
}

---------------------------------------------------------------------
-- What each department type takes part in.
--   roster       : listed in /police
--   showOnBlips  : appears on other units' maps
--   seeBlips     : sees other units on the map
--   receives911  : gets /911 calls
--   canPanic     : can use /panic
--   receivesPanic: gets panic alerts
--   fireCad      : opens the SAFR Fire & Rescue tablet (UnitLink-CAD) with /cad
---------------------------------------------------------------------
Config.DepartmentTypes = {
    leo      = { roster = true,  showOnBlips = true,  seeBlips = true,  receives911 = true,  canPanic = true,  receivesPanic = true },
    fire     = { roster = false, showOnBlips = false, seeBlips = false, receives911 = false, canPanic = false, receivesPanic = false, fireCad = true },
    aviation = { roster = false, showOnBlips = false, seeBlips = false, receives911 = false, canPanic = false, receivesPanic = false },
}
