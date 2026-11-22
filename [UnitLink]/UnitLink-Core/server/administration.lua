-- UnitLink Core: administration authorisation and dashboard callbacks.
--
-- Every admin request is authorised here, on the server, on every call. The NUI only
-- hides buttons for convenience; it is never a security control.
--
-- Who may do what:
--   * Console (source 0) and bootstrap admins (config/bootstrap.lua): everything.
--   * Everyone else: needs the matching node on their ACTIVE character, and
--       - may not change their own character's groups/overrides,
--       - may only manage characters whose highest group priority is below their own,
--       - may only assign groups with a priority below their own,
--       - may only grant/deny nodes they hold themselves,
--       - may only create/edit/delete groups below their own priority.
--     (The last four rules can be turned off in Config.Security.)

UnitLink = UnitLink or {}
local Admin = {}
UnitLink.Admin = Admin

local Utils = UnitLink.Utils
local Errors = UnitLink.Errors
local Permissions = UnitLink.Permissions
local Groups = UnitLink.Groups

local NODES = {
    access = 'unitlink.admin.access',
    players = 'unitlink.admin.players',
    identifiers = 'unitlink.admin.identifiers',
    characters = 'unitlink.admin.characters',
    permissions = 'unitlink.admin.permissions',
    groups = 'unitlink.admin.groups',
    audit = 'unitlink.admin.audit',
}
Admin.Nodes = NODES

---------------------------------------------------------------------------
-- Authorisation
---------------------------------------------------------------------------

function Admin.IsSuper(src)
    return src == 0 or UnitLink.Players.IsBootstrap(src)
end

function Admin.Can(src, node)
    if Admin.IsSuper(src) then return true end
    return Permissions.Has(src, node)
end

function Admin.Capabilities(src)
    local caps = { bootstrap = Admin.IsSuper(src) }
    for key, node in pairs(NODES) do caps[key] = Admin.Can(src, node) end
    -- Every section needs dashboard access first.
    if not caps.access then
        for key in pairs(NODES) do caps[key] = false end
    end
    return caps
end

function Admin.ActorPriority(src)
    if Admin.IsSuper(src) then return math.huge end
    local player = UnitLink.Players.Get(src)
    if not player or not player.characterId then return -1 end
    -- effective.direct includes groups that come from Discord roles.
    return Groups.MaxPriority(player.effective and player.effective.direct or player.groups)
end

local function characterPriority(characterId)
    local effective = Permissions.GetEffective(characterId)
    if not effective then return nil end
    return Groups.MaxPriority(effective.direct)
end

-- Can src change this character's record, groups or overrides?
function Admin.CanManageCharacter(src, characterId)
    if Admin.IsSuper(src) then return true end
    local player = UnitLink.Players.Get(src)
    if player and player.characterId == characterId then return false, Errors.Hierarchy end
    if not Config.Security.EnforcePriorityHierarchy then return true end
    local target = characterPriority(characterId)
    if target == nil then return false, Errors.Database end
    if target >= Admin.ActorPriority(src) then return false, Errors.Hierarchy end
    return true
end

function Admin.CanAssignGroup(src, group)
    if Admin.IsSuper(src) then return true end
    local def = Groups.Get(group)
    if not def then return false, Errors.UnknownGroup end
    if Config.Security.EnforcePriorityHierarchy and def.priority >= Admin.ActorPriority(src) then
        return false, Errors.Hierarchy
    end
    return true
end

function Admin.CanGrantNode(src, node)
    if Admin.IsSuper(src) then return true end
    if Config.Security.EnforceGrantOwnership and not Permissions.Has(src, node) then
        return false, Errors.Hierarchy
    end
    return true
end

-- Can src write this group definition (create/update)?
function Admin.CanWriteGroup(src, name, raw)
    if Admin.IsSuper(src) then return true end
    local mine = Admin.ActorPriority(src)
    if Config.Security.EnforcePriorityHierarchy then
        local existing = Groups.Get(name)
        if existing and existing.priority >= mine then return false, Errors.Hierarchy end
        if (Utils.ToInteger(raw.priority) or 0) >= mine then return false, Errors.Hierarchy end
        for _, parent in ipairs(type(raw.inherits) == 'table' and raw.inherits or {}) do
            local def = Groups.Get(parent)
            if def and def.priority >= mine then return false, Errors.Hierarchy end
        end
    end
    if Config.Security.EnforceGrantOwnership then
        local existing = Groups.Get(name)
        for _, node in ipairs(type(raw.permissions) == 'table' and raw.permissions or {}) do
            local alreadyThere = existing and existing.permSet[node]
            if not alreadyThere and type(node) == 'string' and not Permissions.Has(src, node) then
                return false, Errors.Hierarchy
            end
        end
    end
    return true
