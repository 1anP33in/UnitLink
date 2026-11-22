-- TSRP Core: chat and console commands. Every command authorises on the server.
--
--   /tsrp                         open the admin dashboard
--   /tsrp players                 dashboard -> players
--   /tsrp character [id]          dashboard -> characters (optionally open one)
--   /tsrp groups                  dashboard -> groups
--   /tsrp permissions [id] [node] dashboard -> permissions (or explain a node)
--   /tsrp addgroup <charId> <group>       /tsrp removegroup <charId> <group>
--   /tsrp allow <charId> <node>           /tsrp deny <charId> <node>
--   /tsrp clear <charId> <node>           /tsrp explain <charId> <node>
--   /tsrp chars <serverId|license>        /tsrp reloadgroups
--
-- The same subcommands work from the server console (as `tsrp ...`), which is how the
-- first owner is set up: `tsrp addgroup 1000 owner`.

TSRP = TSRP or {}
local Commands = {}
TSRP.Commands = Commands

local Utils = TSRP.Utils
local Admin = TSRP.Admin
local Permissions = TSRP.Permissions

local function reply(src, msg, isError)
    if src == 0 then
        print((isError and '^1' or '^2') .. '[tsrp] ^7' .. msg)
    else
        TriggerClientEvent('chat:addMessage', src, {
            color = isError and { 255, 99, 99 } or { 94, 234, 212 },
            multiline = true,
            args = { 'TSRP', msg },
        })
    end
end

local function errText(code)
    if type(code) ~= 'string' then return tostring(code) end
    local base = code:match('^([%w_]+)') or code
    return TSRP.T(base) .. (code:find(':') and (' (' .. code:match(':(.*)$') .. ')') or '')
end

local function openDashboard(src, section, arg)
    if src == 0 then return reply(0, 'The dashboard is in-game only. Try: tsrp players | tsrp groups | tsrp chars <id>') end
    if not Admin.Can(src, Admin.Nodes.access) then
        TSRP.Log.Audit(TSRP.AuditActions.AdminDenied, src, nil, { request = 'open' })
        return reply(src, TSRP.T('no_permission_command'), true)
    end
    local player = TSRP.Players.Get(src)
    if not player then return end
    TSRP.Log.Audit(TSRP.AuditActions.AdminOpen, src, nil, { section = section })
    TriggerClientEvent(TSRP.ClientEvents.OpenAdmin, src, { section = section or 'overview', arg = arg })
end

local function requireNode(src, node)
    if Admin.Can(src, node) then return true end
    reply(src, TSRP.T('unauthorized'), true)
    return false
end

local sub = {}

sub.players = function(src)
    if src ~= 0 then return openDashboard(src, 'players') end
    for s, p in pairs(TSRP.Players.All()) do
        print(('  [%d] %s  %s  state=%s  char=%s'):format(s, p.name, p.identifier, p.state,
            p.characterId and (p.characterId .. ' ' .. p.character.firstname .. ' ' .. p.character.lastname) or '-'))
    end
end

sub.character = function(src, args)
    return openDashboard(src, 'characters', Utils.ToId(args[1]))
end
sub.characters = sub.character

