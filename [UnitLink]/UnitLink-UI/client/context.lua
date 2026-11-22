---------------------------------------------------------------------
-- Context menu
--
-- RegisterContext({
--   id = 'garage', title = 'Garage', description = 'Lot B', icon = 'garage',
--   menu = 'parentId',            -- shows a back button that opens this menu
--   onExit = function() end, onBack = function() end,
--   options = {
--     { title = 'Vehicles', description = '3 stored', icon = 'car', menu = 'garage_vehicles' },
--     { title = 'Fuel', icon = 'fuel', progress = 65, progressColor = '#22c38a' },
--     { title = 'Info', icon = 'info', metadata = { { label = 'Plate', value = 'UnitLink 001' }, { label = 'Engine', value = '92%', progress = 92 } } },
--     { title = 'Give Keys', icon = 'key', keybind = 'K', onSelect = function(args) end, args = { ... } },
--     { title = 'Impound', icon = 'ban', disabled = true },
--     { title = 'Lot B · 12 spaces free', icon = 'pin', readOnly = true },
--     { title = 'Event', event = 'my:clientEvent', serverEvent = 'my:serverEvent', args = { ... }, close = false },
--   },
-- })
-- ShowContext('garage')   HideContext(runOnExit)   GetOpenContext()
--
-- metadata can also be { 'text', 'text' } or { Plate = 'UnitLink 001' }.
-- Option also takes: iconColor, image (url shown on hover), arrow.
---------------------------------------------------------------------
local menus = {}
local openId = nil

local function normalizeMeta(meta)
    if type(meta) ~= 'table' then return nil end
    local out = {}
    if meta[1] ~= nil then
        for _, m in ipairs(meta) do
            if type(m) == 'table' then
                out[#out + 1] = { label = m.label, value = m.value ~= nil and tostring(m.value) or nil, progress = m.progress }
            else
                out[#out + 1] = { label = tostring(m) }
            end
        end
    else
        local keys = {}
        for k in pairs(meta) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do out[#out + 1] = { label = tostring(k), value = tostring(meta[k]) } end
    end
    return out
end

function RegisterContext(menu)
    if type(menu) ~= 'table' then return end
    if menu.id then
        menus[menu.id] = menu
    else
        for _, m in ipairs(menu) do RegisterContext(m) end
    end
end

function ShowContext(id)
    local m = menus[id]
    if not m then return print(('[UnitLink-UI] context menu "%s" is not registered'):format(tostring(id))) end
    openId = id
    local options = {}
    for i, o in ipairs(m.options or {}) do
        options[i] = {
            title = o.title, description = o.description, icon = o.icon, iconColor = o.iconColor,
            disabled = o.disabled, readOnly = o.readOnly, keybind = o.keybind,
            progress = o.progress, progressColor = o.progressColor or o.colorScheme,
            metadata = normalizeMeta(o.metadata), image = o.image,
            arrow = o.menu ~= nil or o.arrow == true,
        }
    end
    UI.send('context:open', {
        title = m.title, description = m.description, icon = m.icon, color = m.color,
        canBack = m.menu ~= nil, options = options,
    })
    UI.focus('context', true)
end

function HideContext(runOnExit)
    local m = openId and menus[openId]
    if not m then return end
    openId = nil
    UI.unfocus('context')
    UI.send('context:close')
    -- wrapped: functions from other resources arrive as callable tables, not plain functions
    if runOnExit and m.onExit then CreateThread(function() m.onExit() end) end
end

function GetOpenContext() return openId end

UI.callback('context:select', function(d)
    local m = openId and menus[openId]
    if not m then return end
    local o = (m.options or {})[tonumber(d.index)]
    if not o or o.disabled or o.readOnly then return end
    if o.menu then return ShowContext(o.menu) end
    if o.close ~= false then HideContext(false) end
    CreateThread(function()
        if o.onSelect then o.onSelect(o.args) end
        if o.event then TriggerEvent(o.event, o.args) end
        if o.serverEvent then TriggerServerEvent(o.serverEvent, o.args) end
    end)
end)

UI.callback('context:back', function()
    local m = openId and menus[openId]
    if not m then return end
    if m.onBack then CreateThread(function() m.onBack() end) end
    if m.menu then ShowContext(m.menu) else HideContext(true) end
end)

UI.callback('context:close', function() HideContext(true) end)

exports('RegisterContext', RegisterContext)
exports('ShowContext', ShowContext)
exports('HideContext', HideContext)
exports('GetOpenContext', GetOpenContext)
