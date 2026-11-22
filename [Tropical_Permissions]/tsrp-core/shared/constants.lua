-- TSRP Core: shared constants.

TSRP = TSRP or {}

TSRP.Version = '1.0.0'
TSRP.ResourceName = GetCurrentResourceName and GetCurrentResourceName() or 'tsrp-core'

-- The only client -> server network event. Every client request goes through the
-- callback router in server/callbacks.lua, which validates and rate-limits it.
TSRP.NetEvents = {
    Callback = 'tsrp-core:server:cb',
    CallbackResponse = 'tsrp-core:client:cb',
}

-- Local server events other resources can listen to with AddEventHandler.
-- Never register these with RegisterNetEvent: clients must not be able to fake them.
TSRP.ServerEvents = {
    Ready = 'tsrp-core:server:ready',
    CharacterCreated = 'tsrp-core:server:characterCreated',
    CharacterDeleted = 'tsrp-core:server:characterDeleted',
    CharacterLoaded = 'tsrp-core:server:characterLoaded',
    CharacterSpawned = 'tsrp-core:server:characterSpawned',
    CharacterUnloaded = 'tsrp-core:server:characterUnloaded',
    CharacterSwitched = 'tsrp-core:server:characterSwitched',
    PermissionsUpdated = 'tsrp-core:server:permissionsUpdated',
    GroupAssigned = 'tsrp-core:server:groupAssigned',
    GroupRemoved = 'tsrp-core:server:groupRemoved',
    GroupsChanged = 'tsrp-core:server:groupsChanged',
    MetadataUpdated = 'tsrp-core:server:metadataUpdated',
    Audit = 'tsrp-core:server:audit',
}

-- Server -> client events (and local client events re-fired for other client scripts).
TSRP.ClientEvents = {
    CharacterLoaded = 'tsrp-core:client:characterLoaded',
    CharacterSpawned = 'tsrp-core:client:characterSpawned',
    CharacterUnloaded = 'tsrp-core:client:characterUnloaded',
    PermissionsUpdated = 'tsrp-core:client:permissionsUpdated',
    OpenAppearance = 'tsrp-core:client:openAppearance',
    OpenAdmin = 'tsrp-core:client:openAdmin',
    EnterSelection = 'tsrp-core:client:enterSelection',
    Notify = 'tsrp-core:client:notify',
}

-- Player session states (server authoritative).
TSRP.States = {
    Connecting = 'connecting', -- object exists, not yet at character selection
    Selecting = 'selecting',   -- at the character selection screen
    Creating = 'creating',     -- character loaded, appearance creator open
    Spawning = 'spawning',     -- character + appearance loaded, choosing a spawn
    Active = 'active',         -- in the world
}

TSRP.Patterns = {
    PermissionNode = '^[a-z0-9_%-]+$',  -- per segment; see Utils.IsValidPermissionNode
    GroupName = '^[a-z][a-z0-9_]*$',
    MetadataKey = '^[%w_%-%.]+$',
    Model = '^[%w_]+$',
}
