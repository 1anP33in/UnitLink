-- TSRP Core: default permission groups (server only).
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
        description = 'Server owner. Full access. Discord: TSRP | Owners',
        priority = 100,
        inherits = { 'co_owner' },
        permissions = { '*' },
        system = true,
    },
    co_owner = {
        label = 'Co-Owner',
        description = 'Discord: TSRP | Co-Owners',
        priority = 96,
        inherits = { 'head_management' },
        permissions = { '*' },
    },
    head_management = {
        label = 'Head of Management',
        description = 'Discord: TSRP | Head Of Management',
        priority = 93,
        inherits = { 'management' },
        permissions = {},
    },
    management = {
        label = 'Management',
        description = 'Discord: TSRP | Management, and the Development/General/Department/Staff Manager roles',
        priority = 90,
        inherits = { 'junior_management' },
        permissions = { 'tsrp.admin.groups', 'tsrp.admin.identifiers' },
        system = true,
    },
    junior_management = {
        label = 'Junior Management',
        description = 'Discord: TSRP | Junior Management, Department/Staff Coordinator, Management Assistant',
        priority = 88,
        inherits = { 'trial_management' },
        permissions = { 'tsrp.admin.audit' },
    },
    trial_management = {
        label = 'Trial Management',
        description = 'Discord: TSRP | Trial Management',
        priority = 86,
        inherits = { 'head_admin' },
        permissions = {},
    },
    head_admin = {
        label = 'Head Administrator',
        description = 'Discord: TSRP | Head Administrator',
        priority = 84,
        inherits = { 'senior_admin' },
        permissions = {},
    },
    senior_admin = {
        label = 'Senior Administrator',
        description = 'Discord: TSRP | Senior Administrator',
        priority = 82,
        inherits = { 'admin' },
        permissions = {},
    },
    admin = {
        label = 'Administrator',
        description = 'Discord: TSRP | Administrator',
        priority = 80,
        inherits = { 'head_moderator' },
        permissions = { 'tsrp.admin.characters', 'tsrp.admin.permissions', 'tsrp.appearance.edit' },
        system = true,
    },
    head_moderator = {
        label = 'Head Moderator',
        description = 'Discord: TSRP | Head Moderator',
        priority = 76,
        inherits = { 'senior_moderator' },
        permissions = {},
    },
    senior_moderator = {
        label = 'Senior Moderator',
        description = 'Discord: TSRP | Senior Moderator',
        priority = 74,
        inherits = { 'moderator' },
        permissions = {},
    },
    moderator = {
        label = 'Moderator',
        description = 'Discord: TSRP | Moderator',
        priority = 70,
        inherits = { 'trial_moderator' },
        permissions = {},
        system = true,
    },
    trial_moderator = {
        label = 'Trial Moderator',
        description = 'Discord: TSRP | Trial Moderator',
        priority = 66,
        inherits = { 'support' },
        permissions = {},
    },
    support = {
        label = 'Support Team',
        description = 'Can open the dashboard and see who is online. Discord: TSRP | Support Team',
        priority = 60,
        inherits = { 'staff' },
        permissions = { 'tsrp.admin.access', 'tsrp.admin.players' },
    },
    staff = {
        label = 'Staff',
        description = 'Base for every staff tier. Discord: TSRP | Staff Team',
        priority = 55,
        inherits = {},
        permissions = { 'tsrp.staff' },
    },
    developer = {
        label = 'Development Team',
        description = 'Developer tools (tsrp.dev.*). Discord: TSRP | Development Team',
        priority = 50,
        inherits = {},
        permissions = { 'tsrp.dev.*' },
    },

    leo_command = {
        label = 'LEO High Command',
        description = 'Command over every police department. Discord: TSRP | Department High Command',
        priority = 40,
        inherits = { 'leo_supervisor' },
        permissions = { 'tsrp.police.*' },
    },
    leo_supervisor = {
        label = 'LEO Supervisor',
        description = 'Shared base for every police supervisor (SASP, BCSO, LSP, DHS).',
        priority = 35,
        inherits = { 'leo' },
        permissions = { 'tsrp.police.supervisor', 'tsrp.police.roster' },
    },
    leo = {
        label = 'Law Enforcement',
        description = 'Shared base for every police department (SASP, BCSO, LSP, DHS). Assign the department group instead.',
        priority = 30,
        inherits = {},
        permissions = { 'tsrp.police.duty', 'tsrp.police.dispatch' },
    },

    safr_command = {
        label = 'SAFR Command',
        description = 'Command over fire and EMS. Discord: TSRP | Department High Command',
        priority = 40,
        inherits = { 'safr_supervisor' },
        permissions = { 'tsrp.safr.*' },
    },
    safr_supervisor = {
        label = 'SAFR Supervisor',
        description = 'Shared base for fire and EMS supervisors (SAFD).',
        priority = 35,
        inherits = { 'safr' },
        permissions = { 'tsrp.safr.supervisor' },
    },
    safr = {
        label = 'SAFR',
        description = 'Shared base for fire and EMS (SAFD). Assign the department group instead.',
        priority = 30,
        inherits = {},
        permissions = { 'tsrp.safr.duty', 'tsrp.safr.dispatch' },
    },

    -- Department groups are generated below from Config.Departments.

    civilian = {
        label = 'Civilian',
        description = 'Default group for every character.',
        priority = 0,
        inherits = {},
        permissions = { 'tsrp.character.switch', 'tsrp.civilian.jobs', 'tsrp.civilian.businesses' },
        system = true,
    },
}

