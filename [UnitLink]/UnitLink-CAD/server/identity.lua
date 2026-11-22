---------------------------------------------------------------------
-- Identity: who people are (name, DOB, licenses) and who officers are.
--
--   core       : UnitLink-Core characters (exports), as before
--   standalone : UnitLink's own civilian profiles (ul_civilians), made with
--                /civ. Officers are identified by their account (ul_players),
--                which matches ACE permissions (also account-level).
-- Config.Identity = 'auto' picks core when UnitLink-Core is running.
---------------------------------------------------------------------
Identity = {}

local active = {}   -- [src] = civilian profile id (standalone)
local players = {}  -- [src] = ul_players id (cache)

function Identity.mode()
    local m = Config.Identity or 'auto'
    if m == 'auto' then
        return GetResourceState(Config.CoreResource or 'UnitLink-Core') == 'started' and 'core' or 'standalone'
    end
    return m == 'core' and 'core' or 'standalone'
end

local function core(name, ...)
    local res = Config.CoreResource or 'UnitLink-Core'
    if GetResourceState(res) ~= 'started' then return false end
    local args = table.pack(...)
    local ok, a = pcall(function()
        local r = exports[res]
        return r[name](r, table.unpack(args, 1, args.n))
    end)
    if not ok then UL.log(('^1%s export %s failed: %s^7'):format(res, name, tostring(a))) return false end
    return true, a
end

-- Account identifier (license by default), never sent to clients
function Identity.owner(src)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return nil
end

local function playerId(src)
    if players[src] then return players[src] end
    local owner = Identity.owner(src)
    if not owner then return nil end
    local row = UL.DB.single('SELECT id FROM ul_players WHERE identifier = ?', { owner })
    if row then
        UL.DB.update('UPDATE ul_players SET last_seen = CURRENT_TIMESTAMP, name = ? WHERE id = ?', { (GetPlayerName(src) or ''):sub(1, 64), row.id })
        players[src] = row.id
    else
        players[src] = UL.DB.insert('INSERT INTO ul_players (identifier, name) VALUES (?, ?)', { owner, (GetPlayerName(src) or ''):sub(1, 64) })
    end
    return players[src]
end

---------------------------------------------------------------------
-- Officer id: stored on records, returns and notes they write
---------------------------------------------------------------------
function Identity.officerId(src)
    if Identity.mode() == 'core' then
        local ok, id = core('GetCharacterId', src)
        return ok and tonumber(id) or nil
    end
    return playerId(src)
end

---------------------------------------------------------------------
-- People
---------------------------------------------------------------------
local COLS = 'id, firstname, lastname, dateofbirth, gender, nationality, height'

function Identity.search(query)
    if Identity.mode() == 'core' then
        local ok, rows = core('SearchCharacters', query, 25)
        return ok and rows or nil
    end
    local id = tonumber(query)
    if id then
        return UL.DB.query('SELECT ' .. COLS .. ' FROM ul_civilians WHERE id = ? AND deleted = 0', { id })
    end
    local term = UL.trim((query:gsub('[%%_]', '')))
    if #term < 2 then return {} end -- never let a stripped wildcard match everyone
    local like = '%' .. term .. '%'
    return UL.DB.query('SELECT ' .. COLS .. [[ FROM ul_civilians WHERE deleted = 0 AND
        (CONCAT(firstname, ' ', lastname) LIKE ? OR CONCAT(lastname, ' ', firstname) LIKE ?) ORDER BY lastname, firstname LIMIT 25]], { like, like })
end

function Identity.get(id)
    id = tonumber(id)
    if not id then return nil end
    if Identity.mode() == 'core' then
        local ok, row = core('GetCharacterById', id)
        return ok and row or nil
    end
    return UL.DB.single('SELECT ' .. COLS .. ' FROM ul_civilians WHERE id = ? AND deleted = 0', { id })
end

-- raw licenses table (or nil)
function Identity.getLicenses(id)
    if Identity.mode() == 'core' then
        local ok, v = core('GetCharacterMetadata', id, Config.Licenses.metadataKey)
        return ok and v or nil
    end
    local row = UL.DB.single('SELECT licenses FROM ul_civilians WHERE id = ?', { id })
    return row and UL.decode(row.licenses, nil) or nil
end

function Identity.setLicenses(id, value)
    if Identity.mode() == 'core' then
        local ok, a = core('SetCharacterMetadata', id, Config.Licenses.metadataKey, value)
        return ok and a ~= false
    end
    return (UL.DB.update('UPDATE ul_civilians SET licenses = ? WHERE id = ?', { UL.json(value), id }) or 0) > 0
end

---------------------------------------------------------------------
-- Active civilian (standalone): picked with /civ, remembered by last_used
---------------------------------------------------------------------
function Identity.active(src)
    if Identity.mode() == 'core' then
        local ok, id = core('GetCharacterId', src)
        return ok and id and Identity.get(id) or nil
    end
    local owner = Identity.owner(src)
    if not owner then return nil end
    if not active[src] then
        local row = UL.DB.single('SELECT id FROM ul_civilians WHERE owner = ? AND deleted = 0 ORDER BY last_used DESC LIMIT 1', { owner })
        active[src] = row and row.id or false
    end
    return active[src] and Identity.get(active[src]) or nil
end

function Identity.activeName(src)
    local c = Identity.active(src)
    return c and ('%s %s'):format(c.firstname, c.lastname) or nil