sub.groups = function(src)
    if src ~= 0 then return openDashboard(src, 'groups') end
    for _, def in ipairs(TSRP.Groups.List()) do
        print(('  %-18s %-22s prio=%-4d inherits=[%s] perms=%d'):format(def.name, def.label, def.priority,
            table.concat(def.inherits, ','), #def.permissions))
    end
end

sub.explain = function(src, args)
    if not (Admin.Can(src, Admin.Nodes.characters) or Admin.Can(src, Admin.Nodes.permissions)) then
        return reply(src, TSRP.T('unauthorized'), true)
    end
    local id, node = Utils.ToId(args[1]), args[2]
    if not id or not Utils.IsValidPermissionNode(node) then return reply(src, 'Usage: tsrp explain <charId> <node>', true) end
    local effective = Permissions.GetEffective(id)
    if not effective then return reply(src, TSRP.T('not_found'), true) end
    local allowed, reason = Permissions.Resolve(effective, node)
    reply(src, Permissions.DescribeReason(node, allowed, reason))
end

sub.permissions = function(src, args)
    if args[1] and args[2] then return sub.explain(src, args) end
    return openDashboard(src, 'permissions', Utils.ToId(args[1]))
end

sub.chars = function(src, args)
    if not requireNode(src, Admin.Nodes.characters) then return end
    local target = args[1]
    local identifier
    local asSource = Utils.ToId(target)
    if asSource and TSRP.Players.Get(asSource) then
        identifier = TSRP.Players.Get(asSource).identifier
    elseif type(target) == 'string' and target:find('^license2?:') and Admin.Can(src, Admin.Nodes.identifiers) then
        identifier = target
    end
    if not identifier then return reply(src, 'Usage: tsrp chars <serverId|license>', true) end
    local list = TSRP.Characters.FetchForAccount(identifier)
    if not list then return reply(src, TSRP.T('database_error'), true) end
    if #list == 0 then return reply(src, 'No characters.') end
    for _, c in ipairs(list) do
        reply(src, ('#%d  slot %d  %s %s  (%s)'):format(c.id, c.slot, c.firstname, c.lastname, c.dateofbirth))
    end
end

local function mutate(src, args, usage, fn)
    if not requireNode(src, Admin.Nodes.permissions) then return end
    local id, value = Utils.ToId(args[1]), args[2]
    if not id or type(value) ~= 'string' then return reply(src, usage, true) end
    local ok, err = Admin.CanManageCharacter(src, id)
    if not ok then return reply(src, errText(err), true) end
    local done, ferr = fn(id, value)
    if done then reply(src, 'Done.') else reply(src, errText(ferr), true) end
end

sub.addgroup = function(src, args)
    mutate(src, args, 'Usage: tsrp addgroup <charId> <group>', function(id, group)
        local ok, err = Admin.CanAssignGroup(src, group)
        if not ok then return false, err end
        return Permissions.AssignGroup(id, group, src)
    end)
end

sub.removegroup = function(src, args)
    mutate(src, args, 'Usage: tsrp removegroup <charId> <group>', function(id, group)
        if TSRP.Groups.Exists(group) then
            local ok, err = Admin.CanAssignGroup(src, group)
            if not ok then return false, err end
        elseif not Admin.IsSuper(src) then
            return false, TSRP.Errors.UnknownGroup
        end
        return Permissions.RemoveGroup(id, group, src)
    end)
end

local function overrideCmd(allow)
    return function(src, args)
        mutate(src, args, ('Usage: tsrp %s <charId> <node>'):format(allow and 'allow' or 'deny'), function(id, node)
            if not Utils.IsValidPermissionNode(node) then return false, TSRP.Errors.InvalidInput end
            local ok, err = Admin.CanGrantNode(src, node)
            if not ok then return false, err end
            return Permissions.SetOverride(id, node, allow, src)
        end)
    end
end
sub.allow = overrideCmd(true)
sub.deny = overrideCmd(false)

sub.clear = function(src, args)
    mutate(src, args, 'Usage: tsrp clear <charId> <node>', function(id, node)
        if not Utils.IsValidPermissionNode(node) then return false, TSRP.Errors.InvalidInput end
        local ok, err = Admin.CanGrantNode(src, node)
        if not ok then return false, err end
        return Permissions.ClearOverride(id, node, src)
    end)
end

-- tsrp discord [serverId]       show what a player's Discord roles give them
-- tsrp discord sync [serverId]  re-read roles now (one player, or everyone)
sub.discord = function(src, args)
    if not requireNode(src, Admin.Nodes.players) then return end
    local Discord = TSRP.Integrations.Discord
    if not Discord.Active() then
        return reply(src, ('Discord sync is off. Set %s in server.cfg.'):format(Config.Discord.TokenConvar), true)
    end
    if args[1] == 'sync' then
        local target = tonumber(args[2])
        if target then
            local player = TSRP.Players.Get(target)
            if not player then return reply(src, TSRP.T('not_found'), true) end
            Discord.Queue(player)
        else
            Discord.RefreshAll()
        end
        return reply(src, 'Discord roles are being refreshed.')
    end
    local target = tonumber(args[1]) or src
    local player = TSRP.Players.Get(target)
    if not player then return reply(src, 'Usage: tsrp discord <serverId> | tsrp discord sync [serverId]', true) end
    local info = player.discordInfo
    if not info then return reply(src, ('%s: roles not loaded yet.'):format(player.name)) end
    if not info.discordId then return reply(src, ('%s: no Discord account linked to FiveM.'):format(player.name)) end
    local function keys(set)
        local out = {}
        for k in pairs(set) do out[#out + 1] = k end
        table.sort(out)
        return #out > 0 and table.concat(out, ', ') or 'none'
    end
    reply(src, ('%s (Discord %s%s): groups %s | unlocks %s | blocked %s'):format(
        player.name, info.discordId, info.member == false and ', not in the server' or '',
        #info.account > 0 and table.concat(info.account, ', ') or 'none', keys(info.unlocked), keys(info.blocked)))
end

sub.reloadgroups = function(src)
    if not Admin.IsSuper(src) then return reply(src, TSRP.T('unauthorized'), true) end
    if TSRP.Groups.LoadAll() then
        Permissions.RebuildAll()
        reply(src, 'Groups reloaded from the database.')
    else
        reply(src, TSRP.T('database_error'), true)
    end
end

function Commands.Register()
    local name = Config.Commands.Admin
    if name then
        RegisterCommand(name, function(src, args)
            if not TSRP.Ready then return reply(src, TSRP.T('not_ready'), true) end
            if src ~= 0 and not TSRP.RateLimit.CheckNamed(src, 'admin') then
                return reply(src, TSRP.T('rate_limited'), true)
            end
            local action = args[1] and args[1]:lower() or nil
            if not action then return openDashboard(src, 'overview') end
            local handler = sub[action]
            if not handler then
                return reply(src, 'Unknown subcommand. See the TSRP Core README for the command list.', true)
            end
            local rest = {}
            for i = 2, #args do rest[#rest + 1] = args[i] end
            handler(src, rest)
        end, false)
    end

    local appearance = Config.Commands.Appearance
    if appearance then
        RegisterCommand(appearance, function(src)
            if src == 0 or not TSRP.Ready then return end
            if not Permissions.Has(src, 'tsrp.appearance.edit') then
                return reply(src, TSRP.T('no_permission_command'), true)
            end
            local ok, err = TSRP.Appearance.OpenEditor(src)
            if not ok then reply(src, errText(err), true) end
        end, false)
    end
end
