---------------------------------------------------------------------
-- UnitLink client: tablet open/close, NUI <-> server bridge, live pushes,
-- coords -> street / city / county names (game natives, client only).
---------------------------------------------------------------------
local isOpen = false
local mode = nil -- 'cad' | 'civ'
local reqSeq = 0
local pending = {}
local tabletProp = nil

local function notify(message, kind)
    if GetResourceState('UnitLink-UI') ~= 'started' then
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(Config.Name .. ': ' .. tostring(message))
        EndTextCommandThefeedPostTicker(false, true)
        return
    end
    pcall(function() exports['UnitLink-UI']:Notify({ type = kind or 'info', title = Config.Name, message = message, duration = 4000 }) end)
end

---------------------------------------------------------------------
-- Server requests (one in flight per id, 8s timeout)
---------------------------------------------------------------------
local function request(action, payload)
    reqSeq = reqSeq + 1
    local id = reqSeq
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('unitlink:server:req', id, action, payload or {})
    SetTimeout(8000, function()
        if pending[id] then pending[id] = nil; p:resolve({ ok = false, data = 'The server did not answer.' }) end
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('unitlink:client:res', function(id, ok, data)
    local p = pending[id]
    if not p then return end
    pending[id] = nil
    p:resolve({ ok = ok == true, data = data })
end)

---------------------------------------------------------------------
-- Location names
---------------------------------------------------------------------
local function streetAt(c)
    if type(c) ~= 'table' or not c.x then return nil end
    local s1, s2 = GetStreetNameAtCoord(c.x + 0.0, c.y + 0.0, (c.z or 0) + 0.0)
    local street = GetStreetNameFromHashKey(s1)
    local cross = s2 ~= 0 and GetStreetNameFromHashKey(s2) or ''
    if street == '' then return nil end
    return (cross ~= '' and (street .. ' / ' .. cross) or street):upper()
end

local function cityAt(c)
    if type(c) ~= 'table' or not c.x then return '' end
    local label = GetLabelText(GetNameOfZone(c.x + 0.0, c.y + 0.0, (c.z or 0) + 0.0))
    return (label and label ~= 'NULL') and label:upper() or ''
end

-- Rough county split used by most GTA servers: north of the city = Blaine
local function countyAt(c)
    if type(c) ~= 'table' or not c.y then return '' end
    return c.y > 1000.0 and 'BLAINE COUNTY' or 'LOS SANTOS COUNTY'
end

local function decorateCall(c)
    if type(c) ~= 'table' then return end
    c.address = streetAt(c.coords) or (c.street and tostring(c.street):upper()) or 'UNKNOWN'
    c.city = cityAt(c.coords)
    c.county = countyAt(c.coords)
end

local function decorateBoard(b)
    if type(b) ~= 'table' then return end
    for _, c in ipairs(b.calls or {}) do decorateCall(c) end
    for _, u in ipairs(b.units or {}) do u.location = streetAt(u.coords) or '' end
end

-- SAFR board: incidents get address / city / county, units get a location
local function decorateFireBoard(b)
    if type(b) ~= 'table' then return end
    for _, inc in ipairs(b.incidents or {}) do decorateCall(inc) end
    for _, u in ipairs(b.units or {}) do u.location = streetAt(u.coords) or '' end
end

-- DOT board: work orders get address / city / county, units get a location
local function decorateDotBoard(b)
    if type(b) ~= 'table' then return end
    for _, o in ipairs(b.orders or {}) do decorateCall(o) end
    for _, u in ipairs(b.units or {}) do u.location = streetAt(u.coords) or '' end
end

local function myStreet()
    local c = GetEntityCoords(PlayerPedId())
    return streetAt({ x = c.x, y = c.y, z = c.z }) or ''
end

---------------------------------------------------------------------
-- Tablet animation
---------------------------------------------------------------------
local ANIM_DICT, ANIM_CLIP = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base'

local function startTablet()
    if not Config.TabletAnimation then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end
    RequestAnimDict(ANIM_DICT)
    local model = joaat('prop_cs_tablet')
    RequestModel(model)
    local timeout = GetGameTimer() + 3000
    while (not HasAnimDictLoaded(ANIM_DICT) or not HasModelLoaded(model)) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(model) then return end
    local pos = GetEntityCoords(ped)
    tabletProp = CreateObject(model, pos.x, pos.y, pos.z + 0.2, true, true, false)
    AttachEntityToEntity(tabletProp, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
    SetModelAsNoLongerNeeded(model)
    TaskPlayAnim(ped, ANIM_DICT, ANIM_CLIP, 3.0, 3.0, -1, 49, 0, false, false, false)
end

local function stopTablet()
    local ped = PlayerPedId()
    if IsEntityPlayingAnim(ped, ANIM_DICT, ANIM_CLIP, 3) then StopAnimTask(ped, ANIM_DICT, ANIM_CLIP, 1.0) end
    if tabletProp and DoesEntityExist(tabletProp) then DeleteEntity(tabletProp) end
    tabletProp = nil
end

---------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------
local function closeTablet()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = ({ civ = 'closeCiv', fire = 'closeFire', dot = 'closeDot', admin = 'closeAdmin' })[mode] or 'close' })
    if mode == 'cad' or mode == 'fire' or mode == 'dot' then TriggerServerEvent('unitlink:server:closed') end
    mode = nil
    stopTablet()