end

AddEventHandler('playerDropped', function()
    active[source], players[source] = nil, nil
end)

exports('GetActiveProfile', function(src) return Identity.active(tonumber(src)) end)
exports('GetActiveName', function(src) return Identity.activeName(tonumber(src)) end)
exports('GetIdentityMode', function() return Identity.mode() end)

---------------------------------------------------------------------
-- /civ requests (no duty needed). Each handler gets (src, owner, payload).
---------------------------------------------------------------------
UL.civHandlers = {}
local function civ(action, fn) UL.civHandlers[action] = fn end

local GENDERS = { Male = true, Female = true, ['Non-binary'] = true }
local function nationalityOk(v) for _, n in ipairs(Config.Civ.nationalities) do if n == v then return true end end return false end
local function cleanName(v)
    v = UL.clean(v, 32)
    if not v or #v < 2 or not v:match("^[%a][%a%s'%-]*$") then return nil end
    return (v:gsub('^%l', string.upper))
end

local function myProfiles(owner)
    return UL.DB.query('SELECT ' .. COLS .. ", licenses, UNIX_TIMESTAMP(created_at) AS created FROM ul_civilians WHERE owner = ? AND deleted = 0 ORDER BY last_used DESC", { owner }) or {}
end

local function licenseView(raw)
    local d = Config.Licenses.defaults
    local function one(k)
        local v = type(raw) == 'table' and raw[k] or nil
        if type(v) == 'table' then return { status = tostring(v.status or d[k] or 'none'):upper(), points = tonumber(v.points) or 0 } end
        if type(v) == 'string' then return { status = v:upper(), points = 0 } end
        return { status = tostring(d[k] or 'none'):upper(), points = 0 }
    end
    return { drivers = one('drivers'), firearm = one('firearm'), pilot = one('pilot') }
end

civ('civ.list', function(src, owner)
    if Identity.mode() == 'core' then
        return true, { mode = 'core', active = Identity.active(src) }
    end
    local list = myProfiles(owner)
    local current = Identity.active(src)
    for _, p in ipairs(list) do p.licenses = licenseView(UL.decode(p.licenses, nil)) end
    return true, {
        mode = 'standalone', profiles = list, active = current and current.id or nil, max = Config.Civ.maxProfiles,
        nationalities = Config.Civ.nationalities, minAge = Config.Civ.minAge, maxAge = Config.Civ.maxAge,
        suspendAt = Config.Licenses.suspendAt, serverYear = tonumber(os.date('%Y')),
    }
end)

civ('civ.create', function(src, owner, p)
    if Identity.mode() == 'core' then return false, 'Characters come from UnitLink-Core on this server.' end
    if #myProfiles(owner) >= Config.Civ.maxProfiles then return false, ('You can have up to %d profiles.'):format(Config.Civ.maxProfiles) end
    local first, last = cleanName(p.firstname), cleanName(p.lastname)
    if not first or not last then return false, 'Names need at least 2 letters (letters, spaces, - and \' only).' end
    local y, m, d = tostring(p.dateofbirth or ''):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or m < 1 or m > 12 or d < 1 or d > 31 then return false, 'Enter a date of birth.' end
    local age = tonumber(os.date('%Y')) - y
    if age < Config.Civ.minAge or age > Config.Civ.maxAge then return false, ('Age must be %d to %d.'):format(Config.Civ.minAge, Config.Civ.maxAge) end
    if not GENDERS[p.gender] then return false, 'Pick a gender.' end
    if not nationalityOk(p.nationality) then return false, 'Pick a nationality.' end
    local h = UL.int(p.height)
    if not h or h < 120 or h > 230 then return false, 'Height must be 120 to 230 cm.' end
    local id = UL.DB.insert([[INSERT INTO ul_civilians (owner, firstname, lastname, dateofbirth, gender, nationality, height)
        VALUES (?, ?, ?, ?, ?, ?, ?)]], { owner, first, last, ('%04d-%02d-%02d'):format(y, m, d), p.gender, p.nationality, h })
    if not id then return false, 'Database error. Try again.' end
    active[src] = id
    UL.log(('civilian profile %d created: %s %s'):format(id, first, last))
    return true, { id = id }
end)

civ('civ.select', function(src, owner, p)
    if Identity.mode() == 'core' then return false, 'Characters come from UnitLink-Core on this server.' end
    local id = UL.int(p.id)
    local row = id and UL.DB.single('SELECT id, firstname, lastname FROM ul_civilians WHERE id = ? AND owner = ? AND deleted = 0', { id, owner })
    if not row then return false, 'That profile is not yours.' end
    active[src] = row.id
    UL.DB.update('UPDATE ul_civilians SET last_used = CURRENT_TIMESTAMP WHERE id = ?', { row.id })
    return true, { id = row.id, name = row.firstname .. ' ' .. row.lastname }
end)

civ('civ.delete', function(src, owner, p)
    if Identity.mode() == 'core' then return false, 'Characters come from UnitLink-Core on this server.' end
    local id = UL.int(p.id)
    local n = id and UL.DB.update('UPDATE ul_civilians SET deleted = 1 WHERE id = ? AND owner = ? AND deleted = 0', { id, owner }) or 0
    if n == 0 then return false, 'That profile is not yours.' end
    if active[src] == id then active[src] = nil end
    return true
end)
