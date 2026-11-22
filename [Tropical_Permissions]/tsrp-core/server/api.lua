-- TSRP Core: server exports for other resources.
--
-- All getters return copies (FiveM copies tables across resources anyway), so callers
-- can never mutate TSRP Core state directly. Mutation exports validate arguments,
-- respect Config.Security.MutationResourceAllowlist, are audited, and refresh the
-- permission cache immediately.
--
-- Mutation exports take an optional final `actorSource`. When given (a player server
-- id), TSRP Core checks that player is allowed to make the change exactly as if they
-- used the dashboard. When omitted the call is trusted resource code and is audited as
-- 'resource:<name>'.
--
-- See README.md "Export reference" for full documentation.

TSRP = TSRP or {}

local Utils = TSRP.Utils
local Errors = TSRP.Errors
local Permissions = TSRP.Permissions
local Admin = TSRP.Admin

local function invoker()
    return GetInvokingResource() or GetCurrentResourceName()
end

local function mutationAllowed()
    local allow = Config.Security.MutationResourceAllowlist
    if type(allow) ~= 'table' or #allow == 0 then return true end
    local res = invoker()
    return res == GetCurrentResourceName() or Utils.Contains(allow, res)
end

-- Returns actor for audit, or nil + error.
local function resolveActor(actorSource, check)
    if not mutationAllowed() then return nil, Errors.Unauthorized end
    if actorSource == nil then return 'resource:' .. invoker() end
    local src = Utils.ToInteger(actorSource)
    if not src or (src ~= 0 and not TSRP.Players.Get(src)) then return nil, Errors.InvalidInput end
    if check then
        local ok, err = check(src)
        if not ok then return nil, err end
    end
    return src
end

local function toSource(src)
    return Utils.ToInteger(src)
end

---------------------------------------------------------------------------
-- Getters
---------------------------------------------------------------------------

exports('GetPlayer', function(src)
    return TSRP.Players.Snapshot(TSRP.Players.Get(toSource(src)))
end)

exports('GetCharacter', function(src)
    local player = TSRP.Players.Get(toSource(src))
    if not player or not player.character then return nil end
    return TSRP.Characters.ServerView(player.character)
end)

exports('GetCharacterId', function(src)
    local player = TSRP.Players.Get(toSource(src))
    return player and player.characterId or nil
end)

exports('GetSourceFromCharacterId', function(characterId)
    return TSRP.Players.GetSourceByCharacterId(Utils.ToId(characterId))
end)

exports('IsPlayerLoaded', function(src)
    local player = TSRP.Players.Get(toSource(src))
    return player ~= nil and player.characterId ~= nil
end)

exports('IsPlayerSpawned', function(src)
    local player = TSRP.Players.Get(toSource(src))
    return player ~= nil and player.spawned == true
end)

