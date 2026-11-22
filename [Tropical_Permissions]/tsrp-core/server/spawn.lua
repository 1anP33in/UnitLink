-- TSRP Core: spawn selection.
--
-- Clients receive only { id, label, description } for locations they may use and can
-- only answer with an id. Coordinates always come from config/spawn.lua or the
-- character's server-saved last position, never from the client.

TSRP = TSRP or {}
local Spawn = {}
TSRP.Spawn = Spawn

local Errors = TSRP.Errors

local function findLocation(id)
    for _, loc in ipairs(Config.Spawn.Locations) do
        if loc.id == id then return loc end
    end
    return nil
end

local function allowedFor(player, loc)
    local r = loc.restriction
    if not r then return true end
    if r.permission and not TSRP.Permissions.Has(player.source, r.permission) then return false end
    if r.group and not TSRP.Permissions.HasGroup(player.source, r.group) then return false end
    return true
end

local function isNewCharacter(player)
    return not TSRP.Persistence.IsValidPosition(player.character and player.character.lastPosition)
end

function Spawn.Options(player)
    local options = {}
    local newChar = isNewCharacter(player)

    if Config.Spawn.LastLocation.Enabled and not newChar then
        options[#options + 1] = {
            id = 'last',
            label = Config.Spawn.LastLocation.Label,
            description = Config.Spawn.LastLocation.Description,
            last = true,
        }
    end

    for _, loc in ipairs(Config.Spawn.Locations) do
        local usable = allowedFor(player, loc)
        if usable and newChar and Config.Spawn.NewCharacterLocations then
            usable = TSRP.Utils.Contains(Config.Spawn.NewCharacterLocations, loc.id)
        end
        if usable then
            options[#options + 1] = {
                id = loc.id,
                label = loc.label,
                description = loc.description,
                default = loc.id == Config.Spawn.DefaultLocation,
            }
        end
    end
    return options
end

-- Returns coords table { x, y, z, w } or nil, error.
function Spawn.Resolve(player, id)
    if type(id) ~= 'string' or #id > 64 then return nil, Errors.InvalidInput end
    for _, option in ipairs(Spawn.Options(player)) do
        if option.id == id then
            if id == 'last' then
                local p = player.character.lastPosition
                return { x = p.x, y = p.y, z = p.z, w = p.w or 0.0 }
            end
            local loc = findLocation(id)
            local c = loc.coords
            return { x = c.x, y = c.y, z = c.z, w = c.w }
        end
    end
    return nil, Errors.SpawnUnavailable
end

TSRP.Callbacks.Register('tsrp:spawn', function(src, payload)
    local player = TSRP.Players.Get(src)
    if not player.characterId or player.state ~= TSRP.States.Spawning then
        return false, Errors.InvalidState
    end
    local coords, err = Spawn.Resolve(player, payload.id)
    if not coords then return false, err end

    player.state = TSRP.States.Active
    player.spawned = true
    player.lastCoords = coords
    TSRP.Characters.SetBucket(player, false)

    TriggerEvent(TSRP.ServerEvents.CharacterSpawned, src, player.characterId, payload.id)
    TriggerClientEvent(TSRP.ClientEvents.CharacterSpawned, src, payload.id)
    return true, { coords = coords }
end, { rate = 'spawn', exclusive = true })

-- Spawn options again (e.g. after the client reloads the NUI).
TSRP.Callbacks.Register('tsrp:getSpawns', function(src)
    local player = TSRP.Players.Get(src)
    if not player.characterId or player.state ~= TSRP.States.Spawning then
        return false, Errors.InvalidState
    end
    return true, { spawns = Spawn.Options(player) }
end, { rate = 'spawn' })
