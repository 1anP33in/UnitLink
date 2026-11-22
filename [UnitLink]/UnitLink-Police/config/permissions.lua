---------------------------------------------------------------------
-- Duty permissions (checked server side only, fresh on every request)
--
-- With Config.Framework.enabled = true these are UnitLink Core permission
-- nodes, checked against the player's ACTIVE character via
-- exports['UnitLink-Core']:HasPermission. They come from UnitLink-Core's groups:
--
--   sasp            -> unitlink.sasp.duty          (inherits leo: unitlink.police.duty, unitlink.police.dispatch)
--   sasp_supervisor -> unitlink.sasp.supervisor    (inherits leo_supervisor: unitlink.police.supervisor)
--   sasp_command    -> unitlink.sasp.*
--   ...same for bcso, lsp, dhs, safd, faa
--
-- So assigning a character the `bcso` group in the UnitLink dashboard is all
-- it takes for that character (and only that character) to go on duty
-- as BCSO. Wildcards like unitlink.bcso.* (department command) also match.
--
-- With Config.Framework.enabled = false the same strings are used as
-- plain FiveM ACE names (add_ace group.bcso unitlink.bcso.duty allow).
---------------------------------------------------------------------
Config.Permissions = {
    departments = {
        sasp = { node = 'unitlink.sasp.duty', supervisor = 'unitlink.sasp.supervisor' },
        bcso = { node = 'unitlink.bcso.duty', supervisor = 'unitlink.bcso.supervisor' },
        lsp  = { node = 'unitlink.lsp.duty',  supervisor = 'unitlink.lsp.supervisor' },
        dhs  = { node = 'unitlink.dhs.duty',  supervisor = 'unitlink.dhs.supervisor' },
        safd = { node = 'unitlink.safd.duty', supervisor = 'unitlink.safd.supervisor' },
        faa  = { node = 'unitlink.faa.duty',  supervisor = 'unitlink.faa.supervisor' },
    },

    -- Cross-department override: can close any 911 call.
    -- unitlink.police.supervisor = every LEO supervisor and LEO High Command.
    admin = 'unitlink.police.supervisor',
}
