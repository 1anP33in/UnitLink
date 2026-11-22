-- UnitLink Core: character creation, selection, loading, unloading, switching, deletion.
--
-- Ownership rule: every query that reads or changes a character on behalf of a player
-- includes "AND identifier = ?" with the server-side account identifier, so one account
-- can never load, delete or change another account's character, whatever id the client
-- sends.

UnitLink = UnitLink or {}
local Characters = {}
UnitLink.Characters = Characters

local Utils = UnitLink.Utils
local States = UnitLink.States
local Errors = UnitLink.Errors

local SELECT_COLUMNS = [[
    c.id, c.identifier, c.slot, c.firstname, c.lastname,
    DATE_FORMAT(c.dateofbirth, '%Y-%m-%d') AS dateofbirth,
    c.gender, c.nationality, c.height, c.metadata, c.last_position,
    UNIX_TIMESTAMP(c.created_at) AS created_at, UNIX_TIMESTAMP(c.updated_at) AS updated_at
]]

---------------------------------------------------------------------------
-- Shapes
---------------------------------------------------------------------------

function Characters.FromRow(row)
    if not row then return nil end
    local metadata = Utils.JsonDecode(row.metadata, {})
    if type(metadata) ~= 'table' then metadata = {} end
    local position = Utils.JsonDecode(row.last_position, nil)
    return {
        id = tonumber(row.id),
        identifier = row.identifier,
        slot = tonumber(row.slot),
        firstname = row.firstname,
        lastname = row.lastname,
        dateofbirth = row.dateofbirth,
        gender = row.gender,
        nationality = row.nationality,
        height = tonumber(row.height),
        metadata = metadata,
        lastPosition = type(position) == 'table' and position or nil,
        createdAt = tonumber(row.created_at),
        updatedAt = tonumber(row.updated_at),
    }
end

-- Safe for clients: no account identifier, no metadata, no position.
function Characters.Public(char)
    if not char then return nil end
    return {
        id = char.id,
        slot = char.slot,
        firstname = char.firstname,
        lastname = char.lastname,
        fullname = char.firstname .. ' ' .. char.lastname,
        dateofbirth = char.dateofbirth,
        gender = char.gender,
        nationality = char.nationality,
        height = char.height,
        createdAt = char.createdAt,
    }
end

-- For other server resources (includes metadata, never the identifier).
function Characters.ServerView(char)
    if not char then return nil end
    local view = Characters.Public(char)
    view.metadata = Utils.DeepCopy(char.metadata)
    return view
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------

-- Returns character, false (not found / not owned) or nil (database error).
function Characters.FetchOwned(characterId, identifier)
    local row = UnitLink.DB.single('SELECT ' .. SELECT_COLUMNS .. ' FROM unitlink_characters c WHERE c.id = ? AND c.identifier = ?',
        { characterId, identifier })
    if row == nil then return nil end
    if not row then return false end
    return Characters.FromRow(row)
end

function Characters.FetchById(characterId)
    local row = UnitLink.DB.single('SELECT ' .. SELECT_COLUMNS .. ' FROM unitlink_characters c WHERE c.id = ?', { characterId })
    if row == nil then return nil end
    if not row then return false end
    return Characters.FromRow(row)
end

