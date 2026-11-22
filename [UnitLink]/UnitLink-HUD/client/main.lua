-- UnitLink HUD: collects player, world and vehicle data and sends it to the NUI page.
UnitLinkHud = UnitLinkHud or {}

local SPEED_MULT = Config.SpeedUnit == 'kmh' and 3.6 or 2.236936
local DAYS = { 'SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT' }
local MONTHS = { 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC' }

local hidden = false            -- toggled with /hud
local spawned = not Config.RequireSpawn
local needs = { hunger = nil, thirst = nil }
local job = Config.DefaultJob
local weaponNames = {}
for name, label in pairs(Config.WeaponNames) do weaponNames[GetHashKey(name)] = label end
local UNARMED = GetHashKey('WEAPON_UNARMED')

local CORE = 'UnitLink-Core'
local function coreRunning()
    return GetResourceState(CORE) == 'started'
end

-------------------------------------------------------------------------------
-- Job line: follows UnitLink-Police duty (no framework, no character groups).
--   off duty : CIV · Civilian · <active /civ profile name>
--   on duty  : SASP · Trooper · 1A-01   (supervisors: SASP · Sergeant · 1S-01)
-------------------------------------------------------------------------------
local civName = nil

-- UnitLink-Police duty state: { onDuty, department, departmentShort, callsign, supervisor } or { onDuty = false }
local function dutyState()
    if GetResourceState('UnitLink-Police') ~= 'started' then return { onDuty = false } end
    local ok, st = pcall(function() return exports['UnitLink-Police']:GetDutyState() end)
    return ok and type(st) == 'table' and st or { onDuty = false }
end

local function resolveJob()
    local duty = dutyState()
    if not duty.onDuty then
        local j = { chip = Config.DefaultJob.chip, grade = Config.DefaultJob.grade, color = Config.DefaultJob.color }
        if Config.ShowCivilianName and civName then j.grade = j.grade .. ' · ' .. civName end
        return j, duty
    end
    local d = Config.Jobs[duty.department or ''] or {}
    local title = duty.supervisor and (d.supervisorTitle or 'Supervisor') or (d.title or duty.departmentName or 'On Duty')
    return {
        chip = duty.departmentShort or tostring(duty.department or 'DUTY'):upper(),
        grade = title .. (duty.callsign and (' · ' .. duty.callsign) or ''),
        color = d.color or Config.JobDefaultColor,
    }, duty
end

local lastJobKey = nil
local function sendIdentity()
    local duty
    job, duty = resolveJob()
    lastJobKey = ('%s|%s|%s|%s'):format(tostring(duty.onDuty), tostring(duty.department), tostring(duty.callsign), tostring(duty.supervisor))
    SendNUIMessage({
        action = 'identity',
        id = GetPlayerServerId(PlayerId()),
        chip = job.chip, grade = job.grade, color = job.color,
    })
end

-- UnitLink-UI notification helper (does nothing if UnitLink-UI is not running)
function UnitLinkHud.Notify(ntype, title, message, icon)
    if GetResourceState('UnitLink-UI') ~= 'started' then return end
    exports['UnitLink-UI']:Notify({ type = ntype, title = title, message = message, icon = icon })
end

AddEventHandler('unitlink-police:dutyChanged', function(onDuty)
    sendIdentity()
    if Config.Notify.duty then
        if onDuty then
            UnitLinkHud.Notify('info', 'HUD', 'Job line set to **' .. job.chip .. ' · ' .. job.grade .. '**.', 'badge')
        else
            UnitLinkHud.Notify('info', 'HUD', 'Off duty. Job line set to **Civilian**.', 'user')
        end
    end
end)

-- civilian name comes from the server (UnitLink-CAD /civ profile)
RegisterNetEvent('unitlink-hud:client:civName', function(name)
    civName = type(name) == 'string' and name ~= '' and name or nil
    sendIdentity()
end)

-- department / callsign / supervisor can change without going off duty,
-- and the /civ profile can change: re-check every few seconds (cheap)
CreateThread(function()
    local ticks = 0
    while true do
        Wait(3000)
        ticks = ticks + 1
        local _, duty = resolveJob()
        local key = ('%s|%s|%s|%s'):format(tostring(duty.onDuty), tostring(duty.department), tostring(duty.callsign), tostring(duty.supervisor))
        if key ~= lastJobKey then sendIdentity() end
        if ticks % 5 == 0 and not duty.onDuty then TriggerServerEvent('unitlink-hud:server:identity') end
    end
end)

-------------------------------------------------------------------------------
-- Spawning. Standalone: the HUD shows once the player has spawned.
-- With UnitLink-Core, it follows the character lifecycle.
-------------------------------------------------------------------------------
AddEventHandler('playerSpawned', function()
    if coreRunning() then return end
    spawned = true
    sendIdentity()
    TriggerServerEvent('unitlink-hud:server:ready')
    TriggerServerEvent('unitlink-hud:server:identity')
end)
RegisterNetEvent('unitlink-core:client:characterSpawned', function()
    spawned = true
    sendIdentity()
    TriggerServerEvent('unitlink-hud:server:ready')
end)
RegisterNetEvent('unitlink-core:client:characterUnloaded', function()
    if Config.RequireSpawn then spawned = false end
    needs.hunger, needs.thirst = nil, nil
end)

-- Data pushed by our server script
-- warn once when a need drops past a threshold
local warned = { hunger = 100, thirst = 100 }
local function needWarn(kind, value)
    if not Config.Notify.needs or not value then return end
    local label = kind == 'hunger' and 'hungry' or 'thirsty'
    for _, step in ipairs({ 25, 10, 0 }) do
        if value <= step and warned[kind] > step then
            local msg = step == 0 and ("You're starving and losing health. Eat something.")
                or step == 10 and ("You're very " .. label .. '.') or ("You're getting " .. label .. '.')
            if kind == 'thirst' and step == 0 then msg = "You're dehydrated and losing health. Drink something." end
            UnitLinkHud.Notify(step == 0 and 'error' or 'warning', kind == 'hunger' and 'Hunger' or 'Thirst', msg, kind == 'hunger' and 'box' or 'drop')
            break
        end
    end
    warned[kind] = value
end

RegisterNetEvent('unitlink-hud:client:needs', function(hunger, thirst)
    needWarn('hunger', hunger); needWarn('thirst', thirst)
    needs.hunger, needs.thirst = hunger, thirst
end)

-------------------------------------------------------------------------------
-- Hide toggle (cinematic)
-------------------------------------------------------------------------------
RegisterCommand(Config.Toggle.command, function()
    hidden = not hidden
    if Config.Notify.hudToggle then
        UnitLinkHud.Notify('info', 'HUD', hidden and ('HUD hidden. Press **' .. Config.Toggle.key .. '** to bring it back.') or 'HUD shown.', 'eye')
    end
end, false)
RegisterKeyMapping(Config.Toggle.command, 'Hide or show the HUD', 'keyboard', Config.Toggle.key)

-------------------------------------------------------------------------------
-- /hud settings (UnitLink-UI input dialog), saved per player with KVP
-------------------------------------------------------------------------------
local settings = { scale = 100, minimapOnFoot = Config.Show.minimapOnFoot, compass = Config.Show.compass }

local function loadSettings()
    local raw = GetResourceKvpString('unitlink_hud_settings')
    local ok, saved = pcall(json.decode, raw or '')
    if ok and type(saved) == 'table' then
        for k, v in pairs(saved) do if settings[k] ~= nil then settings[k] = v end end
    end
    settings.scale = math.max(Config.Settings.minScale, math.min(Config.Settings.maxScale, tonumber(settings.scale) or 100))
end

local function applySettings()
    Config.Show.minimapOnFoot = settings.minimapOnFoot == true
    SendNUIMessage({ action = 'settings', scale = settings.scale / 100, compass = settings.compass ~= false })
end
UnitLinkHud.ApplySettings = applySettings

RegisterCommand(Config.Settings.command, function()
    if GetResourceState('UnitLink-UI') ~= 'started' then return end
    CreateThread(function()
        local v = exports['UnitLink-UI']:InputDialog('HUD settings', {
            { type = 'slider', label = 'HUD size', min = Config.Settings.minScale, max = Config.Settings.maxScale, step = Config.Settings.step, default = settings.scale, description = '100 = normal size' },
            { type = 'toggle', label = 'Minimap on foot', default = settings.minimapOnFoot == true, description = 'Off = minimap only shows in a vehicle' },
            { type = 'toggle', label = 'Compass and street name', default = settings.compass ~= false },
        }, { icon = 'gear', description = 'Saved for you on this computer.', submitLabel = 'Save' })
        if not v then return end
        settings.scale = tonumber(v[1]) or settings.scale
        settings.minimapOnFoot = v[2] == true
        settings.compass = v[3] == true
        SetResourceKvp('unitlink_hud_settings', json.encode(settings))
        applySettings()
        UnitLinkHud.Notify('success', 'HUD settings saved', 'Size **' .. settings.scale .. '%**.', 'gear')
    end)
end, false)

loadSettings()

exports('IsHidden', function() return hidden end)
exports('SetHidden', function(value) hidden = value and true or false end)
exports('IsSeatbeltOn', function() return UnitLinkHud.seatbelt end)

-------------------------------------------------------------------------------
-- Data collection
-------------------------------------------------------------------------------
local function pct(v) return math.max(0, math.min(100, math.floor(v + 0.5))) end

local function readStatus(ped)
    local maxH = GetEntityMaxHealth(ped) - 100
    local health = maxH > 0 and (GetEntityHealth(ped) - 100) / maxH * 100 or 0
    return {
        health = pct(health),
        armor = pct(GetPedArmour(ped)),
        stamina = pct(100 - GetPlayerSprintStaminaRemaining(PlayerId())),
        hunger = Config.Needs.Enabled and needs.hunger and pct(needs.hunger) or nil,
        thirst = Config.Needs.Enabled and needs.thirst and pct(needs.thirst) or nil,
    }
end

local street = { name = '', zone = '' }
local lastStreetAt = 0
local function readStreet(coords)
    local now = GetGameTimer()
    if now - lastStreetAt < Config.Rates.street then return street end
    lastStreetAt = now
    local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local name = GetStreetNameFromHashKey(s1)
    if s2 ~= 0 then
        local cross = GetStreetNameFromHashKey(s2)
        if cross ~= '' then name = name .. ' / ' .. cross end
    end
    street = { name = name, zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z)) }
    return street