end

local function openTablet()
    if isOpen then return closeTablet() end
    if IsPauseMenuActive() then return end
    local r = request('open')
    if not r.ok then return notify(r.data or 'Could not open the CAD.', 'error') end
    if r.data.kind == 'dot' then
        decorateDotBoard(r.data.board)
        isOpen, mode = true, 'dot'
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'openDot', data = r.data })
        return CreateThread(startTablet)
    end
    if r.data.kind == 'fire' then
        decorateFireBoard(r.data.board)
        isOpen, mode = true, 'fire'
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'openFire', data = r.data })
        return CreateThread(startTablet)
    end
    decorateBoard(r.data.board)
    isOpen, mode = true, 'cad'
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = r.data })
    CreateThread(startTablet)
end

-- /civ: Civilian Portal (profiles, 911, records, vehicles, applications, service requests)
local function openCiv()
    if isOpen then return closeTablet() end
    if IsPauseMenuActive() then return end
    local r = request('civ.portal')
    if not r.ok then return notify(r.data or 'Could not open the Civilian Portal.', 'error') end
    isOpen, mode = true, 'civ'
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCiv', data = r.data })
end

-- /cadadmin: Admin Dashboard (ACE unitlink.admin, checked by the server)
local function openAdmin()
    if isOpen then return closeTablet() end
    if IsPauseMenuActive() then return end
    local r = request('admin.open')
    if not r.ok then return notify(r.data or 'Could not open the Admin Dashboard.', 'error') end
    isOpen, mode = true, 'admin'
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openAdmin', data = r.data })
end
RegisterCommand((Config.Admin and Config.Admin.command) or 'cadadmin', function() CreateThread(openAdmin) end, false)
RegisterCommand(Config.Civ.command, function() CreateThread(openCiv) end, false)

-- civilians: /911fire <message> and /911ems <message> (SAFR)
if Config.Fire and Config.Fire.enabled then
    for kind, cmd in pairs(Config.Fire.commands) do
        RegisterCommand(cmd, function(_, args)
            TriggerServerEvent('unitlink:server:fire911', kind, table.concat(args, ' '), myStreet())
        end, false)
    end
end

RegisterCommand(Config.Command, function() CreateThread(openTablet) end, false)
RegisterCommand('+unitlink_open', function() CreateThread(openTablet) end, false)
RegisterCommand('-unitlink_open', function() end, false)
RegisterKeyMapping('+unitlink_open', 'Open ' .. Config.Name .. ' CAD', 'keyboard', Config.Key or '')
CreateThread(function()
    Wait(1000)
    TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Open the ' .. Config.Name .. ' CAD')
    TriggerEvent('chat:addSuggestion', '/' .. Config.Civ.command, 'Civilian Portal: profiles, 911, records, vehicles, applications')
    TriggerEvent('chat:addSuggestion', '/' .. ((Config.Admin and Config.Admin.command) or 'cadadmin'), 'UnitLink Admin Dashboard (admins only)')
    if Config.Fire and Config.Fire.enabled then
        TriggerEvent('chat:addSuggestion', '/' .. Config.Fire.commands.fire, 'Report a fire to Fire & Rescue', { { name = 'message', help = 'What is burning and where' } })
        TriggerEvent('chat:addSuggestion', '/' .. Config.Fire.commands.medical, 'Call for an ambulance (Fire & Rescue)', { { name = 'message', help = 'Who is hurt and how' } })
    end
    TriggerEvent('chat:removeSuggestion', '/+unitlink_open')
    TriggerEvent('chat:removeSuggestion', '/-unitlink_open')
end)

