-- UnitLink Core: character permission resolution, caching and assignment.
--
-- RESOLUTION ORDER (deterministic) for HasPermission(character, 'a.b.c'):
--
--   Candidates, most specific first: 'a.b.c', 'a.b.*', 'a.*', '*'
--
--   1. Character overrides. Walk the candidates in order; the FIRST candidate that has
--      an override decides the answer (allow -> true, deny -> false). Overrides always
--      beat group grants, so an explicit deny can never be bypassed by any group.
--      A more specific override beats a less specific one (deny 'a.*' + allow 'a.b.c'
--      => 'a.b.c' allowed, 'a.b.d' denied).
--   2. Group grants. If any candidate is granted by any effective group (directly
--      assigned groups plus everything they inherit, recursively), the answer is true.
--   3. Otherwise false. No character loaded => false.
--
-- Effective permissions are computed once when a character loads and cached on the
-- player. The cache is rebuilt whenever that character's groups/overrides change or
-- any group definition changes, so it cannot go stale. HasPermission never queries
-- MySQL.

UnitLink = UnitLink or {}
local Permissions = {}
UnitLink.Permissions = Permissions

local Utils = UnitLink.Utils

Permissions.registry = {} -- [node] = { description, resource }

---------------------------------------------------------------------------
-- Pure resolution
---------------------------------------------------------------------------

