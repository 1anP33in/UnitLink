-- UnitLink Core: database initialisation and health checks.

UnitLink = UnitLink or {}
local Database = {}
UnitLink.Database = Database

Database.RequiredTables = {
    'unitlink_players',
    'unitlink_characters',
    'unitlink_character_appearance',
    'unitlink_groups',
    'unitlink_group_inheritance',
    'unitlink_group_permissions',
    'unitlink_character_groups',
    'unitlink_character_permission_overrides',
    'unitlink_audit_log',
}

-- Split install.sql into statements. Comment lines are removed first; the file must not
-- contain semicolons inside string literals (it does not).
function Database.SplitStatements(sql)
    local cleaned = {}
    for line in (sql .. '\n'):gmatch('([^\n]*)\n') do
        if not line:match('^%s*%-%-') then
            cleaned[#cleaned + 1] = line
        end
    end
    local statements = {}
    for stmt in table.concat(cleaned, '\n'):gmatch('([^;]+);') do
        stmt = UnitLink.Utils.Trim(stmt)
        if stmt ~= '' then statements[#statements + 1] = stmt end
    end
    return statements
end

function Database.MissingTables()
    local rows = UnitLink.DB.query(
        'SELECT TABLE_NAME AS name FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE()', {})
    if not rows then return nil end
    local present = {}
    for _, row in ipairs(rows) do present[string.lower(row.name or row.TABLE_NAME or '')] = true end
    local missing = {}
    for _, name in ipairs(Database.RequiredTables) do
        if not present[name] then missing[#missing + 1] = name end
    end
    return missing
end

function Database.Install()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/install.sql')
    if not sql or sql == '' then
        UnitLink.Log.Error('sql/install.sql could not be read.')
        return false
    end
    for _, statement in ipairs(Database.SplitStatements(sql)) do
        local result = UnitLink.DB.update(statement, {})
        if result == nil then
            UnitLink.Log.Error('Auto-install failed on statement: %s', statement:sub(1, 80))
            return false
        end
    end
    return true
end

-- Returns true when every table exists (installing them if allowed).
function Database.Initialize()
    local ping = UnitLink.DB.scalar('SELECT 1', {})
    if not ping then
        UnitLink.Log.Error('Could not reach MySQL through oxmysql. Check mysql_connection_string.')
        return false
    end

    local missing = Database.MissingTables()
    if not missing then return false end

    if #missing > 0 then
        if Config.Database.AutoInstall then
            UnitLink.Log.Info('Installing missing tables: %s', table.concat(missing, ', '))
            if not Database.Install() then return false end
            missing = Database.MissingTables()
            if not missing then return false end
        end
        if #missing > 0 then
            UnitLink.Log.Error('Missing database tables: %s. Import sql/install.sql.', table.concat(missing, ', '))
            return false
        end
    end

    local retention = tonumber(Config.Database.AuditRetentionDays) or 0
    if retention > 0 then
        UnitLink.DB.update('DELETE FROM unitlink_audit_log WHERE created_at < (NOW() - INTERVAL ? DAY)', { retention })
    end

    return true
end