-- Departments, matching the Tropical Island RP Discord server.
--
-- Each department gets three groups: <id>, <id>_supervisor and <id>_command. They sit on
-- top of the shared base groups above, so anything gated on tsrp.police.duty or
-- tsrp.safr.duty (spawn points, other resources) works for every department:
--
--   sasp_command ─► sasp_supervisor ─► sasp ─► leo
--                   sasp_supervisor ─► leo_supervisor
--
-- Department command gets tsrp.<id>.* for its own department only. Cross-department
-- command (Discord "TSRP | Department High Command") is still leo_command / safr_command.
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
        permissions = { 'tsrp.' .. id .. '.duty' },
    }
    Config.Groups[id .. '_supervisor'] = {
        label = dept.short .. ' Supervisor',
        description = dept.short .. ' supervisors. Discord: ' .. dept.discord[2],
        priority = 35,
        inherits = base and { id, base .. '_supervisor' } or { id },
        permissions = { 'tsrp.' .. id .. '.supervisor', 'tsrp.' .. id .. '.roster' },
    }
    Config.Groups[id .. '_command'] = {
        label = dept.short .. ' High Command',
        description = dept.short .. ' high command. Discord: ' .. dept.discord[3],
        priority = 40,
        inherits = { id .. '_supervisor' },
        permissions = { 'tsrp.' .. id .. '.*' },
    }
end

-- Department permission nodes, so they show up in the admin dashboard's node list.
-- (config/permissions.lua loads before this file.)
Config.PermissionNodes = Config.PermissionNodes or {}
for _, dept in ipairs(Config.Departments) do
    local p = 'tsrp.' .. dept.id .. '.'
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
    permissions = { 'tsrp.faa.pilot' },
}
Config.Groups.fto_assistant = {
    label = 'Assistant Field Instructor',
    description = 'Discord: TSRP | Assistant Field Instructor',
    priority = 33,
    inherits = {},
    permissions = { 'tsrp.police.fto.assist' },
}
Config.Groups.fto = {
    label = 'Field Training Instructor',
    description = 'Discord: TSRP | Field Training Instructor',
    priority = 34,
    inherits = { 'fto_assistant' },
    permissions = { 'tsrp.police.fto.*' },
}

