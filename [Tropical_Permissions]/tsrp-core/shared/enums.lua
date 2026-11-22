-- TSRP Core: shared enums.

TSRP = TSRP or {}

-- Audit log action names.
TSRP.AuditActions = {
    CharacterCreate = 'character.create',
    CharacterDelete = 'character.delete',
    CharacterLoad = 'character.load',
    CharacterSwitch = 'character.switch',
    CharacterEdit = 'character.edit',
    CharacterMetadata = 'character.metadata',
    AppearanceSave = 'appearance.save',
    GroupAssign = 'group.assign',
    GroupRemove = 'group.remove',
    GroupCreate = 'group.create',
    GroupUpdate = 'group.update',
    GroupDelete = 'group.delete',
    PermissionAllow = 'permission.allow',
    PermissionDeny = 'permission.deny',
    PermissionClear = 'permission.clear',
    AdminOpen = 'admin.open',
    AdminDenied = 'admin.denied',
}

-- Error codes returned to clients and API callers. Clients turn them into text with
-- the locale table; codes are stable for other resources to compare against.
TSRP.Errors = {
    NotReady = 'not_ready',
    RateLimited = 'rate_limited',
    InvalidInput = 'invalid_input',
    InvalidState = 'invalid_state',
    NotFound = 'not_found',
    NotOwner = 'not_owner',
    NoSlots = 'no_slots',
    SlotTaken = 'slot_taken',
    NameTaken = 'name_taken',
    AlreadyActive = 'already_active',
    NoCharacter = 'no_character',
    Unauthorized = 'unauthorized',
    Hierarchy = 'hierarchy',
    Database = 'database_error',
    Internal = 'internal_error',
    Cycle = 'inheritance_cycle',
    UnknownGroup = 'unknown_group',
    GroupExists = 'group_exists',
    GroupInUse = 'group_in_use',
    GroupInherited = 'group_inherited',
    SystemGroup = 'system_group',
    Duplicate = 'duplicate',
    ConfirmMismatch = 'confirm_mismatch',
    SpawnUnavailable = 'spawn_unavailable',
    Timeout = 'timeout',
    DiscordManaged = 'discord_managed',
    DiscordRoleRequired = 'discord_role_required',
}
