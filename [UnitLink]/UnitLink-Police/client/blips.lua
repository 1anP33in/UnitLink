---------------------------------------------------------------------
-- Live officer blips. Data comes only from the server (positions read
-- server side); this file just draws it.
--
-- Nearby officers (whose ped is streamed in) get an entity blip that moves
-- smoothly on its own; far away officers get a coordinate blip moved on
-- each server update.
---------------------------------------------------------------------
local B = Config.Blips
local V = Police.Vehicle
local blips = {} -- [serverId] = { handle, mode = 'entity' | 'coord', data }

local SPRITES = {
    [V.FOOT] = B.sprites.foot, [V.CAR] = B.sprites.car, [V.BIKE] = B.sprites.bike,
    [V.HELI] = B.sprites.heli, [V.PLANE] = B.sprites.plane, [V.BOAT] = B.sprites.boat,
}

local function style(handle, d)
    SetBlipSprite(handle, SPRITES[d.v] or B.sprites.foot)
    SetBlipColour(handle, (Config.Departments[d.d] or {}).blipColor or 0)
    SetBlipScale(handle, B.scale)
    SetBlipDisplay(handle, B.display)
    SetBlipAsShortRange(handle, B.shortRange)
    SetBlipCategory(handle, 7)
    ShowHeadingIndicatorOnBlip(handle, B.showHeading and true or false)
    SetBlipFlashes(handle, d.p == true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(B.labelFormat:format(d.c or '?', (Config.Departments[d.d] or {}).short or '?'))
    EndTextCommandSetBlipName(handle)
end

local function remove(id)
    local b = blips[id]
    if not b then return end
    if DoesBlipExist(b.handle) then RemoveBlip(b.handle) end
    blips[id] = nil
end

local function clear()
    for id in pairs(blips) do remove(id) end
end

local function streamedPed(id)
    local player = GetPlayerFromServerId(id)
    if player == -1 then return nil end
    local ped = GetPlayerPed(player)
    return (ped ~= 0 and DoesEntityExist(ped)) and ped or nil
end

local function create(d)
    local ped = streamedPed(d.id)
    local handle, mode
    if ped then
        handle, mode = AddBlipForEntity(ped), 'entity'
    else
        handle, mode = AddBlipForCoord(d.x + 0.0, d.y + 0.0, d.z + 0.0), 'coord'
        SetBlipRotation(handle, math.floor(d.h or 0))
    end
    style(handle, d)
    blips[d.id] = { handle = handle, mode = mode, data = d }
end

local function upsert(d)
    if type(d) ~= 'table' or not d.id or d.id == Police.myId then return end
    local b = blips[d.id]
    if not b then return create(d) end

    -- entity streamed in / out since last time: recreate in the right mode
    local wantEntity = streamedPed(d.id) ~= nil
    if not DoesBlipExist(b.handle) or (b.mode == 'entity') ~= wantEntity then
        remove(d.id)
        return create(d)
    end

    if b.mode == 'coord' then
        SetBlipCoords(b.handle, d.x + 0.0, d.y + 0.0, d.z + 0.0)
        SetBlipRotation(b.handle, math.floor(d.h or 0))
    end
    local o = b.data
    if o.v ~= d.v or o.d ~= d.d or o.c ~= d.c or o.p ~= d.p then style(b.handle, d) end
    b.data = d
end

RegisterNetEvent('unitlink-police:client:blipsFull', function(list)
    if type(list) ~= 'table' then return end
    local seen = {}
    for _, d in ipairs(list) do
        seen[d.id] = true
        upsert(d)
    end
    for id in pairs(blips) do
        if not seen[id] then remove(id) end
    end
end)

RegisterNetEvent('unitlink-police:client:blipsUpdate', function(list)
    if type(list) ~= 'table' then return end
    for _, d in ipairs(list) do upsert(d) end
end)

RegisterNetEvent('unitlink-police:client:blipsRemove', function(id) remove(id) end)
RegisterNetEvent('unitlink-police:client:blipsClear', clear)

AddEventHandler('unitlink-police:dutyChanged', function(onDuty)
    if not onDuty then clear() end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clear() end
end)
