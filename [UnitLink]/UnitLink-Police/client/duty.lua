---------------------------------------------------------------------
-- Duty menu (UnitLink-UI context menu + input dialog)
-- Every action is a request; the server decides.
---------------------------------------------------------------------
DutyMenu = {}

local MENU = 'unitlink_police_duty'

local function askCallsign(dept, submitLabel)
    local last = GetResourceKvpString('unitlink_police:callsign:' .. dept.key)
    local values = UnitLinkUI.input(dept.short .. ' Callsign', {
        {
            type = 'input', label = 'Callsign', icon = 'tag', required = true,
            placeholder = dept.example or '', default = last,
            max = dept.maxLength, description = dept.example and ('Format: ' .. dept.example) or nil,
        },
    }, { icon = 'badge', description = dept.name, submitLabel = submitLabel or 'Go On Duty' })
    return values and values[1] or nil
end

local function goOnDuty(dept)
    local callsign = askCallsign(dept)
    if callsign then TriggerServerEvent('unitlink-police:server:clockIn', dept.key, callsign) end
end

local function changeDepartment(dept)
    local callsign = askCallsign(dept, 'Switch')
    if callsign then TriggerServerEvent('unitlink-police:server:changeDepartment', dept.key, callsign) end
end

local function goOffDuty()
    local ok = UnitLinkUI.confirm({
        header = 'Go off duty?', subheader = State.callsign .. ' · ' .. State.departmentShort,
        content = ('You have been on duty for **%s**.'):format(Utils.formatDuration(Police.elapsed())),
        type = 'warning', icon = 'badge', labels = { confirm = 'Go Off Duty', cancel = 'Stay On' },
    })
    if ok then TriggerServerEvent('unitlink-police:server:clockOut') end
end

local function totalsOption(st)
    local t = st.totals
    if not t then return nil end
    return {
        title = ('Total: %s · %d session%s'):format(Utils.formatDuration(t.seconds), t.sessions, t.sessions == 1 and '' or 's'),
        description = t.persistent and 'Saved duty time' or 'Since the last restart (not saved)',
        icon = 'clock', readOnly = true,
    }
end

