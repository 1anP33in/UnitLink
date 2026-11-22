---------------------------------------------------------------------
-- List menu (keyboard only, the player can keep moving)
--
-- RegisterList({
--   id = 'customs', title = "Benny's", subtitle = 'Bison', icon = 'spray',
--   position = 'top-left',       -- top-left | top-right | bottom-left | bottom-right
--   canClose = true,             -- Backspace / Esc closes
--   disableInput = false,        -- true also blocks movement while open
--   options = {
--     { label = 'Respray', icon = 'spray', description = '...', values = { 'Red', { label = 'Blue', description = '...' } }, defaultIndex = 1 },
--     { label = 'Neon', icon = 'light', checkbox = true, checked = false },
--     { label = 'Engine', icon = 'engine', progress = 50 },
--     { label = 'Turbo', icon = 'turbo', disabled = true },
--     { label = 'Apply', icon = 'check', args = { ... }, close = true },
--   },
--   onSelected   = function(selected, scrollIndex, args) end,  -- moved to a row
--   onSideScroll = function(selected, scrollIndex, args) end,  -- changed a value
--   onCheck      = function(selected, checked, args) end,      -- ticked a checkbox
--   onClose      = function(keyPressed) end,                   -- 'Backspace' | 'Escape' | nil
-- }, function(selected, scrollIndex, args, checked) end)       -- Enter on a row
--
-- ShowList(id, startIndex)   HideList(runOnClose)   SetListOptions(id, options, index)   GetOpenList()
---------------------------------------------------------------------
local lists = {}
local openId = nil

local KEY = { up = 172, down = 173, left = 174, right = 175, enter = 191, back = 194, esc = 200, pause = 199, phone = 27 }
local MOVE = { 30, 31, 21, 22, 36, 44 }

local function initState(l, index)
    l._scroll, l._checked = {}, {}
    for i, o in ipairs(l.options or {}) do
        l._scroll[i] = (o.values and #o.values > 0) and math.max(1, math.min(#o.values, o.defaultIndex or 1)) or 0
        l._checked[i] = o.checked == true
    end
    l._selected = math.max(1, math.min(#(l.options or {}), index or l._selected or 1))
end

local function serialize(l)
    local out = {}
    for i, o in ipairs(l.options or {}) do
        local values
        if o.values then
            values = {}
            for k, v in ipairs(o.values) do
                values[k] = type(v) == 'table' and { label = v.label, description = v.description } or tostring(v)
            end
        end
        out[i] = {
            label = o.label, description = o.description, icon = o.icon,
            values = values, checkbox = o.checkbox == true, progress = o.progress, disabled = o.disabled,
        }
    end
    return out
end

local function state(l)
    return { selected = l._selected, scroll = l._scroll, checked = l._checked }
end

local function sendState(l) UI.send('list:state', state(l)) end

function RegisterList(data, cb)
    if type(data) ~= 'table' or not data.id then return end
    data.cb = cb or data.cb
    lists[data.id] = data
    initState(data)
end

function HideList(runOnClose, key)
    local l = openId and lists[openId]
    if not l then return end
    openId = nil
    UI.send('list:close')
    if runOnClose and l.onClose then CreateThread(function() l.onClose(key) end) end
end

local function call(fn, ...)
    if not fn then return end
    local args = table.pack(...)
    CreateThread(function() fn(table.unpack(args, 1, args.n)) end)
end

function ShowList(id, startIndex)
    local l = lists[id]
    if not l then return print(('[tsrp-ui] list menu "%s" is not registered'):format(tostring(id))) end
    if openId then HideList(false) end
    if startIndex then l._selected = math.max(1, math.min(#(l.options or {}), startIndex)) end
    openId = id
    UI.send('list:open', {
        title = l.title, subtitle = l.subtitle, icon = l.icon, color = l.color,
        position = l.position or Config.List.position, canClose = l.canClose,
        options = serialize(l), state = state(l),
    })

    CreateThread(function()
        local heldSince, lastRepeat = {}, {}
        local function pressed(name)
            local c = KEY[name]
            if IsDisabledControlJustPressed(0, c) then
                heldSince[name], lastRepeat[name] = GetGameTimer(), GetGameTimer()
                return true
            end
            if IsDisabledControlPressed(0, c) and heldSince[name] then
                local now = GetGameTimer()
                if now - heldSince[name] > 350 and now - lastRepeat[name] > 90 then
                    lastRepeat[name] = now
                    return true
                end
            elseif heldSince[name] then
                heldSince[name] = nil
            end
            return false
        end

        while openId == id do
            for _, c in pairs(KEY) do DisableControlAction(0, c, true) end
            DisableControlAction(0, 177, true) -- phone cancel (backspace)
            if l.disableInput then
                for _, c in ipairs(MOVE) do DisableControlAction(0, c, true) end
            end

            local opts = l.options or {}
            local count = #opts
            local sel = l._selected
            local o = opts[sel]

            if count > 0 and (pressed('down') or pressed('up')) then
                local dir = IsDisabledControlPressed(0, KEY.down) and 1 or -1
                l._selected = ((sel - 1 + dir) % count) + 1
                sendState(l)
                local no = opts[l._selected]
                call(l.onSelected, l._selected, l._scroll[l._selected], no and no.args)
            elseif o and (pressed('left') or pressed('right')) then
                if o.values and #o.values > 0 and not o.disabled then
                    local dir = IsDisabledControlPressed(0, KEY.right) and 1 or -1
                    l._scroll[sel] = ((l._scroll[sel] - 1 + dir) % #o.values) + 1
                    sendState(l)
                    call(l.onSideScroll, sel, l._scroll[sel], o.args)
                end
            elseif o and IsDisabledControlJustPressed(0, KEY.enter) then
                if not o.disabled then
                    if o.checkbox then
                        l._checked[sel] = not l._checked[sel]
                        sendState(l)
                        call(l.onCheck, sel, l._checked[sel], o.args)
                    else
                        if o.close ~= false then HideList(false) end
                        call(l.cb, sel, l._scroll[sel], o.args, l._checked[sel])
                    end
                end
            elseif l.canClose ~= false and (IsDisabledControlJustPressed(0, KEY.back) or IsDisabledControlJustPressed(0, 177)) then
                HideList(true, 'Backspace')
            elseif l.canClose ~= false and (IsDisabledControlJustPressed(0, KEY.esc) or IsDisabledControlJustPressed(0, KEY.pause)) then
                HideList(true, 'Escape')
            end
            Wait(0)
        end
    end)
end

function SetListOptions(id, options, index)
    local l = lists[id]
    if not l then return end
    l.options = options or {}
    initState(l, index)
    if openId == id then
        UI.send('list:open', {
            title = l.title, subtitle = l.subtitle, icon = l.icon, color = l.color,
            position = l.position or Config.List.position, canClose = l.canClose,
            options = serialize(l), state = state(l),
        })
    end
end

function GetOpenList() return openId end

exports('RegisterList', RegisterList)
exports('ShowList', ShowList)
exports('HideList', HideList)
exports('SetListOptions', SetListOptions)
exports('GetOpenList', GetOpenList)
