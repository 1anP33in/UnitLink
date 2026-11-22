-- TSRP Core: server-side validation of character identity data.
-- Validate() is pure (apart from os.date) so it can be unit tested.

TSRP = TSRP or {}
local Identity = {}
TSRP.Identity = Identity

local Utils = TSRP.Utils

local function today()
    local t = os.date('*t')
    return { year = t.year, month = t.month, day = t.day }
end

-- Validates and cleans a creation/edit payload.
-- Returns clean table, or nil, field, errorCode.
-- When partial = true, only the fields present are validated (admin edits).
function Identity.Validate(payload, partial, now)
    if type(payload) ~= 'table' then return nil, nil, TSRP.Errors.InvalidInput end
    local rules = Config.Characters
    local clean = {}
    now = now or today()

    local function has(field) return not partial or payload[field] ~= nil end

    for _, field in ipairs({ 'firstname', 'lastname' }) do
        if has(field) then
            local value = Utils.Trim(payload[field])
            value = value and Utils.CollapseSpaces(value)
            if not Utils.IsValidName(value, rules.Names.MinLength, rules.Names.MaxLength) then
                return nil, field, TSRP.Errors.InvalidInput
            end
            clean[field] = Utils.FormatName(value)
        end
    end

    if has('dateofbirth') then
        local y, m, d = Utils.ParseDate(payload.dateofbirth)
        if not y then return nil, 'dateofbirth', TSRP.Errors.InvalidInput end
        local age = Utils.AgeOn(y, m, d, now)
        if age < rules.Age.Min or age > rules.Age.Max then
            return nil, 'dateofbirth', TSRP.Errors.InvalidInput
        end
        clean.dateofbirth = ('%04d-%02d-%02d'):format(y, m, d)
    end

    if has('gender') then
        local ok = false
        for _, g in ipairs(rules.Genders) do
            if g.value == payload.gender then ok = true break end
        end
        if not ok then return nil, 'gender', TSRP.Errors.InvalidInput end
        clean.gender = payload.gender
    end

    if has('nationality') then
        if not Utils.Contains(rules.Nationalities, payload.nationality) then
            return nil, 'nationality', TSRP.Errors.InvalidInput
        end
        clean.nationality = payload.nationality
    end

    if has('height') then
        local h = Utils.ToInteger(payload.height)
        if not h or h < rules.Height.Min or h > rules.Height.Max then
            return nil, 'height', TSRP.Errors.InvalidInput
        end
        clean.height = h
    end

    return clean
end

function Identity.MaxSlots()
    local hard = Config.Characters.HardSlotLimit or 3
    local slots = Utils.ToInteger(Config.Characters.MaxSlots) or 3
    return Utils.Clamp(slots, 1, hard)
end
