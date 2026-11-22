---------------------------------------------------------------------
-- 911 calls on the unit side.
--   - Incoming calls show as an UnitLink-UI dispatch card with key hints.
--   - Keys act on the newest call you haven't accepted or denied.
--   - /calls opens a clickable menu with Accept / Deny / Set Waypoint
--     for every open call.
-- The server owns all call state; this file only displays it and sends
-- requests.
---------------------------------------------------------------------
CallsMenu = {}

local MENU = 'unitlink_police_calls'
local calls = {}      -- [id] = call view from the server
local denied = {}     -- [id] = true once this officer denied it
local shownUntil = {} -- [id] = GetGameTimer() when the card leaves the screen
local snapshotWaiter = nil

local function cardId(id) return 'unitlink_call_' .. id end

local function isUnit(call)
    for _, u in ipairs(call.units or {}) do
        if u.src == Police.myId then return true end
    end
    return false
end

local function unitsText(call)
    local list = {}
    for _, u in ipairs(call.units or {}) do list[#list + 1] = ('%s (%s)'):format(u.callsign, u.department) end
    return #list > 0 and table.concat(list, ', ') or 'None'
end

local function statusText(call)
    local n = #(call.units or {})
    if n == 0 then return 'Pending · no units' end
    return ('Active · %d unit%s: %s'):format(n, n == 1 and '' or 's', unitsText(call))
end

local function short(text, max)
    local s = Utils.sanitize(text, max) or ''
    if Utils.length(text or '') > max then s = s .. '…' end
    return s
end

local function keyHints()
    local K, D = Police.KeyCommands, Config.Keybinds
    return ('**[%s]** Accept · **[%s]** Deny · **[%s]** Waypoint'):format(
        Police.keyLabel(K.accept, D.accept), Police.keyLabel(K.deny, D.deny), Police.keyLabel(K.waypoint, D.waypoint))
end

local function sortedIds()
    local ids = {}
    for id in pairs(calls) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return a > b end)
    return ids
end

-- Newest call this officer hasn't answered yet (target of the keys)
local function pendingTarget()
    for _, id in ipairs(sortedIds()) do
        local c = calls[id]
        if not denied[id] and not isUnit(c) then return c end
    end
end

-- Newest call this officer is responding to
local function myLatestCall()
    for _, id in ipairs(sortedIds()) do
        if isUnit(calls[id]) then return calls[id] end
    end
end