function DutyMenu.open()
    if not UnitLinkUI.available() then
        return UnitLinkUI.notify(('UI unavailable. Use **/%s on <dept> <callsign>** or **/%s off**.'):format(Config.Commands.duty, Config.Commands.duty), 'error', 'Duty')
    end
    local st = Police.requestState()
    if not st then return UnitLinkUI.notify('Could not reach the server. Try again.', 'error', 'Duty') end
    local authorized = st.authorized or {}
    local options = {}

    if st.onDuty then
        local info = Police.StatusInfo[st.status] or {}
        options[#options + 1] = { title = st.callsign .. ' · ' .. st.departmentShort, description = st.departmentName, icon = 'badge', readOnly = true }
        options[#options + 1] = {
            title = 'On duty for ' .. Utils.formatDuration(Police.elapsed()),
            description = ('%d unit%s on duty'):format(st.onDutyCount, st.onDutyCount == 1 and '' or 's'),
            icon = 'clock', readOnly = true,
        }
        options[#options + 1] = {
            title = 'Status: ' .. (info.label or st.status), description = 'Change your response status',
            icon = info.icon or 'signal', iconColor = info.color, menu = MENU .. '_status',
        }
        if st.flags and st.flags.receives911 then
            options[#options + 1] = {
                title = 'Active 911 calls', description = st.activeCalls > 0 and ('Responding to %d'):format(st.activeCalls) or 'View and respond',
                icon = 'bell', onSelect = Police.async(function() CallsMenu.open() end),
            }
        end
        if st.canHideBlip and st.flags and st.flags.showOnBlips then
            options[#options + 1] = {
                title = st.blipVisible and 'Map blip: Visible' or 'Map blip: Hidden',
                description = st.blipVisible and 'Other units can see you on the map' or 'Other units cannot see you',
                icon = 'pin', iconColor = st.blipVisible and '#22c38a' or '#ef4b5a',
                onSelect = Police.async(function() TriggerServerEvent('unitlink-police:server:setBlipVisible', not st.blipVisible) end),
            }
        end
        if #authorized > 0 then
            options[#options + 1] = { title = 'Change department or callsign', icon = 'users', menu = MENU .. '_change' }
        end
        options[#options + 1] = { title = 'Go off duty', icon = 'x', iconColor = '#ef4b5a', onSelect = Police.async(goOffDuty) }
    else
        options[#options + 1] = {
            title = 'Off duty', description = ('%d unit%s on duty'):format(st.onDutyCount, st.onDutyCount == 1 and '' or 's'),
            icon = 'badge', readOnly = true,
        }
        if not st.enabled then
            options[#options + 1] = { title = 'Duty is disabled', description = Police.errorText('disabled'), icon = 'ban', disabled = true }
        elseif st.hasCharacter == false then
            options[#options + 1] = { title = 'No character loaded', description = Police.errorText('no_character'), icon = 'user', disabled = true }
        elseif #authorized == 0 then
            options[#options + 1] = { title = 'No departments', description = Police.errorText('no_departments'), icon = 'ban', disabled = true }
        else
            for _, d in ipairs(authorized) do
                options[#options + 1] = {
                    title = 'Go on duty · ' .. d.short, description = d.name, icon = 'badge',
                    onSelect = Police.async(function() goOnDuty(d) end),
                }
            end
        end
    end
    options[#options + 1] = totalsOption(st)

    -- status submenu
    local statusOptions = {}
    for _, key in ipairs({ 'available', 'busy', 'unavailable' }) do
        local info = Police.StatusInfo[key]
        local current = st.status == key
        statusOptions[#statusOptions + 1] = {
            title = info.label .. (current and ' (current)' or ''), icon = info.icon, iconColor = info.color,
            description = key == 'available' and 'Back to normal. Stays Responding while you are on a call.' or nil,
            disabled = current,
            onSelect = Police.async(function() TriggerServerEvent('unitlink-police:server:setStatus', key) end),
        }
    end

    -- department change submenu
    local changeOptions = {}
    for _, d in ipairs(authorized) do
        changeOptions[#changeOptions + 1] = {
            title = d.short .. (d.key == st.department and ' (current)' or ''), description = d.name, icon = 'badge',
            onSelect = Police.async(function() changeDepartment(d) end),
        }
    end

    UnitLinkUI.registerContext({
        { id = MENU, title = 'Duty', description = st.onDuty and (Police.StatusInfo[st.status] or {}).label or 'Off duty', icon = 'badge', options = options },
        { id = MENU .. '_status', menu = MENU, title = 'Status', description = st.callsign, icon = 'signal', options = statusOptions },
        { id = MENU .. '_change', menu = MENU, title = 'Change Department', description = 'Ends this session and starts a new one', icon = 'users', options = changeOptions },
    })
    UnitLinkUI.showContext(MENU)
end

---------------------------------------------------------------------
-- /duty  |  /duty on <dept> <callsign>  |  /duty off
-- (the argument form also works when UnitLink-UI is down)
---------------------------------------------------------------------
function DutyMenu.command(args)
    local sub = args[1] and args[1]:lower()
    if sub == 'on' and args[2] and args[3] then
        TriggerServerEvent('unitlink-police:server:clockIn', args[2]:lower(), args[3])
    elseif sub == 'off' then
        TriggerServerEvent('unitlink-police:server:clockOut')
    else
        CreateThread(DutyMenu.open)
    end
end

-- Close the duty menus if we go off duty while they are open
AddEventHandler('unitlink-police:dutyChanged', function()
    local open = UnitLinkUI.openContext()
    if open and open:sub(1, #MENU) == MENU then UnitLinkUI.hideContext(false) end
end)
