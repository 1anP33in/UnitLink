---------------------------------------------------------------------
-- Shared server pieces used by every UnitLink tablet:
--   UL.validateForm : report / application forms defined in config.lua
--   UL.activity     : employee activity log (Tools → Activity Log)
--   UL.employee     : who has used which CAD (Tools → Profiles)
--   UL.audit        : admin change history (Admin → Audit)
---------------------------------------------------------------------
local function inList(list, v) for _, x in ipairs(list or {}) do if x == v then return true end end return false end
UL.inList = inList

-- form = { key, label, fields = { { key, label, type, required }, ... } }
-- type: text | area | narr | number | person | incident | unit | <list name> | { options }
-- opts: { lists = { name = {...} }, minNarrative = 20, incidentExists = function(id) }
-- returns data, meta | nil, error
function UL.validateForm(form, input, opts)
    input = type(input) == 'table' and input or {}
    local data, meta = {}, {}
    local minN = opts.minNarrative or 20
    for _, fd in ipairs(form.fields) do
        local key, label, t, required = fd[1], fd[2], fd[3], fd[4] == true
        local v = input[key]
        if v == '' then v = nil end
        if t == 'person' then
            local id = UL.int(v)
            if id then
                local c = Identity.get(id)
                if not c then return nil, label .. ': person not found.' end
                meta.subject, meta.subjectName = id, ('%s %s'):format(c.firstname, c.lastname)
                data[key] = id
            end
        elseif t == 'incident' then
            local id = UL.int(v)
            if id then
                if not (opts.incidentExists and opts.incidentExists(id)) then return nil, label .. ': not found.' end
                meta.incident = id; data[key] = id
            end
        elseif t == 'number' then
            local n = UL.int(v)
            if v ~= nil and (not n or n < 0 or n > 999) then return nil, label .. ' must be 0 to 999.' end
            data[key] = n
        elseif t == 'unit' then
            data[key] = UL.clean(v, 12)
        elseif t == 'text' then
            data[key] = UL.clean(v, 200)
        elseif t == 'area' then
            data[key] = UL.cleanText(v, 1000)
        elseif t == 'narr' then
            data[key] = UL.cleanText(v, 4000)
            if not data[key] or #data[key] < minN then return nil, ('%s must be at least %d characters.'):format(label, minN) end
        else
            local options = type(t) == 'table' and t or (opts.lists or {})[t]
            if v ~= nil and not inList(options, v) then return nil, label .. ': pick an option from the list.' end
            data[key] = v
        end
        if required and data[key] == nil then return nil, label .. ' is required.' end
    end
    return data, meta
end

-- Forms for the tablet (field types resolved, option lists filled in)
function UL.formsForUi(forms, lists)
    local out = {}
    for _, f in ipairs(forms) do
        local fields = {}
        for _, fd in ipairs(f.fields) do
            local t = fd[3]
            local isList = type(t) == 'table' or (lists or {})[t] ~= nil
            fields[#fields + 1] = { key = fd[1], label = fd[2], type = isList and 'list' or t, options = type(t) == 'table' and t or (lists or {})[t], required = fd[4] == true }
        end
        out[#out + 1] = { key = f.key, label = f.label, fields = fields }
    end
    return out
end

---------------------------------------------------------------------
-- Activity / employees / audit
---------------------------------------------------------------------
function UL.activity(o, action)
    if not o or not UL.ready then return end
    UL.DB.insert('INSERT INTO ul_activity (member_id, name, callsign, dept, action) VALUES (?, ?, ?, ?, ?)',
        { o.charId, tostring(o.name):sub(1, 64), o.callsign, o.dept, tostring(action):sub(1, 255) })
end

function UL.employee(o)
    if not o or not UL.ready then return end
    UL.DB.query([[INSERT INTO ul_employees (member_id, name, callsign, dept, kind, last_seen) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE name = VALUES(name), callsign = VALUES(callsign), dept = VALUES(dept), kind = VALUES(kind), last_seen = CURRENT_TIMESTAMP]],
        { o.charId, tostring(o.name):sub(1, 64), o.callsign, o.dept, o.kind })
end

function UL.audit(who, area, change)
    if not UL.ready then return end
    UL.DB.insert('INSERT INTO ul_audit (admin, area, change_text) VALUES (?, ?, ?)', { tostring(who):sub(1, 64), tostring(area):sub(1, 32), tostring(change):sub(1, 255) })
end
