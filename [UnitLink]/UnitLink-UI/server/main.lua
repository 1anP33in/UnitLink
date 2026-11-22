---------------------------------------------------------------------
-- exports['UnitLink-UI']:Notify(target, 'Message', 'success', 5000)
-- exports['UnitLink-UI']:Notify(target, { type = 'info', title = '...', message = '...' })
-- target: player id, or -1 for everyone
---------------------------------------------------------------------
local function Notify(target, a, b, c)
    TriggerClientEvent('unitlink-ui:notify', target or -1, a, b, c)
end

---------------------------------------------------------------------
-- exports['UnitLink-UI']:Dispatch(target, data)
-- target: player id, -1 for everyone, or a list of player ids
---------------------------------------------------------------------
local function Dispatch(target, data)
    if type(data) ~= 'table' then return end
    if type(target) ~= 'table' then target = { target or -1 } end
    for _, t in ipairs(target) do
        TriggerClientEvent('unitlink-ui:dispatch', t, data)
    end
end

exports('Notify', Notify)
exports('Dispatch', Dispatch)