-- 'a.b.c' -> { 'a.b.c', 'a.b.*', 'a.*', '*' };  'a.b.*' -> { 'a.b.*', 'a.*', '*' }
function Permissions.Candidates(node)
    if node == '*' then return { '*' } end
    local parts = {}
    for segment in node:gmatch('[^%.]+') do parts[#parts + 1] = segment end
    local list = { node }
    local last = #parts - 1
    if parts[#parts] == '*' then last = #parts - 2 end
    for i = last, 1, -1 do
        list[#list + 1] = table.concat(parts, '.', 1, i) .. '.*'
    end
    list[#list + 1] = '*'
    return list
end

-- Build the effective permission data from group definitions, the directly assigned
-- group names and the override map ([node] = true/false).
function Permissions.Build(defs, directGroups, overrides)
    local expanded, missing = UnitLink.Groups.Expand(defs, directGroups)
    local granted = {}
    for _, entry in ipairs(expanded) do
        local def = defs[entry.name]
        for _, node in ipairs(def.permissions) do
            if not granted[node] then
                granted[node] = { group = entry.name, via = entry.via, depth = entry.depth }
            end
        end
    end
    local ov = {}
    for node, allow in pairs(overrides or {}) do ov[node] = allow and true or false end
    return {
        direct = Utils.DeepCopy(directGroups or {}),
        groups = expanded,
        groupSet = (function()
            local s = {}
            for _, e in ipairs(expanded) do s[e.name] = true end
            return s
        end)(),
        granted = granted,
        overrides = ov,
        missing = missing,
    }
end

-- Returns allowed (bool), reason table.
function Permissions.Resolve(effective, node)
    if not effective or not Utils.IsValidPermissionNode(node) then
        return false, { type = 'none' }
    end
    local candidates = Permissions.Candidates(node)
    for _, c in ipairs(candidates) do
        local o = effective.overrides[c]
        if o ~= nil then
            return o, { type = o and 'override_allow' or 'override_deny', node = c }
        end
    end
    for _, c in ipairs(candidates) do
        local g = effective.granted[c]
        if g then
            return true, { type = 'group', node = c, group = g.group, via = g.via, inherited = g.depth > 0 }
        end
    end
    return false, { type = 'none' }
end

-- Human readable explanation of a Resolve() reason.
function Permissions.DescribeReason(node, allowed, reason)
    if reason.type == 'override_allow' then
        return ('%s is ALLOWED by an explicit character override on %s'):format(node, reason.node)
    elseif reason.type == 'override_deny' then
        return ('%s is DENIED by an explicit character override on %s'):format(node, reason.node)
    elseif reason.type == 'group' then
        if reason.inherited then
            return ('%s is ALLOWED by group %s (grants %s), inherited through %s'):format(node, reason.group, reason.node, reason.via)
        end
        return ('%s is ALLOWED by group %s (grants %s)'):format(node, reason.group, reason.node)
    end
    return ('%s is DENIED: no override and no group grants it'):format(node)
end

-- Every node this character effectively holds, as written (wildcards included),
-- excluding group grants cancelled by overrides.
function Permissions.ListAllowed(effective)
    local out, seen = {}, {}
    if not effective then return out end
    for node in pairs(effective.granted) do
        if not seen[node] and Permissions.Resolve(effective, node) then
            seen[node] = true
            out[#out + 1] = node
        end
    end
    for node, allow in pairs(effective.overrides) do
        if allow and not seen[node] then
            seen[node] = true
            out[#out + 1] = node
        end
    end
    table.sort(out)
    return out
end

-- Rows for the admin dashboard: every node that is granted or overridden, with the
-- final result and where it came from.
function Permissions.Describe(effective)
    local nodes, rows = {}, {}
    for node in pairs(effective.granted) do nodes[node] = true end
    for node in pairs(effective.overrides) do nodes[node] = true end
    for _, node in ipairs(Utils.SortedKeys(nodes)) do
        local allowed, reason = Permissions.Resolve(effective, node)
        local g = effective.granted[node]
        rows[#rows + 1] = {
            node = node,
            allowed = allowed,
            source = reason.type,
            matched = reason.node,
            group = g and g.group or nil,
            via = g and g.via or nil,
            inherited = g and g.depth > 0 or false,
            override = effective.overrides[node],
            explanation = Permissions.DescribeReason(node, allowed, reason),
        }
    end
    return rows
end

---------------------------------------------------------------------------
-- Registry
---------------------------------------------------------------------------

function Permissions.RegisterNode(node, description, resource)
    if not Utils.IsValidPermissionNode(node) or Utils.IsWildcardNode(node) then return false end
    Permissions.registry[node] = {
        description = type(description) == 'string' and description:sub(1, 200) or '',
        resource = resource or 'UnitLink-Core',
    }
    return true
end

function Permissions.RegistryList()
    local nodes = {}
    for node, info in pairs(Permissions.registry) do
        nodes[#nodes + 1] = { node = node, description = info.description, resource = info.resource }
    end
    -- Include nodes only used in groups so the dashboard can find them too.
    for _, def in pairs(UnitLink.Groups.defs) do
        for _, node in ipairs(def.permissions) do
            if not Permissions.registry[node] then
                nodes[#nodes + 1] = { node = node, description = '', resource = 'group:' .. def.name }
            end
        end
    end
    table.sort(nodes, function(a, b) return a.node < b.node end)
    local dedup, seen = {}, {}
    for _, n in ipairs(nodes) do
        if not seen[n.node] then
            seen[n.node] = true
            dedup[#dedup + 1] = n
        end
    end
    return dedup
end

---------------------------------------------------------------------------
-- Cache management
---------------------------------------------------------------------------

-- Loads groups and overrides for a character from the database.
function Permissions.LoadCharacterData(characterId)
    local groups = UnitLink.DB.query('SELECT group_name FROM unitlink_character_groups WHERE character_id = ?', { characterId })
    local overrides = UnitLink.DB.query('SELECT permission, allow FROM unitlink_character_permission_overrides WHERE character_id = ?', { characterId })
    if not groups or not overrides then return nil end
    local direct, ov = {}, {}
    for _, row in ipairs(groups) do direct[#direct + 1] = row.group_name end
    table.sort(direct)
    for _, row in ipairs(overrides) do
        ov[row.permission] = row.allow == 1 or row.allow == true
    end
    return direct, ov
end

local function pushToClient(player)
    TriggerClientEvent(UnitLink.ClientEvents.PermissionsUpdated, player.source, {
        groups = Utils.DeepCopy(player.groups),
        effectiveGroups = (function()
            local names = {}
            for _, e in ipairs(player.effective.groups) do names[#names + 1] = e.name end
            return names
        end)(),
        permissions = Permissions.ListAllowed(player.effective),
    })
end

-- Rebuild a loaded player's cache from player.groups/player.overrides.
function Permissions.Rebuild(player, silent)
    -- Discord role sync (integrations/discord.lua) adds account groups and drops
    -- department groups the account hasn't unlocked. Inactive = player.groups as-is.
    local direct = UnitLink.Integrations.Discord.EffectiveGroups(player)
    player.effective = Permissions.Build(UnitLink.Groups.defs, direct, player.overrides)
    if #player.effective.missing > 0 then
        UnitLink.Log.Warn('Character %s has unknown group(s): %s', tostring(player.characterId), table.concat(player.effective.missing, ', '))
    end
    if not silent then
        pushToClient(player)
        TriggerEvent(UnitLink.ServerEvents.PermissionsUpdated, player.characterId, player.source)
    end
end

-- Reload a character's data from the database and rebuild, if it is active.
function Permissions.RefreshCharacter(characterId)
    local src = UnitLink.Players.GetSourceByCharacterId(characterId)
    if not src then
        TriggerEvent(UnitLink.ServerEvents.PermissionsUpdated, characterId, nil)
        return true
    end
    local player = UnitLink.Players.Get(src)
    if not player or player.characterId ~= characterId then return true end
    local direct, ov = Permissions.LoadCharacterData(characterId)
    if not direct then return false end
    if player.characterId ~= characterId then return true end
    player.groups, player.overrides = direct, ov
    Permissions.Rebuild(player)
    return true
end

-- Rebuild every active character (after a group definition changed).
function Permissions.RebuildAll()
    for _, player in pairs(UnitLink.Players.All()) do
        if player.characterId then Permissions.Rebuild(player) end
    end
end

---------------------------------------------------------------------------
-- Queries used by the API
---------------------------------------------------------------------------

function Permissions.Has(src, node)
    local player = UnitLink.Players.Get(src)
    if not player or not player.characterId or not player.effective then return false end
    local allowed = Permissions.Resolve(player.effective, node)
    return allowed
end

-- Group check. By default inherited groups count (leo_command has 'leo').
function Permissions.HasGroup(src, group, directOnly)
    local player = UnitLink.Players.Get(src)
    if not player or not player.characterId or not player.effective then return false end
    if directOnly then return Utils.Contains(player.effective.direct, group) end
    return player.effective.groupSet[group] == true
end

-- Effective data for any character (active => cache, offline => built on demand).
function Permissions.GetEffective(characterId)
    local src = UnitLink.Players.GetSourceByCharacterId(characterId)
    local player = src and UnitLink.Players.Get(src)
    if player and player.characterId == characterId and player.effective then
        return player.effective
    end
    local direct, ov = Permissions.LoadCharacterData(characterId)
    if not direct then return nil end
    return Permissions.Build(UnitLink.Groups.defs, direct, ov)
end

---------------------------------------------------------------------------
-- Mutations (authorisation is done by the caller: administration.lua / api.lua)
---------------------------------------------------------------------------

local function characterExists(characterId)
    local row = UnitLink.DB.scalar('SELECT id FROM unitlink_characters WHERE id = ?', { characterId })
    if row == nil then return nil end
    return row ~= false
end

local function actorLabel(actor)
    local identifier = UnitLink.Log.ResolveActor(actor)
    return identifier and identifier:sub(1, 64) or nil
end

function Permissions.AssignGroup(characterId, group, actor)
    characterId = Utils.ToId(characterId)
    if not characterId then return false, UnitLink.Errors.InvalidInput end
    if not UnitLink.Groups.Exists(group) then return false, UnitLink.Errors.UnknownGroup end
    local exists = characterExists(characterId)
    if exists == nil then return false, UnitLink.Errors.Database end
    if not exists then return false, UnitLink.Errors.NotFound end
    local allowed, derr = UnitLink.Integrations.Discord.CheckAssign(characterId, group)
    if not allowed then return false, derr end

    local affected = UnitLink.DB.update(
        'INSERT IGNORE INTO unitlink_character_groups (character_id, group_name, assigned_by) VALUES (?, ?, ?)',
        { characterId, group, actorLabel(actor) })
    if affected == nil then return false, UnitLink.Errors.Database end
    if affected == 0 then return false, UnitLink.Errors.Duplicate end

    Permissions.RefreshCharacter(characterId)
    UnitLink.Log.Audit(UnitLink.AuditActions.GroupAssign, actor, characterId, { group = group })
    TriggerEvent(UnitLink.ServerEvents.GroupAssigned, characterId, group, actorLabel(actor))
    return true
end

function Permissions.RemoveGroup(characterId, group, actor)
    characterId = Utils.ToId(characterId)
    if not characterId or type(group) ~= 'string' then return false, UnitLink.Errors.InvalidInput end
    local affected = UnitLink.DB.update('DELETE FROM unitlink_character_groups WHERE character_id = ? AND group_name = ?', { characterId, group })
    if affected == nil then return false, UnitLink.Errors.Database end
    if affected == 0 then return false, UnitLink.Errors.NotFound end

    Permissions.RefreshCharacter(characterId)
    UnitLink.Log.Audit(UnitLink.AuditActions.GroupRemove, actor, characterId, { group = group })
    TriggerEvent(UnitLink.ServerEvents.GroupRemoved, characterId, group, actorLabel(actor))
    return true
end

-- allow = true (explicit allow) / false (explicit deny)
function Permissions.SetOverride(characterId, node, allow, actor)
    characterId = Utils.ToId(characterId)
    if not characterId or not Utils.IsValidPermissionNode(node) or type(allow) ~= 'boolean' then
        return false, UnitLink.Errors.InvalidInput
    end
    local exists = characterExists(characterId)
    if exists == nil then return false, UnitLink.Errors.Database end
    if not exists then return false, UnitLink.Errors.NotFound end

    local affected = UnitLink.DB.update(
        'INSERT INTO unitlink_character_permission_overrides (character_id, permission, allow, set_by) VALUES (?, ?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE allow = VALUES(allow), set_by = VALUES(set_by)',
        { characterId, node, allow and 1 or 0, actorLabel(actor) })
    if affected == nil then return false, UnitLink.Errors.Database end

    Permissions.RefreshCharacter(characterId)
    UnitLink.Log.Audit(allow and UnitLink.AuditActions.PermissionAllow or UnitLink.AuditActions.PermissionDeny, actor, characterId, { permission = node })
    return true
end

function Permissions.ClearOverride(characterId, node, actor)
    characterId = Utils.ToId(characterId)
    if not characterId or not Utils.IsValidPermissionNode(node) then return false, UnitLink.Errors.InvalidInput end
    local affected = UnitLink.DB.update(
        'DELETE FROM unitlink_character_permission_overrides WHERE character_id = ? AND permission = ?', { characterId, node })
    if affected == nil then return false, UnitLink.Errors.Database end
    if affected == 0 then return false, UnitLink.Errors.NotFound end

    Permissions.RefreshCharacter(characterId)
    UnitLink.Log.Audit(UnitLink.AuditActions.PermissionClear, actor, characterId, { permission = node })
    return true
end
