-- UnitLink Core: default permission groups (server only).
--
-- These are seeded into the database. After that the database is the source of truth
-- and groups are managed from the admin dashboard.
--
-- SeedMode:
--   'missing' : insert groups that do not exist yet; never touch existing ones (default)
--   'force'   : also overwrite label/description/priority/inherits/permissions of the
--               groups listed here on every start (dashboard edits to them are lost)
--
-- inherits = groups whose permissions this group also receives. A senior group lists
-- the group directly below it, e.g. leo_command inherits leo_supervisor.
--
-- priority drives the admin hierarchy: an admin can only assign groups with a lower
-- priority than their own highest group.

Config = Config or {}

Config.GroupSeedMode = 'missing'

-- Groups every new character receives.
Config.DefaultCharacterGroups = { 'civilian' }

Config.Groups = {
    -- Staff ladder. Each tier inherits the one below it, down to `staff`, so blocking
    -- `staff` (Blacklisted / Suspended Staff on Discord) removes every staff tier.
    -- These come from Discord roles (config/discord.lua) and apply to every character.
    owner = {
        label = 'Owner',
        description = 'Server owner. Full access. Discord: UnitLink | Owners',
        priority = 100,
        inherits = { 'co_owner' },
        permissions = { '*' },
        system = true,
    },
    co_owner = {
        label = 'Co-Owner',
        description = 'Discord: UnitLink | Co-Owners',
        priority = 96,
        inherits = { 'head_management' },
        permissions = { '*' },
    },
    head_management = {
        label = 'Head of Management',
        description = 'Discord: UnitLink | Head Of Management',
        priority = 93,
        inherits = { 'management' },
        permissions = {},
    },
    management = {
        label = 'Management',
        description = 'Discord: UnitLink | Management, and the Development/General/Department/Staff Manager roles',
        priority = 90,
        inherits = { 'junior_management' },
        permissions = { 'unitlink.admin.groups', 'unitlink.admin.identifiers' },
        system = true,
    },
    junior_management = {
        label = 'Junior Management',
        description = 'Discord: UnitLink | Junior Management, Department/Staff Coordinator, Management Assistant',
        priority = 88,
        inherits = { 'trial_management' },
        permissions = { 'unitlink.admin.audit' },
    },
    trial_management = {
        label = 'Trial Management',
        description = 'Discord: UnitLink | Trial Management',
        priority = 86,
        inherits = { 'head_admin' },
        permissions = {},
    },
    head_admin = {
        label = 'Head Administrator',
        description = 'Discord: UnitLink | Head Administrator',
        priority = 84,
        inherits = { 'senior_admin' },
        permissions = {},
    },
    senior_admin = {
        label = 'Senior Administrator',
        description = 'Discord: UnitLink | Senior Administrator',
        priority = 82,
        inherits = { 'admin' },
        permissions = {},
    },
    admin = {
        label = 'Administrator',
        description = 'Discord: UnitLink | Administrator',
        priority = 80,
        inherits = { 'head_moderator' },
        permissions = { 'unitlink.admin.characters', 'unitlink.admin.permissions', 'unitlink.appearance.edit' },
        system = true,
    },
    head_moderator = {
        label = 'Head Moderator',
        description = 'Discord: UnitLink | Head Moderator',
        priority = 76,
        inherits = { 'senior_moderator' },
        permissions = {},
    },
    senior_moderator = {
        label = 'Senior Moderator',
        description = 'Discord: UnitLink | Senior Moderator',
        priority = 74,
        inherits = { 'moderator' },
        permissions = {},
    },
    moderator = {
        label = 'Moderator',
        description = 'Discord: UnitLink | Moderator',
        priority = 70,
        inherits = { 'trial_moderator' },
        permissions = {},
        system = true,
    },
    trial_moderator = {
        label = 'Trial Moderator',
        description = 'Discord: UnitLink | Trial Moderator',
        priority = 66,
        inherits = { 'support' },
        permissions = {},
    },
    support = {
        label = 'Support Team',
        description = 'Can open the dashboard and see who is online. Discord: UnitLink | Support Team',
        priority = 60,
        inherits = { 'staff' },
        permissions = { 'unitlink.admin.access', 'unitlink.admin.players' },
    },
    staff = {
        label = 'Staff',
        description = 'Base for every staff tier. Discord: UnitLink | Staff Team',
        priority = 55,
        inherits = {},
        permissions = { 'unitlink.staff' },
    },
    developer = {
        label = 'Development Team',
        description = 'Developer tools (unitlink.dev.*). Discord: UnitLink | Development Team',
        priority = 50,
        inherits = {},
        permissions = { 'unitlink.dev.*' },
    },

    leo_command = {
        label = 'LEO High Command',
        description = 'Command over every police department. Discord: UnitLink | Department High Command',
        priority = 40,
        inherits = { 'leo_supervisor' },
        permissions = { 'unitlink.police.*' },
    },
    leo_supervisor = {
        label = 'LEO Supervisor',
        description = 'Shared base for every police supervisor (SASP, BCSO, LSP, DHS).',
        priority = 35,
        inherits = { 'leo' },
        permissions = { 'unitlink.police.supervisor', 'unitlink.police.roster' },
    },
    leo = {
        label = 'Law Enforcement',
        description = 'Shared base for every police department (SASP, BCSO, LSP, DHS). Assign the department group instead.',
        priority = 30,
        inherits = {},
        permissions = { 'unitlink.police.duty', 'unitlink.police.dispatch' },
    },

    safr_command = {
        label = 'SAFR Command',
        description = 'Command over fire and EMS. Discord: UnitLink | Department High Command',
        priority = 40,
        inherits = { 'safr_supervisor' },
        permissions = { 'unitlink.safr.*' },
    },
    safr_supervisor = {
        label = 'SAFR Supervisor',
        description = 'Shared base for fire and EMS supervisors (SAFD).',
        priority = 35,
        inherits = { 'safr' },
        permissions = { 'unitlink.safr.supervisor' },
    },
    safr = {
        label = 'SAFR',
        description = 'Shared base for fire and EMS (SAFD). Assign the department group instead.',
        priority = 30,
        inherits = {},
        permissions = { 'unitlink.safr.duty', 'unitlink.safr.dispatch' },
    },

    -- Department groups are generated below from Config.Departments.

    civilian = {
        label = 'Civilian',
        description = 'Default group for every character.',
        priority = 0,
        inherits = {},
        permissions = { 'unitlink.character.switch', 'unitlink.civilian.jobs', 'unitlink.civilian.businesses' },
        system = true,
    },
}

