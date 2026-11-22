-- UnitLink Core: shared constants.

UnitLink = UnitLink or {}

UnitLink.Version = '1.0.0'
UnitLink.ResourceName = GetCurrentResourceName and GetCurrentResourceName() or 'UnitLink-Core'

-- The only client -> server network event. Every client request goes through the
-- callback router in server/callbacks.lua, which validates and rate-limits it.
UnitLink.NetEvents = {
    Callback = 'unitlink-core:server:cb',
    CallbackResponse = 'unitlink-core:client:cb',
}

-- Local server events other resources can listen to with AddEventHandler.
-- Never register these with RegisterNetEvent: clients must not be able to fake them.
UnitLink.ServerEvents = {
    Ready = 'unitlink-core:server:ready',
    CharacterCreated = 'unitlink-core:server:characterCreated',
    CharacterDeleted = 'unitlink-core:server:characterDeleted',
    CharacterLoaded = 'unitlink-core:server:characterLoaded',
    CharacterSpawned = 'unitlink-core:server:characterSpawned',
    CharacterUnloaded = 'unitlink-core:server:characterUnloaded',
    CharacterSwitched = 'unitlink-core:server:characterSwitched',
    PermissionsUpdated = 'unitlink-core:server:permissionsUpdated',
    GroupAssigned = 'unitlink-core:server:groupAssigned',
    GroupRemoved = 'unitlink-core:server:groupRemoved',
    GroupsChanged = 'unitlink-core:server:groupsChanged',
    MetadataUpdated = 'unitlink-core:server:metadataUpdated',
    Audit = 'unitlink-core:server:audit',
}

-- Server -> client events (and local client events re-fired for other client scripts).
UnitLink.ClientEvents = {
    CharacterLoaded = 'unitlink-core:client:characterLoaded',
    CharacterSpawned = 'unitlink-core:client:characterSpawned',
    CharacterUnloaded = 'unitlink-core:client:characterUnloaded',
    PermissionsUpdated = 'unitlink-core:client:permissionsUpdated',
    OpenAppearance = 'unitlink-core:client:openAppearance',
    OpenAdmin = 'unitlink-core:client:openAdmin',
    EnterSelection = 'unitlink-core:client:enterSelection',
    Notify = 'unitlink-core:client:notify',
}

-- Player session states (server authoritative).
UnitLink.States = {
    Connecting = 'connecting', -- object exists, not yet at character selection
    Selecting = 'selecting',   -- at the character selection screen
    Creating = 'creating',     -- character loaded, appearance creator open
    Spawning = 'spawning',     -- character + appearance loaded, choosing a spawn
    Active = 'active',         -- in the world
}

UnitLink.Patterns = {
    PermissionNode = '^[a-z0-9_%-]+$',  -- per segment; see Utils.IsValidPermissionNode
    GroupName = '^[a-z][a-z0-9_]*$',
    MetadataKey = '^[%w_%-%.]+$',
    Model = '^[%w_]+$',
}
