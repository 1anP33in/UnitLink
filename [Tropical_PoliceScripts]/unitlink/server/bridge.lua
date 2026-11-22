---------------------------------------------------------------------
-- Bridge to the TSRP resources. Every external call goes through here.
--
-- tsrp-police (server exports): GetUnits, GetCalls, GetCall, CreateCall,
--   UpdateCall, AssignUnit, UnassignUnit, CloseCall, SetUnitStatus, IsSupervisor
--   local events: callCreated, callUpdated, callClosed, unitsChanged
-- tsrp-core (server exports): GetCharacterId, SearchCharacters,
--   GetCharacterById, GetCharacterMetadata, SetCharacterMetadata
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
-- tsrp-police
---------------------------------------------------------------------
function Bridge.units()
    local ok, list = call('tsrp-police', 'GetUnits')
    return ok and list or {}
end

function Bridge.unit(src)
    for _, u in ipairs(Bridge.units()) do
        if u.source == src then return u end
    end
end

function Bridge.calls()
    local ok, list = call('tsrp-police', 'GetCalls')
    return ok and list or {}
end

function Bridge.call(id)
    local ok, c = call('tsrp-police', 'GetCall', id)
    return ok and c or nil
end

-- Wraps tsrp-police "ok, err" exports
local function action(name, ...)
    local ok, a, b = call('tsrp-police', name, ...)
    if not ok then return false, 'tsrp-police is not running.' end
    return a, b
end

function Bridge.createCall(src, data) return action('CreateCall', src, data) end
function Bridge.updateCall(src, id, fields) return action('UpdateCall', src, id, fields) end
function Bridge.assign(src, id) return action('AssignUnit', src, id) end
function Bridge.unassign(src, id) return action('UnassignUnit', src, id) end
function Bridge.closeCall(src, id) return action('CloseCall', src, id) end
function Bridge.setStatus(src, status) return action('SetUnitStatus', src, status) end

function Bridge.isSupervisor(src)
    local ok, v = call('tsrp-police', 'IsSupervisor', src)
    return ok and v == true
end

---------------------------------------------------------------------
-- tsrp-core
---------------------------------------------------------------------
function Bridge.characterId(src)
    local ok, id = call('tsrp-core', 'GetCharacterId', src)
    return ok and tonumber(id) or nil
end

function Bridge.searchCharacters(query)
    local ok, rows = call('tsrp-core', 'SearchCharacters', query, 25)
    return ok and rows or nil
end

function Bridge.character(id)
    local ok, row = call('tsrp-core', 'GetCharacterById', id)
    return ok and row or nil
end

function Bridge.metadata(id, key)
    local ok, v = call('tsrp-core', 'GetCharacterMetadata', id, key)
    return ok and v or nil
end

function Bridge.setMetadata(id, key, value)
    local ok, a = call('tsrp-core', 'SetCharacterMetadata', id, key, value)
    return ok and a ~= false
end

---------------------------------------------------------------------
-- Positions (OneSync, server side) for the units grid
---------------------------------------------------------------------
function Bridge.coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local c = GetEntityCoords(ped)
    return { x = math.floor(c.x * 10) / 10, y = math.floor(c.y * 10) / 10, z = math.floor(c.z) }
end
