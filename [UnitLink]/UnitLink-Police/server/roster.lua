---------------------------------------------------------------------
-- /police roster + live officer blip sync.
--
-- Positions are read SERVER side (OneSync) - clients never report their
-- own location. Updates only go to on-duty units whose department type has
-- `seeBlips`, and only officers that moved / changed are sent each tick.
---------------------------------------------------------------------
Roster = {}

local V = Police.Vehicle

---------------------------------------------------------------------
-- Roster
---------------------------------------------------------------------
local subscribers = {} -- [source] = true while /police is open
local dirty = false

function Roster.build()
    local byDept, total = {}, 0
    Duty.each('roster', function(_, s)
        local list = byDept[s.department] or {}
        list[#list + 1] = {
            callsign = s.callsign, name = s.name, status = s.status,
            elapsed = os.time() - s.startedAt,
        }
        byDept[s.department] = list
        total = total + 1
    end)
    local departments = {}
    for _, key in ipairs(Utils.departmentKeys()) do
        local list = byDept[key]
        if list then
            table.sort(list, function(a, b) return a.callsign < b.callsign end)
            local d = Config.Departments[key]
            departments[#departments + 1] = { key = key, short = d.short, name = d.name, officers = list }
        end
    end
    return { total = total, departments = departments }
end

local function canViewRoster(src)
    return not Config.Roster.onDutyOnly or Duty.isOnDuty(src)
end

Police.net('requestRoster', 'roster', function(src, subscribe)
    if not canViewRoster(src) then
        return Police.notify(src, 'Only on-duty units can view the roster.', 'error', 'Roster')
    end
    Police.toClient(src, 'roster', Roster.build())
    subscribers[src] = subscribe == true or nil
end)

-- No rate limit: closing must always work
RegisterNetEvent('unitlink-police:server:closeRoster', function()
    subscribers[source] = nil
end)

Police.on('rosterChanged', function() dirty = true end)

-- Push live updates to open rosters at most once per second
CreateThread(function()
    while true do
        Wait(1000)
        if dirty and next(subscribers) then
            dirty = false
            local data = Roster.build()
            for src in pairs(subscribers) do
                if canViewRoster(src) and GetPlayerName(src) then
                    Police.toClient(src, 'roster', data)
                else
                    subscribers[src] = nil
                end
            end
        elseif not next(subscribers) then
            dirty = false
        end
    end
end)

---------------------------------------------------------------------
-- Blips
---------------------------------------------------------------------
local lastSent = {}   -- [officerSrc] = last entry sent
local needsFull = {}  -- [viewerSrc] = true -> send a full snapshot next tick
local panicUntil = {} -- [officerSrc] = os.time() when the panic flash ends

local VEHICLE_TYPES = { automobile = V.CAR, bike = V.BIKE, quadbike = V.BIKE, heli = V.HELI, plane = V.PLANE, boat = V.BOAT, submarine = V.BOAT, train = V.CAR, trailer = V.CAR }

local function viewers()
    local list = {}
    Duty.each('seeBlips', function(src) list[#list + 1] = src end)
    return list
end

local function sendToViewers(event, ...)
    for _, src in ipairs(viewers()) do Police.toClient(src, event, ...) end
end

local function entryFor(src, s)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local c = GetEntityCoords(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    local v, heading = V.FOOT, GetEntityHeading(ped)
    if veh and veh ~= 0 then
        v = VEHICLE_TYPES[GetVehicleType(veh)] or V.CAR
        heading = GetEntityHeading(veh)
    end
    return {
        id = src,
        x = math.floor(c.x * 10 + 0.5) / 10, y = math.floor(c.y * 10 + 0.5) / 10, z = math.floor(c.z + 0.5),
        h = math.floor(heading + 0.5),
        v = v, d = s.department, c = s.callsign,
        p = (panicUntil[src] or 0) > os.time() or nil,
    }
end

local function changed(a, b)
    if not b then return true end
    if a.v ~= b.v or a.d ~= b.d or a.c ~= b.c or a.p ~= b.p then return true end
    local dx, dy = a.x - b.x, a.y - b.y
    if dx * dx + dy * dy >= (Config.Blips.minDistance or 3.0) ^ 2 then return true end
    return math.abs(((a.h - b.h + 180) % 360) - 180) >= 25
end

local function removeOfficer(src)
    if lastSent[src] == nil then return end
    lastSent[src] = nil
    sendToViewers('blipsRemove', src)
end

function Roster.setPanic(src, seconds)
    panicUntil[src] = os.time() + seconds
    lastSent[src] = nil -- force a send next tick
end

Police.on('clockIn', function(s)
    if Utils.deptHas(s.department, 'seeBlips') then needsFull[s.source] = true end
end)

Police.on('clockOut', function(s)
    needsFull[s.source] = nil
    panicUntil[s.source] = nil
    removeOfficer(s.source)
    Police.toClient(s.source, 'blipsClear')
    subscribers[s.source] = canViewRoster(s.source) and subscribers[s.source] or nil
end)

Police.on('blipVisibilityChanged', function(s)
    if not s.blipVisible then removeOfficer(s.source) end
end)

Police.on('playerDropped', function(src)
    subscribers[src] = nil
    needsFull[src] = nil
    panicUntil[src] = nil
end)

CreateThread(function()
    while true do
        Wait(math.max(500, Config.Blips.updateInterval or 2500))
        if Config.Blips.enabled then
            local targets = viewers()
            if #targets > 0 then
                local all, delta = {}, {}
                Duty.each('showOnBlips', function(src, s)
                    if s.blipVisible then
                        local e = entryFor(src, s)
                        if e then
                            all[#all + 1] = e
                            if changed(e, lastSent[src]) then
                                delta[#delta + 1] = e
                                lastSent[src] = e
                            end
                        end
                    end
                end)
                for _, src in ipairs(targets) do
                    if needsFull[src] then
                        needsFull[src] = nil
                        Police.toClient(src, 'blipsFull', all)
                    elseif #delta > 0 then
                        Police.toClient(src, 'blipsUpdate', delta)
                    end
                end
            end
        end
    end
end)
