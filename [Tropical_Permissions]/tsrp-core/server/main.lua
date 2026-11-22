-- TSRP Core: server bootstrap and player connection lifecycle.

TSRP = TSRP or {}
TSRP.Ready = false

local Log = TSRP.Log

local function registerConfigNodes()
    for node, description in pairs(Config.PermissionNodes or {}) do
        if not TSRP.Permissions.RegisterNode(node, description, 'tsrp-core') then
            Log.Warn('Invalid permission node in config/permissions.lua: %s', tostring(node))
        end
    end
end

local function adoptConnectedPlayers()
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        if src and not TSRP.Players.Get(src) then
            local player, err = TSRP.Players.Create(src)
            if not player then
                Log.Warn('Could not adopt connected player %s: %s', src, tostring(err))
            end
        end
    end
end

local function initialize()
    Log.Info('Starting TSRP Core %s...', TSRP.Version)

    if GetConvar('onesync', 'off') == 'off' then
        Log.Warn('OneSync appears to be off. TSRP Core reads positions server-side and needs OneSync.')
    end

    if not TSRP.Database.Initialize() then
        Log.Error('Database initialisation failed. TSRP Core is NOT ready and will refuse connections.')
        return
    end

    if not TSRP.Groups.LoadAll() then
        Log.Error('Could not load groups. TSRP Core is NOT ready.')
        return
    end
    TSRP.Groups.Seed()

    for _, group in ipairs(Config.DefaultCharacterGroups or {}) do
        if not TSRP.Groups.Exists(group) then
            Log.Warn('Default character group "%s" does not exist.', group)
        end
    end

    registerConfigNodes()
    TSRP.Integrations.Discord.Start()
    TSRP.Commands.Register()
    TSRP.Persistence.Start()

    if Config.Logging.Webhook and Config.Logging.Webhook.Enabled then
        Log.AddSink(TSRP.Integrations.Webhook.Send)
    end

    if #(Config.Bootstrap.Licenses or {}) == 0 and not Config.Bootstrap.Ace then
        Log.Warn('No bootstrap admins configured (config/bootstrap.lua). Use the server console: tsrp addgroup <charId> owner')
    end

    if GetResourceState(Config.Appearance.Resource) ~= 'started' then
        Log.Warn('%s is not started. New characters will use default freemode peds.', Config.Appearance.Resource)
    end

    adoptConnectedPlayers()

    TSRP.Ready = true
    Log.Info('^2Ready.^7 %d group(s) loaded.', TSRP.Utils.Count(TSRP.Groups.defs))
    TriggerEvent(TSRP.ServerEvents.Ready)
end

TSRP.DB.onReady(function()
    CreateThread(initialize)
end)

---------------------------------------------------------------------------
-- Connections
---------------------------------------------------------------------------

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update(('Connecting to %s...'):format(Config.ServerName))

    local waited = 0
    while not TSRP.Ready and waited < 20000 do
        Wait(500)
        waited = waited + 500
    end
    if not TSRP.Ready then
        deferrals.done(('%s is still starting up. Please try again in a minute.'):format(Config.ServerName))
        return
    end

    local identifier = TSRP.Players.GetIdentifier(src)
    if not identifier then
        deferrals.done('No Rockstar license was found for your account. Restart FiveM and try again.')
        return
    end

    if Config.Discord and Config.Discord.RequireDiscord and TSRP.Integrations.Discord.Active()
        and not TSRP.Integrations.Discord.GetDiscordId(src) then
        deferrals.done('Open Discord before launching FiveM so your Discord account is linked, then try again.')
        return
    end

    if TSRP.Players.IdentifierInUse(identifier) then
        deferrals.done('This account is already connected to the server.')
        return
    end

    deferrals.done()
end)

AddEventHandler('playerJoining', function()
    local src = source
    local waited = 0
    while not TSRP.Ready and waited < 30000 do
        Wait(500)
        waited = waited + 500
    end
    if not TSRP.Ready or TSRP.Players.Get(src) then return end -- adopted during initialise
    local player, err = TSRP.Players.Create(src)
    if not player then
        if err == 'duplicate' then
            DropPlayer(tostring(src), 'This account is already connected to the server.')
        elseif err ~= 'dropped' then
            Log.Error('Could not create player object for %s: %s', src, tostring(err))
        end
    end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local player = TSRP.Players.Get(src)
    if not player then return end
    if player.characterId then
        TSRP.Characters.Unload(player, 'dropped')
    end
    TSRP.Players.Touch(player.identifier)
    TSRP.Players.Remove(src)
    Log.Debug('Player %s left (%s).', src, tostring(reason))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    -- Database calls cannot be awaited here; queue them on oxmysql.
    local saved = TSRP.Persistence.SaveAll(true)
    for src in pairs(TSRP.Players.All()) do
        SetPlayerRoutingBucket(tostring(src), 0)
    end
    if saved > 0 then Log.Info('Queued saves for %d character(s).', saved) end
end)
