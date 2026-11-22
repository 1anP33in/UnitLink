-- UnitLink Core: permission node registry and security settings (server only).
--
-- Nodes listed here appear in the admin dashboard's searchable permission list.
-- Other resources can register more at runtime with
--   exports['UnitLink-Core']:RegisterPermissionNode('myres.something', 'Description')
-- Any well-formed node works with HasPermission() whether or not it is registered.

Config = Config or {}

Config.PermissionNodes = {
    -- Administration
    ['unitlink.admin.access']       = 'Open the UnitLink admin dashboard and /ulcore command',
    ['unitlink.admin.players']      = 'View connected players and their active characters',
    ['unitlink.admin.identifiers']  = 'See account identifiers (licenses) in the dashboard',
    ['unitlink.admin.characters']   = 'View and edit character records and metadata',
    ['unitlink.admin.permissions']  = 'Assign groups and permission overrides to characters',
    ['unitlink.admin.groups']       = 'Create, edit and delete permission groups',
    ['unitlink.admin.audit']        = 'Read the administrative audit log',

    -- Character lifecycle
    ['unitlink.character.create']   = 'Reserved for in-character creation flows (selection screen is governed by slots)',
    ['unitlink.character.delete']   = 'Reserved for in-character deletion flows (selection screen is governed by ownership)',
    ['unitlink.character.switch']   = 'Switch to another character without reconnecting',
    ['unitlink.appearance.edit']    = 'Use /appearance to change this character\'s appearance',

    -- Law enforcement
    ['unitlink.police.duty']        = 'Go on duty as law enforcement',
    ['unitlink.police.dispatch']    = 'Use police dispatch tools',
    ['unitlink.police.roster']      = 'View the police roster',
    ['unitlink.police.supervisor']  = 'Police supervisor tools',

    -- Fire / EMS
    ['unitlink.safr.duty']          = 'Go on duty as SAFR',
    ['unitlink.safr.dispatch']      = 'Use SAFR dispatch tools',
    ['unitlink.safr.supervisor']    = 'SAFR supervisor tools',

    -- Civilian
    ['unitlink.civilian.jobs']       = 'Take civilian jobs',
    ['unitlink.civilian.businesses'] = 'Own and run businesses',
}

Config.Security = {
    -- Max inheritance depth when resolving groups (protects against bad data).
    MaxInheritanceDepth = 16,

    -- Admins may only assign groups (and edit characters holding groups) whose
    -- priority is LOWER than their own highest group priority. They may only grant
    -- or deny nodes they themselves have. Bootstrap admins and the console bypass this.
    EnforcePriorityHierarchy = true,
    EnforceGrantOwnership = true,

    -- Mutation exports (AddGroup, GrantPermission, ...) may only be called by these
    -- resources. Empty table = any server resource may call them.
    MutationResourceAllowlist = {},

    -- Rate limits for client requests: { max requests, per milliseconds }.
    RateLimits = {
        global          = { 40, 5000 },
        enterSelection  = { 4, 10000 },
        preview         = { 12, 5000 },
        createCharacter = { 3, 30000 },
        deleteCharacter = { 3, 30000 },
        selectCharacter = { 5, 10000 },
        saveAppearance  = { 5, 10000 },
        spawn           = { 5, 10000 },
        switchCharacter = { 2, 15000 },
        admin           = { 30, 5000 },
        adminMutation   = { 15, 5000 },
    },
}
