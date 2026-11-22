-- Shared helpers for every UnitLink-UI component (client files share this global)
UI = {}

local nuiReady = false
local pending = {}

-- Send a message to the NUI (queued until the page has loaded)
function UI.send(action, data)
    local msg = { action = action, data = data }
    if nuiReady then
        SendNUIMessage(msg)
    else
        pending[#pending + 1] = msg
    end
end

-- Register a NUI callback; always answers right away so the page never waits
function UI.callback(name, fn)
    RegisterNUICallback(name, function(data, cb)
        cb('ok')
        fn(type(data) == 'table' and data or {})
    end)
end

function UI.playSound(sound)
    if not Config.Sounds or type(sound) ~= 'table' or not sound[1] then return end
    PlaySoundFrontend(-1, sound[1], sound[2], true)
end

---------------------------------------------------------------------
-- NUI focus stack: dialogs, menus and mini games can overlap, so the
-- most recent one decides keyboard / mouse focus.
---------------------------------------------------------------------
local focus = {}

local function applyFocus()
    local top = focus[#focus]
    if top then
        SetNuiFocus(true, top.mouse)
    else
        SetNuiFocus(false, false)
    end
end

function UI.focus(owner, mouse)
    for i = #focus, 1, -1 do
        if focus[i].owner == owner then table.remove(focus, i) end
    end
    focus[#focus + 1] = { owner = owner, mouse = mouse == true }
    applyFocus()
end

function UI.unfocus(owner)
    for i = #focus, 1, -1 do
        if focus[i].owner == owner then table.remove(focus, i) end
    end
    applyFocus()
end

function UI.hasFocus()
    return #focus > 0
end

---------------------------------------------------------------------
-- Page loaded: send config and anything queued
---------------------------------------------------------------------
local function uiConfig()
    local n = Config.Notify
    local types, departments, priorities = {}, {}, {}
    for k, v in pairs(n.types) do
        types[k] = { title = v.title, tag = v.tag, color = v.color, icon = v.icon }
    end
    for k, v in pairs(n.departments) do
        departments[k] = { label = v.label, icon = v.icon, tint = v.tint, strip = v.strip, colors = v.colors }
    end
    for i, v in ipairs(n.priorities) do
        priorities[i] = { label = v.label, short = v.short, color = v.color, pulse = v.pulse == true }
    end
    return {
        scale = Config.Scale,
        accent = Config.Accent,
        notify = {
            position = n.position, offset = n.offset, maxVisible = n.maxVisible,
            types = types, departments = departments, priorities = priorities,
            flash = n.flash, priorityIndicator = n.priorityIndicator,
        },
        progress = { position = Config.Progress.position, cancelKey = Config.Progress.cancelKey },
        dialog = { backdrop = Config.Dialog.backdrop },
        context = { position = Config.Context.position },
        list = { position = Config.List.position },
        radial = { key = Config.Radial.key },
        textui = { position = Config.TextUI.position },
    }
end

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    SendNUIMessage({ action = 'init', data = uiConfig() })
    for i = 1, #pending do SendNUIMessage(pending[i]) end
    pending = {}
    cb('ok')
end)

---------------------------------------------------------------------
-- Hide everything while the pause menu is open
---------------------------------------------------------------------
if Config.HideInPauseMenu then
    CreateThread(function()
        local hidden = false
        while true do
            local paused = IsPauseMenuActive()
            if paused ~= hidden then
                hidden = paused
                UI.send('visible', { visible = not paused })
            end
            Wait(250)
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)

-- Keep UnitLink-UI (notifications, menus, dialogs) drawn in front of other NUI pages
-- such as the HUD, so they can always be read. Higher z-index = further in front.
CreateThread(function()
    if SetNuiZindex then SetNuiZindex(Config.ZIndex or 100) end
end)
