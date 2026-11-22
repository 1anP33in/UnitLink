---------------------------------------------------------------------
-- AlertDialog(data) -> 'confirm' | 'cancel'   (blocks, call from a thread)
--
-- data = {
--   header = 'Delete outfit?', subheader = 'This can't be undone',
--   content = 'Text, supports **bold** and \n',
--   icon = 'trash', type = 'danger',   -- info | success | warning | danger | error
--   callout = { type = 'warning', label = 'Heads up', text = '...' },  -- or a list
--   labels = { confirm = 'Delete', cancel = 'Keep' },
--   cancel = true,                     -- false hides the cancel button
-- }
---------------------------------------------------------------------
local alertPromise = nil

function AlertDialog(data)
    if alertPromise then return 'cancel' end
    data = data or {}
    alertPromise = promise.new()
    local p = alertPromise
    UI.send('alert:open', {
        header = data.header, subheader = data.subheader, content = data.content,
        icon = data.icon, type = data.type, color = data.color,
        callout = data.callout, labels = data.labels, cancel = data.cancel,
    })
    UI.focus('alert', true)
    return Citizen.Await(p)
end

local function closeAlert(result)
    if not alertPromise then return end
    local p = alertPromise
    alertPromise = nil
    UI.unfocus('alert')
    UI.send('alert:close')
    p:resolve(result == 'confirm' and 'confirm' or 'cancel')
end

UI.callback('alert:close', function(d) closeAlert(d.result) end)

function CloseAlert() closeAlert('cancel') end

exports('AlertDialog', AlertDialog)
exports('CloseAlert', CloseAlert)

---------------------------------------------------------------------
-- InputDialog(heading, rows, options?) -> { value1, value2, ... } or nil if cancelled
-- (blocks, call from a thread)
--
-- rows = {
--   { type = 'input', label = 'Name', placeholder = '...', icon = 'user', required = true, min = 2, max = 20, password = false },
--   { type = 'textarea', label = 'Notes', max = 200 },
--   { type = 'number', label = 'Amount', min = 1, max = 10, step = 1, default = 1 },
--   { type = 'select', label = 'Job', options = { { value = 'mech', label = 'Mechanic' }, 'Farmer' } },
--   { type = 'multi-select', label = 'Tags', options = { ... }, default = { 'a' } },
--   { type = 'slider', label = 'Volume', min = 0, max = 100, step = 5, default = 50 },
--   { type = 'toggle', label = 'Public', description = '...' },
--   { type = 'checkbox', label = 'I agree', required = true },
--   { type = 'color', label = 'Color', default = '#3ba7ff', colors = { '#ff0000', ... } },
--   { type = 'date', label = 'Date' },          -- 'YYYY-MM-DD'
--   { type = 'date-range', label = 'Dates' },   -- { from, to }
-- }
-- Every row also takes: description, disabled, default.
-- options = { icon = 'edit', description = '...', submitLabel = 'Save', cancelLabel = 'Back', cancel = true, color = '#hex' }
---------------------------------------------------------------------
local inputPromise = nil

function InputDialog(heading, rows, options)
    if inputPromise then return nil end
    options = options or {}
    inputPromise = promise.new()
    local p = inputPromise
    UI.send('input:open', {
        heading = heading, rows = rows or {},
        icon = options.icon, description = options.description, color = options.color,
        submitLabel = options.submitLabel, cancelLabel = options.cancelLabel, cancel = options.cancel,
    })
    UI.focus('input', true)
    return Citizen.Await(p)
end

local function closeInput(values)
    if not inputPromise then return end
    local p = inputPromise
    inputPromise = nil
    UI.unfocus('input')
    UI.send('input:close')
    p:resolve(values)
end

UI.callback('input:submit', function(d)
    if d.cancelled then closeInput(nil) else closeInput(d.values or {}) end
end)

function CloseInput() closeInput(nil) end

exports('InputDialog', InputDialog)
exports('CloseInput', CloseInput)
