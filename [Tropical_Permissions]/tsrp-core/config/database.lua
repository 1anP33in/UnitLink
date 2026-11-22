-- TSRP Core: database settings (server only).

Config = Config or {}

Config.Database = {
    -- Create any missing TSRP tables from sql/install.sql on start. Every statement is
    -- CREATE TABLE IF NOT EXISTS, so this never touches existing data.
    AutoInstall = true,

    -- Seconds between automatic saves of active characters (position + metadata).
    AutosaveInterval = 300,

    -- Keep audit log rows for this many days (0 = keep forever). Pruned on start.
    AuditRetentionDays = 0,
}
