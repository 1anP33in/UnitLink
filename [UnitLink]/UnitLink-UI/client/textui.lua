---------------------------------------------------------------------
-- Text UI
--   ShowTextUI('Open Garage')
--   ShowTextUI({ key = 'E', title = 'Open Garage', description = 'Lot B', icon = 'garage', color = '#3ba7ff', position = 'right-center' })
--   ShowTextUI({ title = 'Gas Station', options = { { key = 'E', label = 'Refuel', icon = 'fuel' }, { key = 'H', label = 'Car Wash' } } })
--   HideTextUI()   IsTextUIOpen()
-- Safe to call every frame: unchanged calls are skipped.
-- position: right-center | left-center | top-center | bottom-center
---------------------------------------------------------------------
local current = nil

function ShowTextUI(data)
    if type(data) == 'string' then data = { title = data } end
    if type(data) ~= 'table' then return end
    local encoded = json.encode(data)
    if encoded == current then return end
    current = encoded
    UI.send('text:show', data)
end

function HideTextUI()
    if not current then return end
    current = nil
    UI.send('text:hide')
end

function IsTextUIOpen() return current ~= nil end

exports('ShowTextUI', ShowTextUI)
exports('HideTextUI', HideTextUI)
exports('IsTextUIOpen', IsTextUIOpen)
