-- TSRP Core: spawn locations (server only; clients only ever receive the id, label and
-- description of locations they are allowed to use, and can only send back an id).
--
-- restriction (optional): { permission = 'node' } and/or { group = 'name' }.
-- Both must pass when both are given.

Config = Config or {}

Config.Spawn = {
    DefaultLocation = 'legion',

    -- Brand-new characters can only use these (they have no last location yet).
    NewCharacterLocations = { 'legion', 'airport' },

    LastLocation = {
        Enabled = true,
        Label = 'Last Location',
        Description = 'Where you were when you last left the city.',
    },

    -- Positions outside this box are treated as invalid (e.g. corrupted saves).
    WorldBounds = { minX = -4500.0, maxX = 4500.0, minY = -4500.0, maxY = 8500.0, minZ = -200.0, maxZ = 2000.0 },

    Locations = {
        {
            id = 'legion',
            label = 'Legion Square',
            description = 'Downtown Los Santos, in the middle of everything.',
            coords = vector4(195.17, -933.77, 30.69, 144.5),
        },
        {
            id = 'airport',
            label = 'LSIA Arrivals',
            description = 'Just landed at Los Santos International.',
            coords = vector4(-1037.74, -2738.04, 20.17, 329.39),
        },
        {
            id = 'sandy',
            label = 'Sandy Shores',
            description = 'Blaine County, out in the desert.',
            coords = vector4(1961.64, 3740.48, 32.34, 300.0),
        },
        {
            id = 'paleto',
            label = 'Paleto Bay',
            description = 'Quiet town on the northern coast.',
            coords = vector4(-275.52, 6226.63, 31.49, 45.0),
        },
        {
            id = 'mrpd',
            label = 'Mission Row PD',
            description = 'Report for duty at Mission Row.',
            coords = vector4(428.23, -984.28, 29.71, 3.5),
            restriction = { permission = 'tsrp.police.duty' },
        },
        {
            id = 'pillbox',
            label = 'Pillbox Medical',
            description = 'Report for duty at Pillbox Hill Medical Center.',
            coords = vector4(298.0, -584.0, 43.26, 70.0),
            restriction = { permission = 'tsrp.safr.duty' },
        },
    },
}
