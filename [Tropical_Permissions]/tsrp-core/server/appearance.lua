-- TSRP Core: per-character appearance storage (server side of the illenium adapter).
--
-- Appearance is always saved against the server's active character id for that
-- player, and only while the server has opened an appearance session (new character
-- creation, /appearance, or exports['tsrp-core']:OpenAppearanceEditor). The client
-- never sends a character id, so one character's appearance can never overwrite
-- another's.

TSRP = TSRP or {}
local Appearance = {}
TSRP.Appearance = Appearance

local Utils = TSRP.Utils
local Errors = TSRP.Errors

local MAX_BYTES = 65535

-- Keys produced by illenium-appearance getPedAppearance() (v5.x):
-- model, headBlend, faceFeatures, headOverlays, components, props, hair, tattoos, eyeColor
local ALLOWED_KEYS = {
    model = 'string', headBlend = 'table', faceFeatures = 'table', headOverlays = 'table',
    components = 'table', props = 'table', hair = 'table', tattoos = 'table', eyeColor = 'number',
}

-- Returns decoded appearance table, false when none is stored, nil on database error.
function Appearance.Fetch(characterId)
    local row = TSRP.DB.single('SELECT model, appearance FROM tsrp_character_appearance WHERE character_id = ?', { characterId })
    if row == nil then return nil end
    if not row then return false end
    local decoded = Utils.JsonDecode(row.appearance, nil)
    if type(decoded) ~= 'table' then return false end
    decoded.model = decoded.model or row.model
    return decoded
end

-- Cleans an appearance table from a client. Returns clean table or nil.
function Appearance.Sanitize(appearance)
    if type(appearance) ~= 'table' then return nil end
    local clean = {}
    for key, kind in pairs(ALLOWED_KEYS) do
        local value = appearance[key]
        if value ~= nil then
            if type(value) ~= kind then return nil end
            clean[key] = value
        end
    end
    if type(clean.model) ~= 'string' or #clean.model > 64 or not clean.model:find(TSRP.Patterns.Model) then
        return nil
    end
    if not Utils.IsJsonSafe(clean) then return nil end
    local encoded = Utils.JsonEncode(clean)
    if not encoded or #encoded > MAX_BYTES then return nil end
    return clean, encoded
end

function Appearance.Save(characterId, clean, encoded)
    local affected = TSRP.DB.update(
        'INSERT INTO tsrp_character_appearance (character_id, model, appearance) VALUES (?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE model = VALUES(model), appearance = VALUES(appearance)',
        { characterId, clean.model, encoded })
    return affected ~= nil
end

-- Opens an appearance session for an active character and tells the client to show
-- the editor. sections: illenium section flags (ped, headBlend, components, ...).
function Appearance.OpenEditor(src, sections)
    local player = TSRP.Players.Get(src)
    if not player or not player.characterId or player.state ~= TSRP.States.Active then
        return false, Errors.NoCharacter
    end
    local cfg = {}
    local base = type(sections) == 'table' and sections or Config.Appearance.EditSections
    for _, key in ipairs({ 'ped', 'headBlend', 'faceFeatures', 'headOverlays', 'components', 'props', 'tattoos' }) do
        cfg[key] = base[key] == true
    end
    player.appearanceEdit = { isNew = false, sections = cfg, characterId = player.characterId }
    TriggerClientEvent(TSRP.ClientEvents.OpenAppearance, src, cfg)
    return true
end

TSRP.Callbacks.Register('tsrp:saveAppearance', function(src, payload)
    local player = TSRP.Players.Get(src)
    local session = player.appearanceEdit
    if not player.characterId or not session then return false, Errors.InvalidState end
    if session.characterId and session.characterId ~= player.characterId then
        player.appearanceEdit = nil
        return false, Errors.InvalidState
    end

    local clean, encoded = Appearance.Sanitize(payload.appearance)
    if not clean then return false, Errors.InvalidInput end

    -- Without the "ped" section the model cannot change: it must stay the character's
    -- freemode model (new characters) or the model they already had.
    local sections = session.sections or Config.Appearance.NewCharacterSections
    if not sections.ped then
        local expected
        if session.isNew then
            expected = Config.Appearance.Models[player.character.gender] or Config.Appearance.Models.male
        else
            local current = Appearance.Fetch(player.characterId)
            if current == nil then return false, Errors.Database end
            expected = current and current.model or Config.Appearance.Models[player.character.gender]
        end
        if clean.model ~= expected then return false, Errors.InvalidInput end
    end

    local characterId = player.characterId
    if not Appearance.Save(characterId, clean, encoded) then return false, Errors.Database end
    if not TSRP.Players.IsCurrent(player) or player.characterId ~= characterId then
        return false, Errors.InvalidState
    end

    player.appearanceEdit = nil
    TSRP.Log.Audit(TSRP.AuditActions.AppearanceSave, src, characterId, { isNew = session.isNew == true, model = clean.model })

    if session.isNew and player.state == TSRP.States.Creating then
        player.state = TSRP.States.Spawning
        return true, { spawns = TSRP.Spawn.Options(player) }
    end
    return true, {}
end, { rate = 'saveAppearance', exclusive = true })

-- Editing an existing appearance can be cancelled; new characters cannot skip it.
TSRP.Callbacks.Register('tsrp:cancelAppearance', function(src)
    local player = TSRP.Players.Get(src)
    if player.appearanceEdit and not player.appearanceEdit.isNew then
        player.appearanceEdit = nil
        return true, {}
    end
    return false, Errors.InvalidState
end, { rate = 'saveAppearance' })
