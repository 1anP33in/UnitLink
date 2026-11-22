-- TSRP Core: connected player registry and account identification.
--
-- The player object is internal and mutable. Other resources only ever receive copies
-- through the exports in server/api.lua.

TSRP = TSRP or {}
local Players = {}
TSRP.Players = Players

local players = {}      -- [src] = player
local byIdentifier = {} -- [identifier] = src
local byCharacter = {}  -- [characterId] = src
local sessionCounter = 0

-- Server-authoritative account identifier. Never taken from client input.
function Players.GetIdentifier(src)
    local idType = Config.IdentifierType or 'license'
    local identifier = GetPlayerIdentifierByType(tostring(src), idType)
    if identifier and identifier ~= '' then return identifier end
    return nil
end

function Players.IsConnected(src)
    return src and GetPlayerName(tostring(src)) ~= nil
end

function Players.Get(src)
    return players[tonumber(src) or -1]
end

function Players.All()
    return players
end

function Players.GetByIdentifier(identifier)
    local src = byIdentifier[identifier]
    return src and players[src] or nil
end

function Players.GetSourceByCharacterId(characterId)
    return byCharacter[characterId]
end

-- True while the player object is the same session it was when an async operation
-- started (protects against a disconnect/reconnect during a database await).
function Players.IsCurrent(player)
    return player ~= nil and players[player.source] == player
end

-- Is another live session using this identifier?
function Players.IdentifierInUse(identifier)
    local src = byIdentifier[identifier]
    if not src then return false end
    if Players.IsConnected(src) then return true end
    -- Stale entry (dropped without cleanup); clear it.
    Players.Remove(src)
    return false
end

function Players.IsBootstrap(src)
    if not src or src == 0 then return true end
    local player = players[src]
    local identifier = player and player.identifier or Players.GetIdentifier(src)
    if identifier then
        for _, allowed in ipairs(Config.Bootstrap.Licenses or {}) do
            if allowed == identifier then return true end
        end
    end
    if Config.Bootstrap.Ace and IsPlayerAceAllowed(tostring(src), Config.Bootstrap.Ace) then
        return true
    end
    return false
end

-- Create (or refresh) the account row and the in-memory player object.
function Players.Create(src)
    src = tonumber(src)
    local identifier = Players.GetIdentifier(src)
    if not identifier then
        return nil, 'no_identifier'
    end

    local existing = byIdentifier[identifier]
    if existing and existing ~= src and Players.IsConnected(existing) then
        return nil, 'duplicate'
    end
    if existing and existing ~= src then Players.Remove(existing) end

    local name = (GetPlayerName(tostring(src)) or 'unknown'):sub(1, 64)
    local accountId = TSRP.DB.insert(
        'INSERT INTO tsrp_players (identifier, name, last_seen) VALUES (?, ?, NOW()) ' ..
        'ON DUPLICATE KEY UPDATE id = LAST_INSERT_ID(id), name = VALUES(name), last_seen = NOW()',
        { identifier, name })
    if not accountId then
        return nil, TSRP.Errors.Database
    end

    -- The player may have dropped during the await.
    if not Players.IsConnected(src) then return nil, 'dropped' end

    sessionCounter = sessionCounter + 1
    local player = {
        source = src,
        identifier = identifier,
        accountId = accountId,
        name = name,
        session = sessionCounter,
        state = TSRP.States.Connecting,
        characterId = nil,
        character = nil,
        groups = {},          -- direct group names (array)
        overrides = {},       -- [node] = true/false
        effective = nil,      -- permission cache (server/permissions.lua)
        spawned = false,
        appearanceEdit = nil, -- open appearance session { isNew = bool }
        busy = false,
        joinedAt = os.time(),
        lastCharacterId = nil,
    }
    players[src] = player
    byIdentifier[identifier] = src
    TSRP.Integrations.Discord.Queue(player)
    return player
end

function Players.SetCharacter(player, characterId)
    if player.characterId then byCharacter[player.characterId] = nil end
    player.characterId = characterId
    if characterId then byCharacter[characterId] = player.source end
end

function Players.Remove(src)
    local player = players[src]
    if not player then return end
    if player.characterId and byCharacter[player.characterId] == src then
        byCharacter[player.characterId] = nil
    end
    if byIdentifier[player.identifier] == src then
        byIdentifier[player.identifier] = nil
    end
    players[src] = nil
    TSRP.RateLimit.Clear(src)
end

function Players.Touch(identifier)
    TSRP.DB.updateAsync('UPDATE tsrp_players SET last_seen = NOW() WHERE identifier = ?', { identifier })
end

-- Copy safe to hand to other server resources.
function Players.Snapshot(player)
    if not player then return nil end
    return {
        source = player.source,
        identifier = player.identifier,
        accountId = player.accountId,
        name = player.name,
        state = player.state,
        loaded = player.characterId ~= nil,
        spawned = player.spawned,
        characterId = player.characterId,
        character = player.character and TSRP.Characters.Public(player.character) or nil,
        groups = TSRP.Utils.DeepCopy(player.groups),
        permissions = player.effective and TSRP.Permissions.ListAllowed(player.effective) or {},
    }
end

function Players.Count()
    local total, loaded = 0, 0
    for _, p in pairs(players) do
        total = total + 1
        if p.characterId then loaded = loaded + 1 end
    end
    return total, loaded
end