-- Departments.
--
-- Each department gets three groups: <id>, <id>_supervisor and <id>_command. They sit on
-- top of the shared base groups above, so anything gated on unitlink.police.duty or
-- unitlink.safr.duty (spawn points, other resources) works for every department:
--
--   sasp_command ─► sasp_supervisor ─► sasp ─► leo
--                   sasp_supervisor ─► leo_supervisor
--
-- Department command gets unitlink.<id>.* for its own department only. Cross-department
-- command (Discord "UnitLink | Department High Command") is still leo_command / safr_command.
--
-- discord = the matching Discord role names, for reference when assigning groups.
Config.Departments = {
    { id = 'sasp', label = 'San Andreas State Police', short = 'SASP', base = 'leo',
      discord = { 'San Andreas State Police', 'SASP | Supervisor', 'SASP | High Command' } },
    { id = 'bcso', label = "Blaine County Sheriff's Office", short = 'BCSO', base = 'leo',
      discord = { "Blaine County Sheriff's Office", 'BCSO | Supervisor', 'BCSO | High Command' } },
    { id = 'lsp', label = 'Los Santos Police', short = 'LSP', base = 'leo',
      discord = { 'Los Santos Police', 'LSP | Supervisor', 'LSP | High Command' } },
    { id = 'dhs', label = 'Department of Homeland Security', short = 'DHS', base = 'leo',
      discord = { 'TRP | Department of Homeland Security', 'DHS | Supervisor', 'DHS | High Command' } },
    { id = 'safd', label = 'San Andreas Fire Department', short = 'SAFD', base = 'safr',
      discord = { 'San Andreas Fire Department', 'SAFD | Supervisor', 'SAFD | High Command' } },
    -- FAA has no shared base group: it is neither police nor fire.
    { id = 'faa', label = 'Federal Aviation Administration', short = 'FAA', base = nil,
      discord = { 'Federal Aviation Administration', 'FAA | Supervisor', 'FAA | High Command' } },
}

for _, dept in ipairs(Config.Departments) do
    local id, base = dept.id, dept.base
    Config.Groups[id] = {
        label = dept.label,
        description = dept.short .. ' members. Discord: ' .. dept.discord[1],
        priority = 30,
        inherits = base and { base } or {},
        permissions = { 'unitlink.' .. id .. '.duty' },
    }
    Config.Groups[id .. '_supervisor'] = {
        label = dept.short .. ' Supervisor',
        description = dept.short .. ' supervisors. Discord: ' .. dept.discord[2],
        priority = 35,
        inherits = base and { id, base .. '_supervisor' } or { id },
        permissions = { 'unitlink.' .. id .. '.supervisor', 'unitlink.' .. id .. '.roster' },
    }
    Config.Groups[id .. '_command'] = {
        label = dept.short .. ' High Command',
        description = dept.short .. ' high command. Discord: ' .. dept.discord[3],
        priority = 40,
        inherits = { id .. '_supervisor' },
        permissions = { 'unitlink.' .. id .. '.*' },
    }
end

-- Department permission nodes, so they show up in the admin dashboard's node list.
-- (config/permissions.lua loads before this file.)
Config.PermissionNodes = Config.PermissionNodes or {}
for _, dept in ipairs(Config.Departments) do
    local p = 'unitlink.' .. dept.id .. '.'
    Config.PermissionNodes[p .. 'duty'] = 'Go on duty as ' .. dept.short
    Config.PermissionNodes[p .. 'supervisor'] = dept.short .. ' supervisor tools'
    Config.PermissionNodes[p .. 'roster'] = 'View the ' .. dept.short .. ' roster'
