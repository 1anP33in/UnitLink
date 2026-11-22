-- TSRP Core logic tests. Runs the real server Lua files against FiveM stubs and an
-- in-memory fake of the oxmysql adapter (TSRP.DB). MySQL itself is NOT exercised.

local ROOT = TSRP_ROOT
local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then passed = passed + 1
    else failed = failed + 1; print('FAIL: ' .. name .. (detail and (' -> ' .. tostring(detail)) or '')) end
end

---------------------------------------------------------------- JSON (test only)
local json = {}
local function enc(v)
    local t = type(v)
    if t == 'nil' then return 'null' end
    if t == 'boolean' then return tostring(v) end
    if t == 'number' then return (math.type(v) == 'integer') and tostring(v) or string.format('%.14g', v) end
    if t == 'string' then return '"' .. v:gsub('[%c"\\]', function(c) return string.format('\\u%04x', c:byte()) end) .. '"' end
    if #v > 0 or next(v) == nil then
        if next(v) == nil then return '{}' end
        local out = {}
        for i = 1, #v do out[i] = enc(v[i]) end
        return '[' .. table.concat(out, ',') .. ']'
    end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = enc(k) .. ':' .. enc(v[k] ~= nil and v[k] or v[tonumber(k)]) end
    return '{' .. table.concat(out, ',') .. '}'
