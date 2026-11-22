---------------------------------------------------------------------
-- Notify
--   Notify('Saved!', 'success', 5000)
--   Notify({ type = 'info', title = 'Garage', message = 'Vehicle **stored**.' })
-- Fields: type, title, message, duration, icon, color, id, sound
-- Passing an id that is already on screen updates that card in place.
---------------------------------------------------------------------
local seq = 0
local function nextId(prefix)
    seq = seq + 1
    return prefix .. seq
end

function Notify(a, b, c)
    local data = type(a) == 'table' and a or { message = a, type = b, duration = c }
    local types = Config.Notify.types
    local kind = types[data.type] and data.type or 'info'
    local t = types[kind]
    local duration = tonumber(data.duration) or t.duration or Config.Notify.defaultDuration
    local id = data.id and tostring(data.id) or nextId('n')

    if data.sound ~= false then UI.playSound(data.sound or t.sound) end

    UI.send('notify', {
        id = id,
        type = kind,
        title = data.title,
        message = data.message ~= nil and tostring(data.message) or '',
        duration = duration,
        icon = data.icon,
        color = data.color,
    })
    return id
end

---------------------------------------------------------------------
-- Dispatch (police / SAFR style)
--   Dispatch({ dept = 'police', code = '10-31', title = 'Robbery in Progress',
--              message = '...', priority = 1, location = 'Main St' })
-- Fields: dept, code, title, message, priority, location, duration,
--         flash (true/false overrides config), icon, id, sound
---------------------------------------------------------------------
function Dispatch(data)
    if type(data) ~= 'table' then return end
    local n = Config.Notify
    local dept = n.departments[data.dept] and data.dept or 'police'
    local prio = math.floor(tonumber(data.priority) or n.defaultPriority)
    if not n.priorities[prio] then prio = n.defaultPriority end
    local p = n.priorities[prio] or {}
    local duration = tonumber(data.duration) or p.duration or n.defaultDuration
    local id = data.id and tostring(data.id) or nextId('d')

    if data.sound ~= false then UI.playSound(data.sound or p.sound) end

    local flash
    if type(data.flash) == 'boolean' then flash = data.flash end

    UI.send('dispatch', {
        id = id,
        dept = dept,
        code = data.code,
        title = data.title,
        message = data.message ~= nil and tostring(data.message) or '',
        priority = prio,
        location = data.location,
        flash = flash,
        duration = duration,
        icon = data.icon,
    })
    return id
end

function RemoveNotify(id) UI.send('notify:remove', { id = tostring(id) }) end
function ClearNotify() UI.send('notify:clear') end

exports('Notify', Notify)
exports('Dispatch', Dispatch)
exports('RemoveNotify', RemoveNotify)
exports('ClearNotify', ClearNotify)

RegisterNetEvent('tsrp-ui:notify', Notify)
RegisterNetEvent('tsrp-ui:dispatch', Dispatch)
RegisterNetEvent('tsrp-ui:clearNotify', ClearNotify)
