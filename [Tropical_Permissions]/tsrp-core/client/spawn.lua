-- TSRP Core: spawn selection (client). The client picks an id; the server returns the
-- coordinates.

TSRPSpawn = {}
local Sp = TSRPSpawn

function Sp.ShowSelector(spawns)
    TSRPScene.FadeOut(300)
    TSRPScene.OverviewCamera()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    TSRPNui.Open('spawn', {
        spawns = spawns or {},
        character = TSRPClient.character,
    })
    TSRPScene.FadeIn(600)
end

local function finalize(coords)
    TSRPScene.FadeOut(400)
    TSRPNui.Close()
    TSRPScene.Teleport(coords.x, coords.y, coords.z, coords.w)
    TSRPScene.End()
    TSRPClient.inSelection = false
    TSRPClient.spawned = true
    LocalPlayer.state:set('tsrp:spawned', true, false)
    Wait(500)
    TSRPScene.FadeIn(800)
end

RegisterNUICallback('spawn:select', function(body, cb)
    local id = body and body.id
    if type(id) ~= 'string' then return TSRPNui.Reply(cb, false, TSRP.Errors.InvalidInput) end
    local ok, data = TSRP.Call('tsrp:spawn', { id = id })
    if not ok then return TSRPNui.Reply(cb, false, data) end
    cb({ ok = true })
    CreateThread(function() finalize(data.coords) end)
end)
