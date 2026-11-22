-- UnitLink Core: spawn selection (client). The client picks an id; the server returns the
-- coordinates.

UnitLinkSpawn = {}
local Sp = UnitLinkSpawn

function Sp.ShowSelector(spawns)
    UnitLinkScene.FadeOut(300)
    UnitLinkScene.OverviewCamera()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    UnitLinkNui.Open('spawn', {
        spawns = spawns or {},
        character = UnitLinkClient.character,
    })
    UnitLinkScene.FadeIn(600)
end

local function finalize(coords)
    UnitLinkScene.FadeOut(400)
    UnitLinkNui.Close()
    UnitLinkScene.Teleport(coords.x, coords.y, coords.z, coords.w)
    UnitLinkScene.End()
    UnitLinkClient.inSelection = false
    UnitLinkClient.spawned = true
    LocalPlayer.state:set('unitlink-core:spawned', true, false)
    Wait(500)
    UnitLinkScene.FadeIn(800)
end

RegisterNUICallback('spawn:select', function(body, cb)
    local id = body and body.id
    if type(id) ~= 'string' then return UnitLinkNui.Reply(cb, false, UnitLink.Errors.InvalidInput) end
    local ok, data = UnitLink.Call('unitlink-core:spawn', { id = id })
    if not ok then return UnitLinkNui.Reply(cb, false, data) end
    cb({ ok = true })
    CreateThread(function() finalize(data.coords) end)
end)
