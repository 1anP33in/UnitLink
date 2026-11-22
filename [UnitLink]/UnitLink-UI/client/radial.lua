---------------------------------------------------------------------
-- Radial menu (opened with Config.Radial.key, default Z)
--
-- AddRadialItem({ id = 'vehicle', label = 'Vehicle', icon = 'car', description = 'Doors, engine…', menu = 'vehicle_menu' })
-- AddRadialItem({
--   id = 'phone', label = 'Phone', icon = 'phone', badge = 3,
--   onSelect = function(item) end,      -- or event = 'client:event' / serverEvent = 'server:event', args = { ... }
--   keepOpen = false, readOnly = false, progress = 65,
-- })
-- RegisterRadial({ id = 'vehicle_menu', title = 'Vehicle', items = { ...same item fields... } })
-- RemoveRadialItem(id)   ClearRadialItems()   DisableRadial(true/false)   HideRadial()   IsRadialOpen()
--
-- More than 6 items on a page adds a "More" wedge automatically.
---------------------------------------------------------------------
local items = {}   -- main menu, in order
local subs = {}    -- submenus by id
local stack = {}   -- open submenu ids
local isOpen = false
local disabled = false

local function current()
    if #stack == 0 then return items, nil end
    local s = subs[stack[#stack]]
    return s and s.items or {}, s
end

local function render()
    local list, sub = current()
    local out = {}
    for i, it in ipairs(list) do
        out[i] = {
            label = it.label, description = it.description, icon = it.icon,
            badge = it.badge, progress = it.progress, readOnly = it.readOnly,
        }
    end
    UI.send('radial:open', { items = out, sub = sub ~= nil, title = sub and sub.title or nil })
end

function HideRadial()
    if not isOpen then return end
    isOpen = false
    stack = {}
    UI.unfocus('radial')
    UI.send('radial:close')
end

local function openRadial()
    if disabled or isOpen or #items == 0 then return end
    if UI.hasFocus() or IsPauseMenuActive() or IsPlayerDead(PlayerId()) then return end
    isOpen = true
    stack = {}
    render()
    UI.focus('radial', true)
end

local function indexOf(list, id)
    for i, it in ipairs(list) do
        if it.id == id then return i end
    end
end

function AddRadialItem(item)
    if type(item) ~= 'table' then return end
    if item.id == nil and item[1] then
        for _, it in ipairs(item) do AddRadialItem(it) end
        return
    end
    local i = item.id and indexOf(items, item.id)
    if i then items[i] = item else items[#items + 1] = item end
    if isOpen and #stack == 0 then render() end
end

function RemoveRadialItem(id)
    local i = indexOf(items, id)
    if i then table.remove(items, i) end
    if isOpen then
        if #items == 0 then HideRadial() elseif #stack == 0 then render() end
    end
end

function ClearRadialItems()
    items = {}
    HideRadial()
end

function RegisterRadial(menu)
    if type(menu) ~= 'table' or not menu.id then return end
    subs[menu.id] = menu
    if isOpen and stack[#stack] == menu.id then render() end
end

function DisableRadial(state)
    disabled = state ~= false
    if disabled then HideRadial() end
end

function IsRadialOpen() return isOpen end

UI.callback('radial:select', function(d)
    if not isOpen then return end
    local list = current()
    local it = list[tonumber(d.index)]
    if not it or it.readOnly then return end
    if it.menu then
        if subs[it.menu] then
            stack[#stack + 1] = it.menu
            render()
        end
        return
    end
    if not it.keepOpen then HideRadial() end
    CreateThread(function()
        if it.onSelect then it.onSelect(it) end
        if it.event then TriggerEvent(it.event, it.args) end
        if it.serverEvent then TriggerServerEvent(it.serverEvent, it.args) end
    end)
end)

UI.callback('radial:back', function()
    if not isOpen then return end
    if #stack > 0 then
        stack[#stack] = nil
        render()
    else
        HideRadial()
    end
end)

UI.callback('radial:close', HideRadial)

if Config.Radial.enabled then
    RegisterCommand(Config.Radial.command, function()
        if isOpen then HideRadial() else openRadial() end
    end, false)
    RegisterKeyMapping(Config.Radial.command, 'Open radial menu', 'keyboard', Config.Radial.key)
end

exports('AddRadialItem', AddRadialItem)
exports('RemoveRadialItem', RemoveRadialItem)
exports('ClearRadialItems', ClearRadialItems)
exports('RegisterRadial', RegisterRadial)
exports('DisableRadial', DisableRadial)
exports('HideRadial', HideRadial)
exports('IsRadialOpen', IsRadialOpen)
