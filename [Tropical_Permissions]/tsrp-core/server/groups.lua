-- TSRP Core: permission groups, inheritance and validation.
--
-- Inheritance: group A "inherits" group B when A receives every permission of B
-- (and, recursively, of everything B inherits). Senior groups inherit junior ones:
--   owner -> management -> admin -> moderator
--   leo_command -> leo_supervisor -> leo
--
-- The pure functions at the top (FindCycle, ValidateDefinitions, Expand) take a
-- definitions table so they can be tested without a database.

TSRP = TSRP or {}
local Groups = {}
TSRP.Groups = Groups

Groups.defs = {} -- [name] = definition (see normalize)

local Utils = TSRP.Utils

local function maxDepth()
    return (Config.Security and Config.Security.MaxInheritanceDepth) or 16
end

---------------------------------------------------------------------------
-- Pure helpers
---------------------------------------------------------------------------

-- Returns an array describing the first inheritance cycle found, or nil.
function Groups.FindCycle(defs)
    local WHITE, GREY, BLACK = 0, 1, 2
    local color, stack = {}, {}

    local function visit(name)
        color[name] = GREY
        stack[#stack + 1] = name
        local def = defs[name]
        if def then
            for _, parent in ipairs(def.inherits or {}) do
                local c = color[parent] or WHITE
                if c == GREY then
                    local cycle, started = {}, false
                    for _, n in ipairs(stack) do
                        if n == parent then started = true end
                        if started then cycle[#cycle + 1] = n end
                    end
                    cycle[#cycle + 1] = parent
                    return cycle
                elseif c == WHITE and defs[parent] then
                    local found = visit(parent)
                    if found then return found end
                end
            end
        end
        stack[#stack] = nil
        color[name] = BLACK
        return nil
    end

    for _, name in ipairs(Utils.SortedKeys(defs)) do
        if (color[name] or WHITE) == WHITE then
            local found = visit(name)
            if found then return found end
        end
    end
    return nil
end

-- Validates a whole definitions table. Returns true or false, errorCode, detail.
function Groups.ValidateDefinitions(defs)
    for name, def in pairs(defs) do
        if not Utils.IsValidGroupName(name) then
            return false, TSRP.Errors.InvalidInput, 'invalid group name: ' .. tostring(name)
        end
        local seen = {}
        for _, parent in ipairs(def.inherits or {}) do
            if parent == name then
                return false, TSRP.Errors.Cycle, name .. ' cannot inherit itself'
            end
            if seen[parent] then
                return false, TSRP.Errors.Duplicate, name .. ' inherits ' .. parent .. ' twice'
            end
            seen[parent] = true
            if not defs[parent] then
                return false, TSRP.Errors.UnknownGroup, name .. ' inherits unknown group ' .. tostring(parent)
            end
        end
        for _, node in ipairs(def.permissions or {}) do
            if not Utils.IsValidPermissionNode(node) then
                return false, TSRP.Errors.InvalidInput, name .. ' has invalid permission node ' .. tostring(node)
            end
        end
    end
    local cycle = Groups.FindCycle(defs)
    if cycle then
        return false, TSRP.Errors.Cycle, table.concat(cycle, ' -> ')
    end
    return true
end

-- Expand directly assigned groups into every effective group.
-- Returns an ordered array of { name, via, depth } (via = the directly assigned group
-- it came through; depth 0 = assigned directly) and an array of unknown names.
function Groups.Expand(defs, directNames, limit)
    limit = limit or maxDepth()
    local result, seen, missing = {}, {}, {}

    local function walk(name, via, depth)
        if seen[name] then return end
        local def = defs[name]
        if not def then
            missing[#missing + 1] = name
            return
        end
        if depth > limit then return end
        seen[name] = true
        result[#result + 1] = { name = name, via = via, depth = depth }
        for _, parent in ipairs(def.inherits or {}) do
            walk(parent, via, depth + 1)
        end
    end

    -- Direct assignments first (depth 0) so they are reported as the source when a
    -- group is both assigned directly and inherited.
    local sortedDirect = {}
    for _, n in ipairs(directNames or {}) do sortedDirect[#sortedDirect + 1] = n end
    table.sort(sortedDirect, function(a, b)
        local pa = defs[a] and defs[a].priority or -1
        local pb = defs[b] and defs[b].priority or -1
        if pa ~= pb then return pa > pb end
        return a < b
    end)
    for _, name in ipairs(sortedDirect) do
        if defs[name] and not seen[name] then
            seen[name] = true
            result[#result + 1] = { name = name, via = name, depth = 0 }
        elseif not defs[name] then
            missing[#missing + 1] = name
        end
    end
    for _, name in ipairs(sortedDirect) do
        local def = defs[name]
        if def then
            for _, parent in ipairs(def.inherits or {}) do
                walk(parent, name, 1)
            end
        end
    end
    return result, missing
end

-- Normalises a definition coming from config, the database or the dashboard.
function Groups.Normalize(name, raw)
    raw = raw or {}
    local inherits, perms, seenP = {}, {}, {}
    for _, parent in ipairs(raw.inherits or {}) do
        if type(parent) == 'string' then inherits[#inherits + 1] = parent end
    end
    for _, node in ipairs(raw.permissions or {}) do
        if type(node) == 'string' and not seenP[node] then
            seenP[node] = true
            perms[#perms + 1] = node
        end
    end
    table.sort(perms)
    local permSet = {}
    for _, node in ipairs(perms) do permSet[node] = true end
    return {
        name = name,
        label = type(raw.label) == 'string' and raw.label or name,
        description = type(raw.description) == 'string' and raw.description or '',
        priority = Utils.ToInteger(raw.priority) or 0,
        inherits = inherits,
        permissions = perms,
        permSet = permSet,
        metadata = type(raw.metadata) == 'table' and raw.metadata or {},
        system = raw.system == true,
    }
end

---------------------------------------------------------------------------
-- Cache access
---------------------------------------------------------------------------

function Groups.Get(name)
    return Groups.defs[name]
end

function Groups.Exists(name)
    return Groups.defs[name] ~= nil
end

function Groups.List()
    local list = {}
    for _, name in ipairs(Utils.SortedKeys(Groups.defs)) do
        list[#list + 1] = Groups.defs[name]
    end
    table.sort(list, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        return a.name < b.name
    end)
    return list
end

-- Public (JSON-safe) copy of a definition.
function Groups.Public(def)
    if not def then return nil end
    return {
        name = def.name,
        label = def.label,
        description = def.description,
        priority = def.priority,
        inherits = Utils.DeepCopy(def.inherits),
        permissions = Utils.DeepCopy(def.permissions),
        metadata = Utils.DeepCopy(def.metadata),
        system = def.system,
    }
end

-- Highest priority among a set of direct groups (including inherited ones).
function Groups.MaxPriority(directNames)
    local best = -1
    local expanded = Groups.Expand(Groups.defs, directNames)
    for _, entry in ipairs(expanded) do
        local def = Groups.defs[entry.name]
        if def and def.priority > best then best = def.priority end
    end
    return best
end

---------------------------------------------------------------------------
-- Database
---------------------------------------------------------------------------

function Groups.LoadAll()
    local rows = TSRP.DB.query('SELECT name, label, description, priority, metadata, is_system FROM tsrp_groups', {})
    local inh = TSRP.DB.query('SELECT group_name, inherits_name FROM tsrp_group_inheritance', {})
    local perms = TSRP.DB.query('SELECT group_name, permission FROM tsrp_group_permissions', {})
    if not rows or not inh or not perms then return false end

    local raw = {}
    for _, row in ipairs(rows) do
        raw[row.name] = {
            label = row.label,
            description = row.description,
            priority = row.priority,
            metadata = Utils.JsonDecode(row.metadata, {}),
            system = row.is_system == 1 or row.is_system == true,
            inherits = {},
            permissions = {},
        }
    end
    for _, row in ipairs(inh) do
        if raw[row.group_name] then table.insert(raw[row.group_name].inherits, row.inherits_name) end
    end
    for _, row in ipairs(perms) do
        if raw[row.group_name] then table.insert(raw[row.group_name].permissions, row.permission) end
    end

    local defs = {}
    for name, r in pairs(raw) do
        table.sort(r.inherits)
        defs[name] = Groups.Normalize(name, r)
    end

    local ok, _, detail = Groups.ValidateDefinitions(defs)
    if not ok then
        -- The database should never contain a cycle (we validate before writing), but if
        -- someone edited it by hand, keep running: Expand() is cycle-safe.
        TSRP.Log.Error('Group data problem: %s. Fix it in the admin dashboard.', tostring(detail))
    end

    Groups.defs = defs
    return true
end

local function writeQueries(def, isNew)
    local q = {}
    if isNew then
        q[#q + 1] = {
            query = 'INSERT INTO tsrp_groups (name, label, description, priority, metadata, is_system) VALUES (?, ?, ?, ?, ?, ?)',
            values = { def.name, def.label, def.description, def.priority, Utils.JsonEncode(def.metadata) or '{}', def.system and 1 or 0 },
        }
    else
        q[#q + 1] = {
            query = 'UPDATE tsrp_groups SET label = ?, description = ?, priority = ?, metadata = ? WHERE name = ?',
            values = { def.label, def.description, def.priority, Utils.JsonEncode(def.metadata) or '{}', def.name },
        }
        q[#q + 1] = { query = 'DELETE FROM tsrp_group_inheritance WHERE group_name = ?', values = { def.name } }
        q[#q + 1] = { query = 'DELETE FROM tsrp_group_permissions WHERE group_name = ?', values = { def.name } }
    end
    for _, parent in ipairs(def.inherits) do
        q[#q + 1] = { query = 'INSERT INTO tsrp_group_inheritance (group_name, inherits_name) VALUES (?, ?)', values = { def.name, parent } }
    end
    for _, node in ipairs(def.permissions) do
        q[#q + 1] = { query = 'INSERT INTO tsrp_group_permissions (group_name, permission) VALUES (?, ?)', values = { def.name, node } }
    end
    return q
end

-- Seed the config groups into the database (see Config.GroupSeedMode).
function Groups.Seed()
    local configDefs = {}
    for name, raw in pairs(Config.Groups or {}) do
        configDefs[name] = Groups.Normalize(name, raw)
    end
    local ok, _, detail = Groups.ValidateDefinitions(configDefs)
    if not ok then
        TSRP.Log.Error('config/groups.lua is invalid: %s. Groups were not seeded.', tostring(detail))
        return false
    end

    local force = Config.GroupSeedMode == 'force'
    local queries = {}

    -- Insert group rows first (inheritance rows reference other groups).
    local toInsert = {}
    for _, name in ipairs(Utils.SortedKeys(configDefs)) do
        local def = configDefs[name]
        if not Groups.defs[name] then
            toInsert[#toInsert + 1] = def
            queries[#queries + 1] = {
                query = 'INSERT INTO tsrp_groups (name, label, description, priority, metadata, is_system) VALUES (?, ?, ?, ?, ?, ?)',
                values = { def.name, def.label, def.description, def.priority, Utils.JsonEncode(def.metadata) or '{}', def.system and 1 or 0 },
            }
        elseif force then
            queries[#queries + 1] = {
                query = 'UPDATE tsrp_groups SET label = ?, description = ?, priority = ?, is_system = ? WHERE name = ?',
                values = { def.label, def.description, def.priority, def.system and 1 or 0, def.name },
            }
            queries[#queries + 1] = { query = 'DELETE FROM tsrp_group_inheritance WHERE group_name = ?', values = { name } }
            queries[#queries + 1] = { query = 'DELETE FROM tsrp_group_permissions WHERE group_name = ?', values = { name } }
            toInsert[#toInsert + 1] = def
        end
    end
    for _, def in ipairs(toInsert) do
        for _, parent in ipairs(def.inherits) do
            queries[#queries + 1] = { query = 'INSERT IGNORE INTO tsrp_group_inheritance (group_name, inherits_name) VALUES (?, ?)', values = { def.name, parent } }
        end
        for _, node in ipairs(def.permissions) do
            queries[#queries + 1] = { query = 'INSERT IGNORE INTO tsrp_group_permissions (group_name, permission) VALUES (?, ?)', values = { def.name, node } }
        end
    end

    if #queries == 0 then return true end

    -- A group seeded now may inherit a group that only exists in the database (or vice
    -- versa); validate the merged result before writing anything.
    local merged = Utils.DeepCopy(Groups.defs)
    for _, def in ipairs(toInsert) do merged[def.name] = def end
    local mok, _, mdetail = Groups.ValidateDefinitions(merged)
    if not mok then
        TSRP.Log.Error('Seeding groups would break group data: %s. Nothing was seeded.', tostring(mdetail))
        return false
    end

    if not TSRP.DB.transaction(queries) then
        TSRP.Log.Error('Seeding groups failed.')
        return false
    end
    TSRP.Log.Info('Seeded %d group(s) from config.', #toInsert)
    return Groups.LoadAll()
end

-- Validate a proposed definition against the current cache.
-- Returns normalized def or nil, errorCode, detail.
function Groups.ValidateProposal(name, raw, isNew)
    if not Utils.IsValidGroupName(name) then
        return nil, TSRP.Errors.InvalidInput, 'name'
    end
    if isNew and Groups.defs[name] then
        return nil, TSRP.Errors.GroupExists
    end
    if not isNew and not Groups.defs[name] then
        return nil, TSRP.Errors.UnknownGroup
    end
    if type(raw.label) ~= 'string' or #Utils.Trim(raw.label) < 1 or #raw.label > 64 then
        return nil, TSRP.Errors.InvalidInput, 'label'
    end
    if raw.description ~= nil and (type(raw.description) ~= 'string' or #raw.description > 255) then
        return nil, TSRP.Errors.InvalidInput, 'description'
    end
    local priority = Utils.ToInteger(raw.priority or 0)
    if not priority or priority < 0 or priority > 1000 then
        return nil, TSRP.Errors.InvalidInput, 'priority'
    end
    if type(raw.inherits or {}) ~= 'table' or #(raw.inherits or {}) > 32 then
        return nil, TSRP.Errors.InvalidInput, 'inherits'
    end
    if type(raw.permissions or {}) ~= 'table' or #(raw.permissions or {}) > 500 then
        return nil, TSRP.Errors.InvalidInput, 'permissions'
    end
    for _, node in ipairs(raw.permissions or {}) do
        if not Utils.IsValidPermissionNode(node) then
            return nil, TSRP.Errors.InvalidInput, 'permission:' .. tostring(node)
        end
    end

    local existing = Groups.defs[name]
    local def = Groups.Normalize(name, {
        label = Utils.Trim(raw.label),
        description = raw.description and Utils.Trim(raw.description) or '',
        priority = priority,
        inherits = raw.inherits or {},
        permissions = raw.permissions or {},
        metadata = existing and existing.metadata or {},
        system = existing and existing.system or false,
    })

    local proposed = {}
    for n, d in pairs(Groups.defs) do proposed[n] = d end
    proposed[name] = def
    local ok, err, detail = Groups.ValidateDefinitions(proposed)
    if not ok then return nil, err, detail end
    return def
end

function Groups.Create(raw)
    local name = type(raw.name) == 'string' and raw.name or ''
    local def, err, detail = Groups.ValidateProposal(name, raw, true)
    if not def then return false, err, detail end
    if not TSRP.DB.transaction(writeQueries(def, true)) then return false, TSRP.Errors.Database end
    Groups.defs[name] = def
    return true, def
end

function Groups.Update(name, raw)
    local def, err, detail = Groups.ValidateProposal(name, raw, false)
    if not def then return false, err, detail end
    if not TSRP.DB.transaction(writeQueries(def, false)) then return false, TSRP.Errors.Database end
    Groups.defs[name] = def
    return true, def
end

-- Delete a group. If characters hold it, reassignTo must name another group; they are
-- moved there in the same transaction. Groups inherited by others cannot be deleted.
function Groups.Delete(name, reassignTo)
    local def = Groups.defs[name]
    if not def then return false, TSRP.Errors.UnknownGroup end
    if def.system then return false, TSRP.Errors.SystemGroup end

    for otherName, other in pairs(Groups.defs) do
        if otherName ~= name and Utils.Contains(other.inherits, name) then
            return false, TSRP.Errors.GroupInherited, otherName
        end
    end

    local assigned = TSRP.DB.scalar('SELECT COUNT(*) FROM tsrp_character_groups WHERE group_name = ?', { name })
    if assigned == nil then return false, TSRP.Errors.Database end
    assigned = tonumber(assigned) or 0

    local queries = {}
    if assigned > 0 then
        if type(reassignTo) ~= 'string' or reassignTo == '' then
            return false, TSRP.Errors.GroupInUse, assigned
        end
        if reassignTo == name or not Groups.defs[reassignTo] then
            return false, TSRP.Errors.UnknownGroup
        end
        queries[#queries + 1] = {
            query = 'INSERT IGNORE INTO tsrp_character_groups (character_id, group_name, assigned_by) ' ..
                'SELECT character_id, ?, ? FROM tsrp_character_groups WHERE group_name = ?',
            values = { reassignTo, 'reassign:' .. name, name },
        }
        queries[#queries + 1] = { query = 'DELETE FROM tsrp_character_groups WHERE group_name = ?', values = { name } }
    end
    queries[#queries + 1] = { query = 'DELETE FROM tsrp_groups WHERE name = ?', values = { name } }

    if not TSRP.DB.transaction(queries) then return false, TSRP.Errors.Database end
    Groups.defs[name] = nil
    return true, assigned
end