-- Whitelists, donator tiers and perk packs. These come from Discord roles and apply
-- to every character on the account. Other resources check the nodes, e.g.
--   exports['tsrp-core']:HasPermission(src, 'tsrp.pack.sports')
local function perk(name, label, discordRole, nodes, inherits, priority)
    Config.Groups[name] = {
        label = label,
        description = 'Discord: ' .. discordRole,
        priority = priority or 10,
        inherits = inherits or {},
        permissions = nodes,
    }
end

perk('whitelist_leo',  'Whitelisted LEO',          'TSRP | Whitelisted LEO',          { 'tsrp.whitelist.leo' })
perk('whitelist_gang', 'Whitelisted Gang Member',  'TSRP | Whitelisted Gang Member',  { 'tsrp.whitelist.gang' })

perk('donator',      'Donator',       'TSRP | Donator',           { 'tsrp.donator' }, nil, 12)
perk('vip_premium',  'Premium VIP',   'Donator | Premium VIP',    { 'tsrp.vip.premium' },  { 'donator' },     13)
perk('vip_elite',    'Elite VIP',     'Donator | Elite VIP',      { 'tsrp.vip.elite' },    { 'vip_premium' }, 14)
perk('vip_ultimate', 'Ultimate VIP',  'Donator | Ultimate VIP',   { 'tsrp.vip.ultimate' }, { 'vip_elite' },   15)

perk('pack_sports',      'Sports Car Pack',     'Donator | Sports Car Pack',  { 'tsrp.pack.sports' })
perk('pack_muscle',      'Muscle Car Pack',     'Donator | Muscle Car Pack',  { 'tsrp.pack.muscle' })
perk('pack_leo_1',       'LEO Pack #1',         'Donator | LEO Pack #1',      { 'tsrp.pack.leo1' })
perk('pack_leo_2',       'LEO Pack #2',         'Donator | LEO Pack #2',      { 'tsrp.pack.leo2' })
perk('pack_leo_3',       'LEO Pack #3',         'Donator | LEO Pack #3',      { 'tsrp.pack.leo3' })
perk('pack_weapons',     'Weapons Pack',        'Donator | Weapons Pack',     { 'tsrp.pack.weapons' })
perk('pack_owners_cars', 'Owners Car Pack',     'TSRP | Owners Car Pack',     { 'tsrp.pack.owners' })
perk('speed_bypass',     'Owners Speed Bypass', 'TSRP | Owners Speed Bypass', { 'tsrp.vehicle.speedbypass' })
perk('booster',          'Server Booster',      'TSRP | Server Booster',      { 'tsrp.booster' })

-- Register the nodes above so they show up in the dashboard.
local extraNodes = {
    ['tsrp.staff'] = 'Member of staff (any tier)',
    ['tsrp.dev.tools'] = 'Developer tools',
    ['tsrp.faa.pilot'] = 'Fly FAA department aircraft',
    ['tsrp.police.fto.assist'] = 'Assistant field training instructor',
    ['tsrp.police.fto.train'] = 'Field training instructor',
    ['tsrp.whitelist.leo'] = 'Whitelisted for law enforcement',
    ['tsrp.whitelist.gang'] = 'Whitelisted gang member',
    ['tsrp.donator'] = 'Donator',
    ['tsrp.vip.premium'] = 'Premium VIP',
    ['tsrp.vip.elite'] = 'Elite VIP',
    ['tsrp.vip.ultimate'] = 'Ultimate VIP',
    ['tsrp.pack.sports'] = 'Sports car pack',
    ['tsrp.pack.muscle'] = 'Muscle car pack',
    ['tsrp.pack.leo1'] = 'LEO pack #1',
    ['tsrp.pack.leo2'] = 'LEO pack #2',
    ['tsrp.pack.leo3'] = 'LEO pack #3',
    ['tsrp.pack.weapons'] = 'Weapons pack',
    ['tsrp.pack.owners'] = 'Owners car pack',
    ['tsrp.vehicle.speedbypass'] = 'Bypass vehicle speed limits',
    ['tsrp.booster'] = 'Server booster',
}
for node, description in pairs(extraNodes) do Config.PermissionNodes[node] = description end
