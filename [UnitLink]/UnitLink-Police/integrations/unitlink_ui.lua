---------------------------------------------------------------------
-- UnitLink-UI adapter
--
-- Every call from UnitLink-Police to the UI goes through this file, so the
-- rest of the resource never talks to UnitLink-UI directly.
--
-- Integration contract (checked against UnitLink-UI's source, v1.0.0):
--   Server exports : Notify(target, data), Dispatch(target, data)
--   Client exports : Notify(data), Dispatch(data), RemoveNotify(id),
--                    RegisterContext(menu), ShowContext(id), HideContext(runOnExit),
--                    GetOpenContext(), InputDialog(heading, rows, options),
--                    AlertDialog(data)
--   Notify data    : { type, title, message, duration, icon, id }
--                    types: success | error | warning | info | announce | sms
--                    same id = update the card already on screen
--   Dispatch data  : { id, dept ('police'|'safr'), code, title, message,
--                    priority (1-3), location, duration, flash, sound }
--   message text supports **bold** and \n.
--
-- Limitation: UnitLink-UI notifications are display-only (no mouse focus,
-- no buttons). Accept / Deny / Set Waypoint are therefore offered as
--   1) keybinds shown on the call card, and
--   2) real buttons in the /calls context menu (UnitLink-UI context menus are clickable).
-- No UnitLink-UI files are modified.
--
-- If UnitLink-UI is not running, notifications fall back to the native GTA
-- feed and menus explain the problem instead of failing silently.
---------------------------------------------------------------------
UnitLinkUI = {}

local RESOURCE = Config.UI.resource
local warned = false

function UnitLinkUI.available()
    local state = GetResourceState(RESOURCE)
    if state == 'started' then
        warned = false
        return true
    end
    if not warned then
        warned = true
        print(('^3[UnitLink-Police] UI resource "%s" is %s. Using fallback notifications.^7'):format(RESOURCE, state))
    end
    return false
end

-- Calls an UnitLink-UI export safely. Returns ok, result.
local function call(name, ...)
    if not UnitLinkUI.available() then return false end
    local args = table.pack(...)
    -- index inside pcall too: a missing export throws on lookup
    local ok, result = pcall(function()
        local ui = exports[RESOURCE]
        return ui[name](ui, table.unpack(args, 1, args.n))
    end)
    if not ok then
        print(('^1[UnitLink-Police] UnitLink-UI export %s failed: %s^7'):format(name, tostring(result)))
        return false
    end
    return true, result
end

local function plain(text)
    return (tostring(text or ''):gsub('%*%*', ''):gsub('\n', ' '))
end

if IsDuplicityVersion() then
    -------------------------------------------------------------- server
    function UnitLinkUI.notify(target, message, kind, title, duration)
        local ok = call('Notify', target, { type = kind or 'info', title = title, message = message, duration = duration })
        if not ok then
            TriggerClientEvent('unitlink-police:client:fallbackNotify', target, plain((title and (title .. ': ') or '') .. message))
        end
    end
else
    -------------------------------------------------------------- client
    local function feed(text)
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandThefeedPostTicker(false, true)
    end

    RegisterNetEvent('unitlink-police:client:fallbackNotify', function(text)
        if type(text) == 'string' then feed(text) end
    end)

    function UnitLinkUI.notify(message, kind, title, duration, id)
        local ok = call('Notify', { type = kind or 'info', title = title, message = message, duration = duration, id = id })
        if not ok then feed(plain((title and (title .. ': ') or '') .. message)) end
    end

    function UnitLinkUI.dispatch(data)
        local ok = call('Dispatch', data)
        if not ok then feed(plain(('%s %s - %s'):format(data.code or '', data.title or '', data.message or ''))) end
    end

    function UnitLinkUI.remove(id) call('RemoveNotify', id) end

    function UnitLinkUI.registerContext(menu) return (call('RegisterContext', menu)) end
    function UnitLinkUI.showContext(id) return (call('ShowContext', id)) end
    function UnitLinkUI.hideContext(runOnExit) call('HideContext', runOnExit) end

    function UnitLinkUI.openContext()
        local ok, id = call('GetOpenContext')
        return ok and id or nil
    end

    -- Blocking (call from a thread). Returns the values table or nil.
    function UnitLinkUI.input(heading, rows, options)
        local ok, values = call('InputDialog', heading, rows, options)
        return ok and values or nil
    end

    -- Blocking. Returns true only when the player confirmed.
    function UnitLinkUI.confirm(data)
        local ok, result = call('AlertDialog', data)
        return ok and result == 'confirm'
    end
end
