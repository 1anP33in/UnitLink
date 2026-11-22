-- UnitLink Core: logging (server only; webhook URLs never reach clients).
--
-- Every audit entry is always written to the unitlink_audit_log table and fired as the
-- local server event 'unitlink-core:server:audit' (entry). The sinks below are optional.

Config = Config or {}

Config.Logging = {
    Console = true, -- print audit entries to the server console

    Webhook = {
        Enabled = true,
        -- Sends staff audit entries to a Discord channel (management only).
        -- Treat this URL as a secret: anyone with it can post to that channel.
        Url = GetConvar('unitlink_core_log_webhook', ''), -- secret: set it in server.cfg (set unitlink_core_log_webhook "..."), never in this file
        Username = 'UnitLink Core',
        RedactIdentifiers = true, -- replace license ids with a short hash
        -- Staff-relevant actions only. character.load / character.switch / appearance.save fire
        -- on every join and outfit change and would flood the channel. nil = every action.
        Actions = {
            'character.create', 'character.delete', 'character.edit', 'character.metadata',
            'group.assign', 'group.remove', 'group.create', 'group.update', 'group.delete',
            'permission.allow', 'permission.deny', 'permission.clear',
            'admin.open', 'admin.denied',
        },
    },
}
