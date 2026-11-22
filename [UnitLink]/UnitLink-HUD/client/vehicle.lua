-- Seatbelt and turn signals. main.lua reads UnitLinkHud.seatbelt for the HUD.
UnitLinkHud = UnitLinkHud or {}
UnitLinkHud.seatbelt = false

local SPEED_MULT = Config.SpeedUnit == 'kmh' and 3.6 or 2.236936

-- Vehicle classes with no seatbelt: motorcycles, cycles, boats, helicopters, planes, trains.
local NO_BELT = { [8] = true, [13] = true, [14] = true, [15] = true, [16] = true, [21] = true }

function UnitLinkHud.BeltApplies(veh)
    return veh ~= 0 and not NO_BELT[GetVehicleClass(veh)]
end

local function click(on)
    PlaySoundFrontend(-1, on and 'NAV_UP_DOWN' or 'NAV_LEFT_RIGHT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

-------------------------------------------------------------------------------
-- Seatbelt
-------------------------------------------------------------------------------
if Config.Seatbelt.Enabled then
    RegisterCommand('seatbelt', function()
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if not UnitLinkHud.BeltApplies(veh) then return end
        UnitLinkHud.seatbelt = not UnitLinkHud.seatbelt
        click(UnitLinkHud.seatbelt)
        if Config.Notify.seatbelt and UnitLinkHud.Notify then
            if UnitLinkHud.seatbelt then
                UnitLinkHud.Notify('success', 'Seatbelt', 'Seatbelt on.', 'check')
            else
                UnitLinkHud.Notify('warning', 'Seatbelt', 'Seatbelt off.', 'warning')
            end
        end
    end, false)
    RegisterKeyMapping('seatbelt', 'Toggle seatbelt', 'keyboard', Config.Seatbelt.key)

    local function eject(ped, veh, velocity)
        local pos = GetOffsetFromEntityInWorldCoords(veh, 0.0, 1.6, 1.0)
        SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
        Wait(1)
        SetPedToRagdoll(ped, 3000, 3000, 0, false, false, false)
        SetEntityVelocity(ped, velocity.x, velocity.y, velocity.z)
        if Config.Seatbelt.EjectDamage > 0 then
            ApplyDamageToPed(ped, Config.Seatbelt.EjectDamage, false)
        end
        if Config.Notify.eject and UnitLinkHud.Notify then
            UnitLinkHud.Notify('error', 'Crash', 'You were thrown from the vehicle. Wear your seatbelt (' .. Config.Seatbelt.key .. ').', 'car')
        end
    end

    CreateThread(function()
        local prevSpeed, prevVelocity = 0.0, vector3(0.0, 0.0, 0.0)
        local minSpeed = Config.Seatbelt.EjectMinSpeed / SPEED_MULT -- to m/s
        while true do
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and UnitLinkHud.BeltApplies(veh) then
                -- We handle ejection ourselves, so turn off GTA's own windscreen ejection.
                SetPedConfigFlag(ped, 32, false)

                if UnitLinkHud.seatbelt then
                    if Config.Seatbelt.LockExitWhileBuckled then DisableControlAction(0, 75, true) end
                    prevSpeed = GetEntitySpeed(veh)
                    Wait(0)
                else
                    local speed = GetEntitySpeed(veh)
                    if Config.Seatbelt.EjectEnabled
                        and prevSpeed > minSpeed
                        and (prevSpeed - speed) > prevSpeed * Config.Seatbelt.EjectDrop
                        and HasEntityCollidedWithAnything(veh) then
                        eject(ped, veh, prevVelocity)
                        prevSpeed = 0.0
                    else
                        prevSpeed = speed
                        prevVelocity = GetEntityVelocity(veh)
                    end
                    Wait(50)
                end
            else
                if UnitLinkHud.seatbelt then UnitLinkHud.seatbelt = false end
                prevSpeed = 0.0
                Wait(500)
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- Turn signals. 0 = off, 1 = left, 2 = right, 3 = hazards (same values as
-- GetVehicleIndicatorLights). Synced with an entity state bag.
-------------------------------------------------------------------------------
local function applyIndicators(veh, value)
    value = value or 0
    SetVehicleIndicatorLights(veh, 1, value == 1 or value == 3) -- 1 = left
    SetVehicleIndicatorLights(veh, 0, value == 2 or value == 3) -- 0 = right
end

local function setIndicators(want)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end
    local current = Entity(veh).state.thudIndicator or 0
    local value = current == want and 0 or want
    applyIndicators(veh, value)
    Entity(veh).state:set('thudIndicator', value, true)
    click(value ~= 0)
    if Config.Notify.hazards and UnitLinkHud.Notify and (want == 3) then
        UnitLinkHud.Notify('info', 'Hazard lights', value == 3 and 'Hazards on.' or 'Hazards off.', 'warning')
    end
end

if Config.Indicators.Enabled then
    RegisterCommand('indicator_left', function() setIndicators(1) end, false)
    RegisterCommand('indicator_right', function() setIndicators(2) end, false)
    RegisterCommand('indicator_hazards', function() setIndicators(3) end, false)
    RegisterKeyMapping('indicator_left', 'Turn signal left', 'keyboard', Config.Indicators.left)
    RegisterKeyMapping('indicator_right', 'Turn signal right', 'keyboard', Config.Indicators.right)
    RegisterKeyMapping('indicator_hazards', 'Hazard lights', 'keyboard', Config.Indicators.hazards)

    AddStateBagChangeHandler('thudIndicator', nil, function(bagName, _, value)
        local veh = GetEntityFromStateBagName(bagName)
        if veh ~= 0 then applyIndicators(veh, value) end
    end)
end
