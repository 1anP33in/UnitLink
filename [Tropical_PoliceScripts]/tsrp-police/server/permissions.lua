---------------------------------------------------------------------
-- Duty access checks. The only source of truth for department access.
-- Called fresh every time (never cached), so role changes apply at once.
--
-- Framework mode : TSRP Core permission nodes on the ACTIVE character
--                  (fails closed if tsrp-core is down or no character).
-- Standalone mode: the same strings as FiveM ACE names.
---------------------------------------------------------------------
Permissions = {}

local function check(src, node)
    if type(node) ~= 'string' or node == '' then return false end
    if Framework.enabled() then
        return Framework.hasPermission(src, node)
    end
    return IsPlayerAceAllowed(tostring(src), node)
end

function Permissions.canUseDepartment(src, dept)
    if type(dept) ~= 'string' or not Config.Departments[dept] then return false end
    local p = Config.Permissions.departments[dept]
    return p ~= nil and check(src, p.node)
end

function Permissions.isSupervisor(src, dept)
    local p = Config.Permissions.departments[dept]
    return p ~= nil and check(src, p.supervisor)
end

function Permissions.isAdmin(src)
    return check(src, Config.Permissions.admin)
end

-- Framework mode: a character must be loaded before going on duty
function Permissions.hasCharacter(src)
    if not Framework.enabled() then return true end
    return Framework.isLoaded(src)
end

-- Departments this player may clock into, sorted, safe to send to the client
function Permissions.authorizedDepartments(src)
    local list = {}
    if not Permissions.hasCharacter(src) then return list end
    for _, key in ipairs(Utils.departmentKeys()) do
        if Permissions.canUseDepartment(src, key) then
            local d = Config.Departments[key]
            local rules = d.callsign or {}
            list[#list + 1] = {
                key = key, short = d.short, name = d.name,
                example = rules.example, minLength = rules.minLength, maxLength = rules.maxLength,
            }
        end
    end
    return list
end
