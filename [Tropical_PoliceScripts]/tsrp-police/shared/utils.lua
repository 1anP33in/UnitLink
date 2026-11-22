Utils = {}

function Utils.trim(s)
    return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- Character count that understands UTF-8 (falls back to bytes on bad input)
function Utils.length(s)
    return utf8.len(s) or #s
end

-- Clean player-supplied text: no control chars, no GTA ~color~ codes,
-- no angle brackets, single spaces, trimmed and capped to maxLen characters.
function Utils.sanitize(s, maxLen)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('%c', ' '):gsub('[~<>]', ''):gsub('%s+', ' ')
    s = Utils.trim(s)
    if maxLen and Utils.length(s) > maxLen then
        local ok, cut = pcall(utf8.offset, s, maxLen + 1)
        s = (ok and cut) and s:sub(1, cut - 1) or s:sub(1, maxLen)
    end
    return s
end

-- Returns true, normalizedCallsign  or  false, errorCode
function Utils.validateCallsign(raw, rules)
    rules = rules or {}
    if type(raw) ~= 'string' then return false, 'callsign_missing' end
    local cs = Utils.trim(raw):gsub('%s+', '')
    if rules.uppercase ~= false then cs = cs:upper() end
    if cs == '' then return false, 'callsign_missing' end
    if #cs < (rules.minLength or 2) or #cs > (rules.maxLength or 10) then return false, 'callsign_length' end
    if not cs:match('^[%w%-]+$') then return false, 'callsign_chars' end
    if rules.pattern and not cs:match(rules.pattern) then return false, 'callsign_format' end
    return true, cs
end

-- 3725 -> '1h 02m', 300 -> '5m', 20 -> '<1m'
function Utils.formatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local h = seconds // 3600
    local m = (seconds % 3600) // 60
    if h > 0 then return ('%dh %02dm'):format(h, m) end
    if m > 0 then return ('%dm'):format(m) end
    return '<1m'
end

function Utils.department(key)
    return key and Config.Departments[key] or nil
end

-- Flags for a department's type (roster, seeBlips, receives911, ...)
function Utils.deptFlags(key)
    local d = Utils.department(key)
    return d and Config.DepartmentTypes[d.type] or {}
end

function Utils.deptHas(key, flag)
    return Utils.deptFlags(key)[flag] == true
end

-- Department keys sorted by `order`
function Utils.departmentKeys()
    local keys = {}
    for k in pairs(Config.Departments) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local oa, ob = Config.Departments[a].order or 99, Config.Departments[b].order or 99
        if oa == ob then return a < b end
        return oa < ob
    end)
    return keys
end

function Utils.statusLabel(status)
    local info = Police.StatusInfo[status]
    return info and info.label or tostring(status)
end
