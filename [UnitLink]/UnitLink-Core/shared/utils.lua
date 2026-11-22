-- UnitLink Core: shared utilities. Pure functions only (no natives), so they can be unit
-- tested outside the game.

UnitLink = UnitLink or {}
local Utils = {}
UnitLink.Utils = Utils

function Utils.Trim(value)
    if type(value) ~= 'string' then return nil end
    return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

-- Collapse runs of whitespace into a single space.
function Utils.CollapseSpaces(value)
    if type(value) ~= 'string' then return nil end
    return (value:gsub('%s+', ' '))
end

function Utils.DeepCopy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[Utils.DeepCopy(k, seen)] = Utils.DeepCopy(v, seen)
    end
    return copy
end

function Utils.Contains(list, needle)
    if type(list) ~= 'table' then return false end
    for i = 1, #list do
        if list[i] == needle then return true end
    end
    return false
end

function Utils.SortedKeys(map)
    local keys = {}
    for k in pairs(map or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

function Utils.Count(map)
    local n = 0
    for _ in pairs(map or {}) do n = n + 1 end
    return n
end

function Utils.ToInteger(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    if math.floor(n) ~= n then return nil end
    return math.tointeger(n) or n
end

-- Positive integer id (character ids, server ids, etc.).
function Utils.ToId(value)
    local n = Utils.ToInteger(value)
    if not n or n < 1 or n > 9007199254740991 then return nil end
    return n
end

-- Names: ASCII letters, with single inner spaces, hyphens or apostrophes.
function Utils.IsValidName(value, minLen, maxLen)
    if type(value) ~= 'string' then return false end
    local len = #value
    if len < (minLen or 1) or len > (maxLen or 32) then return false end
    if value:find("[^%a '%-]") then return false end
    if not value:find('^%a') or not value:find('%a$') then return false end
    if value:find("[ '%-][ '%-]") then return false end
    return true
end

-- Capitalise the first letter of each name part ("mary-jane o'neil" -> "Mary-Jane O'Neil").
-- The rest is kept as typed so names like "McKenzie" survive.
function Utils.FormatName(value)
    return (value:gsub("(%a)([%a]*)", function(first, rest)
        return first:upper() .. rest
    end))
end

local DAYS_IN_MONTH = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

function Utils.IsLeapYear(y)
    return (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0
end

-- Parses 'YYYY-MM-DD'. Returns year, month, day or nil.
function Utils.ParseDate(value)
    if type(value) ~= 'string' then return nil end
    local y, m, d = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    if not y then return nil end
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if m < 1 or m > 12 or d < 1 then return nil end
    local maxDay = DAYS_IN_MONTH[m]
    if m == 2 and Utils.IsLeapYear(y) then maxDay = 29 end
    if d > maxDay then return nil end
    return y, m, d
end

-- Whole years between a birth date and "today" ({ year=, month=, day= }).
function Utils.AgeOn(y, m, d, today)
    local age = today.year - y
    if today.month < m or (today.month == m and today.day < d) then
        age = age - 1
    end
    return age
end

-- Permission nodes: lowercase dot-separated segments of [a-z0-9_-]. The last segment
-- may be '*' (wildcard), and '*' alone means everything.
function Utils.IsValidPermissionNode(node)
    if type(node) ~= 'string' then return false end
    local len = #node
    if len < 1 or len > 128 then return false end
    if node == '*' then return true end
    local segments = {}
    for segment in (node .. '.'):gmatch('([^%.]*)%.') do
        segments[#segments + 1] = segment
    end
    if #segments == 0 then return false end
    for i, segment in ipairs(segments) do
        if segment == '*' then
            if i ~= #segments or i == 1 then return false end
        elseif segment == '' or not segment:find('^[a-z0-9_%-]+$') then
            return false
        end
    end
    return true
end

function Utils.IsWildcardNode(node)
    return node == '*' or (type(node) == 'string' and node:sub(-2) == '.*')
end

function Utils.IsValidGroupName(name)
    return type(name) == 'string' and #name >= 2 and #name <= 50 and name:find('^[a-z][a-z0-9_]*$') ~= nil
end

function Utils.IsValidMetadataKey(key, maxLen)
    return type(key) == 'string' and #key >= 1 and #key <= (maxLen or 64) and key:find('^[%w_%-%.]+$') ~= nil
end

-- True when a value only contains JSON-safe types (no functions/userdata/cycles).
function Utils.IsJsonSafe(value, depth, seen)
    depth = depth or 0
    if depth > 24 then return false end
    local t = type(value)
    if t == 'nil' or t == 'boolean' or t == 'string' then return true end
    if t == 'number' then return value == value and value ~= math.huge and value ~= -math.huge end
    if t ~= 'table' then return false end
    seen = seen or {}
    if seen[value] then return false end
    seen[value] = true
    for k, v in pairs(value) do
        local kt = type(k)
        if kt ~= 'string' and kt ~= 'number' then return false end
        if not Utils.IsJsonSafe(v, depth + 1, seen) then return false end
    end
    seen[value] = nil
    return true
end

function Utils.JsonDecode(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    if ok and decoded ~= nil then return decoded end
    return fallback
end

function Utils.JsonEncode(value)
    local ok, encoded = pcall(json.encode, value)
    if ok then return encoded end
    return nil
end

-- Short, non-reversible tag for an identifier (for logs that should not show it).
function Utils.Redact(identifier)
    if type(identifier) ~= 'string' then return 'unknown' end
    local h = 5381
    for i = 1, #identifier do
        h = ((h * 33) + identifier:byte(i)) % 4294967296
    end
    return ('acct-%08x'):format(h)
end

function Utils.Clamp(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end