end

-- Department extras. Like the department groups, Discord unlocks these and staff
-- assign them to a character.
Config.Groups.faa_pilot = {
    label = 'FAA Department Pilot',
    description = 'Can fly department aircraft. Discord: FAA | Department Pilot',
    priority = 32,
    inherits = { 'faa' },
    permissions = { 'unitlink.faa.pilot' },
}
Config.Groups.fto_assistant = {
    label = 'Assistant Field Instructor',
    description = 'Discord: UnitLink | Assistant Field Instructor',
    priority = 33,
    inherits = {},
    permissions = { 'unitlink.police.fto.assist' },
}
Config.Groups.fto = {
    label = 'Field Training Instructor',
    description = 'Discord: UnitLink | Field Training Instructor',
    priority = 34,
    inherits = { 'fto_assistant' },
    permissions = { 'unitlink.police.fto.*' },
}

-- Whitelists, donator tiers and perk packs. These come from Discord roles and apply
-- to every character on the account. Other resources check the nodes, e.g.
--   exports['UnitLink-Core']:HasPermission(src, 'unitlink.pack.sports')
local function perk(name, label, discordRole, nodes, inherits, priority)
    Config.Groups[name] = {
        label = label,
        description = 'Discord: ' .. discordRole,
        priority = priority or 10,
        inherits = inherits or {},
        permissions = nodes,
    }
end

perk('whitelist_leo',  'Whitelisted LEO',          'UnitLink | Whitelisted LEO',          { 'unitlink.whitelist.leo' })
perk('whitelist_gang', 'Whitelisted Gang Member',  'UnitLink | Whitelisted Gang Member',  { 'unitlink.whitelist.gang' })

perk('donator',      'Donator',       'UnitLink | Donator',           { 'unitlink.donator' }, nil, 12)
perk('vip_premium',  'Premium VIP',   'Donator | Premium VIP',    { 'unitlink.vip.premium' },  { 'donator' },     13)
perk('vip_elite',    'Elite VIP',     'Donator | Elite VIP',      { 'unitlink.vip.elite' },    { 'vip_premium' }, 14)
perk('vip_ultimate', 'Ultimate VIP',  'Donator | Ultimate VIP',   { 'unitlink.vip.ultimate' }, { 'vip_elite' },   15)

perk('pack_sports',      'Sports Car Pack',     'Donator | Sports Car Pack',  { 'unitlink.pack.sports' })
perk('pack_muscle',      'Muscle Car Pack',     'Donator | Muscle Car Pack',  { 'unitlink.pack.muscle' })
perk('pack_leo_1',       'LEO Pack #1',         'Donator | LEO Pack #1',      { 'unitlink.pack.leo1' })
perk('pack_leo_2',       'LEO Pack #2',         'Donator | LEO Pack #2',      { 'unitlink.pack.leo2' })
perk('pack_leo_3',       'LEO Pack #3',         'Donator | LEO Pack #3',      { 'unitlink.pack.leo3' })
perk('pack_weapons',     'Weapons Pack',        'Donator | Weapons Pack',     { 'unitlink.pack.weapons' })
perk('pack_owners_cars', 'Owners Car Pack',     'UnitLink | Owners Car Pack',     { 'unitlink.pack.owners' })
perk('speed_bypass',     'Owners Speed Bypass', 'UnitLink | Owners Speed Bypass', { 'unitlink.vehicle.speedbypass' })
perk('booster',          'Server Booster',      'UnitLink | Server Booster',      { 'unitlink.booster' })

-- Register the nodes above so they show up in the dashboard.
local extraNodes = {
    ['unitlink.staff'] = 'Member of staff (any tier)',
    ['unitlink.dev.tools'] = 'Developer tools',
    ['unitlink.faa.pilot'] = 'Fly FAA department aircraft',
    ['unitlink.police.fto.assist'] = 'Assistant field training instructor',
    ['unitlink.police.fto.train'] = 'Field training instructor',
    ['unitlink.whitelist.leo'] = 'Whitelisted for law enforcement',
    ['unitlink.whitelist.gang'] = 'Whitelisted gang member',
    ['unitlink.donator'] = 'Donator',
    ['unitlink.vip.premium'] = 'Premium VIP',
    ['unitlink.vip.elite'] = 'Elite VIP',
    ['unitlink.vip.ultimate'] = 'Ultimate VIP',
    ['unitlink.pack.sports'] = 'Sports car pack',
    ['unitlink.pack.muscle'] = 'Muscle car pack',
    ['unitlink.pack.leo1'] = 'LEO pack #1',
    ['unitlink.pack.leo2'] = 'LEO pack #2',
    ['unitlink.pack.leo3'] = 'LEO pack #3',
    ['unitlink.pack.weapons'] = 'Weapons pack',
    ['unitlink.pack.owners'] = 'Owners car pack',
    ['unitlink.vehicle.speedbypass'] = 'Bypass vehicle speed limits',
    ['unitlink.booster'] = 'Server booster',
}
for node, description in pairs(extraNodes) do Config.PermissionNodes[node] = description end
