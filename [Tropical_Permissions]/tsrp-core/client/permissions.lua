-- TSRP Core: client-side permission mirror.
--
-- The server pushes the active character's effective groups and permission nodes so
-- client scripts can show or hide UI. This is a convenience copy ONLY: anything that
-- matters must be checked on the server with exports['tsrp-core']:HasPermission.

local function resolveLocal(node)
    if type(node) ~= 'string' then return false end
    -- Mirrors the server's candidate walk, but the client copy does not include denied
    -- nodes, so treat it as a hint.
    local set = TSRPClient.permissionSet
    if set[node] or set['*'] then return true end
    local parts = {}
    for segment in node:gmatch('[^%.]+') do parts[#parts + 1] = segment end
    for i = #parts - 1, 1, -1 do
        if set[table.concat(parts, '.', 1, i) .. '.*'] then return true end
    end
    return false
end

RegisterNetEvent(TSRP.ClientEvents.PermissionsUpdated, function(data)
    if type(data) ~= 'table' then return end
    TSRPClient.permissions = data.permissions or {}
    TSRPClient.groups = data.groups or {}
    TSRPClient.effectiveGroups = data.effectiveGroups or {}
    local set = {}
    for _, node in ipairs(TSRPClient.permissions) do set[node] = true end
    TSRPClient.permissionSet = set
end)

exports('HasPermission', function(node) return resolveLocal(node) end)
exports('GetGroups', function(includeInherited)
    return includeInherited and TSRPClient.effectiveGroups or TSRPClient.groups
end)
exports('HasGroup', function(group)
    for _, g in ipairs(TSRPClient.effectiveGroups) do
        if g == group then return true end
    end
    return false
end)