---------------------------------------------------------------------
-- NUI -> client -> server
---------------------------------------------------------------------
RegisterNUICallback('req', function(data, cb)
    local action = type(data) == 'table' and data.action
    local payload = type(data) == 'table' and type(data.payload) == 'table' and data.payload or {}
    if type(action) ~= 'string' then return cb({ ok = false, data = 'Bad request.' }) end

    -- client-only actions
    if action == 'close' then closeTablet(); return cb({ ok = true }) end
    if action == 'panic' then
        TriggerServerEvent('unitlink-police:server:panic', myStreet())
        return cb({ ok = true })
    end

    if action == 'createCall' or action == 'fire.create' or action == 'fire.mayday' or action == 'dot.create'
        or action == 'civ.call' or action == 'civ.service' then payload.street = myStreet() end

    local r = request(action, payload)
    if r.ok then
        -- portal 911 to police: UnitLink-Police takes the call from the caller's own event (same as /911)
        if action == 'civ.call' and type(r.data) == 'table' and r.data.police then
            TriggerServerEvent('unitlink-police:server:submitCall', r.data.message, payload.street)
        end
        if action == 'board' then decorateBoard(r.data) end
        if action == 'fire.board' then decorateFireBoard(r.data) end
        if action == 'dot.board' then decorateDotBoard(r.data) end
        if action == 'dot.get' and type(r.data) == 'table' and r.data.order then decorateCall(r.data.order) end
        if action == 'dot.waypoint' and type(r.data) == 'table' and r.data.coords then
            SetNewWaypoint(r.data.coords.x + 0.0, r.data.coords.y + 0.0)
        end
        if action == 'fire.get' and type(r.data) == 'table' and r.data.incident then decorateCall(r.data.incident) end
        if action == 'fire.waypoint' and type(r.data) == 'table' and r.data.coords then
            SetNewWaypoint(r.data.coords.x + 0.0, r.data.coords.y + 0.0)
        end
        if action == 'getCall' and type(r.data) == 'table' then decorateCall(r.data.call) end
        if action == 'waypoint' and type(r.data) == 'table' and r.data.coords then
            SetNewWaypoint(r.data.coords.x + 0.0, r.data.coords.y + 0.0)
        end
    end
    cb(r)
end)

-- server pushes (board, notes, alerts, signal 100, force close)
RegisterNetEvent('unitlink:client:push', function(kind, data)
    if not isOpen or (mode ~= 'cad' and mode ~= 'fire' and mode ~= 'dot') then return end
    if kind == 'forceClose' then
        closeTablet()
        return notify(data or 'CAD closed.', 'warning')
    end
    -- shared tools pushes go to every department tablet
    if kind:sub(1, 5) == 'tools' then return SendNUIMessage({ action = 'toolsPush', kind = kind, data = data }) end
    if mode == 'dot' then
        if kind:sub(1, 3) ~= 'dot' then return end
        if kind == 'dotBoard' then decorateDotBoard(data) end
        return SendNUIMessage({ action = 'dotPush', kind = kind, data = data })
    end
    if mode == 'fire' then
        if kind:sub(1, 4) ~= 'fire' then return end
        if kind == 'fireBoard' then decorateFireBoard(data) end
        return SendNUIMessage({ action = 'firePush', kind = kind, data = data })
    end
    if kind:sub(1, 4) == 'fire' or kind:sub(1, 3) == 'dot' then return end
    if kind == 'board' then decorateBoard(data) end
    SendNUIMessage({ action = 'push', kind = kind, data = data })
end)

-- going off duty closes the tablet
AddEventHandler('unitlink-police:dutyChanged', function(onDuty)
    if not onDuty and (mode == 'cad' or mode == 'fire' or mode == 'dot') then closeTablet() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
    stopTablet()
end)
