---------------------------------------------------------------------
-- UnitLink-Perms: Discord roles -> ACE groups (see config.lua)
--
-- A player's groups are added with `add_principal player.<id> <group>`
-- and removed with `remove_principal` when they lose the role or leave.
-- If Discord can't be reached, nobody loses anything: groups only change
-- on a real answer from Discord.
---------------------------------------------------------------------
local RES = GetCurrentResourceName()
local API = 'https://discord.com/api/v10'
local applied = {}      -- [src] = { [group] = true }
local noDiscord = {}    -- [src] = true (already told the console)
local warnedToken = false

local function log(msg, color) print(('^%s[%s]^7 %s'):format(color or '5', RES, msg)) end
local function token() return GetConvar(Config.TokenConvar or 'unitlink_discord_token', '') end

local ROLE = {}
for _, r in ipairs(Config.Roles or {}) do ROLE[tostring(r.id)] = r end

---------------------------------------------------------------------
-- Groups: create them, and check this resource may run the commands
---------------------------------------------------------------------
local canRun = false
local function setupGroups()
    -- probe: can this resource run add_ace / add_principal?
    ExecuteCommand('add_ace group.unitlink_perms_probe unitlink.perms.probe allow')
    local probe = IsPrincipalAceAllowed('group.unitlink_perms_probe', 'unitlink.perms.probe')
    canRun = probe == true or (type(probe) == 'number' and probe ~= 0)
    if not canRun then
        log('This resource is not allowed to run add_ace / add_principal. Add to server.cfg:', '1')
        log(('  add_ace resource.%s command.add_ace allow'):format(RES), '1')
        log(('  add_ace resource.%s command.add_principal allow'):format(RES), '1')
        log(('  add_ace resource.%s command.remove_principal allow'):format(RES), '1')
        return
    end
    local n = 0
    for group, nodes in pairs(Config.Groups or {}) do
        for _, node in ipairs(nodes) do ExecuteCommand(('add_ace %s %s allow'):format(group, node)); n = n + 1 end
    end
    log(('%d permissions set up on %d groups.'):format(n, (function() local c = 0 for _ in pairs(Config.Groups or {}) do c = c + 1 end return c end)()), '2')
end

