-- TSRP Core: oxmysql adapter (server only).
--
-- Uses the documented oxmysql Lua API loaded by '@oxmysql/lib/MySQL.lua':
--   MySQL.query.await, MySQL.single.await, MySQL.scalar.await, MySQL.insert.await,
--   MySQL.update.await, MySQL.transaction.await, MySQL.ready
-- Every call is parameterised and wrapped in pcall. On failure the functions return
-- nil (and log the error) instead of throwing, so callers can answer with
-- TSRP.Errors.Database rather than crashing a handler.

TSRP = TSRP or {}
local DB = {}
TSRP.DB = DB

local function logError(kind, query, err)
    local msg = ('[tsrp-core] ^1Database error^7 (%s): %s\n    query: %s'):format(kind, tostring(err), query)
    print(msg)
end

local function run(kind, query, params)
    if type(MySQL) ~= 'table' or type(MySQL[kind]) ~= 'table' then
        logError(kind, query, 'oxmysql is not loaded')
        return false, nil
    end
    local ok, result = pcall(MySQL[kind].await, query, params or {})
    if not ok then
        logError(kind, query, result)
        return false, nil
    end
    return true, result
end

-- Rows (array). Returns nil on error, {} when nothing matched.
function DB.query(query, params)
    local ok, rows = run('query', query, params)
    if not ok then return nil end
    return rows or {}
end

-- First row or false when nothing matched; nil on error.
function DB.single(query, params)
    local ok, row = run('single', query, params)
    if not ok then return nil end
    return row or false
end

-- First column of first row, or false when nothing matched; nil on error.
function DB.scalar(query, params)
    local ok, value = run('scalar', query, params)
    if not ok then return nil end
    if value == nil then return false end
    return value
end

-- Insert id (number) on success; nil on error.
function DB.insert(query, params)
    local ok, id = run('insert', query, params)
    if not ok then return nil end
    return id or 0
end

-- Affected rows (number) on success; nil on error.
function DB.update(query, params)
    local ok, affected = run('update', query, params)
    if not ok then return nil end
    return affected or 0
end

-- queries: array of { query = 'SQL', values = { ... } }. Returns true only if the
-- whole transaction committed.
function DB.transaction(queries)
    if type(MySQL) ~= 'table' or type(MySQL.transaction) ~= 'table' then
        logError('transaction', '(batch)', 'oxmysql is not loaded')
        return false
    end
    local ok, result = pcall(MySQL.transaction.await, queries)
    if not ok then
        logError('transaction', '(batch of ' .. #queries .. ')', result)
        return false
    end
    return result == true
end

-- Fire-and-forget update (used where we cannot wait, e.g. resource stop).
function DB.updateAsync(query, params)
    if type(MySQL) ~= 'table' or type(MySQL.update) ~= 'table' then return end
    pcall(MySQL.update, query, params or {}, function() end)
end

function DB.insertAsync(query, params)
    if type(MySQL) ~= 'table' or type(MySQL.insert) ~= 'table' then return end
    pcall(MySQL.insert, query, params or {}, function() end)
end

function DB.available()
    return type(MySQL) == 'table' and GetResourceState('oxmysql') == 'started'
end

function DB.onReady(cb)
    if type(MySQL) == 'table' and type(MySQL.ready) == 'function' then
        MySQL.ready(cb)
    else
        CreateThread(function()
            local waited = 0
            while GetResourceState('oxmysql') ~= 'started' and waited < 30000 do
                Wait(500)
                waited = waited + 500
            end
            cb()
        end)
    end
end