end

local function readClock()
    local m = GetClockMonth() + 1
    return {
        time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
        date = ('%s %d %s'):format(DAYS[GetClockDayOfWeek() + 1] or '', GetClockDayOfMonth(), MONTHS[m] or ''),
    }
end

local function readWeapon(ped, inVehicle)
    if not Config.Show.weapon then return nil end
    local _, weapon = GetCurrentPedWeapon(ped, true)
    if not weapon or weapon == UNARMED or weapon == 0 then return nil end
    if inVehicle and not IsPedDoingDriveby(ped) then return nil end
    local data = { name = weaponNames[weapon] or 'Weapon' }
    local maxClip = GetMaxAmmoInClip(ped, weapon, true)
    if maxClip and maxClip > 1 then
        local _, clip = GetAmmoInClip(ped, weapon)
        local total = GetAmmoInPedWeapon(ped, weapon)
        data.clip, data.maxClip = clip, maxClip
        data.reserve = math.max(0, total - clip)
    end
    return data
end

local function readVoice()
    if not Config.Show.voice then return nil end
    local pid = PlayerId()
    local data = { talking = NetworkIsPlayerTalking(pid) or MumbleIsPlayerTalking(pid) }
    if GetResourceState('pma-voice') == 'started' then
        local prox = LocalPlayer.state.proximity
        if type(prox) == 'table' and prox.index then
            data.range = math.max(0, math.min(2, prox.index - 1))
            data.label = prox.mode
        end
        local channel = LocalPlayer.state.radioChannel
        if channel and channel ~= 0 then data.radio = 'CH ' .. tostring(channel) end
    end
    return data
