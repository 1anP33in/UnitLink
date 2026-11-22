-- UnitLink Core: NUI bridge and focus management.

UnitLinkNui = {}
local N = UnitLinkNui

local ready = false
local queue = {}
N.focused = false
N.view = nil -- 'selection' | 'creation' | 'spawn' | 'admin' | nil

function N.Send(action, data)
    local msg = { action = action, data = data }
    if not ready then
        queue[#queue + 1] = msg
        return
    end
    SendNUIMessage(msg)
end

function N.Focus(state)
    N.focused = state
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(false)
end

-- Show a view and take focus.
function N.Open(view, data)
    N.view = view
    N.Send('open', { view = view, payload = data })
    N.Focus(true)
end

-- Hide whatever is showing and give controls back to the game.
function N.Close()
    N.view = nil
    N.Send('close', {})
    N.Focus(false)
end

RegisterNUICallback('ready', function(_, cb)
    ready = true
    for _, msg in ipairs(queue) do SendNUIMessage(msg) end
    queue = {}
    cb({ ok = true, branding = { name = Config.ServerName, short = Config.ServerShortName } })
end)

-- Generic close request from the UI (Escape key / close buttons). Only views that are
-- allowed to close themselves honour it; character selection cannot be dismissed.
RegisterNUICallback('close', function(_, cb)
    if N.view == 'admin' then
        N.Close()
    end
    cb({ ok = true })
end)

-- Wrap a server call for NUI callbacks: always answers { ok, data | error, field }.
function N.Reply(cb, ok, data)
    if ok then
        cb({ ok = true, data = data })
    else
        local message, field = UnitLink.ErrorMessage(data)
        cb({ ok = false, error = message, code = data, field = field })
    end
end

-- Block the most disruptive controls while a UnitLink UI or scene is active.
CreateThread(function()
    while true do
        if N.focused or UnitLinkClient.inSelection then
            DisableAllControlActions(0)
            HideHudAndRadarThisFrame()
            Wait(0)
        else
            Wait(250)
        end
    end
end)
