-- TSRP Core: Discord role sync (server only). Configured in config/discord.lua.
--
-- Reads each player's roles from the Discord REST API with a bot token and turns them
-- into groups. Nothing is written to the database: Discord groups are applied live when
-- a character's permissions are built (server/permissions.lua -> Rebuild), so removing
-- a role on Discord takes the matching access away at the next refresh, and giving it
-- back restores it.
--
-- If the token convar is not set, the integration is inactive and tsrp-core behaves
-- exactly as before (groups are assigned by hand only).

TSRP = TSRP or {}
TSRP.Integrations = TSRP.Integrations or {}

local Discord = {}
TSRP.Integrations.Discord = Discord

local API = 'https://discord.com/api/v10'
local EMPTY = { roles = {}, account = {}, unlocked = {}, blocked = {}, signature = '' }

local function cfg() return Config.Discord or {} end

local function decode(body)
    if type(body) ~= "string" or body == "" then return nil end
    local ok, data = pcall(json.decode, body)
    return ok and type(data) == "table" and data or nil
end

function Discord.Token()
    local c = cfg()
    if not c.Enabled then return nil end
    local token = GetConvar(c.TokenConvar or 'tsrp_discord_token', '')
    if type(token) ~= 'string' or token == '' then return nil end
    return token
end

function Discord.Active()
    return Discord.Token() ~= nil and type(cfg().GuildId) == 'string' and cfg().GuildId ~= ''
end

---------------------------------------------------------------------------
-- Pure mapping (unit tested)
---------------------------------------------------------------------------

local function expandSet(defs, names, into)
    into = into or {}
    if #names == 0 then return into end
    local expanded = TSRP.Groups.Expand(defs, names)
    for _, e in ipairs(expanded) do into[e.name] = true end
    return into
end

