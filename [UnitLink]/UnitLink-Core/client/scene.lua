-- UnitLink Core: character selection scene, cameras and safe teleporting.

UnitLinkScene = {}
local S = UnitLinkScene

local cam = nil

local function fadeOut(ms)
    if not IsScreenFadedOut() then
        DoScreenFadeOut(ms or 300)
        local timeout = GetGameTimer() + 3000
        while not IsScreenFadedOut() and GetGameTimer() < timeout do Wait(0) end
    end
end
S.FadeOut = fadeOut

local function fadeIn(ms)
    DoScreenFadeIn(ms or 500)
end
S.FadeIn = fadeIn

local function destroyCam()
    if cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
end
S.DestroyCam = destroyCam

-- Load collision around a point and place the ped there, on the ground.
function S.Teleport(x, y, z, heading)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, heading or 0.0)
    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
    end
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 2.0, false)
    if found and math.abs(groundZ - z) < 5.0 then
        SetEntityCoordsNoOffset(ped, x, y, groundZ, false, false, false)
    end
end

local function makeSafe(ped)
    if IsEntityDead(ped) then
        local c = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, true, false)
        ped = PlayerPedId()
    end
    ClearPedTasksImmediately(ped)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
    SetPlayerControl(PlayerId(), false, 0)
    return ped
end

local function pointCamera(fromCoords)
    local ped = PlayerPedId()
    destroyCam()
    local o = Config.Selection.CameraOffset
    local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, o.y, o.z)
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, Config.Selection.CameraFov, false, 0)
    local target = fromCoords or GetEntityCoords(ped)
    PointCamAtCoord(cam, target.x, target.y, target.z + 0.25)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
end

-- Put the player in the selection scene (screen stays faded out; caller fades in).
function S.BeginSelection()
    fadeOut(400)
    local c = Config.Selection.PedCoords
    local ped = PlayerPedId()
    if not IsPedModel(ped, GetHashKey(Config.Appearance.Models.male)) and not IsPedModel(ped, GetHashKey(Config.Appearance.Models.female)) then
        UnitLinkAppearance.SetModel(Config.Appearance.Models.male)
    end
    ped = makeSafe(PlayerPedId())
    FreezeEntityPosition(ped, false)
    S.Teleport(c.x, c.y, c.z, c.w)
    ped = makeSafe(PlayerPedId())
    SetEntityHeading(ped, c.w)
    DisplayRadar(false)
    pointCamera()
end

-- Re-aim the selection camera after a model change.
function S.RefreshCamera()
    if cam then pointCamera() end
end

-- Apply a character's look to the preview ped.
function S.Preview(appearance, defaultModel)
    if appearance then
        UnitLinkAppearance.Apply(appearance, defaultModel)
    elseif defaultModel then
        UnitLinkAppearance.SetModel(defaultModel)
    end
    local ped = makeSafe(PlayerPedId())
    SetEntityHeading(ped, Config.Selection.PedCoords.w)
    S.RefreshCamera()
end

-- High overhead camera used behind the spawn selector.
function S.OverviewCamera()
    destroyCam()
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', -180.0, -1150.0, 520.0, -35.0, 0.0, 20.0, 55.0, false, 0)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
end

-- Leave every scripted scene state and hand control back to the player.
function S.End()
    destroyCam()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true, false)
    SetPlayerControl(PlayerId(), true, 0)
    DisplayRadar(true)
end
