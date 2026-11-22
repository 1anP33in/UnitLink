-- UnitLink Core: chat and console commands. Every command authorises on the server.
--
--   /ulcore                         open the admin dashboard
--   /ulcore players                 dashboard -> players
--   /ulcore character [id]          dashboard -> characters (optionally open one)
--   /ulcore groups                  dashboard -> groups
--   /ulcore permissions [id] [node] dashboard -> permissions (or explain a node)
--   /ulcore addgroup <charId> <group>       /ulcore removegroup <charId> <group>
--   /ulcore allow <charId> <node>           /ulcore deny <charId> <node>
--   /ulcore clear <charId> <node>           /ulcore explain <charId> <node>
--   /ulcore chars <serverId|license>        /ulcore reloadgroups
--
-- The same subcommands work from the server console (as `ulcore ...`), which is how the
-- first owner is set up: `ulcore addgroup 1000 owner`.

UnitLink = UnitLink or {}
local Commands = {}
UnitLink.Commands = Commands

local Utils = UnitLink.Utils
local Admin = UnitLink.Admin
local Permissions = UnitLink.Permissions

local function reply(src, msg, isError)
    if src == 0 then
        print((isError and '^1' or '^2') .. '[UnitLink-Core] ^7' .. msg)
    else
        TriggerClientEvent('chat:addMessage', src, {
            color = isError and { 255, 99, 99 } or { 94, 234, 212 },
            multiline = true,
            args = { 'UnitLink', msg },
        })
    end
end

local function errText(code)
    if type(code) ~= 'string' then return tostring(code) end
    local base = code:match('^([%w_]+)') or code
    return UnitLink.T(base) .. (code:find(':') and (' (' .. code:match(':(.*)$') .. ')') or '')
end

local function openDashboard(src, section, arg)
    if src == 0 then return reply(0, 'The dashboard is in-game only. Try: ulcore players | ulcore groups | ulcore chars <id>') end
    if not Admin.Can(src, Admin.Nodes.access) then
        UnitLink.Log.Audit(UnitLink.AuditActions.AdminDenied, src, nil, { request = 'open' })
        return reply(src, UnitLink.T('no_permission_command'), true)
    end
    local player = UnitLink.Players.Get(src)
    if not player then return end
    UnitLink.Log.Audit(UnitLink.AuditActions.AdminOpen, src, nil, { section = section })
    TriggerClientEvent(UnitLink.ClientEvents.OpenAdmin, src, { section = section or 'overview', arg = arg })
end

local function requireNode(src, node)
    if Admin.Can(src, node) then return true end
    reply(src, UnitLink.T('unauthorized'), true)
    return false
end

local sub = {}

