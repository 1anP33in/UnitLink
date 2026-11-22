---------------------------------------------------------------------
-- Panic alerts (receiving side) + sending a panic.
---------------------------------------------------------------------
PanicClient = {}

local lastPanic = nil
local areaBlips = {}

function PanicClient.trigger()
    -- the server checks duty, department and cooldown
    TriggerServerEvent('unitlink-police:server:panic', Police.myStreet())
end

function PanicClient.recent()
    if lastPanic and GetGameTimer() - lastPanic.at < (Config.Panic.waypointWindow or 60) * 1000 then
        return lastPanic
    end
end

function PanicClient.waypoint(p)
    SetNewWaypoint(p.coords.x + 0.0, p.coords.y + 0.0)
    UnitLinkUI.notify(('Waypoint set to **%s**.'):format(p.callsign), 'success', 'GPS', 2500)
end

local function addAreaBlip(c)
    local area = AddBlipForRadius(c.x + 0.0, c.y + 0.0, c.z + 0.0, 80.0)
    SetBlipColour(area, 1)
    SetBlipAlpha(area, 110)
    SetBlipFlashes(area, true)
    areaBlips[#areaBlips + 1] = area
    SetTimeout((Config.Panic.areaBlipTime or 120) * 1000, function()
        if DoesBlipExist(area) then RemoveBlip(area) end
        for i, b in ipairs(areaBlips) do
            if b == area then table.remove(areaBlips, i) break end
        end
    end)
end

local function clearAreaBlips()
    for _, b in ipairs(areaBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    areaBlips = {}
end

RegisterNetEvent('unitlink-police:client:panic', function(p)
    if type(p) ~= 'table' or type(p.coords) ~= 'table' then return end
    lastPanic = { coords = p.coords, callsign = p.callsign, at = GetGameTimer() }
    local key = Police.keyLabel(Police.KeyCommands.waypoint, Config.Keybinds.waypoint)

    UnitLinkUI.dispatch({
        id = 'unitlink_panic_' .. tostring(p.id),
        dept = Config.UI.panicStyle,
        code = 'PANIC',
        title = ('Officer needs help · %s'):format(p.callsign),
        message = ('%s · %s · %s\n**[%s]** Set waypoint'):format(p.name, p.department, p.time, key),
        location = Police.streetAt(p.coords),
        priority = 1,
        flash = true,
        duration = Config.Panic.notifyDuration,
    })
    addAreaBlip(p.coords)
end)

AddEventHandler('unitlink-police:dutyChanged', function(onDuty)
    if not onDuty then
        lastPanic = nil
        clearAreaBlips()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clearAreaBlips() end
end)