end
json.encode = enc
function json.decode(s)
    local pos = 1
    local function ws() pos = s:find('[^%s]', pos) or #s + 1 end
    local val
    local function str()
        local out = {}
        pos = pos + 1
        while true do
            local c = s:sub(pos, pos)
            if c == '"' then pos = pos + 1 break end
            if c == '\\' then
                local n = s:sub(pos + 1, pos + 1)
                if n == 'u' then out[#out + 1] = utf8.char(tonumber(s:sub(pos + 2, pos + 5), 16)); pos = pos + 6
                else out[#out + 1] = ({ n = '\n', t = '\t', r = '\r', b = '\b', f = '\f' })[n] or n; pos = pos + 2 end
            else out[#out + 1] = c; pos = pos + 1 end
            if pos > #s then error('unterminated string') end
        end
        return table.concat(out)
    end
    function val()
        ws()
        local c = s:sub(pos, pos)
        if c == '{' then
            local obj = {}
            pos = pos + 1; ws()
            if s:sub(pos, pos) == '}' then pos = pos + 1 return obj end
            while true do
                ws(); local k = str(); ws()
                assert(s:sub(pos, pos) == ':', 'expected :'); pos = pos + 1
                obj[k] = val(); ws()
                local d = s:sub(pos, pos); pos = pos + 1
                if d == '}' then return obj end
                assert(d == ',', 'expected ,')
            end
        elseif c == '[' then
            local arr = {}
            pos = pos + 1; ws()
            if s:sub(pos, pos) == ']' then pos = pos + 1 return arr end
            while true do
                arr[#arr + 1] = val(); ws()
                local d = s:sub(pos, pos); pos = pos + 1
                if d == ']' then return arr end
                assert(d == ',', 'expected ,')
            end
        elseif c == '"' then return str()
        elseif s:sub(pos, pos + 3) == 'true' then pos = pos + 4 return true
        elseif s:sub(pos, pos + 4) == 'false' then pos = pos + 5 return false
        elseif s:sub(pos, pos + 3) == 'null' then pos = pos + 4 return nil
        else
            local num = s:match('^-?%d+%.?%d*[eE]?[-+]?%d*', pos)
            assert(num and #num > 0, 'bad json at ' .. pos)
            pos = pos + #num
            return math.tointeger(tonumber(num)) or tonumber(num)
        end
    end
    local r = val()
    return r
end
_G.json = json

---------------------------------------------------------------- FiveM stubs
local clock = 100000
local netHandlers, clientEvents, localEvents, exportsTbl, commands = {}, {}, {}, {}, {}
function GetCurrentResourceName() return 'tsrp-core' end
function GetInvokingResource() return 'tsrp-test' end
function vector3(x, y, z) return { x = x, y = y, z = z } end
function vector4(x, y, z, w) return { x = x, y = y, z = z, w = w } end
function GetGameTimer() return clock end
function Wait() end
function CreateThread() end
function SetTimeout() end
function RegisterNetEvent(name, fn) netHandlers[name] = fn end
function AddEventHandler(name, fn) localEvents[name] = localEvents[name] or {}; table.insert(localEvents[name], fn) end
function TriggerEvent(name, ...) localEvents.__fired = localEvents.__fired or {}; table.insert(localEvents.__fired, { name, ... }) end
function TriggerClientEvent(name, src, ...) table.insert(clientEvents, { name = name, src = src, args = { ... } }) end
function exports(name, fn) exportsTbl[name] = fn end
function RegisterCommand(name, fn) commands[name] = fn end
function GetConvar(_, d) return d end
function GetConvarInt(_, d) return d end
function LoadResourceFile(_, path)
    local f = io.open(ROOT .. '/' .. path, 'r'); if not f then return nil end
    local s = f:read('a'); f:close(); return s
end
function GetResourceState() return 'started' end
local connected, licenses = {}, {}
function GetPlayerIdentifierByType(src, t) return t == 'license' and licenses[tonumber(src)] or nil end
function GetPlayerName(src) return connected[tonumber(src)] and ('player' .. src) or nil end
function IsPlayerAceAllowed() return false end
function SetPlayerRoutingBucket() end
function SetRoutingBucketPopulationEnabled() end
function GetPlayerPed() return 0 end
function GetPlayerPing() return 10 end
function DoesEntityExist() return false end
function GetPlayers() return {} end
function DropPlayer() end
function Player() return { state = { set = function() end } } end
function PerformHttpRequest() end

---------------------------------------------------------------- Fake DB
local db
local function resetDb()
    db = { players = {}, nextPlayer = 1, chars = {}, nextChar = 1000, groups = {}, overrides = {}, appearance = {}, fail = false, lastInsert = nil }
end
resetDb()

local function charRow(c)
    return { id = c.id, identifier = c.identifier, slot = c.slot, firstname = c.firstname, lastname = c.lastname,
        dateofbirth = c.dateofbirth, gender = c.gender, nationality = c.nationality, height = c.height,
        metadata = c.metadata, last_position = c.last_position, created_at = 1, updated_at = 1,
        has_appearance = db.appearance[c.id] and 1 or 0 }
end

local function has(sql, needle) return sql:find(needle, 1, true) ~= nil end

local Fake = {}
function Fake.query(sql, p)
    if db.fail then return nil end
    if has(sql, 'SELECT slot FROM tsrp_characters WHERE identifier = ?') then
        local rows = {}
        for _, c in pairs(db.chars) do if c.identifier == p[1] then rows[#rows + 1] = { slot = c.slot } end end
        return rows
    elseif has(sql, 'LEFT JOIN tsrp_character_appearance') then
        local rows = {}
        for _, c in pairs(db.chars) do if c.identifier == p[1] then rows[#rows + 1] = charRow(c) end end
        table.sort(rows, function(a, b) return a.slot < b.slot end)
        return rows
    elseif has(sql, 'INNER JOIN tsrp_characters c ON c.id = g.character_id') then
        local rows = {}
        for id, set in pairs(db.groups) do
            if db.chars[id] and db.chars[id].identifier == p[1] then
                for g in pairs(set) do rows[#rows + 1] = { character_id = id, group_name = g } end
            end
        end
        return rows
    elseif has(sql, 'SELECT group_name FROM tsrp_character_groups WHERE character_id = ?') then
        local rows = {}
        for g in pairs(db.groups[p[1]] or {}) do rows[#rows + 1] = { group_name = g } end
        return rows
    elseif has(sql, 'SELECT permission, allow FROM tsrp_character_permission_overrides') then
        local rows = {}
        for n, a in pairs(db.overrides[p[1]] or {}) do rows[#rows + 1] = { permission = n, allow = a and 1 or 0 } end
        return rows
    elseif has(sql, 'SELECT character_id FROM tsrp_character_groups WHERE group_name = ?') then
        return {}
    end
    error('fake query not handled: ' .. sql)
end
function Fake.single(sql, p)
    if db.fail then return nil end
    if has(sql, 'c.id = ? AND c.identifier = ?') then
        local c = db.chars[p[1]]
        return (c and c.identifier == p[2]) and charRow(c) or false
    elseif has(sql, 'c.identifier = ? AND c.slot = ?') then
        for _, c in pairs(db.chars) do if c.identifier == p[1] and c.slot == p[2] then return charRow(c) end end
        return false
    elseif has(sql, 'WHERE c.id = ?') then
        local c = db.chars[p[1]]; return c and charRow(c) or false
    elseif has(sql, 'SELECT model, appearance FROM tsrp_character_appearance') then
        local a = db.appearance[p[1]]; return a and { model = a.model, appearance = a.appearance } or false
    end
    error('fake single not handled: ' .. sql)
end
function Fake.scalar(sql, p)
    if db.fail then return nil end
    if has(sql, 'COUNT(*) FROM tsrp_characters WHERE firstname = ? AND lastname = ?') then
        local n = 0
        for id, c in pairs(db.chars) do
            if c.firstname:lower() == p[1]:lower() and c.lastname:lower() == p[2]:lower() and id ~= p[3] then n = n + 1 end
        end
        return n
    elseif has(sql, 'SELECT id FROM tsrp_characters WHERE id = ?') then
        return db.chars[p[1]] and p[1] or false
    elseif has(sql, 'SELECT identifier FROM tsrp_characters WHERE id = ?') then
        return db.chars[p[1]] and db.chars[p[1]].identifier or false
    elseif has(sql, 'SELECT metadata FROM tsrp_characters WHERE id = ?') then
        return db.chars[p[1]] and db.chars[p[1]].metadata or false
    end
    error('fake scalar not handled: ' .. sql)
end
function Fake.insert(sql, p)
    if db.fail then return nil end
    if has(sql, 'INSERT INTO tsrp_players') then
        if not db.players[p[1]] then db.players[p[1]] = db.nextPlayer; db.nextPlayer = db.nextPlayer + 1 end
        return db.players[p[1]]
    end
    error('fake insert not handled: ' .. sql)
end
function Fake.update(sql, p)
    if db.fail then return nil end
    if has(sql, 'DELETE FROM tsrp_characters WHERE id = ? AND identifier = ?') then
        local c = db.chars[p[1]]
        if c and c.identifier == p[2] then
            db.chars[p[1]] = nil; db.groups[p[1]] = nil; db.overrides[p[1]] = nil; db.appearance[p[1]] = nil
            return 1
        end
        return 0
    elseif has(sql, 'INSERT IGNORE INTO tsrp_character_groups') then
        db.groups[p[1]] = db.groups[p[1]] or {}
        if db.groups[p[1]][p[2]] then return 0 end
        db.groups[p[1]][p[2]] = true; return 1
    elseif has(sql, 'DELETE FROM tsrp_character_groups WHERE character_id = ? AND group_name = ?') then
        if db.groups[p[1]] and db.groups[p[1]][p[2]] then db.groups[p[1]][p[2]] = nil return 1 end
        return 0
    elseif has(sql, 'INSERT INTO tsrp_character_permission_overrides') then
        db.overrides[p[1]] = db.overrides[p[1]] or {}
        db.overrides[p[1]][p[2]] = p[3] == 1; return 1
    elseif has(sql, 'DELETE FROM tsrp_character_permission_overrides') then
        if db.overrides[p[1]] and db.overrides[p[1]][p[2]] ~= nil then db.overrides[p[1]][p[2]] = nil return 1 end
        return 0
    elseif has(sql, 'INSERT INTO tsrp_character_appearance') then
        db.appearance[p[1]] = { model = p[2], appearance = p[3] }; return 1
    elseif has(sql, 'UPDATE tsrp_characters SET last_position') then
        if db.chars[p[2]] then db.chars[p[2]].last_position = p[1] end; return 1
    elseif has(sql, 'UPDATE tsrp_characters SET metadata') then
        if db.chars[p[2]] then db.chars[p[2]].metadata = p[1]; return 1 end; return 0
    end
    error('fake update not handled: ' .. sql)
end
function Fake.transaction(queries)
    if db.fail then return false end
    -- Only character creation uses a transaction in these tests.
    local newId
    for _, q in ipairs(queries) do
        if has(q.query, 'INSERT INTO tsrp_characters') then
            local v = q.values
            for _, c in pairs(db.chars) do if c.identifier == v[1] and c.slot == v[2] then return false end end
            newId = db.nextChar; db.nextChar = db.nextChar + 1
            db.chars[newId] = { id = newId, identifier = v[1], slot = v[2], firstname = v[3], lastname = v[4], dateofbirth = v[5],
                gender = v[6], nationality = v[7], height = v[8], metadata = v[9] }
        elseif has(q.query, 'LAST_INSERT_ID()') then
            db.groups[newId] = db.groups[newId] or {}
            db.groups[newId][q.values[1]] = true
        else
            error('fake transaction not handled: ' .. q.query)
        end
    end
    return true
end
function Fake.insertAsync() end
function Fake.updateAsync() end
function Fake.available() return true end
function Fake.onReady() end

---------------------------------------------------------------- Load resource
local function load(path)
    local chunk, err = loadfile(ROOT .. '/' .. path)
    if not chunk then error(err) end
    chunk()
end

for _, f in ipairs({
    'config/config.lua', 'config/characters.lua', 'shared/constants.lua', 'shared/enums.lua',
    'shared/utils.lua', 'shared/locales.lua', 'config/database.lua', 'config/bootstrap.lua',
    'config/permissions.lua', 'config/groups.lua', 'config/spawn.lua', 'config/logging.lua', 'config/discord.lua',
    'integrations/oxmysql.lua', 'integrations/webhook.lua', 'integrations/discord.lua',
    'server/logging.lua', 'server/database.lua', 'server/ratelimit.lua', 'server/callbacks.lua',
    'server/players.lua', 'server/groups.lua', 'server/permissions.lua', 'server/identity.lua',
    'server/characters.lua', 'server/metadata.lua', 'server/appearance.lua', 'server/persistence.lua',
    'server/spawn.lua', 'server/administration.lua', 'server/commands.lua', 'server/api.lua', 'server/main.lua',
}) do
    local ok, err = pcall(load, f)
    check('load ' .. f, ok, err)
end

TSRP.DB = Fake
Config.Logging.Console = false
local Utils, Groups, Perms, Errors = TSRP.Utils, TSRP.Groups, TSRP.Permissions, TSRP.Errors

---------------------------------------------------------------- Utils
check('node valid simple', Utils.IsValidPermissionNode('tsrp.police.duty'))
check('node valid wildcard', Utils.IsValidPermissionNode('tsrp.police.*'))
check('node valid star', Utils.IsValidPermissionNode('*'))
check('node invalid upper', not Utils.IsValidPermissionNode('tsrp.Police'))
check('node invalid mid wildcard', not Utils.IsValidPermissionNode('tsrp.*.duty'))
check('node invalid empty seg', not Utils.IsValidPermissionNode('tsrp..duty'))
check('node invalid lone prefix star', not Utils.IsValidPermissionNode('*.x'))
check('node invalid sql', not Utils.IsValidPermissionNode("tsrp'; DROP TABLE x;--"))
check('name ok', Utils.IsValidName("Mary-Jane", 2, 20))
check('name ok apostrophe', Utils.IsValidName("O'Neil", 2, 20))
check('name bad digits', not Utils.IsValidName("J0hn", 2, 20))
check('name bad double sep', not Utils.IsValidName("Ann--Marie", 2, 20))
check('name bad edge', not Utils.IsValidName("-Ann", 2, 20))
check('name too short', not Utils.IsValidName("A", 2, 20))
check('date leap ok', Utils.ParseDate('2000-02-29') == 2000)
check('date leap bad', Utils.ParseDate('2001-02-29') == nil)
check('date bad month', Utils.ParseDate('2001-13-01') == nil)
check('format name', Utils.FormatName("mary-jane o'neil") == "Mary-Jane O'Neil", Utils.FormatName("mary-jane o'neil"))

---------------------------------------------------------------- SQL file
local stmts = TSRP.Database.SplitStatements(LoadResourceFile('tsrp-core', 'sql/install.sql'))
check('install.sql has 9 statements', #stmts == 9, #stmts)
for _, s in ipairs(stmts) do check('statement is CREATE TABLE', s:find('^CREATE TABLE IF NOT EXISTS') ~= nil, s:sub(1, 40)) end

---------------------------------------------------------------- Groups / inheritance
local defs = {}
for name, raw in pairs(Config.Groups) do defs[name] = Groups.Normalize(name, raw) end
check('config groups valid', Groups.ValidateDefinitions(defs))
Groups.defs = defs

local cyc = Utils.DeepCopy(defs)
cyc.leo = Groups.Normalize('leo', { label = 'x', inherits = { 'leo_command' }, permissions = {} })
local okc, errc = Groups.ValidateDefinitions(cyc)
check('cycle rejected', not okc and errc == Errors.Cycle, errc)
check('FindCycle reports path', Groups.FindCycle(cyc) ~= nil)
local exp = Groups.Expand(cyc, { 'leo' })
check('Expand survives cycle', #exp == 3, #exp)

local unk = Utils.DeepCopy(defs)
unk.leo = Groups.Normalize('leo', { label = 'x', inherits = { 'ghost' } })
local oku, erru = Groups.ValidateDefinitions(unk)
check('unknown parent rejected', not oku and erru == Errors.UnknownGroup, erru)

local self = Utils.DeepCopy(defs)
self.leo = Groups.Normalize('leo', { label = 'x', inherits = { 'leo' } })
check('self inherit rejected', not Groups.ValidateDefinitions(self))

local dup = Utils.DeepCopy(defs)
dup.leo = Groups.Normalize('leo', { label = 'x', inherits = { 'civilian', 'civilian' } })
check('duplicate inherit rejected', not Groups.ValidateDefinitions(dup))

local prop, perr = Groups.ValidateProposal('leo', { label = 'LEO', priority = 30, inherits = { 'leo_command' }, permissions = {} }, false)
check('proposal cycle rejected', prop == nil and perr == Errors.Cycle, perr)
local prop2 = Groups.ValidateProposal('leo', { label = 'LEO', priority = 30, inherits = {}, permissions = { 'BAD NODE' } }, false)
check('proposal bad node rejected', prop2 == nil)
local prop3, e3 = Groups.ValidateProposal('admin', { label = 'x', priority = 1 }, true)
check('proposal duplicate group rejected', prop3 == nil and e3 == Errors.GroupExists, e3)

---------------------------------------------------------------- Resolution
local c = Perms.Candidates('a.b.c')
check('candidates', table.concat(c, ',') == 'a.b.c,a.b.*,a.*,*', table.concat(c, ','))
check('candidates wildcard', table.concat(Perms.Candidates('a.b.*'), ',') == 'a.b.*,a.*,*')

local cmd = Perms.Build(defs, { 'leo_command' }, {})
check('leo_command inherits leo duty', Perms.Resolve(cmd, 'tsrp.police.duty'))
check('leo_command wildcard covers new node', Perms.Resolve(cmd, 'tsrp.police.anything'))
check('leo_command no safr', not Perms.Resolve(cmd, 'tsrp.safr.duty'))
local leo = Perms.Build(defs, { 'leo' }, {})
check('leo has duty', Perms.Resolve(leo, 'tsrp.police.duty'))
check('leo lacks supervisor', not Perms.Resolve(leo, 'tsrp.police.supervisor'))
local _, r = Perms.Resolve(cmd, 'tsrp.police.duty')
check('reason shows inheritance', r.type == 'group' and (r.inherited == true or r.group == 'leo_command'), r.group)

local denied = Perms.Build(defs, { 'leo' }, { ['tsrp.police.duty'] = false })
check('explicit deny beats group', not Perms.Resolve(denied, 'tsrp.police.duty'))
local allowed = Perms.Build(defs, { 'civilian' }, { ['tsrp.police.supervisor'] = true })
check('explicit allow grants', Perms.Resolve(allowed, 'tsrp.police.supervisor'))

-- Departments (config/groups.lua Config.Departments)
for _, d in ipairs(Config.Departments) do
    for _, suffix in ipairs({ '', '_supervisor', '_command' }) do
        check('department group exists ' .. d.id .. suffix, defs[d.id .. suffix] ~= nil)
    end
    check('department node registered ' .. d.id, Config.PermissionNodes['tsrp.' .. d.id .. '.duty'] ~= nil)
end
local sasp = Perms.Build(defs, { 'sasp' }, {})
check('sasp has own duty', Perms.Resolve(sasp, 'tsrp.sasp.duty'))
check('sasp gets shared police duty', Perms.Resolve(sasp, 'tsrp.police.duty'))
check('sasp lacks supervisor', not Perms.Resolve(sasp, 'tsrp.sasp.supervisor') and not Perms.Resolve(sasp, 'tsrp.police.supervisor'))
check('sasp is not bcso', not Perms.Resolve(sasp, 'tsrp.bcso.duty'))
local saspSup = Perms.Build(defs, { 'sasp_supervisor' }, {})
check('sasp supervisor gets shared police supervisor', Perms.Resolve(saspSup, 'tsrp.police.supervisor') and Perms.Resolve(saspSup, 'tsrp.sasp.roster'))
local saspCmd = Perms.Build(defs, { 'sasp_command' }, {})
check('sasp command wildcard own dept', Perms.Resolve(saspCmd, 'tsrp.sasp.anything'))
check('sasp command not other dept', not Perms.Resolve(saspCmd, 'tsrp.lsp.supervisor'))
check('sasp command not all police', not Perms.Resolve(saspCmd, 'tsrp.police.anything'))
local safd = Perms.Build(defs, { 'safd' }, {})
check('safd gets shared safr duty', Perms.Resolve(safd, 'tsrp.safr.duty') and not Perms.Resolve(safd, 'tsrp.police.duty'))
local faa = Perms.Build(defs, { 'faa_command' }, {})
check('faa is neither police nor fire', Perms.Resolve(faa, 'tsrp.faa.duty') and not Perms.Resolve(faa, 'tsrp.police.duty') and not Perms.Resolve(faa, 'tsrp.safr.duty'))
local owner = Perms.Build(defs, { 'owner' }, { ['tsrp.admin.access'] = false })
check('owner star grants anything', Perms.Resolve(owner, 'some.other.node'))
check('deny beats owner star', not Perms.Resolve(owner, 'tsrp.admin.access'))
local wild = Perms.Build(defs, { 'owner' }, { ['tsrp.admin.*'] = false, ['tsrp.admin.players'] = true })
check('wildcard deny', not Perms.Resolve(wild, 'tsrp.admin.groups'))
check('specific allow beats wildcard deny', Perms.Resolve(wild, 'tsrp.admin.players'))
check('invalid node denied', not Perms.Resolve(owner, 'Not Valid'))
check('owner inherits management chain', owner.groupSet.moderator == true)
local listed = Perms.ListAllowed(denied)
local hasDuty = false
for _, n in ipairs(listed) do if n == 'tsrp.police.duty' then hasDuty = true end end
check('ListAllowed omits denied', not hasDuty)

---------------------------------------------------------------- Identity
local today = { year = 2026, month = 11, day = 20 }
local good = { firstname = ' john ', lastname = 'doe', dateofbirth = '1990-01-01', gender = 'male', nationality = 'American', height = 180 }
local clean = TSRP.Identity.Validate(good, false, today)
check('identity ok', clean and clean.firstname == 'John' and clean.lastname == 'Doe', clean and clean.firstname)
local function bad(field, value)
    local p = Utils.DeepCopy(good); p[field] = value
    local r, f = TSRP.Identity.Validate(p, false, today)
    return r == nil and f == field
end
check('too young rejected', bad('dateofbirth', '2010-01-01'))
check('18th birthday tomorrow rejected', bad('dateofbirth', '2008-11-21'))
check('18th birthday today ok', TSRP.Identity.Validate((function() local p = Utils.DeepCopy(good); p.dateofbirth = '2008-11-20'; return p end)(), false, today) ~= nil)
check('too old rejected', bad('dateofbirth', '1900-01-01'))
check('bad date rejected', bad('dateofbirth', '1990-02-30'))
check('bad gender rejected', bad('gender', 'robot'))
check('bad nationality rejected', bad('nationality', 'Atlantean'))
check('height low rejected', bad('height', 100))
check('height float rejected', bad('height', 170.5))
check('name injection rejected', bad('firstname', "Robert'); DROP TABLE"))
check('empty name rejected', bad('lastname', ''))
check('non-string name rejected', bad('firstname', { 1 }))

---------------------------------------------------------------- Lifecycle via the callback router
TSRP.Ready = true
local cb = netHandlers[TSRP.NetEvents.Callback]
check('callback router registered', cb ~= nil)
local reqId = 0
local function call(src, name, payload)
    reqId = reqId + 1
    clientEvents = {}
    _G.source = src
    cb(name, reqId, payload)
    for _, e in ipairs(clientEvents) do
        if e.name == TSRP.NetEvents.CallbackResponse and e.args[1] == reqId then return e.args[2], e.args[3] end
    end
    return nil, 'no reply'
end
local function tick(ms) clock = clock + (ms or 60000) end

-- Players A (src 1) and B (src 2)
connected[1], licenses[1] = true, 'license:aaa'
connected[2], licenses[2] = true, 'license:bbb'
local pA = TSRP.Players.Create(1)
local pB = TSRP.Players.Create(2)
check('account A created', pA and pA.accountId == 1)
check('account B created', pB and pB.accountId == 2)
check('duplicate session detected', TSRP.Players.IdentifierInUse('license:aaa'))
local dupPlayer, dupErr = (function() licenses[3] = 'license:aaa'; connected[3] = true; return TSRP.Players.Create(3) end)()
check('duplicate account second connection refused', dupPlayer == nil and dupErr == 'duplicate', dupErr)
connected[3] = nil

local ok, data = call(1, 'tsrp:enterSelection', {})
check('enter selection', ok and data.maxSlots == 3 and #data.characters == 0, data)

local function mk(first, last, slot)
    return { firstname = first, lastname = last, dateofbirth = '1990-05-05', gender = 'male', nationality = 'American', height = 180, slot = slot }
end
local ids = {}
for i, n in ipairs({ { 'John', 'Doe' }, { 'Mike', 'Smith' }, { 'James', 'Wilson' } }) do
    tick()
    ok, data = call(1, 'tsrp:createCharacter', mk(n[1], n[2]))
    check('create character ' .. i, ok and data.character and data.character.id, data)
    ids[i] = ok and data.character.id
end
check('unique character ids', ids[1] ~= ids[2] and ids[2] ~= ids[3])
check('default civilian group assigned', db.groups[ids[1]] and db.groups[ids[1]].civilian)
tick()
ok, data = call(1, 'tsrp:createCharacter', mk('Fourth', 'Char'))
check('fourth character rejected', not ok and data == Errors.NoSlots, data)

tick()
ok, data = call(2, 'tsrp:createCharacter', mk('Bob', 'Brown'))
check('create refused before selection screen', not ok and data == Errors.InvalidState, data)
call(2, 'tsrp:enterSelection', {})
tick()
ok, data = call(2, 'tsrp:createCharacter', mk('John', 'Doe'))
check('duplicate full name rejected', not ok and data == Errors.NameTaken, data)
tick()
ok, data = call(2, 'tsrp:createCharacter', mk('Bob', 'Brown'))
local bobId = ok and data.character.id
check('account B creates own character', bobId ~= nil)
check('client cannot choose id', bobId == ids[3] + 1)

tick()
ok, data = call(2, 'tsrp:createCharacter', { firstname = 'x' })
check('invalid payload rejected with field', not ok and data:find('^invalid_input:') ~= nil, data)

-- Rate limiting (createCharacter: 3 per 30 s)
for _ = 1, 3 do call(2, 'tsrp:createCharacter', { firstname = 'x' }) end
ok, data = call(2, 'tsrp:createCharacter', { firstname = 'x' })
check('rate limit enforced', not ok and data == Errors.RateLimited, data)
tick()

-- Ownership
ok, data = call(2, 'tsrp:selectCharacter', { id = ids[1] })
check('cannot load another account character', not ok and data == Errors.NotFound, data)
ok, data = call(2, 'tsrp:deleteCharacter', { id = ids[1], confirm = 'John Doe' })
check('cannot delete another account character', not ok and db.chars[ids[1]] ~= nil, data)
ok, data = call(2, 'tsrp:previewCharacter', { id = ids[1] })
check('cannot preview another account character', not ok, data)
ok, data = call(1, 'tsrp:selectCharacter', { id = 'abc' })
check('non-numeric id rejected', not ok and data == Errors.InvalidInput, data)

-- Give characters different groups (console actor)
check('assign leo to John', Perms.AssignGroup(ids[1], 'leo', 0))
check('assign safr to Mike', Perms.AssignGroup(ids[2], 'safr', 0))
local dupA, dupE = Perms.AssignGroup(ids[1], 'leo', 0)
check('duplicate group assignment rejected', not dupA and dupE == Errors.Duplicate, dupE)
local ghostA, ghostE = Perms.AssignGroup(ids[1], 'ghost', 0)
check('unknown group assignment rejected', not ghostA and ghostE == Errors.UnknownGroup, ghostE)

-- Load John
tick()
ok, data = call(1, 'tsrp:selectCharacter', { id = ids[1] })
check('load own character', ok and data.character.id == ids[1], data)
check('new character needs appearance', ok and data.needsAppearance == true and data.defaultModel == 'mp_m_freemode_01')
check('loaded state creating', pA.state == TSRP.States.Creating)
check('John has police duty', exportsTbl.HasPermission(1, 'tsrp.police.duty'))
check('John lacks safr duty', not exportsTbl.HasPermission(1, 'tsrp.safr.duty'))
check('HasGroup leo', exportsTbl.HasGroup(1, 'leo'))

-- Selecting again while loaded is refused
ok, data = call(1, 'tsrp:selectCharacter', { id = ids[2] })
check('second load while active refused', not ok and data == Errors.InvalidState, data)

-- Spawn before appearance refused
ok, data = call(1, 'tsrp:spawn', { id = 'legion' })
check('spawn before appearance refused', not ok and data == Errors.InvalidState, data)

-- Appearance
tick()
ok, data = call(1, 'tsrp:saveAppearance', { appearance = { model = 'a_c_chimp' } })
check('model change without ped section rejected', not ok and data == Errors.InvalidInput, data)
ok, data = call(1, 'tsrp:saveAppearance', { appearance = { model = 'mp_m_freemode_01', components = { { component_id = 0, drawable = 1, texture = 0 } }, evil = function() end } })
check('appearance saved', ok and data.spawns ~= nil, data)
check('appearance stored on John', db.appearance[ids[1]] ~= nil and db.appearance[ids[2]] == nil)
check('unknown appearance keys stripped', db.appearance[ids[1]] and not db.appearance[ids[1]].appearance:find('evil'))
ok, data = call(1, 'tsrp:saveAppearance', { appearance = { model = 'mp_m_freemode_01' } })
check('save without open session refused', not ok and data == Errors.InvalidState, data)

-- Spawn options / validation
local spawnIds = {}
for _, s in ipairs(pA.state == TSRP.States.Spawning and TSRP.Spawn.Options(pA) or {}) do spawnIds[s.id] = true end
check('new character gets only new-character spawns', spawnIds.legion and spawnIds.airport and not spawnIds.last and not spawnIds.mrpd)
tick()
ok, data = call(1, 'tsrp:spawn', { id = 'mrpd' })
check('restricted / disallowed spawn refused', not ok and data == Errors.SpawnUnavailable, data)
ok, data = call(1, 'tsrp:spawn', { id = 'nowhere' })
check('unknown spawn refused', not ok)
ok, data = call(1, 'tsrp:spawn', { coords = { x = 1, y = 2, z = 3 } })
check('raw coords refused', not ok)
ok, data = call(1, 'tsrp:spawn', { id = 'legion' })
check('spawn legion', ok and data.coords and math.abs(data.coords.x - 195.17) < 0.01, data)
check('state active', pA.state == TSRP.States.Active and pA.spawned)

-- Live override changes update the cache immediately
check('deny override applied', Perms.SetOverride(ids[1], 'tsrp.police.duty', false, 0))
check('deny takes effect without reload', not exportsTbl.HasPermission(1, 'tsrp.police.duty'))
check('allow override applied', Perms.SetOverride(ids[1], 'tsrp.police.supervisor', true, 0))
check('allow takes effect', exportsTbl.HasPermission(1, 'tsrp.police.supervisor'))
check('clear override', Perms.ClearOverride(ids[1], 'tsrp.police.duty', 0))
check('cleared deny falls back to group', exportsTbl.HasPermission(1, 'tsrp.police.duty'))
check('remove group', Perms.RemoveGroup(ids[1], 'leo', 0))
check('removed group revoked live', not exportsTbl.HasPermission(1, 'tsrp.police.duty'))
check('assign leo back', Perms.AssignGroup(ids[1], 'leo', 0))

-- Admin authorisation: John is not an admin
tick()
ok, data = call(1, 'admin:overview', {})
check('non-admin dashboard request refused', not ok and data == Errors.Unauthorized, data)
ok, data = call(1, 'admin:addGroup', { id = ids[1], group = 'owner' })
check('non-admin self-escalation refused', not ok and data == Errors.Unauthorized, data)
check('bootstrap does not apply', not TSRP.Players.IsBootstrap(1))

-- Make John a moderator: still cannot assign admin (priority 80 >= 70) nor touch himself
Perms.AssignGroup(ids[1], 'moderator', 0)
Perms.AssignGroup(ids[1], 'admin', 0) -- now admin (80) for permissions node
check('admin can open dashboard', TSRP.Admin.Can(1, 'tsrp.admin.access'))
local okH, eH = TSRP.Admin.CanAssignGroup(1, 'admin')
check('cannot assign own priority level', not okH and eH == Errors.Hierarchy, eH)
check('can assign lower group', TSRP.Admin.CanAssignGroup(1, 'leo'))
local okS, eS = TSRP.Admin.CanManageCharacter(1, ids[1])
check('cannot manage own character', not okS and eS == Errors.Hierarchy, eS)
check('can manage lower character', TSRP.Admin.CanManageCharacter(1, bobId))
local okG, eG = TSRP.Admin.CanGrantNode(1, 'tsrp.admin.groups')
check('cannot grant node not held', not okG and eG == Errors.Hierarchy, eG)
tick()
ok, data = call(1, 'admin:addGroup', { id = bobId, group = 'owner' })
check('admin cannot hand out owner', not ok and data == Errors.Hierarchy, data)
ok, data = call(1, 'admin:addGroup', { id = bobId, group = 'leo' })
check('admin assigns leo to Bob via dashboard', ok, data)
ok, data = call(1, 'admin:getCharacter', { id = bobId })
check('admin reads character details', ok and data.character.id == bobId and data.character.identifier == nil, data)
ok, data = call(1, 'admin:explain', { id = bobId, node = 'tsrp.police.duty' })
check('explain via dashboard', ok and data.allowed == true and data.explanation:find('leo'), data)
ok, data = call(1, 'admin:createGroup', { name = 'test_group', label = 'Test', priority = 10, inherits = {}, permissions = {} })
check('group write needs tsrp.admin.groups', not ok and data == Errors.Unauthorized, data)

-- Switch characters: John -> Mike, permissions must not carry over
tick()
ok, data = call(1, 'tsrp:switchCharacter', {})
check('switch character', ok and #data.characters == 3, data)
check('no permissions while selecting', not exportsTbl.HasPermission(1, 'tsrp.police.duty'))
tick()
ok, data = call(1, 'tsrp:selectCharacter', { id = ids[2] })
check('load Mike after switch', ok, data)
check('Mike has safr duty', exportsTbl.HasPermission(1, 'tsrp.safr.duty'))
check('Mike has no police duty', not exportsTbl.HasPermission(1, 'tsrp.police.duty'))
check('Mike has no admin from John', not exportsTbl.HasPermission(1, 'tsrp.admin.access'))
local switched = false
for _, ev in ipairs(localEvents.__fired or {}) do if ev[1] == TSRP.ServerEvents.CharacterSwitched and ev[3] == ids[1] and ev[4] == ids[2] then switched = true end end
check('characterSwitched event fired', switched)
-- Back to selection from creator (no appearance yet) works without a permission
tick()
ok, data = call(1, 'tsrp:backToSelection', {})
check('back to selection before spawn', ok, data)

-- Third character James: civilian only
tick()
ok, data = call(1, 'tsrp:selectCharacter', { id = ids[3] })
check('James civilian only', ok and exportsTbl.HasPermission(1, 'tsrp.civilian.jobs') and not exportsTbl.HasPermission(1, 'tsrp.police.duty') and not exportsTbl.HasPermission(1, 'tsrp.safr.duty'))
tick()
call(1, 'tsrp:backToSelection', {})

-- Delete with confirmation
tick()
ok, data = call(1, 'tsrp:deleteCharacter', { id = ids[3], confirm = 'wrong name' })
check('delete confirm mismatch', not ok and data == Errors.ConfirmMismatch, data)
ok, data = call(1, 'tsrp:deleteCharacter', { id = ids[3], confirm = ' james  WILSON ' })
check('delete own character', ok and #data.characters == 2 and db.chars[ids[3]] == nil, data)
check('delete cascades groups', db.groups[ids[3]] == nil)

-- Disconnect while loaded
tick()
ok = call(1, 'tsrp:selectCharacter', { id = ids[1] })
check('reload John', ok)
_G.source = 1
for _, fn in ipairs(localEvents.playerDropped or {}) do fn('quit') end
check('drop removes player', TSRP.Players.Get(1) == nil)
check('drop frees character', TSRP.Players.GetSourceByCharacterId(ids[1]) == nil)
connected[1] = nil
check('identifier free after drop', not TSRP.Players.IdentifierInUse('license:aaa'))

-- Reconnect: data persisted
connected[1] = true
pA = TSRP.Players.Create(1)
ok, data = call(1, 'tsrp:enterSelection', {})
check('characters persist after reconnect', ok and #data.characters == 2, data)
ok, data = call(1, 'tsrp:selectCharacter', { id = ids[1] })
check('appearance persists after reconnect', ok and data.needsAppearance == false and data.appearance and data.appearance.model == 'mp_m_freemode_01', data)
check('groups persist after reconnect', exportsTbl.HasPermission(1, 'tsrp.police.duty'))

-- Database failure handling
tick()
call(1, 'tsrp:backToSelection', {})
db.fail = true
tick()
ok, data = call(1, 'tsrp:selectCharacter', { id = ids[1] })
check('db failure returns database_error', not ok and data == Errors.Database, data)
tick()
ok, data = call(1, 'tsrp:createCharacter', mk('Late', 'Comer'))
check('db failure on create handled', not ok and data == Errors.Database, data)
db.fail = false

-- Not ready
TSRP.Ready = false
ok, data = call(1, 'tsrp:enterSelection', {})
check('not ready refused', not ok and data == Errors.NotReady, data)
TSRP.Ready = true

-- Unknown callback / bad payload types
ok, data = call(1, 'tsrp:doesNotExist', {})
check('unknown callback refused', not ok)
ok, data = call(1, 'tsrp:selectCharacter', 'not a table')
check('non-table payload handled', not ok)

-- Metadata
check('metadata set', TSRP.Metadata.Set(ids[1], 'licenses', { driver = true }, nil))
check('metadata get', (TSRP.Metadata.Get(ids[1], 'licenses') or {}).driver == true)
check('metadata bad key rejected', not TSRP.Metadata.Set(ids[1], 'bad key!', 1, nil))
check('metadata function rejected', not TSRP.Metadata.Set(ids[1], 'fn', function() end, nil))

---------------------------------------------------------------- Discord role sync
local D = TSRP.Integrations.Discord
local R = {}
for _, r in ipairs(Config.Discord.Roles) do R[r.name] = r.id end
local problems = D.ValidateConfig(Groups.defs)
check('discord config valid', #problems == 0, table.concat(problems, '; '))
check('discord inactive without token', not D.Active())

local info = D.Compute({ R['TSRP | Owners'] }, Groups.defs)
check('owners role -> owner group', #info.account == 1 and info.account[1] == 'owner')
info = D.Compute({ R['San Andreas State Police'] }, Groups.defs)
check('sasp role unlocks sasp and leo only', info.unlocked.sasp and info.unlocked.leo and not info.unlocked.sasp_supervisor and #info.account == 0)
local g = D.Apply(Groups.defs, { 'civilian', 'sasp' }, nil)
check('no roles: department group switched off', table.concat(g, ',') == 'civilian', table.concat(g, ','))
g = D.Apply(Groups.defs, { 'civilian', 'sasp' }, info)
check('with role: department group works', table.concat(g, ',') == 'civilian,sasp', table.concat(g, ','))
g = D.Apply(Groups.defs, { 'civilian', 'admin' }, D.Compute({}, Groups.defs))
check('hand-assigned staff group ignored', table.concat(g, ',') == 'civilian', table.concat(g, ','))
info = D.Compute({ R['San Andreas State Police'], R['TSRP | Whitelisted LEO'], R['TSRP | Blacklisted LEO'], R['TSRP | Donator'] }, Groups.defs)
g = D.Apply(Groups.defs, { 'civilian', 'sasp' }, info)
check('blacklisted LEO removes police and LEO whitelist', table.concat(g, ',') == 'civilian,donator', table.concat(g, ','))
g = D.Apply(Groups.defs, { 'civilian' }, D.Compute({ R['TSRP | Administrator'], R['Suspended Staff'] }, Groups.defs))
check('suspended staff removes admin', table.concat(g, ',') == 'civilian', table.concat(g, ','))
g = D.Apply(Groups.defs, { 'civilian' }, D.Compute({ R['TSRP | Development Team'], R['Suspended Staff'] }, Groups.defs))
check('suspended staff keeps developer', table.concat(g, ',') == 'civilian,developer', table.concat(g, ','))
local vip = Perms.Build(Groups.defs, (D.Apply(Groups.defs, { 'civilian' }, D.Compute({ R['Donator | Elite VIP'] }, Groups.defs))), {})
check('elite vip includes premium and donator, not ultimate', Perms.Resolve(vip, 'tsrp.vip.premium') and Perms.Resolve(vip, 'tsrp.donator') and not Perms.Resolve(vip, 'tsrp.vip.ultimate'))
local mods = Perms.Build(Groups.defs, (D.Apply(Groups.defs, {}, D.Compute({ R['TSRP | Trial Moderator'] }, Groups.defs))), {})
check('trial moderator can open dashboard', Perms.Resolve(mods, 'tsrp.admin.access') and Perms.Resolve(mods, 'tsrp.staff') and not Perms.Resolve(mods, 'tsrp.admin.permissions'))

-- Live, with the integration switched on by a token
local realGetConvar = GetConvar
GetConvar = function(name, d) if name == 'tsrp_discord_token' then return 'test-token' end return realGetConvar(name, d) end
check('discord active with token', D.Active())

tick()
call(1, 'tsrp:enterSelection', {})
tick()
ok, data = call(1, 'tsrp:selectCharacter', { id = ids[1] })
check('john loads with sync on', ok, data)
local pj = TSRP.Players.Get(1)
check('john has leo in database', Utils.Contains(pj.groups, 'leo'))
check('no Discord roles: leo switched off', not exportsTbl.HasPermission(1, 'tsrp.police.duty'))
D.SetRoles(pj, { R['San Andreas State Police'] }, '123', true)
check('SASP role: leo works again', exportsTbl.HasPermission(1, 'tsrp.police.duty'))
check('SASP role gives no staff', not exportsTbl.HasPermission(1, 'tsrp.admin.access'))
D.SetRoles(pj, { R['San Andreas State Police'], R['TSRP | Owners'] }, '123', true)
check('Owners role: full access live', exportsTbl.HasPermission(1, 'anything.at.all') and exportsTbl.HasGroup(1, 'owner'))
check('Discord groups count for admin rank', TSRP.Admin.ActorPriority(1) == 100, TSRP.Admin.ActorPriority(1))
local okA, eA = Perms.AssignGroup(ids[2], 'admin', 0)
check('cannot hand-assign a Discord-managed group', not okA and eA == Errors.DiscordManaged, eA)
local okB, eB = Perms.AssignGroup(ids[1], 'bcso', 0)
check('cannot assign department without unlocking role', not okB and eB == Errors.DiscordRoleRequired, eB)
check('can assign unlocked department', Perms.AssignGroup(ids[1], 'sasp', 0))
check('assigned department works', exportsTbl.HasPermission(1, 'tsrp.sasp.duty'))
D.SetRoles(pj, { R['San Andreas State Police'], R['TSRP | Blacklisted LEO'] }, '123', true)
check('blacklist applies live', not exportsTbl.HasPermission(1, 'tsrp.sasp.duty') and not exportsTbl.HasPermission(1, 'tsrp.police.duty'))
check('owner gone when role removed', not exportsTbl.HasGroup(1, 'owner'))
check('character keeps sasp in database', Utils.Contains(pj.groups, 'sasp'))
D.SetRoles(pj, { R['San Andreas State Police'] }, '123', true)
check('blacklist lifted restores access', exportsTbl.HasPermission(1, 'tsrp.sasp.duty'))
check('discord error messages exist', TSRP.T(Errors.DiscordManaged) ~= Errors.DiscordManaged and TSRP.T(Errors.DiscordRoleRequired) ~= Errors.DiscordRoleRequired, TSRP.T(Errors.DiscordManaged))
if not commands.tsrp then TSRP.Commands.Register() end
local printed, realPrint = {}, print
print = function(m) printed[#printed + 1] = tostring(m) end
commands.tsrp(0, { 'discord', '1' })
commands.tsrp(0, { 'discord', 'sync' })
print = realPrint
local out = table.concat(printed, '\n')
check('tsrp discord shows a player', out:find('unlocks leo, sasp', 1, true) ~= nil and out:find('refreshed') ~= nil, out)
GetConvar = realGetConvar
check('discord inactive again', not D.Active())

print(('tests: %d passed, %d failed'):format(passed, failed))
return failed == 0
