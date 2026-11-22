---------------------------------------------------------------------
-- Client core: this player's duty state (as told by the server),
-- small helpers shared by the other client files.
---------------------------------------------------------------------
State = { onDuty = false }
local stateAt = 0
local waiters = {}

Police.myId = GetPlayerServerId(PlayerId())

-- Hidden commands behind the rebindable keys (Settings > Key Bindings > FiveM)
Police.KeyCommands = {
    duty     = 'tsrp_police_duty',
    calls    = 'tsrp_police_calls',
    panic    = 'tsrp_police_panic',
    accept   = 'tsrp_police_accept',
    deny     = 'tsrp_police_deny',
    waypoint = 'tsrp_police_waypoint',
}

RegisterNetEvent('tsrp-police:client:dutyState', function(view)
    local wasOnDuty = State.onDuty
    local prevDept, prevCallsign = State.department, State.callsign
    State = type(view) == 'table' and view or { onDuty = false }
    stateAt = GetGameTimer()

    -- only replies that carry menu data (authorized departments) answer
    -- a requestState(); ordinary pushes (status changes etc.) don't
    if State.authorized then
        for i = 1, #waiters do waiters[i](State) end
        waiters = {}
    end

    if State.onDuty and State.callsign and (State.callsign ~= prevCallsign or State.department ~= prevDept) then
        SetResourceKvp('tsrp_police:callsign:' .. State.department, State.callsign)
    end
    if wasOnDuty ~= State.onDuty then
        TriggerEvent('tsrp-police:dutyChanged', State.onDuty, State)
    end
end)

-- Ask the server for fresh state (incl. authorized departments). Blocking.
function Police.requestState(timeoutMs)
    local p = promise.new()
    local done = false
    waiters[#waiters + 1] = function(s)
        if not done then done = true; p:resolve(s) end
    end
    TriggerServerEvent('tsrp-police:server:requestState')
    SetTimeout(timeoutMs or 4000, function()
        if not done then done = true; p:resolve(nil) end
    end)
    return Citizen.Await(p)
end

-- Seconds on duty, counting up locally between server updates
function Police.elapsed()
    if not State.onDuty then return 0 end
    return (State.elapsed or 0) + (GetGameTimer() - stateAt) // 1000
end

function Police.hasFlag(flag)
    return State.onDuty and State.flags and State.flags[flag] == true
end

-- Street + cross street + zone for any coords (resolved on this client)
function Police.streetAt(c)
    if not c then return 'Unknown location' end
    local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local street = GetStreetNameFromHashKey(s1)
    local cross = s2 ~= 0 and GetStreetNameFromHashKey(s2) or ''
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    local text = street ~= '' and street or 'Unknown street'
    if cross ~= '' then text = text .. ' / ' .. cross end
    if zone and zone ~= '' and zone ~= 'NULL' then text = text .. ', ' .. zone end
    return text
end

function Police.myStreet()
    return Police.streetAt(GetEntityCoords(PlayerPedId()))
end

-- Key label for a key-mapped command, e.g. 'Y' (falls back to the default)
function Police.keyLabel(command, fallback)
    local ok, label = pcall(GetControlInstructionalButton, 0, joaat(command) | 0x80000000, true)
    if ok and type(label) == 'string' and label:sub(1, 2) == 't_' then return label:sub(3) end
    return fallback ~= '' and fallback or '?'
end

-- Run a menu callback in this resource's own thread (tsrp-ui calls our
-- onSelect functions from its runtime; blocking work must not run there)
function Police.async(fn)
    return function(...)
        local args = table.pack(...)
        CreateThread(function() fn(table.unpack(args, 1, args.n)) end)
    end
end

-- Pick up our state after joining or a resource restart
CreateThread(function()
    Wait(1000)
    TriggerServerEvent('tsrp-police:server:requestState')
end)

exports('IsOnDuty', function() return State.onDuty end)
exports('GetDutyState', function()
    if not State.onDuty then return { onDuty = false } end
    return {
        onDuty = true, callsign = State.callsign, department = State.department,
        status = State.status, elapsed = Police.elapsed(),
    }
end)
