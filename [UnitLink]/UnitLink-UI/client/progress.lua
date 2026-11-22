---------------------------------------------------------------------
-- ProgressBar(data) -> true when finished, false when cancelled
-- Blocks until done, so call it from a thread.
--
-- data = {
--   duration = 5000, label = 'Repairing Engine', description = '...',
--   icon = 'wrench', color = '#3ba7ff',
--   steps = { 'Cutting', 'Shaping', 'Assembling' },  -- optional segmented bar
--   canCancel = true,
--   disable = { move = true, sprint = true, car = true, combat = true, mouse = false },
--   anim = { dict = 'mini@repair', clip = 'fixing_a_player', flag = 49 } or { scenario = 'WORLD_HUMAN_WELDING' },
--   prop = { model = 'prop_tool_wrench', bone = 57005, pos = vec3(...), rot = vec3(...) } or a list of these,
--   allowDead, allowRagdoll, allowCuffed, allowFalling, allowSwimming  -- all false by default
-- }
---------------------------------------------------------------------
local active = nil

local CONTROLS = {
    move   = { 30, 31, 36 },
    sprint = { 21 },
    car    = { 63, 64, 71, 72, 75 },
    combat = { 24, 25, 37, 47, 58, 140, 141, 142, 143, 257, 263, 264 },
    mouse  = { 1, 2, 106 },
}

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(0)
    end
    return true
end

local function loadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return false end
        Wait(0)
    end
    return true
end

local function spawnProps(ped, props)
    if not props then return {} end
    if props.model then props = { props } end
    local objects = {}
    for _, p in ipairs(props) do
        local model = type(p.model) == 'string' and joaat(p.model) or p.model
        if model and loadModel(model) then
            local c = GetEntityCoords(ped)
            local obj = CreateObject(model, c.x, c.y, c.z, true, true, false)
            local pos = p.pos or vec3(0.0, 0.0, 0.0)
            local rot = p.rot or vec3(0.0, 0.0, 0.0)
            AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, p.bone or 60309),
                pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, p.rotOrder or 0, true)
            SetModelAsNoLongerNeeded(model)
            objects[#objects + 1] = obj
        end
    end
    return objects
end

local function interrupted(ped, d)
    if not d.allowDead and IsPedDeadOrDying(ped, true) then return true end
    if not d.allowRagdoll and IsPedRagdoll(ped) then return true end
    if not d.allowCuffed and IsPedCuffed(ped) then return true end
    if not d.allowFalling and IsPedFalling(ped) then return true end
    if not d.allowSwimming and IsPedSwimming(ped) then return true end
    return false
end

function ProgressBar(d)
    if active then return false end
    d = d or {}
    local duration = tonumber(d.duration) or 3000
    local canCancel = d.canCancel ~= false
    local ped = PlayerPedId()
    active = { cancelled = false }

    -- animation
    local anim = d.anim
    if anim then
        if anim.scenario then
            TaskStartScenarioInPlace(ped, anim.scenario, 0, anim.playEnter ~= false)
        elseif anim.dict and anim.clip and loadDict(anim.dict) then
            TaskPlayAnim(ped, anim.dict, anim.clip, anim.blendIn or 3.0, anim.blendOut or 1.0, -1, anim.flag or 49, 0, false, false, false)
        end
    end
    local props = spawnProps(ped, d.prop)

    -- controls to block
    local blocked = {}
    for group, on in pairs(d.disable or {}) do
        if on and CONTROLS[group] then
            for _, c in ipairs(CONTROLS[group]) do blocked[#blocked + 1] = c end
        end
    end

    UI.send('progress:start', {
        label = d.label, description = d.description, icon = d.icon, color = d.color,
        duration = duration, steps = d.steps, canCancel = canCancel,
    })

    local start = GetGameTimer()
    local completed = true
    while GetGameTimer() - start < duration do
        for i = 1, #blocked do DisableControlAction(0, blocked[i], true) end
        if canCancel and (IsControlJustPressed(0, Config.Progress.cancelControl) or IsDisabledControlJustPressed(0, Config.Progress.cancelControl)) then
            active.cancelled = true
        end
        if active.cancelled or interrupted(ped, d) then
            completed = false
            break
        end
        Wait(0)
    end

    -- cleanup
    if anim then
        if anim.scenario then
            ClearPedTasks(ped)
        elseif anim.dict and anim.clip then
            StopAnimTask(ped, anim.dict, anim.clip, 1.0)
            RemoveAnimDict(anim.dict)
        end
    end
    for _, obj in ipairs(props) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end

    UI.send('progress:end', { cancelled = not completed })
    active = nil
    return completed
end

function CancelProgress()
    if active then active.cancelled = true end
end

function IsProgressActive()
    return active ~= nil
end

exports('ProgressBar', ProgressBar)
exports('CancelProgress', CancelProgress)
exports('IsProgressActive', IsProgressActive)