end

local function readVehicle(ped, veh)
    local speed = GetEntitySpeed(veh) * SPEED_MULT
    local gear = GetVehicleCurrentGear(veh)
    local gearText
    if speed < 1 then gearText = 'N'
    elseif gear == 0 then gearText = 'R'
    else gearText = tostring(gear) end

    local _, lightsOn, highBeams = GetVehicleLightsState(veh)
    local on = function(v) return v == true or v == 1 end
    local emergency = GetVehicleClass(veh) == 18 -- police, ambulance, fire truck
    return {
        speed = math.floor(speed + 0.5),
        gear = gearText,
        fuel = pct(GetVehicleFuelLevel(veh)),
        engine = pct(GetVehicleEngineHealth(veh) / 10),
        beltApplies = Config.Seatbelt.Enabled and UnitLinkHud.BeltApplies(veh),
        belt = UnitLinkHud.seatbelt,
        lights = on(lightsOn) or on(highBeams),
        emergency = emergency,
        siren = emergency and IsVehicleSirenOn(veh) or false,
        indicator = GetVehicleIndicatorLights(veh),
    }
end

-------------------------------------------------------------------------------
-- Main loop
-------------------------------------------------------------------------------
local lastVisible, lastRadar
CreateThread(function()
    Wait(500)
    SendNUIMessage({
        action = 'init',
        show = Config.Show, logo = Config.Logo,
        unit = Config.SpeedUnit == 'kmh' and 'KM/H' or 'MPH',
        letterbox = Config.Toggle.letterbox,
    })
    applySettings()
    if coreRunning() then
        local ok, isSpawned = pcall(function() return exports[CORE]:IsSpawned() end)
        if ok and isSpawned then spawned = true end
    elseif NetworkIsPlayerActive(PlayerId()) and DoesEntityExist(PlayerPedId()) then
        spawned = true -- standalone: resource (re)started while already in game
    end
    TriggerServerEvent('unitlink-hud:server:identity')
    sendIdentity()
    TriggerServerEvent('unitlink-hud:server:ready')

    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local inVehicle = veh ~= 0
        local paused = IsPauseMenuActive()
        local visible = spawned and not hidden and not paused

        if visible ~= lastVisible then
            SendNUIMessage({ action = 'visible', value = visible, cinematic = hidden and spawned })
            lastVisible = visible
        end

        local radar = visible and (inVehicle or Config.Show.minimapOnFoot)
        if radar ~= lastRadar then
            DisplayRadar(radar)
            lastRadar = radar
        end

        if visible then
            local coords = GetEntityCoords(ped)
            local camRot = GetGameplayCamRot(2)
            SendNUIMessage({
                action = 'tick',
                status = readStatus(ped),
                heading = (360.0 - camRot.z) % 360.0,
                street = readStreet(coords),
                clock = readClock(),
                weapon = readWeapon(ped, inVehicle),
                voice = readVoice(),
                vehicle = (inVehicle and Config.Show.vehicle) and readVehicle(ped, veh) or false,
            })
            Wait(inVehicle and Config.Rates.vehicle or Config.Rates.foot)
        else
            Wait(250)
        end
    end
end)

-- Every frame: hide the GTA parts we replace, and everything while hidden.
CreateThread(function()
    while true do
        if hidden then
            HideHudAndRadarThisFrame()
        else
            for i = 1, #Config.HideNative do HideHudComponentThisFrame(Config.HideNative[i]) end
        end
        Wait(0)
    end
end)

-- Hunger/thirst at zero slowly hurts.
if Config.Needs.Enabled and Config.Needs.DamageAtZero > 0 then
    CreateThread(function()
        while true do
            Wait(10000)
            if spawned and ((needs.hunger and needs.hunger <= 0) or (needs.thirst and needs.thirst <= 0)) then
                local ped = PlayerPedId()
                if not IsEntityDead(ped) then
                    SetEntityHealth(ped, math.max(100, GetEntityHealth(ped) - Config.Needs.DamageAtZero))
                end
            end
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then DisplayRadar(true) end
end)

-- Stay behind UnitLink-UI so its notifications and menus are always readable.
if SetNuiZindex then SetNuiZindex(0) end
