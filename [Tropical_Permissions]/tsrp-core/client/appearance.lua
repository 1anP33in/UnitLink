-- TSRP Core: appearance creator flow for new characters and later edits (client).
-- Storage and the "which character" decision are entirely server-side.

TSRPCreator = {}
local C = TSRPCreator

local editing = false

local function saveAppearance(appearance)
    for attempt = 1, 5 do
        local ok, data = TSRP.Call('tsrp:saveAppearance', { appearance = appearance })
        if ok then return true, data end
        if data ~= TSRP.Errors.Database and data ~= TSRP.Errors.Timeout and data ~= TSRP.Errors.RateLimited then
            return false, data
        end
        TSRP.Notify(TSRP.ErrorMessage(data), 'error')
        Wait(2000 * attempt)
    end
    return false, TSRP.Errors.Database
end

-- New character: model by gender, open illenium (no exit), save, return spawn options.
function C.RunNewCharacter(res)
    TSRPNui.Close()
    TSRPScene.FadeOut(400)
    TSRPScene.DestroyCam()

    local spot = Config.Appearance.CreatorCoords
    TSRPAppearance.SetModel(res.defaultModel)
    TSRPScene.Teleport(spot.x, spot.y, spot.z, spot.w)
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)

    TSRPScene.FadeIn(500)
    -- illenium waits for the screen to be faded in before opening.
    local timeout = GetGameTimer() + 3000
    while not IsScreenFadedIn() and GetGameTimer() < timeout do Wait(0) end

    while true do
        local appearance, reason = TSRPAppearance.OpenEditorAwait(res.sections or Config.Appearance.NewCharacterSections, false)
        if not appearance then
            -- illenium missing, failed, or (unexpectedly) cancelled: keep the current ped.
            if reason == 'unavailable' or reason == 'error' then
                TSRP.Notify(TSRP.T('appearance_unavailable'), 'error')
            end
            appearance = TSRPAppearance.GetCurrent(res.defaultModel)
            appearance.model = res.defaultModel
        end

        local ok, data = saveAppearance(appearance)
        if ok then
            return data.spawns
        end
        TSRP.Notify(TSRP.ErrorMessage(data), 'error')
        if data ~= TSRP.Errors.InvalidInput then
            return nil
        end
        -- Invalid appearance (e.g. model changed): reset the model and try again.
        TSRPAppearance.SetModel(res.defaultModel)
        Wait(500)
    end
end

-- Later edits, opened by the server (/appearance or OpenAppearanceEditor export).
RegisterNetEvent(TSRP.ClientEvents.OpenAppearance, function(sections)
    if editing or not TSRPClient.spawned or TSRPNui.focused then
        TSRP.Call('tsrp:cancelAppearance')
        return
    end
    editing = true
    local appearance = TSRPAppearance.OpenEditorAwait(sections or Config.Appearance.EditSections, true)
    if appearance then
        local ok, data = saveAppearance(appearance)
        if ok then
            TSRP.Notify(TSRP.T('appearance_saved'), 'success')
        else
            TSRP.Notify(TSRP.ErrorMessage(data), 'error')
        end
    else
        TSRP.Call('tsrp:cancelAppearance')
    end
    editing = false
end)
