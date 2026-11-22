---------------------------------------------------------------------
-- Bridge to the UnitLink resources. Every external call goes through here.
--
-- UnitLink-Police (server exports): GetUnits, GetCalls, GetCall, CreateCall,
--   UpdateCall, AssignUnit, UnassignUnit, CloseCall, SetUnitStatus, IsSupervisor
--   local events: callCreated, callUpdated, callClosed, unitsChanged
-- People (names, DOB, licenses): server/identity.lua (UnitLink-Core
--   characters, or standalone civilian profiles)
---------------------------------------------------------------------
Bridge = {}

local function call(resource, name, ...)
    if GetResourceState(resource) ~= 'started' then return false end
    local args = table.pack(...)
    local ok, a, b = pcall(function()
        local r = exports[resource]
        return r[name](r, table.unpack(args, 1, args.n))
    end)
    if not ok then
        UL.log(('^1%s export %s failed: %s^7'):format(resource, name, tostring(a)))
        return false
    end
    return true, a, b
end

---------------------------------------------------------------------
-- UnitLink-Police
---------------------------------------------------------------------
function Bridge.units()
    local ok, list = call('UnitLink-Police', 'GetUnits')
    return ok and list or {}
end

function Bridge.unit(src)
    for _, u in ipairs(Bridge.units()) do
        if u.source == src then return u end
    end
end

function Bridge.calls()
    local ok, list = call('UnitLink-Police', 'GetCalls')
    return ok and list or {}
end

function Bridge.call(id)
    local ok, c = call('UnitLink-Police', 'GetCall', id)
    return ok and c or nil
end

-- Wraps UnitLink-Police "ok, err" exports
local function action(name, ...)
    local ok, a, b = call('UnitLink-Police', name, ...)
    if not ok then return false, 'UnitLink-Police is not running.' end
    return a, b
end

function Bridge.createCall(src, data) return action('CreateCall', src, data) end
function Bridge.updateCall(src, id, fields) return action('UpdateCall', src, id, fields) end
function Bridge.assign(src, id) return action('AssignUnit', src, id) end
function Bridge.unassign(src, id) return action('UnassignUnit', src, id) end
function Bridge.closeCall(src, id) return action('CloseCall', src, id) end
function Bridge.setStatus(src, status) return action('SetUnitStatus', src, status) end

function Bridge.isSupervisor(src)
    local ok, v = call('UnitLink-Police', 'IsSupervisor', src)
    return ok and v == true
end

---------------------------------------------------------------------
-- People: UnitLink-Core characters or standalone civilian profiles
-- (server/identity.lua decides which)
---------------------------------------------------------------------
function Bridge.characterId(src) return Identity.officerId(src) end
function Bridge.searchCharacters(query) return Identity.search(query) end
function Bridge.character(id) return Identity.get(id) end
function Bridge.metadata(id) return Identity.getLicenses(id) end
function Bridge.setMetadata(id, _, value) return Identity.setLicenses(id, value) end

---------------------------------------------------------------------
-- Positions (OneSync, server side) for the units grid
---------------------------------------------------------------------
function Bridge.coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local c = GetEntityCoords(ped)
    return { x = math.floor(c.x * 10) / 10, y = math.floor(c.y * 10) / 10, z = math.floor(c.z) }
end
