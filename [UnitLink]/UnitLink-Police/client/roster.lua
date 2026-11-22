---------------------------------------------------------------------
-- /police roster (UnitLink-UI context menu, live while open)
---------------------------------------------------------------------
RosterMenu = {}

local MENU = 'unitlink_police_roster'
local watching = false

local function isOpen() return UnitLinkUI.openContext() == MENU end

local function stopWatching()
    if not watching then return end
    watching = false
    TriggerServerEvent('unitlink-police:server:closeRoster')
end

local function build(data)
    local options = {}
    for _, dept in ipairs(data.departments) do
        local n = #dept.officers
        options[#options + 1] = {
            title = ('%s — %d %s'):format(dept.short, n, n == 1 and 'OFFICER' or 'OFFICERS'),
            description = dept.name, icon = 'badge', readOnly = true,
        }
        for _, o in ipairs(dept.officers) do
            local info = Police.StatusInfo[o.status] or {}
            options[#options + 1] = {
                title = ('%s | %s'):format(o.callsign, o.name),
                description = ('%s · on duty %s'):format(info.label or o.status, Utils.formatDuration(o.elapsed)),
                icon = info.icon or 'user', iconColor = info.color, readOnly = true,
            }
        end
    end
    if #options == 0 then
        options[1] = { title = 'Nobody is on duty', icon = 'users', readOnly = true }
    end
    UnitLinkUI.registerContext({
        id = MENU,
        title = ('On-Duty Law Enforcement: %d'):format(data.total),
        description = 'Updates live',
        icon = 'users',
        options = options,
    })
end

-- While the roster is open, check twice a second whether it is still on
-- screen; once it closes (Esc, another menu) stop the live updates.
-- (UnitLink-UI's onExit can't be used from another resource, see README.)
local function watchUntilClosed()
    CreateThread(function()
        while watching do
            Wait(500)
            if watching and not isOpen() then stopWatching() end
        end
    end)
end

RegisterNetEvent('unitlink-police:client:roster', function(data)
    if type(data) ~= 'table' or type(data.departments) ~= 'table' or not watching then return end
    local first = not RosterMenu.shownOnce
    if not first and not isOpen() then return stopWatching() end
    build(data)
    UnitLinkUI.showContext(MENU)
    if first then
        RosterMenu.shownOnce = true
        watchUntilClosed()
    end
end)

function RosterMenu.open()
    if not UnitLinkUI.available() then
        return UnitLinkUI.notify('The roster needs UnitLink-UI, which is not running.', 'error', 'Roster')
    end
    RosterMenu.shownOnce = false
    watching = true
    TriggerServerEvent('unitlink-police:server:requestRoster', true)
end

AddEventHandler('unitlink-police:dutyChanged', function(onDuty)
    if not onDuty and isOpen() then
        UnitLinkUI.hideContext(false)
        stopWatching()
    end
end)
