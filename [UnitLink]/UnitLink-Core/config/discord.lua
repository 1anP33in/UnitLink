-- UnitLink Core: Discord role sync (server only; the bot token never reaches clients).
--
-- When a player joins, UnitLink Core looks up their Discord account in the guild below and
-- turns their roles into UnitLink-Core groups. Three kinds of mapping:
--
--   groups  = ACCOUNT groups. Applied to every character on the account while the
--             player has the role. Staff, whitelists, donator perks. These groups are
--             Discord-managed: staff can't assign them by hand in /ulcore.
--
--   unlocks = DEPARTMENT groups. The role doesn't make any character a cop; it allows
--             staff to assign that group to one of the player's characters. If the
--             player loses the role, the group stops working on all their characters
--             (it comes back if they get the role again). Unlocking a group also
--             unlocks everything it inherits (sasp unlocks leo).
--
--   blocks  = BLACKLISTS. While the player has the role, these groups (and every group
--             that inherits them) are switched off on all their characters, no matter
--             where they came from. Blocking 'leo' removes every police group.
--
-- Roles not listed here (strikes, ping roles, verification, member milestones, bots)
-- are Discord-only and have no effect in game.
--
-- SETUP
--   1. Discord Developer Portal -> the "UnitLink - Core" application -> Bot -> Reset Token.
--   2. Put it in server.cfg (NOT in this file):
--        set unitlink_discord_token "YOUR_BOT_TOKEN"
--      `set` (not `setr`/`sets`) keeps it server-side.
--   3. The bot only needs to be in the server. It needs no permissions and no
--      privileged intents: it reads members through the REST API.
--   Players must have Discord running when they launch FiveM so FiveM can see their
--   Discord account.

Config = Config or {}