end

local function deny(src, what)
    UnitLink.Log.Audit(UnitLink.AuditActions.AdminDenied, src, nil, { request = what })
    return false, Errors.Unauthorized
end

---------------------------------------------------------------------------
-- Data helpers
---------------------------------------------------------------------------

local function likeEscape(s)
    return (s:gsub('[\\%%_]', function(c) return '\\' .. c end))
end

local function characterSummary(row, showIdentifier)
    local id = tonumber(row.id)
    local online = UnitLink.Players.GetSourceByCharacterId(id)
    return {
        id = id,
        slot = tonumber(row.slot),
        firstname = row.firstname,
        lastname = row.lastname,
        fullname = row.firstname .. ' ' .. row.lastname,
        dateofbirth = row.dateofbirth,
        gender = row.gender,
        nationality = row.nationality,
        online = online ~= nil,
        source = online,
        identifier = showIdentifier and row.identifier or nil,
    }
end

function Admin.CharacterDetails(src, characterId)
    local char = UnitLink.Characters.FetchById(characterId)
    if char == nil then return nil, Errors.Database end
    if not char then return nil, Errors.NotFound end

    local effective = Permissions.GetEffective(characterId)
    if not effective then return nil, Errors.Database end

    local caps = Admin.Capabilities(src)
    local overrides = {}
    for _, node in ipairs(Utils.SortedKeys(effective.overrides)) do
        overrides[#overrides + 1] = { node = node, allow = effective.overrides[node] }
    end
    local effectiveGroups = {}
    for _, e in ipairs(effective.groups) do
        local def = Groups.Get(e.name)
        effectiveGroups[#effectiveGroups + 1] = {
            name = e.name, label = def and def.label or e.name, via = e.via, inherited = e.depth > 0,
        }
    end
    local directGroups = {}
    for _, name in ipairs(effective.direct) do
        local def = Groups.Get(name)
        directGroups[#directGroups + 1] = { name = name, label = def and def.label or name, priority = def and def.priority or -1, missing = def == nil }
    end
    local online = UnitLink.Players.GetSourceByCharacterId(characterId)
    local metadata = UnitLink.Metadata.GetAll(characterId) or {}
    local canManage = Admin.CanManageCharacter(src, characterId)

    return {
        character = {
            id = char.id, slot = char.slot, firstname = char.firstname, lastname = char.lastname,
            dateofbirth = char.dateofbirth, gender = char.gender, nationality = char.nationality,
            height = char.height, createdAt = char.createdAt, updatedAt = char.updatedAt,
            identifier = caps.identifiers and char.identifier or nil,
            lastPosition = char.lastPosition,
        },
        online = online ~= nil,
        source = online,
        groups = directGroups,
        effectiveGroups = effectiveGroups,
        overrides = overrides,
        permissions = Permissions.Describe(effective),
        metadata = metadata,
        canManage = canManage == true,
    }
end

---------------------------------------------------------------------------
-- Callback registration helper
---------------------------------------------------------------------------

local function adminCallback(name, node, handler, mutation)
    UnitLink.Callbacks.Register('admin:' .. name, function(src, payload)
        if not Admin.Can(src, NODES.access) then return deny(src, name) end
        if node then
            local nodes = type(node) == 'table' and node or { node }
            local any = false
            for _, n in ipairs(nodes) do
                if Admin.Can(src, n) then any = true break end
            end
            if not any then return deny(src, name) end
        end
        return handler(src, payload)
    end, { rate = mutation and 'adminMutation' or 'admin' })
end

---------------------------------------------------------------------------
-- Read endpoints
---------------------------------------------------------------------------

adminCallback('init', nil, function(src)
    return true, {
        capabilities = Admin.Capabilities(src),
        serverName = Config.ServerName,
        version = UnitLink.Version,
        rules = {
            genders = Config.Characters.Genders,
            nationalities = Config.Characters.Nationalities,
            heightMin = Config.Characters.Height.Min,
            heightMax = Config.Characters.Height.Max,
        },
    }
end)

adminCallback('overview', nil, function()
    local connected, loaded = UnitLink.Players.Count()
    local active = 0
    for _, p in pairs(UnitLink.Players.All()) do
        if p.state == UnitLink.States.Active then active = active + 1 end
    end
    local totals = UnitLink.DB.single('SELECT (SELECT COUNT(*) FROM unitlink_characters) AS characters, (SELECT COUNT(*) FROM unitlink_players) AS accounts', {})
    if not totals then return false, Errors.Database end
    local maxSlots = UnitLink.Identity.MaxSlots()
    local accounts = tonumber(totals.accounts) or 0
    local characters = tonumber(totals.characters) or 0
    return true, {
        connected = connected,
        loaded = loaded,
        active = active,
        totalCharacters = characters,
        totalAccounts = accounts,
        slotsPerAccount = maxSlots,
        availableSlots = math.max(0, accounts * maxSlots - characters),
        groups = Utils.Count(Groups.defs),
        maxClients = GetConvarInt('sv_maxclients', 48),
    }
end)

adminCallback('players', NODES.players, function(src)
    local showIds = Admin.Can(src, NODES.identifiers)
    local list = {}
    for s, p in pairs(UnitLink.Players.All()) do
        local groups = {}
        for _, g in ipairs(p.groups) do
            local def = Groups.Get(g)
            groups[#groups + 1] = def and def.label or g
        end
        list[#list + 1] = {
            source = s,
            name = p.name,
            identifier = showIds and p.identifier or nil,
            state = p.state,
            characterId = p.characterId,
            characterName = p.character and (p.character.firstname .. ' ' .. p.character.lastname) or nil,
            groups = groups,
            ping = GetPlayerPing(tostring(s)),
            bootstrap = showIds and UnitLink.Players.IsBootstrap(s) or nil,
        }
    end
    table.sort(list, function(a, b) return a.source < b.source end)
    return true, list
end)

adminCallback('searchCharacters', { NODES.characters, NODES.permissions }, function(src, payload)
    local query = Utils.Trim(type(payload.query) == 'string' and payload.query:sub(1, 64) or '') or ''
    local showIds = Admin.Can(src, NODES.identifiers)
    local base = "SELECT id, identifier, slot, firstname, lastname, DATE_FORMAT(dateofbirth, '%Y-%m-%d') AS dateofbirth, gender, nationality FROM unitlink_characters "
    local rows
    local asId = Utils.ToId(query)
    if query == '' then
        rows = UnitLink.DB.query(base .. 'ORDER BY updated_at DESC LIMIT 50', {})
    elseif asId then
        rows = UnitLink.DB.query(base .. 'WHERE id = ? LIMIT 1', { asId })
    elseif showIds and query:find('^license2?:') then
        rows = UnitLink.DB.query(base .. 'WHERE identifier = ? ORDER BY slot LIMIT 10', { query })
    else
        local like = '%' .. likeEscape(query) .. '%'
        rows = UnitLink.DB.query(base .. "WHERE CONCAT(firstname, ' ', lastname) LIKE ? ORDER BY lastname, firstname LIMIT 50", { like })
    end
    if not rows then return false, Errors.Database end
    local list = {}
    for _, row in ipairs(rows) do list[#list + 1] = characterSummary(row, showIds) end
    return true, list
end)

adminCallback('getCharacter', { NODES.characters, NODES.permissions }, function(src, payload)
    local id = Utils.ToId(payload.id)
    if not id then return false, Errors.InvalidInput end
    local details, err = Admin.CharacterDetails(src, id)
    if not details then return false, err end
    return true, details
end)

adminCallback('explain', { NODES.characters, NODES.permissions }, function(_, payload)
    local id = Utils.ToId(payload.id)
    local node = type(payload.node) == 'string' and Utils.Trim(payload.node) or nil
    if not id or not Utils.IsValidPermissionNode(node) then return false, Errors.InvalidInput end
    local effective = Permissions.GetEffective(id)
    if not effective then return false, Errors.NotFound end
    local allowed, reason = Permissions.Resolve(effective, node)
    return true, {
        node = node,
        allowed = allowed,
        reason = reason,
        candidates = Permissions.Candidates(node),
        explanation = Permissions.DescribeReason(node, allowed, reason),
    }
end)

adminCallback('groups', nil, function(src)
    local counts = UnitLink.DB.query('SELECT group_name, COUNT(*) AS n FROM unitlink_character_groups GROUP BY group_name', {})
    if not counts then return false, Errors.Database end
    local byName = {}
    for _, row in ipairs(counts) do byName[row.group_name] = tonumber(row.n) end
    local list = {}
    for _, def in ipairs(Groups.List()) do
        local pub = Groups.Public(def)
        pub.assigned = byName[def.name] or 0
        local expanded = Groups.Expand(Groups.defs, { def.name })
        pub.effectiveGroups = {}
        for _, e in ipairs(expanded) do pub.effectiveGroups[#pub.effectiveGroups + 1] = e.name end
        list[#list + 1] = pub
    end
    local priority = Admin.ActorPriority(src)
    return true, { groups = list, actorPriority = priority == math.huge and 100000 or priority }
end)

adminCallback('nodes', nil, function()
    return true, Permissions.RegistryList()
end)

adminCallback('audit', NODES.audit, function(src, payload)
    local page = Utils.Clamp(Utils.ToInteger(payload.page) or 1, 1, 10000)
    local where, params = {}, {}
    if type(payload.action) == 'string' and payload.action ~= '' and #payload.action <= 64 then
        where[#where + 1] = 'action = ?'
        params[#params + 1] = payload.action
    end
    local target = Utils.ToId(payload.characterId)
    if target then
        where[#where + 1] = '(target_character_id = ? OR actor_character_id = ?)'
        params[#params + 1] = target
        params[#params + 1] = target
    end
    -- page is a clamped integer, so formatting it into the query is safe (and avoids
    -- MySQL 8 prepared-statement quirks with LIMIT placeholders).
    local offset = math.floor((page - 1) * 50)
    local rows = UnitLink.DB.query(
        'SELECT id, UNIX_TIMESTAMP(created_at) AS ts, actor_identifier, actor_character_id, target_character_id, action, details ' ..
        'FROM unitlink_audit_log ' .. (#where > 0 and ('WHERE ' .. table.concat(where, ' AND ') .. ' ') or '') ..
        ('ORDER BY id DESC LIMIT 50 OFFSET %d'):format(offset), params)
    if not rows then return false, Errors.Database end
    local showIds = Admin.Can(src, NODES.identifiers)
    local list = {}
    for _, row in ipairs(rows) do
        local actor = row.actor_identifier
        local details = row.details
        if not showIds then
            if actor and actor:find(':') then actor = Utils.Redact(actor) end
            if type(details) == 'string' then
                details = details:gsub('license2?:%x+', function(m) return Utils.Redact(m) end)
            end
        end
        list[#list + 1] = {
            id = tonumber(row.id),
            timestamp = tonumber(row.ts),
            actor = actor,
            actorCharacterId = tonumber(row.actor_character_id),
            targetCharacterId = tonumber(row.target_character_id),
            action = row.action,
            details = Utils.JsonDecode(details, details),
        }
    end
    return true, { page = page, entries = list }
end)

---------------------------------------------------------------------------
-- Mutations
---------------------------------------------------------------------------

local function guardCharacter(src, payload)
    local id = Utils.ToId(payload.id)
    if not id then return nil, Errors.InvalidInput end
    local ok, err = Admin.CanManageCharacter(src, id)
    if not ok then return nil, err end
    return id
end

adminCallback('updateCharacter', NODES.characters, function(src, payload)
    local id, err = guardCharacter(src, payload)
    if not id then return false, err end
    return UnitLink.Characters.Update(id, type(payload.fields) == 'table' and payload.fields or {}, src)
end, true)

adminCallback('setMetadata', NODES.characters, function(src, payload)
    local id, err = guardCharacter(src, payload)
    if not id then return false, err end
    if not Utils.IsValidMetadataKey(payload.key, Config.Metadata.MaxKeyLength) then return false, Errors.InvalidInput end
    local value = nil
    if type(payload.value) == 'string' and payload.value ~= '' then
        if #payload.value > Config.Metadata.MaxEncodedBytes then return false, Errors.InvalidInput end
        local ok, decoded = pcall(json.decode, payload.value)
        if not ok then return false, Errors.InvalidInput end
        value = decoded
    end
    return UnitLink.Metadata.Set(id, payload.key, value, src)
end, true)

adminCallback('addGroup', NODES.permissions, function(src, payload)
    local id, err = guardCharacter(src, payload)
    if not id then return false, err end
    local ok, gerr = Admin.CanAssignGroup(src, payload.group)
    if not ok then return false, gerr end
    return Permissions.AssignGroup(id, payload.group, src)
end, true)

adminCallback('removeGroup', NODES.permissions, function(src, payload)
    local id, err = guardCharacter(src, payload)
    if not id then return false, err end
    if Groups.Exists(payload.group) then
        local ok, gerr = Admin.CanAssignGroup(src, payload.group)
        if not ok then return false, gerr end
    elseif not Admin.IsSuper(src) then
        -- Removing a stale (deleted) group name is harmless but keep it to super admins.
        return false, Errors.UnknownGroup
    end
    return Permissions.RemoveGroup(id, payload.group, src)
end, true)

adminCallback('setOverride', NODES.permissions, function(src, payload)
    local id, err = guardCharacter(src, payload)
    if not id then return false, err end
    local node = type(payload.node) == 'string' and Utils.Trim(payload.node) or nil
    if not Utils.IsValidPermissionNode(node) or type(payload.allow) ~= 'boolean' then return false, Errors.InvalidInput end
    local ok, nerr = Admin.CanGrantNode(src, node)
    if not ok then return false, nerr end
    return Permissions.SetOverride(id, node, payload.allow, src)
end, true)

adminCallback('clearOverride', NODES.permissions, function(src, payload)
    local id, err = guardCharacter(src, payload)
    if not id then return false, err end
    local node = type(payload.node) == 'string' and payload.node or nil
    if not Utils.IsValidPermissionNode(node) then return false, Errors.InvalidInput end
    local ok, nerr = Admin.CanGrantNode(src, node)
    if not ok then return false, nerr end
    return Permissions.ClearOverride(id, node, src)
end, true)

local function afterGroupChange(action, src, name, details)
    Permissions.RebuildAll()
    UnitLink.Log.Audit(action, src, nil, details or { group = name })
    TriggerEvent(UnitLink.ServerEvents.GroupsChanged, name, action)
end

local function groupPayload(payload)
    local function strList(v)
        local out = {}
        if type(v) ~= 'table' then return out end
        for _, s in ipairs(v) do
            if type(s) == 'string' then out[#out + 1] = Utils.Trim(s) end
        end
        return out
    end
    return {
        name = type(payload.name) == 'string' and Utils.Trim(payload.name) or '',
        label = payload.label,
        description = payload.description,
        priority = payload.priority,
        inherits = strList(payload.inherits),
        permissions = strList(payload.permissions),
    }
end

adminCallback('createGroup', NODES.groups, function(src, payload)
    local raw = groupPayload(payload)
    local ok, err = Admin.CanWriteGroup(src, raw.name, raw)
    if not ok then return false, err end
    local created, result, detail = Groups.Create(raw)
    if not created then return false, result .. (detail and (':' .. tostring(detail)) or '') end
    afterGroupChange(UnitLink.AuditActions.GroupCreate, src, raw.name, Groups.Public(result))
    return true, Groups.Public(result)
end, true)

adminCallback('updateGroup', NODES.groups, function(src, payload)
    local raw = groupPayload(payload)
    if not Groups.Exists(raw.name) then return false, Errors.UnknownGroup end
    local ok, err = Admin.CanWriteGroup(src, raw.name, raw)
    if not ok then return false, err end
    local before = Groups.Public(Groups.Get(raw.name))
    local updated, result, detail = Groups.Update(raw.name, raw)
    if not updated then return false, result .. (detail and (':' .. tostring(detail)) or '') end
    afterGroupChange(UnitLink.AuditActions.GroupUpdate, src, raw.name, { group = raw.name, before = before, after = Groups.Public(result) })
    return true, Groups.Public(result)
end, true)

adminCallback('deleteGroup', NODES.groups, function(src, payload)
    local name = type(payload.name) == 'string' and payload.name or ''
    local def = Groups.Get(name)
    if not def then return false, Errors.UnknownGroup end
    if not Admin.IsSuper(src) and Config.Security.EnforcePriorityHierarchy and def.priority >= Admin.ActorPriority(src) then
        return false, Errors.Hierarchy
    end
    local reassign = type(payload.reassignTo) == 'string' and payload.reassignTo ~= '' and payload.reassignTo or nil
    if reassign then
        local ok, err = Admin.CanAssignGroup(src, reassign)
        if not ok then return false, err end
    end
    -- Characters who had the group need their caches rebuilt from the database.
    local affected = UnitLink.DB.query('SELECT character_id FROM unitlink_character_groups WHERE group_name = ?', { name }) or {}
    local deleted, result, detail = Groups.Delete(name, reassign)
    if not deleted then return false, result .. (detail and (':' .. tostring(detail)) or '') end
    for _, row in ipairs(affected) do
        Permissions.RefreshCharacter(tonumber(row.character_id))
    end
    afterGroupChange(UnitLink.AuditActions.GroupDelete, src, name, { group = name, reassignedTo = reassign, characters = result })
    return true, { moved = result }
end, true)
