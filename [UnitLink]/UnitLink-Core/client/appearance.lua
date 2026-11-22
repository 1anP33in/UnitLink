-- UnitLink Core: appearance creator flow for new characters and later edits (client).
-- Storage and the "which character" decision are entirely server-side.

UnitLinkCreator = {}
local C = UnitLinkCreator

local editing = false

local function saveAppearance(appearance)
    for attempt = 1, 5 do
        local ok, data = UnitLink.Call('unitlink-core:saveAppearance', { appearance = appearance })
        if ok then return true, data end
        if data ~= UnitLink.Errors.Database and data ~= UnitLink.Errors.Timeout and data ~= UnitLink.Errors.RateLimited then
            return false, data
        end
        UnitLink.Notify(UnitLink.ErrorMessage(data), 'error')
        Wait(2000 * attempt)
    end
    return false, UnitLink.Errors.Database
end

-- New character: model by gender, open illenium (no exit), save, return spawn options.
function C.RunNewCharacter(res)
    UnitLinkNui.Close()
    UnitLinkScene.FadeOut(400)
    UnitLinkScene.DestroyCam()

    local spot = Config.Appearance.CreatorCoords
    UnitLinkAppearance.SetModel(res.defaultModel)
    UnitLinkScene.Teleport(spot.x, spot.y, spot.z, spot.w)
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)

    UnitLinkScene.FadeIn(500)
    -- illenium waits for the screen to be faded in before opening.
    local timeout = GetGameTimer() + 3000
    while not IsScreenFadedIn() and GetGameTimer() < timeout do Wait(0) end

    while true do
        local appearance, reason = UnitLinkAppearance.OpenEditorAwait(res.sections or Config.Appearance.NewCharacterSections, false)
        if not appearance then
            -- illenium missing, failed, or (unexpectedly) cancelled: keep the current ped.
            if reason == 'unavailable' or reason == 'error' then
                UnitLink.Notify(UnitLink.T('appearance_unavailable'), 'error')
            end
            appearance = UnitLinkAppearance.GetCurrent(res.defaultModel)
            appearance.model = res.defaultModel
        end

        local ok, data = saveAppearance(appearance)
        if ok then
            return data.spawns
        end
        UnitLink.Notify(UnitLink.ErrorMessage(data), 'error')
        if data ~= UnitLink.Errors.InvalidInput then
            return nil
        end
        -- Invalid appearance (e.g. model changed): reset the model and try again.
        UnitLinkAppearance.SetModel(res.defaultModel)
        Wait(500)
    end
end

-- Later edits, opened by the server (/appearance or OpenAppearanceEditor export).
RegisterNetEvent(UnitLink.ClientEvents.OpenAppearance, function(sections)
    if editing or not UnitLinkClient.spawned or UnitLinkNui.focused then
        UnitLink.Call('unitlink-core:cancelAppearance')
        return
    end
    editing = true
    local appearance = UnitLinkAppearance.OpenEditorAwait(sections or Config.Appearance.EditSections, true)
    if appearance then
        local ok, data = saveAppearance(appearance)
        if ok then
            UnitLink.Notify(UnitLink.T('appearance_saved'), 'success')
        else
            UnitLink.Notify(UnitLink.ErrorMessage(data), 'error')
        end
    else
        UnitLink.Call('unitlink-core:cancelAppearance')
    end
    editing = false
end)