Config.Discord = {
    Enabled = true,
    GuildId = '1522709667350839316',
    TokenConvar = 'unitlink_discord_token',

    -- Re-check every connected player's roles this often (seconds). Roles are also
    -- re-checked when a player joins and each time they go back to character selection.
    RefreshSeconds = 300,

    -- true = refuse to let people join without a Discord account linked to FiveM.
    RequireDiscord = false,
    -- true = also refuse people who aren't in the Discord server.
    RequireMembership = false,

    Roles = {
        -- Staff ------------------------------------------------------------------
        { id = '1522709667350839324', name = 'UnitLink | Owners',             groups = { 'owner' } },
        { id = '1522709667350839325', name = 'UnitLink | Co-Owners',          groups = { 'co_owner' } },
        { id = '1522709667397238819', name = 'UnitLink | Head Of Management', groups = { 'head_management' } },
        { id = '1522709667397238820', name = 'UnitLink | Management',         groups = { 'management' } },
        { id = '1522709667397238821', name = 'UnitLink | Junior Management',  groups = { 'junior_management' } },
        { id = '1522709667397238822', name = 'UnitLink | Trial Management',   groups = { 'trial_management' } },
        { id = '1522709667414020208', name = 'UnitLink | Development Manager', groups = { 'management', 'developer' } },
        { id = '1522709667414020209', name = 'UnitLink | General Manager',    groups = { 'management' } },
        { id = '1522709667414020210', name = 'UnitLink | Department Manager', groups = { 'management' } },
        { id = '1522709667414020211', name = 'UnitLink | Staff Manager',      groups = { 'management' } },
        { id = '1522709667438919869', name = 'UnitLink | Department Coordinator', groups = { 'junior_management' } },
        { id = '1522709667438919870', name = 'UnitLink | Staff Coordinator',  groups = { 'junior_management' } },
        { id = '1522709667455832105', name = 'UnitLink | Management Assistant', groups = { 'junior_management' } },
        { id = '1522709667455832114', name = 'UnitLink | Head Administrator', groups = { 'head_admin' } },
        { id = '1522709667468546209', name = 'UnitLink | Senior Administrator', groups = { 'senior_admin' } },
        { id = '1522709667468546211', name = 'UnitLink | Administrator',      groups = { 'admin' } },
        { id = '1522709667468546213', name = 'UnitLink | Head Moderator',     groups = { 'head_moderator' } },
        { id = '1522709667468546214', name = 'UnitLink | Senior Moderator',   groups = { 'senior_moderator' } },
        { id = '1522709667468546215', name = 'UnitLink | Moderator',          groups = { 'moderator' } },
        { id = '1522709667468546216', name = 'UnitLink | Trial Moderator',    groups = { 'trial_moderator' } },
        { id = '1522709667468546217', name = 'UnitLink | Staff Team',         groups = { 'staff' } },
        { id = '1522709667485188221', name = 'UnitLink | Support Team',       groups = { 'support' } },
        { id = '1522709667485188222', name = 'UnitLink | Development Team',   groups = { 'developer' } },
        -- Discord-only, no in-game effect: Store Manager, Business Management,
        -- Retired Management, Senior Staff Team, Chat Moderation, Appeals Team.

        -- Cross-department --------------------------------------------------------
        { id = '1522709667485188225', name = 'UnitLink | Department High Command', unlocks = { 'leo_command', 'safr_command' } },
        { id = '1522709667501969438', name = 'UnitLink | Department Supervisor',   unlocks = { 'leo_supervisor', 'safr_supervisor' } },
        { id = '1522709667501969440', name = 'UnitLink | Field Training Instructor',  unlocks = { 'fto' } },
        { id = '1522709667468546210', name = 'UnitLink | Assistant Field Instructor', unlocks = { 'fto_assistant' } },
        -- Not mapped: UnitLink | Command Staff (add an unlock here if it should do something).

        -- Departments --------------------------------------------------------------
        { id = '1522709667501969444', name = 'San Andreas State Police', unlocks = { 'sasp' } },
        { id = '1522709667501969443', name = 'SASP | Supervisor',        unlocks = { 'sasp_supervisor' } },
        { id = '1522709667501969442', name = 'SASP | High Command',      unlocks = { 'sasp_command' } },

        { id = '1522709667514683462', name = "Blaine County Sheriff's Office", unlocks = { 'bcso' } },
        { id = '1522709667501969447', name = 'BCSO | Supervisor',        unlocks = { 'bcso_supervisor' } },
        { id = '1522709667501969446', name = 'BCSO | High Command',      unlocks = { 'bcso_command' } },

        { id = '1522709667514683466', name = 'Los Santos Police',        unlocks = { 'lsp' } },
        { id = '1522709667514683465', name = 'LSP | Supervisor',         unlocks = { 'lsp_supervisor' } },
        { id = '1522709667514683464', name = 'LSP | High Command',       unlocks = { 'lsp_command' } },

        { id = '1522709667531194662', name = 'San Andreas Fire Department', unlocks = { 'safd' } },
        { id = '1522709667531194661', name = 'SAFD | Supervisor',        unlocks = { 'safd_supervisor' } },
        { id = '1522709667531194660', name = 'SAFD | High Command',      unlocks = { 'safd_command' } },

        { id = '1522709667531194666', name = 'Federal Aviation Administration', unlocks = { 'faa' } },
        { id = '1522709667531194665', name = 'FAA | Supervisor',         unlocks = { 'faa_supervisor' } },
        { id = '1522709667531194664', name = 'FAA | High Command',       unlocks = { 'faa_command' } },
        { id = '1522709667531194667', name = 'FAA | Department Pilot',   unlocks = { 'faa_pilot' } },

        { id = '1522709667455832111', name = 'TRP | Department of Homeland Security', unlocks = { 'dhs' } },
        { id = '1522709667455832110', name = 'DHS | Supervisor',         unlocks = { 'dhs_supervisor' } },
        { id = '1522709667560820833', name = 'DHS | High Command',       unlocks = { 'dhs_command' } },

        -- Whitelists ---------------------------------------------------------------
        { id = '1522709667531194669', name = 'UnitLink | Whitelisted LEO',         groups = { 'whitelist_leo' } },
        { id = '1522709667548106783', name = 'UnitLink | Whitelisted Gang Member', groups = { 'whitelist_gang' } },

        -- Donators and perks -------------------------------------------------------
        { id = '1522709667560820832', name = 'UnitLink | Donator',           groups = { 'donator' } },
        { id = '1522709667560820836', name = 'Donator | Premium VIP',    groups = { 'vip_premium' } },
        { id = '1522709667560820835', name = 'Donator | Elite VIP',      groups = { 'vip_elite' } },
        { id = '1522709667560820834', name = 'Donator | Ultimate VIP',   groups = { 'vip_ultimate' } },
        { id = '1522709667569074215', name = 'Donator | Sports Car Pack', groups = { 'pack_sports' } },
        { id = '1522709667569074214', name = 'Donator | Muscle Car Pack', groups = { 'pack_muscle' } },
        { id = '1522709667569074213', name = 'Donator | LEO Pack #1',    groups = { 'pack_leo_1' } },
        { id = '1522709667569074212', name = 'Donator | LEO Pack #2',    groups = { 'pack_leo_2' } },
        { id = '1522709667569074211', name = 'Donator | LEO Pack #3',    groups = { 'pack_leo_3' } },
        { id = '1522709667569074207', name = 'Donator | Weapons Pack',   groups = { 'pack_weapons' } },
        { id = '1522709667438919865', name = 'UnitLink | Owners Car Pack',   groups = { 'pack_owners_cars' } },
        { id = '1522709667438919864', name = 'UnitLink | Owners Speed Bypass', groups = { 'speed_bypass' } },
        { id = '1522709667581788332', name = 'UnitLink | Server Booster',    groups = { 'booster' } },

        -- Blacklists ---------------------------------------------------------------
        { id = '1522709667602628719', name = 'UnitLink | Blacklisted LEO',   blocks = { 'leo', 'fto_assistant', 'whitelist_leo' } },
        { id = '1522709667602628724', name = 'LEO Cooldown - 2 Weeks',   blocks = { 'leo', 'fto_assistant' } },
        { id = '1522709667602628721', name = 'UnitLink | Blacklisted Public Officer', blocks = { 'leo', 'safr', 'faa', 'fto_assistant' } },
        { id = '1522709667594375340', name = 'UnitLink | Blacklisted Staff', blocks = { 'staff' } },
        { id = '1522709667548106790', name = 'Suspended Staff',          blocks = { 'staff' } },
        { id = '1522709667602628720', name = 'UnitLink | Blacklisted Development Team', blocks = { 'developer' } },
        -- Not mapped: UnitLink | Blacklisted GSP (add blocks here once you decide what it covers).
    },
}