sub.players = function(src)
    if src ~= 0 then return openDashboard(src, 'players') end
    for s, p in pairs(UnitLink.Players.All()) do
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
    for _, def in ipairs(UnitLink.Groups.List()) do
        print(('  %-18s %-22s prio=%-4d inherits=[%s] perms=%d'):format(def.name, def.label, def.priority,
            table.concat(def.inherits, ','), #def.permissions))
    end
end

sub.explain = function(src, args)
    if not (Admin.Can(src, Admin.Nodes.characters) or Admin.Can(src, Admin.Nodes.permissions)) then
        return reply(src, UnitLink.T('unauthorized'), true)
    end
    local id, node = Utils.ToId(args[1]), args[2]
    if not id or not Utils.IsValidPermissionNode(node) then return reply(src, 'Usage: ulcore explain <charId> <node>', true) end
    local effective = Permissions.GetEffective(id)
    if not effective then return reply(src, UnitLink.T('not_found'), true) end
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
    if asSource and UnitLink.Players.Get(asSource) then
        identifier = UnitLink.Players.Get(asSource).identifier
    elseif type(target) == 'string' and target:find('^license2?:') and Admin.Can(src, Admin.Nodes.identifiers) then
        identifier = target
    end
    if not identifier then return reply(src, 'Usage: ulcore chars <serverId|license>', true) end
    local list = UnitLink.Characters.FetchForAccount(identifier)
    if not list then return reply(src, UnitLink.T('database_error'), true) end
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
    mutate(src, args, 'Usage: ulcore addgroup <charId> <group>', function(id, group)
        local ok, err = Admin.CanAssignGroup(src, group)
        if not ok then return false, err end
        return Permissions.AssignGroup(id, group, src)
    end)
end

sub.removegroup = function(src, args)
    mutate(src, args, 'Usage: ulcore removegroup <charId> <group>', function(id, group)
        if UnitLink.Groups.Exists(group) then
            local ok, err = Admin.CanAssignGroup(src, group)
            if not ok then return false, err end
        elseif not Admin.IsSuper(src) then
            return false, UnitLink.Errors.UnknownGroup
        end
        return Permissions.RemoveGroup(id, group, src)
    end)
end

local function overrideCmd(allow)
    return function(src, args)
        mutate(src, args, ('Usage: ulcore %s <charId> <node>'):format(allow and 'allow' or 'deny'), function(id, node)
            if not Utils.IsValidPermissionNode(node) then return false, UnitLink.Errors.InvalidInput end
            local ok, err = Admin.CanGrantNode(src, node)
            if not ok then return false, err end
            return Permissions.SetOverride(id, node, allow, src)
        end)
    end
end
sub.allow = overrideCmd(true)
sub.deny = overrideCmd(false)

sub.clear = function(src, args)
    mutate(src, args, 'Usage: ulcore clear <charId> <node>', function(id, node)
        if not Utils.IsValidPermissionNode(node) then return false, UnitLink.Errors.InvalidInput end
        local ok, err = Admin.CanGrantNode(src, node)
        if not ok then return false, err end
        return Permissions.ClearOverride(id, node, src)
    end)
end

-- ulcore discord [serverId]       show what a player's Discord roles give them
-- ulcore discord sync [serverId]  re-read roles now (one player, or everyone)
sub.discord = function(src, args)
    if not requireNode(src, Admin.Nodes.players) then return end
    local Discord = UnitLink.Integrations.Discord
    if not Discord.Active() then
        return reply(src, ('Discord sync is off. Set %s in server.cfg.'):format(Config.Discord.TokenConvar), true)
    end
    if args[1] == 'sync' then
        local target = tonumber(args[2])
        if target then
            local player = UnitLink.Players.Get(target)
            if not player then return reply(src, UnitLink.T('not_found'), true) end
            Discord.Queue(player)
        else
            Discord.RefreshAll()
        end
        return reply(src, 'Discord roles are being refreshed.')
    end
    local target = tonumber(args[1]) or src
    local player = UnitLink.Players.Get(target)
    if not player then return reply(src, 'Usage: ulcore discord <serverId> | ulcore discord sync [serverId]', true) end
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
    if not Admin.IsSuper(src) then return reply(src, UnitLink.T('unauthorized'), true) end
    if UnitLink.Groups.LoadAll() then
        Permissions.RebuildAll()
        reply(src, 'Groups reloaded from the database.')
    else
        reply(src, UnitLink.T('database_error'), true)
    end
end

function Commands.Register()
    local name = Config.Commands.Admin
    if name then
        RegisterCommand(name, function(src, args)
            if not UnitLink.Ready then return reply(src, UnitLink.T('not_ready'), true) end
            if src ~= 0 and not UnitLink.RateLimit.CheckNamed(src, 'admin') then
                return reply(src, UnitLink.T('rate_limited'), true)
            end
            local action = args[1] and args[1]:lower() or nil
            if not action then return openDashboard(src, 'overview') end
            local handler = sub[action]
            if not handler then
                return reply(src, 'Unknown subcommand. See the UnitLink Core README for the command list.', true)
            end
            local rest = {}
            for i = 2, #args do rest[#rest + 1] = args[i] end
            handler(src, rest)
        end, false)
    end

    local appearance = Config.Commands.Appearance
    if appearance then
        RegisterCommand(appearance, function(src)
            if src == 0 or not UnitLink.Ready then return end
            if not Permissions.Has(src, 'unitlink.appearance.edit') then
                return reply(src, UnitLink.T('no_permission_command'), true)
            end
            local ok, err = UnitLink.Appearance.OpenEditor(src)
            if not ok then reply(src, errText(err), true) end
        end, false)
    end
end
