-- TSRP Core: admin dashboard bridge (client).
-- The dashboard is opened by the server after it authorises /tsrp. Every dashboard
-- request goes to an 'admin:*' server callback which re-checks permissions.

local ACTIONS = {
    init = true, overview = true, players = true, searchCharacters = true, getCharacter = true,
    explain = true, groups = true, nodes = true, audit = true, updateCharacter = true,
    setMetadata = true, addGroup = true, removeGroup = true, setOverride = true,
    clearOverride = true, createGroup = true, updateGroup = true, deleteGroup = true,
}

RegisterNetEvent(TSRP.ClientEvents.OpenAdmin, function(opts)
    if TSRPClient.inSelection or TSRPNui.view ~= nil then return end
    opts = type(opts) == 'table' and opts or {}
    TSRPNui.Open('admin', { section = opts.section, arg = opts.arg })
end)

RegisterNUICallback('admin:request', function(body, cb)
    if TSRPNui.view ~= 'admin' then return cb({ ok = false, error = TSRP.T('invalid_state') }) end
    local action = type(body) == 'table' and body.action or nil
    if type(action) ~= 'string' or not ACTIONS[action] then
        return cb({ ok = false, error = TSRP.T('invalid_input') })
    end
    local ok, data = TSRP.Call('admin:' .. action, type(body.payload) == 'table' and body.payload or {})
    TSRPNui.Reply(cb, ok, data)
end)

RegisterNUICallback('admin:close', function(_, cb)
    if TSRPNui.view == 'admin' then TSRPNui.Close() end
    cb({ ok = true })
end)
