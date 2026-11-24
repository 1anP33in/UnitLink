---------------------------------------------------------------------
-- UnitLink-Perms: Discord roles -> ACE groups
--
-- Replace the example IDs below with IDs from your own Discord server.
-- Enable Discord Developer Mode, then right-click your server or role
-- and choose "Copy ID". Do not put your bot token in this file.
---------------------------------------------------------------------
Config = {}

Config.GuildId = 'YOUR_DISCORD_GUILD_ID'
Config.TokenConvar = 'unitlink_discord_token'
Config.RefreshSeconds = 300
Config.Command = 'ulperms'
Config.Log = true

---------------------------------------------------------------------
-- ACE groups and permissions. These are created when the resource
-- starts. Add groups here before referring to them in Config.Roles.
--
-- The three small examples below demonstrate a normal department role,
-- a department supervisor role, and an administrator role.
---------------------------------------------------------------------
Config.Groups = {
    ['group.police']            = { 'unitlink.police.duty' },
    ['group.police_supervisor'] = { 'unitlink.police.duty', 'unitlink.police.supervisor' },
    ['group.unitlink_admin']    = { 'unitlink.admin' },
}

---------------------------------------------------------------------
-- Discord role ID -> ACE groups.
--
-- Replace each EXAMPLE_* value with a real Discord role ID. Keep role
-- IDs quoted: Discord IDs are too large for Lua numbers. A role may
-- grant `groups`, prevent `blocks`, or do both. Blocked groups always
-- win, even if another role grants them.
---------------------------------------------------------------------
Config.Roles = {
    -- Basic police officer: grants on-duty access.
    { id = 'EXAMPLE_POLICE_ROLE_ID', name = 'Police Officer', groups = { 'group.police' } },

    -- Police supervisor: includes duty access and supervisor actions.
    { id = 'EXAMPLE_POLICE_SUPERVISOR_ROLE_ID', name = 'Police Supervisor', groups = { 'group.police_supervisor' } },

    -- Administrator: grants access to the UnitLink admin dashboard.
    { id = 'EXAMPLE_ADMIN_ROLE_ID', name = 'UnitLink Administrator', groups = { 'group.unitlink_admin' } },

    -- Optional blacklist: removes all police access while the role is held.
    { id = 'EXAMPLE_POLICE_BLACKLIST_ROLE_ID', name = 'Police Blacklist', blocks = {
        'group.police', 'group.police_supervisor'
    } },
}
