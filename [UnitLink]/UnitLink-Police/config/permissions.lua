---------------------------------------------------------------------
-- Duty permissions (checked server side only, fresh on every request)
--
-- STANDALONE (default, Config.Framework.enabled = false): these are plain
-- FiveM ACE names, checked with IsPlayerAceAllowed on the player's ACCOUNT.
-- Nothing is stored on characters. In server.cfg:
--
--   add_ace group.sasp unitlink.sasp.duty allow
--   add_ace group.sasp_supervisor unitlink.sasp.supervisor allow
--   add_principal identifier.license:xxxxxxxx group.sasp
--
-- Granting the parent node (unitlink.sasp) also allows its children.
-- Examples (and how to add more) are in aceperms.md at the repo root.
--
-- Framework mode (Config.Framework.enabled = true): the same strings are
-- UnitLink-Core permission nodes on the player's active character.
---------------------------------------------------------------------
Config.Permissions = {
    departments = {
        sasp = { node = 'unitlink.sasp.duty', supervisor = 'unitlink.sasp.supervisor' },
        bcso = { node = 'unitlink.bcso.duty', supervisor = 'unitlink.bcso.supervisor' },
        lsp  = { node = 'unitlink.lsp.duty',  supervisor = 'unitlink.lsp.supervisor' },
        dhs  = { node = 'unitlink.dhs.duty',  supervisor = 'unitlink.dhs.supervisor' },
        safr = { node = 'unitlink.safr.duty', supervisor = 'unitlink.safr.supervisor' },
        dot  = { node = 'unitlink.dot.duty',  supervisor = 'unitlink.dot.supervisor' },
        faa  = { node = 'unitlink.faa.duty',  supervisor = 'unitlink.faa.supervisor' },
    },

    -- Cross-department override: can close any 911 call.
    -- unitlink.police.supervisor = every LEO supervisor and LEO High Command.
    admin = 'unitlink.police.supervisor',
}