exports('GetActivePlayers', function()
    local list = {}
    for src, p in pairs(TSRP.Players.All()) do
        if p.characterId then list[#list + 1] = { source = src, characterId = p.characterId } end
    end
    return list
end)

exports('HasPermission', function(src, node)
    if not Utils.IsValidPermissionNode(node) then return false end
    return Permissions.Has(toSource(src), node)
end)

-- directOnly = true ignores inherited groups.
exports('HasGroup', function(src, group, directOnly)
    if type(group) ~= 'string' then return false end
    return Permissions.HasGroup(toSource(src), group, directOnly == true)
end)

-- includeInherited = true returns every effective group.
exports('GetGroups', function(src, includeInherited)
    local player = TSRP.Players.Get(toSource(src))
    if not player or not player.characterId or not player.effective then return {} end
    if includeInherited then
        local names = {}
        for _, e in ipairs(player.effective.groups) do names[#names + 1] = e.name end
        return names
    end
    return Utils.DeepCopy(player.groups)
end)

-- Re-read a player's Discord roles now (e.g. right after a bot gives them a role).
exports('RefreshDiscordRoles', function(src)
    local player = TSRP.Players.Get(toSource(src))
    if not player then return false end
    TSRP.Integrations.Discord.Queue(player)
    return TSRP.Integrations.Discord.Active()
end)

exports('GetPermissions', function(src)
    local player = TSRP.Players.Get(toSource(src))
    if not player or not player.effective then return {} end
    return Permissions.ListAllowed(player.effective)
end)

-- Works for online and offline characters. Returns { allowed, explanation, reason }.
exports('ExplainPermission', function(characterId, node)
    characterId = Utils.ToId(characterId)
    if not characterId or not Utils.IsValidPermissionNode(node) then return nil end
    local effective = Permissions.GetEffective(characterId)
    if not effective then return nil end
    local allowed, reason = Permissions.Resolve(effective, node)
    return { allowed = allowed, reason = reason, explanation = Permissions.DescribeReason(node, allowed, reason) }
end)

exports('CharacterHasPermission', function(characterId, node)
    characterId = Utils.ToId(characterId)
    if not characterId or not Utils.IsValidPermissionNode(node) then return false end
    local effective = Permissions.GetEffective(characterId)
    if not effective then return false end
    local allowed = Permissions.Resolve(effective, node)
    return allowed
end)

exports('GetGroupDefinition', function(name)
    return TSRP.Groups.Public(TSRP.Groups.Get(name))
end)

exports('GetGroupList', function()
    local list = {}
    for _, def in ipairs(TSRP.Groups.List()) do list[#list + 1] = TSRP.Groups.Public(def) end
    return list
end)

exports('IsBootstrapAdmin', function(src)
    src = toSource(src)
    if not src or src == 0 then return false end
    return TSRP.Players.IsBootstrap(src)
end)

exports('RegisterPermissionNode', function(node, description)
    return Permissions.RegisterNode(node, description, invoker())
end)

---------------------------------------------------------------------------
-- Metadata
---------------------------------------------------------------------------

exports('GetMetadata', function(src, key)
    local player = TSRP.Players.Get(toSource(src))
    if not player or not player.characterId then return nil end
    return TSRP.Metadata.Get(player.characterId, key)
end)

exports('SetMetadata', function(src, key, value)
    if not mutationAllowed() then return false, Errors.Unauthorized end
    local player = TSRP.Players.Get(toSource(src))
    if not player or not player.characterId then return false, Errors.NoCharacter end
    return TSRP.Metadata.Set(player.characterId, key, value, nil)
end)

exports('GetCharacterMetadata', function(characterId, key)
    if key == nil then return TSRP.Metadata.GetAll(characterId) end
    return TSRP.Metadata.Get(characterId, key)
end)

exports('SetCharacterMetadata', function(characterId, key, value)
    if not mutationAllowed() then return false, Errors.Unauthorized end
    return TSRP.Metadata.Set(characterId, key, value, nil)
end)

---------------------------------------------------------------------------
-- Group and permission mutations
---------------------------------------------------------------------------

exports('AddGroup', function(characterId, group, actorSource)
    characterId = Utils.ToId(characterId)
    if not characterId or type(group) ~= 'string' then return false, Errors.InvalidInput end
    local actor, err = resolveActor(actorSource, function(src)
        if not Admin.Can(src, Admin.Nodes.permissions) then return false, Errors.Unauthorized end
        local ok, e = Admin.CanManageCharacter(src, characterId)
        if not ok then return false, e end
        return Admin.CanAssignGroup(src, group)
    end)
    if not actor then return false, err end
    return Permissions.AssignGroup(characterId, group, actor)
end)

exports('RemoveGroup', function(characterId, group, actorSource)
    characterId = Utils.ToId(characterId)
    if not characterId or type(group) ~= 'string' then return false, Errors.InvalidInput end
    local actor, err = resolveActor(actorSource, function(src)
        if not Admin.Can(src, Admin.Nodes.permissions) then return false, Errors.Unauthorized end
        local ok, e = Admin.CanManageCharacter(src, characterId)
        if not ok then return false, e end
        if TSRP.Groups.Exists(group) then return Admin.CanAssignGroup(src, group) end
        return Admin.IsSuper(src), Errors.UnknownGroup
    end)
    if not actor then return false, err end
    return Permissions.RemoveGroup(characterId, group, actor)
end)

local function overrideExport(allow)
    return function(characterId, node, actorSource)
        characterId = Utils.ToId(characterId)
        if not characterId or not Utils.IsValidPermissionNode(node) then return false, Errors.InvalidInput end
        local actor, err = resolveActor(actorSource, function(src)
            if not Admin.Can(src, Admin.Nodes.permissions) then return false, Errors.Unauthorized end
            local ok, e = Admin.CanManageCharacter(src, characterId)
            if not ok then return false, e end
            return Admin.CanGrantNode(src, node)
        end)
        if not actor then return false, err end
        if allow == nil then
            return Permissions.ClearOverride(characterId, node, actor)
        end
        return Permissions.SetOverride(characterId, node, allow, actor)
    end
end

-- Explicit allow override.
exports('GrantPermission', overrideExport(true))
-- Explicit deny override (beats every group grant).
exports('DenyPermission', overrideExport(false))
-- Remove an override (allow or deny); the character falls back to its groups.
exports('RevokePermission', overrideExport(nil))
exports('ClearPermissionOverride', overrideExport(nil))

---------------------------------------------------------------------------
-- Appearance / lifecycle helpers
---------------------------------------------------------------------------

-- Open the appearance editor for a player (e.g. a clothing shop resource).
-- sections: { ped, headBlend, faceFeatures, headOverlays, components, props, tattoos }
exports('OpenAppearanceEditor', function(src, sections)
    return TSRP.Appearance.OpenEditor(toSource(src), sections)
end)

-- Send a player back to character selection (saves first). Respects nothing but the
-- caller's own logic, so only trusted resources should use it.
exports('ForceCharacterSelection', function(src)
    if not mutationAllowed() then return false, Errors.Unauthorized end
    local player = TSRP.Players.Get(toSource(src))
    if not player or not player.characterId then return false, Errors.NoCharacter end
    player.lastCharacterId = player.characterId
    TSRP.Characters.Unload(player, 'forced')
    local data = TSRP.Characters.EnterSelection(player)
    TriggerClientEvent(TSRP.ClientEvents.EnterSelection, player.source, data)
    return true
end)

---------------------------------------------------------------------------
-- Read-only character lookup for other resources (e.g. UnitLink CAD).
-- Works for offline characters. Never returns account identifiers.
---------------------------------------------------------------------------

local LOOKUP_COLUMNS = "id, firstname, lastname, DATE_FORMAT(dateofbirth, '%Y-%m-%d') AS dateofbirth, gender, nationality, height"

local function lookupEscape(s)
    return (s:gsub('[\\%%_]', function(c) return '\\' .. c end))
end

-- query: part of a name ("doe", "john doe", "doe john") or a character id.
-- Returns a list (max `limit`, default 25, cap 50), or nil on database error.
exports('SearchCharacters', function(query, limit)
    query = type(query) == 'string' and (Utils.Trim(query:sub(1, 64)) or '') or ''
    if query == '' then return {} end
    limit = math.max(1, math.min(50, math.floor(tonumber(limit) or 25)))
    local asId = Utils.ToId(query)
    if asId then
        return TSRP.DB.query('SELECT ' .. LOOKUP_COLUMNS .. ' FROM tsrp_characters WHERE id = ? LIMIT 1', { asId })
    end
    local like = '%' .. lookupEscape(query) .. '%'
    return TSRP.DB.query('SELECT ' .. LOOKUP_COLUMNS .. " FROM tsrp_characters WHERE CONCAT(firstname, ' ', lastname) LIKE ? OR CONCAT(lastname, ' ', firstname) LIKE ? ORDER BY lastname, firstname LIMIT " .. limit, { like, like })
end)

-- One character's public fields, or nil if it does not exist.
exports('GetCharacterById', function(characterId)
    characterId = Utils.ToId(characterId)
    if not characterId then return nil end
    local row = TSRP.DB.single('SELECT ' .. LOOKUP_COLUMNS .. ' FROM tsrp_characters WHERE id = ?', { characterId })
    return row or nil
end)

exports('GetVersion', function()
    return TSRP.Version
end)
