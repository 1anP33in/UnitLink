-- UnitLink Core: character selection flow (client).
-- The client only ever sends character ids; the server checks ownership every time.

UnitLinkSelection = {}
local Sel = UnitLinkSelection

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
        local ok, data = UnitLink.Call('unitlink-core:enterSelection')
        if ok then return data end
        if data ~= UnitLink.Errors.NotReady and data ~= UnitLink.Errors.InvalidState and data ~= UnitLink.Errors.Timeout
            and data ~= UnitLink.Errors.RateLimited then
            return nil, data
        end
        Wait(2000)
    end
    return nil, UnitLink.Errors.Timeout
end

-- Enter character selection. data may be supplied by the server (switch / forced).
function Sel.Enter(data)
    if UnitLinkClient.busy then return end
    UnitLinkClient.busy = true
    UnitLinkClient.inSelection = true
    UnitLinkClient.spawned = false
    LocalPlayer.state:set('unitlink-core:spawned', false, false)

    UnitLinkScene.BeginSelection()

    if not data then
        local err
        data, err = fetchSelection()
        if not data then
            closeLoadingScreen()
            UnitLinkScene.FadeIn(500)
            UnitLinkNui.Open('selection', { error = UnitLink.ErrorMessage(err), characters = {}, maxSlots = 0 })
            UnitLinkClient.busy = false
            return
        end
    end

    closeLoadingScreen()
    UnitLinkNui.Open('selection', data)
    Wait(300)
    UnitLinkScene.FadeIn(800)
    UnitLinkClient.busy = false
end

-- Preview a character on the scene ped (hover / click on a card).
RegisterNUICallback('selection:preview', function(body, cb)
    local ok, data = UnitLink.Call('unitlink-core:previewCharacter', { id = body and body.id })
    if ok and UnitLinkClient.inSelection then
        UnitLinkScene.Preview(data.appearance, data.defaultModel)
    end
    UnitLinkNui.Reply(cb, ok, ok and { id = data.id } or data)
end)

RegisterNUICallback('selection:delete', function(body, cb)
    local ok, data = UnitLink.Call('unitlink-core:deleteCharacter', { id = body and body.id, confirm = body and body.confirm })
    UnitLinkNui.Reply(cb, ok, data)
end)

RegisterNUICallback('selection:refresh', function(_, cb)
    local ok, data = UnitLink.Call('unitlink-core:enterSelection')
    UnitLinkNui.Reply(cb, ok, data)
end)

-- Load a character, run the appearance creator if needed, then show spawns.
local function playCharacter(id)
    local ok, res = UnitLink.Call('unitlink-core:selectCharacter', { id = id })
    if not ok then return false, res end

    CreateThread(function()
        UnitLinkClient.character = res.character
        UnitLinkClient.loaded = true
        local spawns = res.spawns

        if res.needsAppearance then
            spawns = UnitLinkCreator.RunNewCharacter(res)
            if not spawns then
                -- Could not save an appearance; go back to selection.
                Sel.Back()
                return
            end
        else
            UnitLinkScene.FadeOut(300)
            UnitLinkAppearance.Apply(res.appearance, res.defaultModel)
        end

        UnitLinkSpawn.ShowSelector(spawns)
    end)
    return true
end
Sel.Play = playCharacter

-- Unload a character that has not spawned yet and return to the selection screen.
function Sel.Back()
    local ok, data = UnitLink.Call('unitlink-core:backToSelection')
    if not ok then
        UnitLink.Notify(UnitLink.ErrorMessage(data), 'error')
        return false
    end
    UnitLinkClient.busy = false
    Sel.Enter(data)
    return true
end

RegisterNUICallback('spawn:back', function(_, cb)
    cb({ ok = true })
    CreateThread(Sel.Back)
end)

RegisterNUICallback('selection:select', function(body, cb)
    local ok, err = playCharacter(body and body.id)
    if ok then cb({ ok = true }) else UnitLinkNui.Reply(cb, false, err) end
end)

-- Create, then go straight into that character.
RegisterNUICallback('selection:create', function(body, cb)
    if type(body) ~= 'table' then return UnitLinkNui.Reply(cb, false, UnitLink.Errors.InvalidInput) end
    local ok, data = UnitLink.Call('unitlink-core:createCharacter', {
        firstname = body.firstname, lastname = body.lastname, dateofbirth = body.dateofbirth,
        gender = body.gender, nationality = body.nationality, height = body.height, slot = body.slot,
    })
    if not ok then return UnitLinkNui.Reply(cb, false, data) end
    cb({ ok = true, data = data })
    local played, err = playCharacter(data.character.id)
    if not played then
        UnitLink.Notify(UnitLink.ErrorMessage(err), 'error')
    end
end)

-- /switchcharacter
if Config.Commands.SwitchCharacter then
    RegisterCommand(Config.Commands.SwitchCharacter, function()
        if not UnitLinkClient.spawned or UnitLinkClient.busy then return end
        UnitLinkClient.busy = true
        local ok, data = UnitLink.Call('unitlink-core:switchCharacter')
        UnitLinkClient.busy = false
        if not ok then
            UnitLink.Notify(UnitLink.ErrorMessage(data), 'error')
            return
        end
        UnitLink.Notify(UnitLink.T('switch_started'), 'info')
        if UnitLinkNui.view == 'admin' then UnitLinkNui.Close() end
        Sel.Enter(data)
    end, false)
end