---------------------------------------------------------------------
-- Call card
---------------------------------------------------------------------
local function showCard(call, isNew)
    if denied[call.id] then return end
    local now = GetGameTimer()
    local duration
    if isNew then
        duration = Config.Emergency.notifyDuration
    else
        duration = (shownUntil[call.id] or 0) - now
        if duration < 750 then return end -- card already gone; don't pop it back up
    end
    shownUntil[call.id] = now + duration

    local lines = { call.message, ('%s · %s'):format(statusText(call), call.time) }
    lines[#lines + 1] = isUnit(call) and '**You are responding.** Use /' .. Config.Commands.calls .. ' to cancel.' or keyHints()

    UnitLinkUI.dispatch({
        id = cardId(call.id),
        dept = Config.UI.dispatchStyle,
        code = ('911 · #%d'):format(call.id),
        title = call.callerName,
        message = table.concat(lines, '\n'),
        location = Police.streetAt(call.coords),
        priority = Config.Emergency.priority,
        duration = duration,
        sound = (not isNew) and false or nil,
    })
end

local function forget(id)
    calls[id], denied[id], shownUntil[id] = nil, nil, nil
    UnitLinkUI.remove(cardId(id))
end

---------------------------------------------------------------------
-- Requests (the server validates every one)
---------------------------------------------------------------------
function CallsMenu.action(action, id)
    TriggerServerEvent('unitlink-police:server:callAction', action, id)
end

local function needs911()
    if Police.hasFlag('receives911') then return true end
    UnitLinkUI.notify('Only on-duty units receive 911 calls.', 'error', '911', 3000)
    return false
end

function CallsMenu.keyAccept()
    if not Police.hasFlag('receives911') then return end
    local c = pendingTarget()
    if not c then return UnitLinkUI.notify('No pending calls.', 'info', '911', 2500) end
    CallsMenu.action('accept', c.id)
end

function CallsMenu.keyDeny()
    if not Police.hasFlag('receives911') then return end
    local c = pendingTarget()
    if not c then return UnitLinkUI.notify('No pending calls.', 'info', '911', 2500) end
    CallsMenu.action('deny', c.id)
end

function CallsMenu.keyWaypoint()
    if not State.onDuty then return end
    local panic = PanicClient and PanicClient.recent()
    if panic then return PanicClient.waypoint(panic) end
    if not Police.hasFlag('receives911') then return end
    local c = pendingTarget() or myLatestCall()
    if not c then return UnitLinkUI.notify('No calls to set a waypoint for.', 'info', '911', 2500) end
    CallsMenu.action('waypoint', c.id)
end

---------------------------------------------------------------------
-- /calls menu
---------------------------------------------------------------------
local function build()
    local menus, root = {}, {}
    for _, id in ipairs(sortedIds()) do
        local c = calls[id]
        local mine = isUnit(c)
        local info = Police.CallStatusInfo[c.status] or {}
        local street = Police.streetAt(c.coords)
        root[#root + 1] = {
            title = ('#%d · %s'):format(id, c.callerName),
            description = (mine and '**Responding** · ' or (denied[id] and 'Dismissed · ' or '')) .. short(c.message, 60),
            icon = 'bell', iconColor = mine and '#3ba7ff' or info.color,
            metadata = {
                { label = 'Status', value = info.label or c.status },
                { label = 'Units', value = unitsText(c) },
                { label = 'Location', value = street },
                { label = 'Received', value = c.time },
            },
            menu = MENU .. '_' .. id,
        }

        local options = {
            { title = 'Call details', description = c.message, icon = 'info', readOnly = true },
            { title = street, description = 'Received ' .. c.time, icon = 'pin', readOnly = true },
            { title = statusText(c), icon = 'users', readOnly = true },
        }
        local act = function(a) return Police.async(function() CallsMenu.action(a, id) end) end
        if mine then
            options[#options + 1] = { title = 'Set Waypoint', icon = 'map', onSelect = act('waypoint') }
            options[#options + 1] = { title = 'Cancel Response', description = 'Stop responding; the call stays open', icon = 'ban', iconColor = '#f5a524', onSelect = act('cancel') }
            options[#options + 1] = { title = 'Close Call', description = 'Ends the call for every unit', icon = 'check', iconColor = '#8892a6', onSelect = act('close') }
        else
            options[#options + 1] = { title = 'Accept', description = 'Respond to this call', icon = 'check', iconColor = '#22c38a', onSelect = act('accept') }
            options[#options + 1] = { title = 'Deny', description = 'Dismiss for you only', icon = 'x', iconColor = '#ef4b5a', onSelect = act('deny'), disabled = denied[id] == true }
            options[#options + 1] = { title = 'Set Waypoint', description = 'Accepts the call and sets GPS', icon = 'map', iconColor = '#3ba7ff', onSelect = act('waypoint') }
            if State.supervisor then
                options[#options + 1] = { title = 'Close Call', description = 'Supervisor', icon = 'check', iconColor = '#8892a6', onSelect = act('close') }
            end
        end
        menus[#menus + 1] = { id = MENU .. '_' .. id, menu = MENU, title = ('Call #%d'):format(id), description = c.callerName, icon = 'bell', options = options }
    end
    if #root == 0 then root[1] = { title = 'No open calls', icon = 'check', readOnly = true } end
    local n = #sortedIds()
    table.insert(menus, 1, { id = MENU, title = 'Active 911 Calls', description = ('%d open'):format(n), icon = 'bell', options = root })
    UnitLinkUI.registerContext(menus)
end

local function refreshIfOpen()
    local open = UnitLinkUI.openContext()
    if not open or open:sub(1, #MENU) ~= MENU then return end
    build()
    if open ~= MENU and not calls[tonumber(open:sub(#MENU + 2)) or -1] then open = MENU end
    UnitLinkUI.showContext(open)
end

function CallsMenu.open()
    if not needs911() then return end
    if not UnitLinkUI.available() then return UnitLinkUI.notify('The calls menu needs UnitLink-UI, which is not running.', 'error', '911') end
    local p = promise.new()
    snapshotWaiter = p
    TriggerServerEvent('unitlink-police:server:requestCalls')
    SetTimeout(2000, function() if snapshotWaiter == p then snapshotWaiter = nil; p:resolve(false) end end)
    Citizen.Await(p) -- fresh list, or the local cache if the server is slow / rate limited
    build()
    UnitLinkUI.showContext(MENU)
end

---------------------------------------------------------------------
-- Server -> client
---------------------------------------------------------------------
RegisterNetEvent('unitlink-police:client:callNew', function(call)
    if type(call) ~= 'table' or not call.id then return end
    calls[call.id] = call
    showCard(call, true)
    refreshIfOpen()
end)

RegisterNetEvent('unitlink-police:client:callUpdate', function(call, actor)
    if type(call) ~= 'table' or not call.id then return end
    calls[call.id] = call
    showCard(call, false)
    if actor and actor.action == 'accepted' and actor.src ~= Police.myId and Config.Emergency.announceAccepts and not denied[call.id] then
        UnitLinkUI.notify(('**%s** is responding to #%d.'):format(actor.callsign, call.id), 'info', 'Dispatch', 4000)
    end
    refreshIfOpen()
end)

RegisterNetEvent('unitlink-police:client:callRemoved', function(id, reason, byCallsign)
    id = tonumber(id)
    if not id then return end
    local call = calls[id]
    if call and isUnit(call) then
        if reason == 'expired' then
            UnitLinkUI.notify(('Call **#%d** expired.'):format(id), 'info', 'Dispatch', 4000)
        elseif reason == 'closed' then
            UnitLinkUI.notify(('Call **#%d** was closed%s.'):format(id, byCallsign and (' by ' .. byCallsign) or ''), 'info', 'Dispatch', 4000)
        end
    end
    forget(id)
    refreshIfOpen()
end)

RegisterNetEvent('unitlink-police:client:callsSnapshot', function(list)
    if type(list) ~= 'table' then return end
    local fresh = {}
    for _, c in ipairs(list) do
        fresh[c.id] = c
        if c.denied then denied[c.id] = true end
    end
    for id in pairs(calls) do
        if not fresh[id] then forget(id) end
    end
    calls = fresh
    if snapshotWaiter then
        local p = snapshotWaiter
        snapshotWaiter = nil
        p:resolve(true)
    else
        refreshIfOpen()
    end
end)

RegisterNetEvent('unitlink-police:client:callDenied', function(id)
    id = tonumber(id)
    if not id then return end
    denied[id] = true
    UnitLinkUI.remove(cardId(id))
    refreshIfOpen()
end)

RegisterNetEvent('unitlink-police:client:setWaypoint', function(coords, label)
    if type(coords) ~= 'table' or not coords.x then return end
    SetNewWaypoint(coords.x + 0.0, coords.y + 0.0)
    UnitLinkUI.notify(('Waypoint set to **%s**.'):format(label or 'call'), 'success', 'GPS', 2500)
end)

AddEventHandler('unitlink-police:dutyChanged', function(onDuty)
    if onDuty then return end
    for id in pairs(calls) do forget(id) end
    calls, denied, shownUntil = {}, {}, {}
    local open = UnitLinkUI.openContext()
    if open and open:sub(1, #MENU) == MENU then UnitLinkUI.hideContext(false) end
end)