---------------------------------------------------------------------
-- Apply a player's groups (only the difference)
---------------------------------------------------------------------
local function setGroups(src, want)
    if not canRun then return end
    local have = applied[src] or {}
    local added, removed = {}, {}
    for g in pairs(want) do
        if not have[g] then ExecuteCommand(('add_principal player.%d %s'):format(src, g)); added[#added + 1] = g end
    end
    for g in pairs(have) do
        if not want[g] then ExecuteCommand(('remove_principal player.%d %s'):format(src, g)); removed[#removed + 1] = g end
    end
    applied[src] = want
    if Config.Log and (#added > 0 or #removed > 0) then
        local name = GetPlayerName(src) or ('player ' .. src)
        local parts = {}
        for _, g in ipairs(added) do parts[#parts + 1] = '^2+' .. g .. '^7' end
        for _, g in ipairs(removed) do parts[#parts + 1] = '^1-' .. g .. '^7' end
        log(('%s [%d]: %s'):format(name, src, table.concat(parts, ' ')))
    end
    TriggerEvent('unitlink-perms:updated', src, want)
end

local function groupsFromRoles(roles)
    local want, blocked = {}, {}
    for _, id in ipairs(roles or {}) do
        local r = ROLE[tostring(id)]
        if r then
            for _, g in ipairs(r.groups or {}) do want[g] = true end
            for _, g in ipairs(r.blocks or {}) do blocked[g] = true end
        end
    end
    for g in pairs(blocked) do want[g] = nil end
    return want
end

local function discordId(src)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        local d = id:match('^discord:(%d+)$')
        if d then return d end
    end
end

---------------------------------------------------------------------
-- Ask Discord for one player's roles
---------------------------------------------------------------------
local function refresh(src, done)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then if done then done() end return end
    local t = token()
    if t == '' then
        if not warnedToken then warnedToken = true; log(('No bot token. Add to server.cfg: set %s "YOUR_BOT_TOKEN"'):format(Config.TokenConvar), '1') end
        if done then done() end
        return
    end
    local uid = discordId(src)
    if not uid then
        if not noDiscord[src] then
            noDiscord[src] = true
            if Config.Log then log(('%s [%d] has no Discord linked (Discord must be open when FiveM starts). No groups.'):format(GetPlayerName(src) or '?', src), '3') end
        end
        setGroups(src, {})
        if done then done() end
        return
    end
    PerformHttpRequest(('%s/guilds/%s/members/%s'):format(API, Config.GuildId, uid), function(status, body, headers)
        if not GetPlayerName(src) then if done then done() end return end
        if status == 200 then
            local ok, member = pcall(json.decode, body or '')
            if ok and type(member) == 'table' then setGroups(src, groupsFromRoles(member.roles)) end
        elseif status == 404 then
            setGroups(src, {}) -- not in the Discord server
        elseif status == 429 then
            local ok, b = pcall(json.decode, body or '')
            local wait = math.ceil(((ok and type(b) == 'table' and tonumber(b.retry_after)) or 2) * 1000) + 250
            SetTimeout(wait, function() refresh(src) end)
        elseif status == 401 or status == 403 then
            if not warnedToken then warnedToken = true; log(('Discord refused the bot (HTTP %d). Check the token and that the bot is in server %s.'):format(status, Config.GuildId), '1') end
        else
            -- Discord down or slow: keep the groups they already have
            if Config.Log then log(('Discord did not answer for [%d] (HTTP %s). Keeping their groups.'):format(src, tostring(status)), '3') end
        end
        if done then done() end
    end, 'GET', '', { Authorization = 'Bot ' .. t, ['Content-Type'] = 'application/json' })
end

-- one at a time, spaced out, so a full server doesn't hit Discord's rate limit
local function refreshAll()
    local list = GetPlayers()
    local i = 0
    local function nextOne()
        i = i + 1
        if not list[i] then return end
        refresh(list[i], function() SetTimeout(250, nextOne) end)
    end
    nextOne()
end

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------
AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(500, function() refresh(src) end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    -- server ids get reused: never leave groups on an id
    if applied[src] then
        for g in pairs(applied[src]) do ExecuteCommand(('remove_principal player.%d %s'):format(src, g)) end
    end
    applied[src], noDiscord[src] = nil, nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for src, groups in pairs(applied) do
        for g in pairs(groups) do ExecuteCommand(('remove_principal player.%d %s'):format(src, g)) end
    end
end)

CreateThread(function()
    setupGroups()
    if token() == '' then
        log(('No bot token. Add to server.cfg: set %s "YOUR_BOT_TOKEN"'):format(Config.TokenConvar), '1')
        warnedToken = true
    end
    refreshAll() -- players already online (resource restart)
    while true do
        Wait((Config.RefreshSeconds or 300) * 1000)
        refreshAll()
    end
end)

---------------------------------------------------------------------
-- Console: ulperms            -> who has which group
--          ulperms refresh    -> re-check everyone now
--          ulperms refresh 12 -> re-check one player
---------------------------------------------------------------------
RegisterCommand(Config.Command or 'ulperms', function(src, args)
    if src ~= 0 then return end -- server console only
    if args[1] == 'refresh' then
        if args[2] then refresh(tonumber(args[2])); log('Refreshing player ' .. args[2] .. '.')
        else refreshAll(); log('Refreshing everyone online.') end
        return
    end
    local any = false
    for _, s in ipairs(GetPlayers()) do
        local n = tonumber(s)
        local gs = {}
        for g in pairs(applied[n] or {}) do gs[#gs + 1] = g end
        table.sort(gs)
        log(('[%d] %s  discord:%s  %s'):format(n, GetPlayerName(n) or '?', discordId(n) or 'none', #gs > 0 and table.concat(gs, ', ') or '(no groups)'))
        any = true
    end
    if not any then log('Nobody online.') end
end, true)

exports('Refresh', function(src) refresh(src) end)
exports('GetGroups', function(src) local t = {} for g in pairs(applied[tonumber(src)] or {}) do t[#t + 1] = g end return t end)
