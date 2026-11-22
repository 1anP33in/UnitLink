-- UnitLink Core: server bootstrap and player connection lifecycle.

UnitLink = UnitLink or {}
UnitLink.Ready = false

local Log = UnitLink.Log

local function registerConfigNodes()
    for node, description in pairs(Config.PermissionNodes or {}) do
        if not UnitLink.Permissions.RegisterNode(node, description, 'UnitLink-Core') then
            Log.Warn('Invalid permission node in config/permissions.lua: %s', tostring(node))
        end
    end
end

local function adoptConnectedPlayers()
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        if src and not UnitLink.Players.Get(src) then
            local player, err = UnitLink.Players.Create(src)
            if not player then
                Log.Warn('Could not adopt connected player %s: %s', src, tostring(err))
            end
        end
    end
end

local function initialize()
    Log.Info('Starting UnitLink Core %s...', UnitLink.Version)

    if GetConvar('onesync', 'off') == 'off' then
        Log.Warn('OneSync appears to be off. UnitLink Core reads positions server-side and needs OneSync.')
    end

    if not UnitLink.Database.Initialize() then
        Log.Error('Database initialisation failed. UnitLink Core is NOT ready and will refuse connections.')
        return
    end

    if not UnitLink.Groups.LoadAll() then
        Log.Error('Could not load groups. UnitLink Core is NOT ready.')
        return
    end
    UnitLink.Groups.Seed()

    for _, group in ipairs(Config.DefaultCharacterGroups or {}) do
        if not UnitLink.Groups.Exists(group) then
            Log.Warn('Default character group "%s" does not exist.', group)
        end
    end

    registerConfigNodes()
    UnitLink.Integrations.Discord.Start()
    UnitLink.Commands.Register()
    UnitLink.Persistence.Start()

    if Config.Logging.Webhook and Config.Logging.Webhook.Enabled then
        Log.AddSink(UnitLink.Integrations.Webhook.Send)
    end

    if #(Config.Bootstrap.Licenses or {}) == 0 and not Config.Bootstrap.Ace then
        Log.Warn('No bootstrap admins configured (config/bootstrap.lua). Use the server console: ulcore addgroup <charId> owner')
    end

    if GetResourceState(Config.Appearance.Resource) ~= 'started' then
        Log.Warn('%s is not started. New characters will use default freemode peds.', Config.Appearance.Resource)
    end

    adoptConnectedPlayers()

    UnitLink.Ready = true
    Log.Info('^2Ready.^7 %d group(s) loaded.', UnitLink.Utils.Count(UnitLink.Groups.defs))
    TriggerEvent(UnitLink.ServerEvents.Ready)
end

UnitLink.DB.onReady(function()
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
    while not UnitLink.Ready and waited < 20000 do
        Wait(500)
        waited = waited + 500
    end
    if not UnitLink.Ready then
        deferrals.done(('%s is still starting up. Please try again in a minute.'):format(Config.ServerName))
        return
    end

    local identifier = UnitLink.Players.GetIdentifier(src)
    if not identifier then
        deferrals.done('No Rockstar license was found for your account. Restart FiveM and try again.')
        return
    end

    if Config.Discord and Config.Discord.RequireDiscord and UnitLink.Integrations.Discord.Active()
        and not UnitLink.Integrations.Discord.GetDiscordId(src) then
        deferrals.done('Open Discord before launching FiveM so your Discord account is linked, then try again.')
        return
    end

    if UnitLink.Players.IdentifierInUse(identifier) then
        deferrals.done('This account is already connected to the server.')
        return
    end

    deferrals.done()
end)

AddEventHandler('playerJoining', function()
    local src = source
    local waited = 0
    while not UnitLink.Ready and waited < 30000 do
        Wait(500)
        waited = waited + 500
    end
    if not UnitLink.Ready or UnitLink.Players.Get(src) then return end -- adopted during initialise
    local player, err = UnitLink.Players.Create(src)
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
    local player = UnitLink.Players.Get(src)
    if not player then return end
    if player.characterId then
        UnitLink.Characters.Unload(player, 'dropped')
    end
    UnitLink.Players.Touch(player.identifier)
    UnitLink.Players.Remove(src)
    Log.Debug('Player %s left (%s).', src, tostring(reason))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    -- Database calls cannot be awaited here; queue them on oxmysql.
    local saved = UnitLink.Persistence.SaveAll(true)
    for src in pairs(UnitLink.Players.All()) do
        SetPlayerRoutingBucket(tostring(src), 0)
    end
    if saved > 0 then Log.Info('Queued saves for %d character(s).', saved) end
end)
