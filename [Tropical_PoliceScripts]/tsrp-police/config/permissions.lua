---------------------------------------------------------------------
-- Duty permissions (checked server side only, fresh on every request)
--
-- With Config.Framework.enabled = true these are TSRP Core permission
-- nodes, checked against the player's ACTIVE character via
-- exports['tsrp-core']:HasPermission. They come from tsrp-core's groups:
--
--   sasp            -> tsrp.sasp.duty          (inherits leo: tsrp.police.duty, tsrp.police.dispatch)
--   sasp_supervisor -> tsrp.sasp.supervisor    (inherits leo_supervisor: tsrp.police.supervisor)
--   sasp_command    -> tsrp.sasp.*
--   ...same for bcso, lsp, dhs, safd, faa
--
-- So assigning a character the `bcso` group in the TSRP dashboard is all
-- it takes for that character (and only that character) to go on duty
-- as BCSO. Wildcards like tsrp.bcso.* (department command) also match.
--
-- With Config.Framework.enabled = false the same strings are used as
-- plain FiveM ACE names (add_ace group.bcso tsrp.bcso.duty allow).
---------------------------------------------------------------------
Config.Permissions = {
    departments = {
        sasp = { node = 'tsrp.sasp.duty', supervisor = 'tsrp.sasp.supervisor' },
        bcso = { node = 'tsrp.bcso.duty', supervisor = 'tsrp.bcso.supervisor' },
        lsp  = { node = 'tsrp.lsp.duty',  supervisor = 'tsrp.lsp.supervisor' },
        dhs  = { node = 'tsrp.dhs.duty',  supervisor = 'tsrp.dhs.supervisor' },
        safd = { node = 'tsrp.safd.duty', supervisor = 'tsrp.safd.supervisor' },
        faa  = { node = 'tsrp.faa.duty',  supervisor = 'tsrp.faa.supervisor' },
    },

    -- Cross-department override: can close any 911 call.
    -- tsrp.police.supervisor = every LEO supervisor and LEO High Command.
    admin = 'tsrp.police.supervisor',
}