function Characters.FetchForAccount(identifier)
    local rows = UnitLink.DB.query('SELECT ' .. SELECT_COLUMNS ..
        ', (a.character_id IS NOT NULL) AS has_appearance FROM unitlink_characters c ' ..
        'LEFT JOIN unitlink_character_appearance a ON a.character_id = c.id WHERE c.identifier = ? ORDER BY c.slot ASC',
        { identifier })
    if not rows then return nil end
    local list = {}
    for _, row in ipairs(rows) do
        local char = Characters.FromRow(row)
        char.hasAppearance = row.has_appearance == 1 or row.has_appearance == true
        list[#list + 1] = char
    end
    return list
end

-- Highest-priority group label per character, for the selection cards.
local function primaryGroups(identifier)
    local rows = UnitLink.DB.query(
        'SELECT g.character_id, g.group_name FROM unitlink_character_groups g ' ..
        'INNER JOIN unitlink_characters c ON c.id = g.character_id WHERE c.identifier = ?', { identifier })
    local best = {}
    for _, row in ipairs(rows or {}) do
        local def = UnitLink.Groups.Get(row.group_name)
        local id = tonumber(row.character_id)
        if def and (not best[id] or def.priority > best[id].priority) then
            best[id] = def
        end
    end
    return best
end

-- Everything the selection screen needs.
function Characters.SelectionData(player)
    local list = Characters.FetchForAccount(player.identifier)
    if not list then return nil end
    local groups = primaryGroups(player.identifier)
    local cards = {}
    for _, char in ipairs(list) do
        local card = Characters.Public(char)
        card.hasAppearance = char.hasAppearance
        card.group = groups[char.id] and groups[char.id].label or nil
        cards[#cards + 1] = card
    end
    local rules = Config.Characters
    return {
        serverName = Config.ServerName,
        characters = cards,
        maxSlots = UnitLink.Identity.MaxSlots(),
        rules = {
            nameMin = rules.Names.MinLength,
            nameMax = rules.Names.MaxLength,
            ageMin = rules.Age.Min,
            ageMax = rules.Age.Max,
            heightMin = rules.Height.Min,
            heightMax = rules.Height.Max,
            genders = rules.Genders,
            nationalities = rules.Nationalities,
            confirmDelete = rules.DeleteRequiresNameConfirmation,
            today = os.date('%Y-%m-%d'),
        },
    }
end

---------------------------------------------------------------------------
-- Session helpers
---------------------------------------------------------------------------

local function setBucket(player, private)
    local bucket = private and (Config.Selection.PrivateBucketBase + player.source) or 0
    SetPlayerRoutingBucket(tostring(player.source), bucket)
    if private then
        SetRoutingBucketPopulationEnabled(bucket, false)
    end
end
Characters.SetBucket = setBucket

local function setStateBag(player)
    local bag = Player(player.source).state
    bag:set('unitlink-core:characterId', player.characterId, true)
    bag:set('unitlink-core:loaded', player.characterId ~= nil, true)
end

function Characters.EnterSelection(player)
    player.state = States.Selecting
    player.spawned = false
    setBucket(player, true)
    UnitLink.Integrations.Discord.Queue(player) -- fresh Discord roles before each pick
    return Characters.SelectionData(player)
end

-- Unload the active character (save first unless skipSave).
function Characters.Unload(player, reason, skipSave)
    if not player or not player.characterId then return end
    local characterId = player.characterId
    if not skipSave then
        UnitLink.Persistence.SaveCharacter(player)
    end
    UnitLink.Players.SetCharacter(player, nil)
    player.character = nil
    player.groups = {}
    player.overrides = {}
    player.effective = nil
    player.spawned = false
    player.appearanceEdit = nil
    player.lastCoords = nil
    if UnitLink.Players.IsConnected(player.source) then
        setStateBag(player)
        TriggerClientEvent(UnitLink.ClientEvents.CharacterUnloaded, player.source, characterId)
    end
    TriggerEvent(UnitLink.ServerEvents.CharacterUnloaded, player.source, characterId, reason or 'unload')
end

---------------------------------------------------------------------------
-- Create
---------------------------------------------------------------------------

function Characters.Create(player, payload)
    if player.state ~= States.Selecting or player.characterId then
        return false, Errors.InvalidState
    end

    local clean, field, err = UnitLink.Identity.Validate(payload)
    if not clean then
        return false, (err or Errors.InvalidInput) .. ':' .. tostring(field)
    end

    local used = UnitLink.DB.query('SELECT slot FROM unitlink_characters WHERE identifier = ?', { player.identifier })
    if not used then return false, Errors.Database end

    local maxSlots = UnitLink.Identity.MaxSlots()
    if #used >= maxSlots then return false, Errors.NoSlots end

    local taken = {}
    for _, row in ipairs(used) do taken[tonumber(row.slot)] = true end

    local slot
    local wanted = Utils.ToInteger(payload.slot)
    if wanted and wanted >= 1 and wanted <= maxSlots then
        if taken[wanted] then return false, Errors.SlotTaken end
        slot = wanted
    else
        for i = 1, maxSlots do
            if not taken[i] then slot = i break end
        end
    end
    if not slot then return false, Errors.NoSlots end

    if Config.Characters.Names.UniqueFullName then
        local count = UnitLink.DB.scalar('SELECT COUNT(*) FROM unitlink_characters WHERE firstname = ? AND lastname = ?',
            { clean.firstname, clean.lastname })
        if count == nil then return false, Errors.Database end
        if (tonumber(count) or 0) > 0 then return false, Errors.NameTaken end
    end

    local queries = {
        {
            query = 'INSERT INTO unitlink_characters (identifier, slot, firstname, lastname, dateofbirth, gender, nationality, height, metadata) ' ..
                'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            values = { player.identifier, slot, clean.firstname, clean.lastname, clean.dateofbirth,
                clean.gender, clean.nationality, clean.height, '{}' },
        },
    }
    -- Default groups reference the new id through LAST_INSERT_ID() inside the same
    -- transaction (unitlink_character_groups has no AUTO_INCREMENT column, so the value
    -- stays the character id for every row).
    for _, group in ipairs(Config.DefaultCharacterGroups or {}) do
        if UnitLink.Groups.Exists(group) then
            queries[#queries + 1] = {
                query = 'INSERT INTO unitlink_character_groups (character_id, group_name, assigned_by) VALUES (LAST_INSERT_ID(), ?, ?)',
                values = { group, 'system' },
            }
        else
            UnitLink.Log.Warn('Default group %s does not exist; not assigned.', group)
        end
    end

    if not UnitLink.DB.transaction(queries) then
        return false, Errors.Database
    end

    local char = UnitLink.DB.single('SELECT ' .. SELECT_COLUMNS .. ' FROM unitlink_characters c WHERE c.identifier = ? AND c.slot = ?',
        { player.identifier, slot })
    if not char then return false, Errors.Database end
    char = Characters.FromRow(char)

    UnitLink.Log.Audit(UnitLink.AuditActions.CharacterCreate, player.source, char.id, {
        name = char.firstname .. ' ' .. char.lastname, slot = slot,
    })
    TriggerEvent(UnitLink.ServerEvents.CharacterCreated, player.source, char.id, Characters.ServerView(char))
    return true, { character = Characters.Public(char) }
end

---------------------------------------------------------------------------
-- Delete
---------------------------------------------------------------------------

function Characters.Delete(player, payload)
    if player.state ~= States.Selecting or player.characterId then
        return false, Errors.InvalidState
    end
    local characterId = Utils.ToId(payload.id)
    if not characterId then return false, Errors.InvalidInput end

    local char = Characters.FetchOwned(characterId, player.identifier)
    if char == nil then return false, Errors.Database end
    if not char then
        UnitLink.Log.Warn('Player %s tried to delete character %s they do not own.', player.source, characterId)
        return false, Errors.NotFound
    end
    if UnitLink.Players.GetSourceByCharacterId(characterId) then
        return false, Errors.AlreadyActive
    end

    if Config.Characters.DeleteRequiresNameConfirmation then
        local typed = Utils.Trim(payload.confirm)
        local expected = (char.firstname .. ' ' .. char.lastname):lower()
        if not typed or Utils.CollapseSpaces(typed):lower() ~= expected then
            return false, Errors.ConfirmMismatch
        end
    end

    local affected = UnitLink.DB.update('DELETE FROM unitlink_characters WHERE id = ? AND identifier = ?', { characterId, player.identifier })
    if affected == nil then return false, Errors.Database end
    if affected == 0 then return false, Errors.NotFound end

    UnitLink.Log.Audit(UnitLink.AuditActions.CharacterDelete, player.source, characterId, {
        name = char.firstname .. ' ' .. char.lastname, slot = char.slot,
    })
    TriggerEvent(UnitLink.ServerEvents.CharacterDeleted, player.source, characterId)

    if not UnitLink.Players.IsCurrent(player) then return false, Errors.InvalidState end
    return true, Characters.SelectionData(player)
end

---------------------------------------------------------------------------
-- Select / load
---------------------------------------------------------------------------

function Characters.Load(player, characterId)
    if player.state ~= States.Selecting or player.characterId then
        return false, Errors.InvalidState
    end
    characterId = Utils.ToId(characterId)
    if not characterId then return false, Errors.InvalidInput end

    local char = Characters.FetchOwned(characterId, player.identifier)
    if char == nil then return false, Errors.Database end
    if not char then
        UnitLink.Log.Warn('Player %s tried to load character %s they do not own.', player.source, characterId)
        return false, Errors.NotFound
    end
    if UnitLink.Players.GetSourceByCharacterId(characterId) then
        return false, Errors.AlreadyActive
    end

    local direct, overrides = UnitLink.Permissions.LoadCharacterData(characterId)
    if not direct then return false, Errors.Database end
    local appearance = UnitLink.Appearance.Fetch(characterId)
    if appearance == nil then return false, Errors.Database end

    -- The player may have disconnected (or another request changed state) while we
    -- were waiting on the database.
    if not UnitLink.Players.IsCurrent(player) or player.state ~= States.Selecting or player.characterId then
        return false, Errors.InvalidState
    end
    if UnitLink.Players.GetSourceByCharacterId(characterId) then
        return false, Errors.AlreadyActive
    end

    player.character = char
    UnitLink.Players.SetCharacter(player, characterId)
    player.groups = direct
    player.overrides = overrides
    player.spawned = false
    player.lastCoords = nil

    local needsAppearance = appearance == false
    if needsAppearance then
        player.state = States.Creating
        player.appearanceEdit = { isNew = true }
    else
        player.state = States.Spawning
        player.appearanceEdit = nil
    end

    setStateBag(player)
    UnitLink.Permissions.Rebuild(player)

    local public = Characters.Public(char)
    TriggerClientEvent(UnitLink.ClientEvents.CharacterLoaded, player.source, public)
    TriggerEvent(UnitLink.ServerEvents.CharacterLoaded, player.source, characterId, Characters.ServerView(char))

    if player.lastCharacterId then
        local previous = player.lastCharacterId
        player.lastCharacterId = nil
        UnitLink.Log.Audit(UnitLink.AuditActions.CharacterSwitch, player.source, characterId, { from = previous, to = characterId })
        TriggerEvent(UnitLink.ServerEvents.CharacterSwitched, player.source, previous, characterId)
    else
        UnitLink.Log.Audit(UnitLink.AuditActions.CharacterLoad, player.source, characterId, nil)
    end

    return true, {
        character = public,
        appearance = appearance or nil,
        needsAppearance = needsAppearance,
        defaultModel = Config.Appearance.Models[char.gender] or Config.Appearance.Models.male,
        sections = needsAppearance and Config.Appearance.NewCharacterSections or nil,
        spawns = (not needsAppearance) and UnitLink.Spawn.Options(player) or nil,
    }
end

---------------------------------------------------------------------------
-- Switch
---------------------------------------------------------------------------

function Characters.Switch(player)
    if not player.characterId then return false, Errors.NoCharacter end
    if player.state ~= States.Active and player.state ~= States.Spawning then
        return false, Errors.InvalidState
    end
    if Config.Characters.SwitchRequiresPermission
        and not UnitLink.Permissions.Has(player.source, 'unitlink.character.switch') then
        return false, Errors.Unauthorized
    end
    player.lastCharacterId = player.characterId
    Characters.Unload(player, 'switch')
    local data = Characters.EnterSelection(player)
    if not data then return false, Errors.Database end
    return true, data
end

---------------------------------------------------------------------------
-- Admin edits
---------------------------------------------------------------------------

local EDITABLE = { 'firstname', 'lastname', 'dateofbirth', 'gender', 'nationality', 'height' }

function Characters.Update(characterId, fields, actor)
    characterId = Utils.ToId(characterId)
    if not characterId or type(fields) ~= 'table' then return false, Errors.InvalidInput end

    local filtered = {}
    for _, key in ipairs(EDITABLE) do
        if fields[key] ~= nil then filtered[key] = fields[key] end
    end
    if next(filtered) == nil then return false, Errors.InvalidInput end

    local clean, field, err = UnitLink.Identity.Validate(filtered, true)
    if not clean then return false, (err or Errors.InvalidInput) .. ':' .. tostring(field) end

    local before = Characters.FetchById(characterId)
    if before == nil then return false, Errors.Database end
    if not before then return false, Errors.NotFound end

    local sets, values, changes = {}, {}, {}
    for _, key in ipairs(EDITABLE) do -- column names come from this fixed list only
        if clean[key] ~= nil and clean[key] ~= before[key] then
            sets[#sets + 1] = key .. ' = ?'
            values[#values + 1] = clean[key]
            changes[key] = { from = before[key], to = clean[key] }
        end
    end
    if #sets == 0 then return true, Characters.Public(before) end

    if (clean.firstname or clean.lastname) and Config.Characters.Names.UniqueFullName then
        local count = UnitLink.DB.scalar('SELECT COUNT(*) FROM unitlink_characters WHERE firstname = ? AND lastname = ? AND id <> ?',
            { clean.firstname or before.firstname, clean.lastname or before.lastname, characterId })
        if count == nil then return false, Errors.Database end
        if (tonumber(count) or 0) > 0 then return false, Errors.NameTaken end
    end

    values[#values + 1] = characterId
    local affected = UnitLink.DB.update('UPDATE unitlink_characters SET ' .. table.concat(sets, ', ') .. ' WHERE id = ?', values)
    if affected == nil then return false, Errors.Database end

    -- Keep the live session in sync.
    local src = UnitLink.Players.GetSourceByCharacterId(characterId)
    local player = src and UnitLink.Players.Get(src)
    if player and player.character and player.character.id == characterId then
        for key, change in pairs(changes) do player.character[key] = change.to end
        TriggerClientEvent(UnitLink.ClientEvents.CharacterLoaded, src, Characters.Public(player.character))
    end

    UnitLink.Log.Audit(UnitLink.AuditActions.CharacterEdit, actor, characterId, { changes = changes })
    local after = Characters.FetchById(characterId)
    return true, after and Characters.Public(after) or nil
end

---------------------------------------------------------------------------
-- Client callbacks
---------------------------------------------------------------------------

local Register = UnitLink.Callbacks.Register

Register('unitlink-core:enterSelection', function(src)
    local player = UnitLink.Players.Get(src)
    if player.characterId then return false, Errors.InvalidState end
    local data = Characters.EnterSelection(player)
    if not data then return false, Errors.Database end
    return true, data
end, { rate = 'enterSelection', exclusive = true })

Register('unitlink-core:previewCharacter', function(src, payload)
    local player = UnitLink.Players.Get(src)
    if player.state ~= States.Selecting then return false, Errors.InvalidState end
    local characterId = Utils.ToId(payload.id)
    if not characterId then return false, Errors.InvalidInput end
    local char = Characters.FetchOwned(characterId, player.identifier)
    if char == nil then return false, Errors.Database end
    if not char then return false, Errors.NotFound end
    local appearance = UnitLink.Appearance.Fetch(characterId)
    if appearance == nil then return false, Errors.Database end
    return true, {
        id = characterId,
        appearance = appearance or nil,
        defaultModel = Config.Appearance.Models[char.gender] or Config.Appearance.Models.male,
    }
end, { rate = 'preview' })

Register('unitlink-core:createCharacter', function(src, payload)
    return Characters.Create(UnitLink.Players.Get(src), payload)
end, { rate = 'createCharacter', exclusive = true })

Register('unitlink-core:deleteCharacter', function(src, payload)
    return Characters.Delete(UnitLink.Players.Get(src), payload)
end, { rate = 'deleteCharacter', exclusive = true })

Register('unitlink-core:selectCharacter', function(src, payload)
    return Characters.Load(UnitLink.Players.Get(src), payload.id)
end, { rate = 'selectCharacter', exclusive = true })

Register('unitlink-core:switchCharacter', function(src)
    return Characters.Switch(UnitLink.Players.Get(src))
end, { rate = 'switchCharacter', exclusive = true })

-- "Return to selection" before the character has entered the world (from the spawn
-- picker, or if appearance creation could not finish). No permission needed: the
-- character never spawned, so nothing is skipped.
Register('unitlink-core:backToSelection', function(src)
    local player = UnitLink.Players.Get(src)
    if not player.characterId then return false, Errors.NoCharacter end
    if player.state ~= States.Creating and player.state ~= States.Spawning then
        return false, Errors.InvalidState
    end
    Characters.Unload(player, 'back', true)
    local data = Characters.EnterSelection(player)
    if not data then return false, Errors.Database end
    return true, data
end, { rate = 'switchCharacter', exclusive = true })