-- managed = groups that only ever come from Discord (account groups).
-- gated   = groups a character may only hold while the account has an unlocking role.
function Discord.Sets(defs)
    local managed, unlockNames = {}, {}
    for _, role in ipairs(cfg().Roles or {}) do
        for _, g in ipairs(role.groups or {}) do managed[g] = true end
        for _, g in ipairs(role.unlocks or {}) do unlockNames[#unlockNames + 1] = g end
    end
    local gated = expandSet(defs, unlockNames)
    return managed, gated
end

-- roleIds: array of Discord role ID strings. Returns the account's Discord info.
function Discord.Compute(roleIds, defs)
    local have = {}
    for _, id in ipairs(roleIds or {}) do have[tostring(id)] = true end

    local accountSet, unlockNames, blocked = {}, {}, {}
    for _, role in ipairs(cfg().Roles or {}) do
        if have[tostring(role.id)] then
            for _, g in ipairs(role.groups or {}) do accountSet[g] = true end
            for _, g in ipairs(role.unlocks or {}) do unlockNames[#unlockNames + 1] = g end
            for _, g in ipairs(role.blocks or {}) do blocked[g] = true end
        end
    end
    local account = {}
    for g in pairs(accountSet) do account[#account + 1] = g end
    table.sort(account)
    local unlocked = expandSet(defs, unlockNames)

    local function keys(set)
        local out = {}
        for k in pairs(set) do out[#out + 1] = k end
        table.sort(out)
        return table.concat(out, ',')
    end
    return {
        roles = have,
        account = account,
        unlocked = unlocked,
        blocked = blocked,
        signature = table.concat(account, ',') .. '|' .. keys(unlocked) .. '|' .. keys(blocked),
    }
end

-- True if group, or anything it inherits, is blocked.
function Discord.IsBlocked(defs, group, blocked)
    if not blocked or next(blocked) == nil then return false end
    for _, e in ipairs(TSRP.Groups.Expand(defs, { group })) do
        if blocked[e.name] then return true end
    end
    return false
end

-- The groups a character really gets: its own groups minus Discord-managed ones,
-- minus department groups the account hasn't unlocked, plus the account's Discord
-- groups, minus anything blocked. Returns the sorted list and the dropped names.
function Discord.Apply(defs, characterGroups, info)
    info = info or EMPTY
    local managed, gated = Discord.Sets(defs)
    local out, seen, dropped = {}, {}, {}
    local function add(g)
        if seen[g] then return end
        seen[g] = true
        if Discord.IsBlocked(defs, g, info.blocked) then
            dropped[#dropped + 1] = g
        else
            out[#out + 1] = g
        end
    end
    for _, g in ipairs(characterGroups or {}) do
        if managed[g] then
            dropped[#dropped + 1] = g
        elseif gated[g] and not info.unlocked[g] then
            dropped[#dropped + 1] = g
        else
            add(g)
        end
    end
    for _, g in ipairs(info.account or {}) do add(g) end
    table.sort(out)
    return out, dropped
end

-- Used by Permissions.Rebuild.
function Discord.EffectiveGroups(player)
    if not Discord.Active() then return player.groups end
    return (Discord.Apply(TSRP.Groups.defs, player.groups, player.discordInfo))
end

-- Used by Permissions.AssignGroup. Returns true, or false + error code.
function Discord.CheckAssign(characterId, group)
    if not Discord.Active() then return true end
    local managed, gated = Discord.Sets(TSRP.Groups.defs)
    if managed[group] then return false, TSRP.Errors.DiscordManaged end
    if gated[group] then
        local identifier = TSRP.DB.scalar('SELECT identifier FROM tsrp_characters WHERE id = ?', { characterId })
        if identifier == nil then return false, TSRP.Errors.Database end
        local owner = identifier and TSRP.Players.GetByIdentifier(identifier)
        -- Only checked while the owner is online and their roles are known; otherwise
        -- the assignment is stored and enforced when they next load in.
        if owner and owner.discordInfo and not owner.discordInfo.unlocked[group] then
            return false, TSRP.Errors.DiscordRoleRequired
        end
    end
    return true
end

---------------------------------------------------------------------------
-- Applying results to players
---------------------------------------------------------------------------

function Discord.GetDiscordId(src)
    local id = GetPlayerIdentifierByType(tostring(src), 'discord')
    if type(id) ~= 'string' then return nil end
    id = id:gsub('^discord:', '')
    if not id:match('^%d+$') then return nil end
    return id
end

-- member: true (in the guild), false (not in the guild), nil (no Discord linked).
function Discord.SetRoles(player, roleIds, discordId, member)
    local info = Discord.Compute(roleIds, TSRP.Groups.defs)
    info.discordId, info.member, info.fetchedAt = discordId, member, os.time()
    local before = player.discordInfo and player.discordInfo.signature
    player.discordInfo = info

    if member == false and cfg().RequireMembership then
        DropPlayer(tostring(player.source), ('You must be in the %s Discord server to play.'):format(Config.ServerName))
        return
    end

    if info.signature ~= before then
        TSRP.Log.Info('Discord sync for %s: groups [%s]', player.name or player.source, table.concat(info.account, ', '))
        if player.characterId then TSRP.Permissions.Rebuild(player) end
    end
end

---------------------------------------------------------------------------
-- HTTP queue (one request at a time, respects Discord rate limits)
---------------------------------------------------------------------------

local queue, queued, busy = {}, {}, false
local lastAuthError = 0
local pump

local function authError(status)
    if os.time() - lastAuthError < 60 then return end
    lastAuthError = os.time()
    if status == 401 then
        TSRP.Log.Error('Discord sync: the bot token is invalid (401). Reset it and update %s in server.cfg.', cfg().TokenConvar)
    else
        TSRP.Log.Error('Discord sync: the bot cannot read guild %s (%d). Is it in the server?', cfg().GuildId, status)
    end
end

local function finish(delay)
    busy = false
    SetTimeout(delay or 300, pump)
end

pump = function()
    if busy or #queue == 0 then return end
    local token = Discord.Token()
    if not token then queue, queued = {}, {} return end

    local src = table.remove(queue, 1)
    local session = queued[src]
    queued[src] = nil
    local player = TSRP.Players.Get(src)
    if not player or player.session ~= session then return pump() end

    local discordId = Discord.GetDiscordId(src)
    if not discordId then
        Discord.SetRoles(player, {}, nil, nil)
        return pump()
    end

    busy = true
    local url = ('%s/guilds/%s/members/%s'):format(API, cfg().GuildId, discordId)
    PerformHttpRequest(url, function(status, body)
        local current = TSRP.Players.Get(src)
        local live = current and current.session == session
        if status == 200 then
            local data = decode(body)
            if live then Discord.SetRoles(current, (data and data.roles) or {}, discordId, true) end
            finish()
        elseif status == 404 then
            if live then Discord.SetRoles(current, {}, discordId, false) end
            finish()
        elseif status == 429 then
            local data = decode(body)
            local wait = math.ceil(((data and tonumber(data.retry_after)) or 2) * 1000)
            if live then
                table.insert(queue, 1, src)
                queued[src] = session
            end
            finish(wait)
        elseif status == 401 or status == 403 then
            authError(status) -- keep whatever roles we already had
            finish()
        else
            TSRP.Log.Warn('Discord sync: request for %s failed (%s). Keeping previous roles.', src, tostring(status))
            finish(1000)
        end
    end, 'GET', '', { ['Authorization'] = 'Bot ' .. token })
end

-- Queue a player for a role refresh. Safe to call often; duplicates are ignored.
function Discord.Queue(player)
    if not player or not Discord.Active() then return end
    if queued[player.source] then return end
    queued[player.source] = player.session
    queue[#queue + 1] = player.source
    pump()
end

function Discord.RefreshAll()
    for _, player in pairs(TSRP.Players.All()) do Discord.Queue(player) end
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

-- Returns a list of problems with config/discord.lua (unknown groups etc.).
function Discord.ValidateConfig(defs)
    local problems, seenIds = {}, {}
    local managed = Discord.Sets(defs)
    for i, role in ipairs(cfg().Roles or {}) do
        local label = role.name or ('Roles[' .. i .. ']')
        if type(role.id) ~= 'string' or not role.id:match('^%d+$') then
            problems[#problems + 1] = label .. ': id must be a Discord role ID string'
        elseif seenIds[role.id] then
            problems[#problems + 1] = label .. ': role ID listed twice'
        end
        seenIds[role.id or i] = true
        for _, kind in ipairs({ 'groups', 'unlocks', 'blocks' }) do
            for _, g in ipairs(role[kind] or {}) do
                if not defs[g] then problems[#problems + 1] = ('%s: %s refers to unknown group "%s"'):format(label, kind, g) end
            end
        end
        for _, g in ipairs(role.unlocks or {}) do
            if managed[g] then problems[#problems + 1] = ('%s: "%s" is both an account group and an unlock'):format(label, g) end
        end
    end
    return problems
end

function Discord.Start()
    local c = cfg()
    if not c.Enabled then return end
    for _, problem in ipairs(Discord.ValidateConfig(TSRP.Groups.defs)) do
        TSRP.Log.Warn('config/discord.lua: %s', problem)
    end
    local token = Discord.Token()
    if not token then
        TSRP.Log.Warn('Discord sync is off: set %s in server.cfg. Groups can only be assigned by hand until then.', c.TokenConvar)
        return
    end

    PerformHttpRequest(('%s/guilds/%s'):format(API, c.GuildId), function(status, body)
        if status == 200 then
            local data = decode(body)
            TSRP.Log.Info('^2Discord sync connected^7 to %s.', data and data.name or c.GuildId)
        elseif status == 401 or status == 403 or status == 404 then
            authError(status == 404 and 403 or status)
        else
            TSRP.Log.Warn('Discord sync: could not reach Discord (%s). Will keep retrying.', tostring(status))
        end
    end, 'GET', '', { ['Authorization'] = 'Bot ' .. token })

    CreateThread(function()
        while true do
            Wait(math.max(60, tonumber(c.RefreshSeconds) or 300) * 1000)
            Discord.RefreshAll()
        end
    end)
end
