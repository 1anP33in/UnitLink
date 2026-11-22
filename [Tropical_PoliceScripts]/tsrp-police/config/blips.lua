---------------------------------------------------------------------
-- Live officer blips
-- Colors come from each department's blipColor in config/departments.lua.
---------------------------------------------------------------------
Config.Blips = {
    enabled        = true,
    updateInterval = 2500, -- ms between position updates sent to on-duty units

    -- GTA blip sprite ids (https://docs.fivem.net/docs/game-references/blips/)
    sprites = {
        foot  = 1,
        car   = 56,
        bike  = 226,
        heli  = 43,
        plane = 307,
        boat  = 427,
    },

    scale        = 0.85,
    display      = 2,     -- 2 = map and minimap
    shortRange   = false, -- true = only on the minimap when nearby
    showHeading  = true,  -- heading cone on the blip
    labelFormat  = '%s | %s', -- callsign, department short name

    allowHide    = true,  -- officers can hide their own blip from the duty menu
    minDistance  = 3.0,   -- meters moved before a new position is sent
}
