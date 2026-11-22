-- TSRP Core: bootstrap administrator access (server only, never sent to clients).
--
-- Bootstrap admins are ACCOUNTS, not characters. They can always open the admin
-- dashboard and manage groups/permissions, even if no character has any admin group.
-- This keeps the server from being locked out. Bootstrap access does NOT give their
-- characters any character permissions: HasPermission() is unaffected.
--
-- Find your license with `tsrp players` in the server console while you are connected.

Config = Config or {}

Config.Bootstrap = {
    -- Full identifiers, e.g. 'license:1a2b3c4d5e...'
    Licenses = {
        -- 'license:REPLACE_ME',
    },

    -- Optional ACE. Anyone allowed this ACE in server.cfg is a bootstrap admin:
    --   add_ace identifier.license:xxxx tsrp.bootstrap allow
    -- Set to false to only use the Licenses list above.
    Ace = 'tsrp.bootstrap',
}
