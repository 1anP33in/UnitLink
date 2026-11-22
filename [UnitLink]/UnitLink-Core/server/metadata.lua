-- UnitLink Core: flexible per-character metadata (JSON column on unitlink_characters).
--
-- Use it for data other resources own (licences, department info, references to
-- vehicles/houses...). Relational data that needs querying should get its own table
-- in the resource that owns it.

UnitLink = UnitLink or {}
local Metadata = {}
UnitLink.Metadata = Metadata

local Utils = UnitLink.Utils
local Errors = UnitLink.Errors

local function validKey(key)
    return Utils.IsValidMetadataKey(key, Config.Metadata.MaxKeyLength)
end

local function activePlayer(characterId)
    local src = UnitLink.Players.GetSourceByCharacterId(characterId)
    local player = src and UnitLink.Players.Get(src)
    if player and player.character and player.character.id == characterId then return player end
    return nil
end

-- Returns the whole metadata table for a character (copy), or nil.
function Metadata.GetAll(characterId)
    characterId = Utils.ToId(characterId)
    if not characterId then return nil end
    local player = activePlayer(characterId)
    if player then return Utils.DeepCopy(player.character.metadata) end
    local raw = UnitLink.DB.scalar('SELECT metadata FROM unitlink_characters WHERE id = ?', { characterId })
    if not raw then return nil end
    local decoded = Utils.JsonDecode(raw, {})
    return type(decoded) == 'table' and decoded or {}
end

function Metadata.Get(characterId, key)
    if not validKey(key) then return nil end
    local all = Metadata.GetAll(characterId)
    return all and Utils.DeepCopy(all[key]) or nil
end

-- Set (or clear with value = nil) a metadata key. Returns true or false, error.
function Metadata.Set(characterId, key, value, actor)
    characterId = Utils.ToId(characterId)
    if not characterId or not validKey(key) then return false, Errors.InvalidInput end
    if not Utils.IsJsonSafe(value) then return false, Errors.InvalidInput end

    local player = activePlayer(characterId)
    local all
    if player then
        all = Utils.DeepCopy(player.character.metadata)
    else
        all = Metadata.GetAll(characterId)
        if not all then return false, Errors.NotFound end
    end
    all[key] = Utils.DeepCopy(value)

    local encoded = Utils.JsonEncode(all)
    if not encoded or #encoded > Config.Metadata.MaxEncodedBytes then return false, Errors.InvalidInput end

    local affected = UnitLink.DB.update('UPDATE unitlink_characters SET metadata = ? WHERE id = ?', { encoded, characterId })
    if affected == nil then return false, Errors.Database end
    if affected == 0 then return false, Errors.NotFound end

    player = activePlayer(characterId)
    if player then player.character.metadata = all end

    -- Resources may write metadata often; only audit when an actor is named
    -- (admin dashboard edits always pass one).
    if actor ~= nil then
        UnitLink.Log.Audit(UnitLink.AuditActions.CharacterMetadata, actor, characterId, { key = key })
    end
    TriggerEvent(UnitLink.ServerEvents.MetadataUpdated, characterId, key, Utils.DeepCopy(value))
    return true
end
