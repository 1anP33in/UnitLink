-- TSRP Core: saving active characters (last position) and autosave.
--
-- Character fields, groups, overrides, metadata and appearance are written to MySQL
-- the moment they change. The only "live" state is the last position, which is read
-- server-side from the ped (OneSync) - never from client input - and saved on
-- unload, on disconnect, on resource stop and every Config.Database.AutosaveInterval.

TSRP = TSRP or {}
local Persistence = {}
TSRP.Persistence = Persistence

local Utils = TSRP.Utils

local function inBounds(x, y, z)
    local b = Config.Spawn.WorldBounds
    return x >= b.minX and x <= b.maxX and y >= b.minY and y <= b.maxY and z >= b.minZ and z <= b.maxZ
end

-- Server-side read of the player's position, or nil.
function Persistence.ReadPosition(src)
    local ped = GetPlayerPed(tostring(src))
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    if not coords then return nil end
    local x, y, z = coords.x + 0.0, coords.y + 0.0, coords.z + 0.0
    if x == 0.0 and y == 0.0 then return nil end
    if not inBounds(x, y, z) then return nil end
    return {
        x = math.floor(x * 100 + 0.5) / 100,
        y = math.floor(y * 100 + 0.5) / 100,
        z = math.floor(z * 100 + 0.5) / 100,
        w = math.floor((GetEntityHeading(ped) or 0.0) * 10 + 0.5) / 10,
    }
end

function Persistence.IsValidPosition(pos)
    return type(pos) == 'table' and type(pos.x) == 'number' and type(pos.y) == 'number'
        and type(pos.z) == 'number' and inBounds(pos.x, pos.y, pos.z)
end

-- Save one active character. async = true uses fire-and-forget queries (resource stop).
function Persistence.SaveCharacter(player, async)
    if not player or not player.characterId or not player.character then return true end
    if not player.spawned then return true end

    local pos = Persistence.ReadPosition(player.source) or player.lastCoords
    if not Persistence.IsValidPosition(pos) then return true end

    local encoded = Utils.JsonEncode(pos)
    player.character.lastPosition = pos
    if async then
        TSRP.DB.updateAsync('UPDATE tsrp_characters SET last_position = ? WHERE id = ?', { encoded, player.characterId })
        return true
    end
    return TSRP.DB.update('UPDATE tsrp_characters SET last_position = ? WHERE id = ?', { encoded, player.characterId }) ~= nil
end

function Persistence.SaveAll(async)
    local saved = 0
    for _, player in pairs(TSRP.Players.All()) do
        if player.characterId and player.spawned then
            Persistence.SaveCharacter(player, async)
            saved = saved + 1
        end
    end
    return saved
end

function Persistence.Start()
    -- Cache positions so a disconnect (when the ped may already be gone) still saves
    -- a recent location.
    CreateThread(function()
        while true do
            Wait(10000)
            for src, player in pairs(TSRP.Players.All()) do
                if player.characterId and player.spawned then
                    local pos = Persistence.ReadPosition(src)
                    if pos then player.lastCoords = pos end
                end
            end
        end
    end)

    CreateThread(function()
        local interval = math.max(60, tonumber(Config.Database.AutosaveInterval) or 300) * 1000
        while true do
            Wait(interval)
            local count = Persistence.SaveAll(false)
            if count > 0 then TSRP.Log.Debug('Autosaved %d character(s).', count) end
        end
    end)
end
