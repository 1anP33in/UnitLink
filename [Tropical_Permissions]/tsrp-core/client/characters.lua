-- TSRP Core: character selection flow (client).
-- The client only ever sends character ids; the server checks ownership every time.

TSRPSelection = {}
local Sel = TSRPSelection

local loadingClosed = false

local function closeLoadingScreen()
    if loadingClosed then return end
    loadingClosed = true
    local cfg = Config.LoadingScreen
    if cfg.ShutdownEvent then TriggerEvent(cfg.ShutdownEvent) end
    SetTimeout(cfg.ForceShutdownAfterMs or 2500, function()
        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()
    end)
end

-- Ask the server for the selection data, retrying while it starts up.
local function fetchSelection()
    for _ = 1, 30 do
        local ok, data = TSRP.Call('tsrp:enterSelection')
        if ok then return data end
        if data ~= TSRP.Errors.NotReady and data ~= TSRP.Errors.InvalidState and data ~= TSRP.Errors.Timeout
            and data ~= TSRP.Errors.RateLimited then
            return nil, data
        end
        Wait(2000)
    end
    return nil, TSRP.Errors.Timeout
end

-- Enter character selection. data may be supplied by the server (switch / forced).
function Sel.Enter(data)
    if TSRPClient.busy then return end
    TSRPClient.busy = true
    TSRPClient.inSelection = true
    TSRPClient.spawned = false
    LocalPlayer.state:set('tsrp:spawned', false, false)

    TSRPScene.BeginSelection()

    if not data then
        local err
        data, err = fetchSelection()
        if not data then
            closeLoadingScreen()
            TSRPScene.FadeIn(500)
            TSRPNui.Open('selection', { error = TSRP.ErrorMessage(err), characters = {}, maxSlots = 0 })
            TSRPClient.busy = false
            return
        end
    end

    closeLoadingScreen()
    TSRPNui.Open('selection', data)
    Wait(300)
    TSRPScene.FadeIn(800)
    TSRPClient.busy = false
end

-- Preview a character on the scene ped (hover / click on a card).
RegisterNUICallback('selection:preview', function(body, cb)
    local ok, data = TSRP.Call('tsrp:previewCharacter', { id = body and body.id })
    if ok and TSRPClient.inSelection then
        TSRPScene.Preview(data.appearance, data.defaultModel)
    end
    TSRPNui.Reply(cb, ok, ok and { id = data.id } or data)
end)

RegisterNUICallback('selection:delete', function(body, cb)
    local ok, data = TSRP.Call('tsrp:deleteCharacter', { id = body and body.id, confirm = body and body.confirm })
    TSRPNui.Reply(cb, ok, data)
end)

RegisterNUICallback('selection:refresh', function(_, cb)
    local ok, data = TSRP.Call('tsrp:enterSelection')
    TSRPNui.Reply(cb, ok, data)
end)

-- Load a character, run the appearance creator if needed, then show spawns.
local function playCharacter(id)
    local ok, res = TSRP.Call('tsrp:selectCharacter', { id = id })
    if not ok then return false, res end

    CreateThread(function()
        TSRPClient.character = res.character
        TSRPClient.loaded = true
        local spawns = res.spawns

        if res.needsAppearance then
            spawns = TSRPCreator.RunNewCharacter(res)
            if not spawns then
                -- Could not save an appearance; go back to selection.
                Sel.Back()
                return
            end
        else
            TSRPScene.FadeOut(300)
            TSRPAppearance.Apply(res.appearance, res.defaultModel)
        end

        TSRPSpawn.ShowSelector(spawns)
    end)
    return true
end
Sel.Play = playCharacter

-- Unload a character that has not spawned yet and return to the selection screen.
function Sel.Back()
    local ok, data = TSRP.Call('tsrp:backToSelection')
    if not ok then
        TSRP.Notify(TSRP.ErrorMessage(data), 'error')
        return false
    end
    TSRPClient.busy = false
    Sel.Enter(data)
    return true
end

RegisterNUICallback('spawn:back', function(_, cb)
    cb({ ok = true })
    CreateThread(Sel.Back)
end)

RegisterNUICallback('selection:select', function(body, cb)
    local ok, err = playCharacter(body and body.id)
    if ok then cb({ ok = true }) else TSRPNui.Reply(cb, false, err) end
end)

-- Create, then go straight into that character.
RegisterNUICallback('selection:create', function(body, cb)
    if type(body) ~= 'table' then return TSRPNui.Reply(cb, false, TSRP.Errors.InvalidInput) end
    local ok, data = TSRP.Call('tsrp:createCharacter', {
        firstname = body.firstname, lastname = body.lastname, dateofbirth = body.dateofbirth,
        gender = body.gender, nationality = body.nationality, height = body.height, slot = body.slot,
    })
    if not ok then return TSRPNui.Reply(cb, false, data) end
    cb({ ok = true, data = data })
    local played, err = playCharacter(data.character.id)
    if not played then
        TSRP.Notify(TSRP.ErrorMessage(err), 'error')
    end
end)

-- /switchcharacter
if Config.Commands.SwitchCharacter then
    RegisterCommand(Config.Commands.SwitchCharacter, function()
        if not TSRPClient.spawned or TSRPClient.busy then return end
        TSRPClient.busy = true
        local ok, data = TSRP.Call('tsrp:switchCharacter')
        TSRPClient.busy = false
        if not ok then
            TSRP.Notify(TSRP.ErrorMessage(data), 'error')
            return
        end
        TSRP.Notify(TSRP.T('switch_started'), 'info')
        if TSRPNui.view == 'admin' then TSRPNui.Close() end
        Sel.Enter(data)
    end, false)
end
