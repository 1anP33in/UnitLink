-- UnitLink Core: client bootstrap, server callback client, shared client state.

UnitLink = UnitLink or {}

UnitLinkClient = {
    character = nil,     -- public character data
    permissions = {},    -- effective nodes (UI hints only; the server decides)
    permissionSet = {},
    groups = {},
    effectiveGroups = {},
    loaded = false,
    spawned = false,
    inSelection = false,
    busy = false,
}

---------------------------------------------------------------------------
-- Server callbacks
---------------------------------------------------------------------------

local pending, nextId = {}, 0

-- Blocking request to the server. Returns ok, dataOrErrorCode.
function UnitLink.Call(name, payload, timeoutMs)
    nextId = nextId + 1
    local id = nextId
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent(UnitLink.NetEvents.Callback, name, id, payload or {})
    SetTimeout(timeoutMs or 20000, function()
        if pending[id] then
            pending[id] = nil
            p:resolve({ false, UnitLink.Errors.Timeout })
        end
    end)
    local result = Citizen.Await(p)
    return result[1], result[2]
end

RegisterNetEvent(UnitLink.NetEvents.CallbackResponse, function(id, ok, data)
    local p = pending[id]
    if not p then return end
    pending[id] = nil
    p:resolve({ ok, data })
end)

-- Error code -> readable text ('invalid_input:firstname' -> field message).
function UnitLink.ErrorMessage(code)
    if type(code) ~= 'string' then return UnitLink.T('internal_error') end
    local base, field = code:match('^([%w_]+):?(.*)$')
    if base == UnitLink.Errors.InvalidInput and field and field ~= '' and Config.Characters then
        local known = { firstname = true, lastname = true, dateofbirth = true, gender = true, nationality = true, height = true }
        if known[field] then return UnitLink.FieldMessage(field), field end
    end
    local text = UnitLink.T(base or code)
    if field and field ~= '' and base ~= UnitLink.Errors.InvalidInput then
        return text, nil
    end
    return text, (field ~= '' and field or nil)
end

-- Notification types UnitLink-UI understands
local UI_TYPES = { success = true, error = true, warning = true, info = true }

-- Uses UnitLink-UI when it is running (Config.UI.NotifyResource), otherwise the
-- built-in toast. A failing UnitLink-UI export also falls back, so a message is
-- never lost.
function UnitLink.Notify(message, kind)
    kind = kind or 'info'
    local res = Config.UI and Config.UI.NotifyResource
    if res and res ~= '' and GetResourceState(res) == 'started' then
        local ok = pcall(function()
            exports[res]:Notify({
                type = UI_TYPES[kind] and kind or 'info',
                title = Config.UI.NotifyTitle,
                message = message,
            })
        end)
        if ok then return end
    end
    UnitLinkNui.Send('toast', { message = message, kind = kind })
end

RegisterNetEvent(UnitLink.ClientEvents.Notify, function(message, kind)
    if type(message) == 'string' then UnitLink.Notify(message, kind) end
end)

---------------------------------------------------------------------------
-- Lifecycle events from the server
---------------------------------------------------------------------------

RegisterNetEvent(UnitLink.ClientEvents.CharacterLoaded, function(character)
    UnitLinkClient.character = character
    UnitLinkClient.loaded = true
end)

RegisterNetEvent(UnitLink.ClientEvents.CharacterUnloaded, function()
    UnitLinkClient.character = nil
    UnitLinkClient.loaded = false
    UnitLinkClient.spawned = false
    UnitLinkClient.permissions = {}
    UnitLinkClient.permissionSet = {}
    UnitLinkClient.groups = {}
    UnitLinkClient.effectiveGroups = {}
    LocalPlayer.state:set('unitlink-core:spawned', false, false)
end)

RegisterNetEvent(UnitLink.ClientEvents.EnterSelection, function(data)
    CreateThread(function() UnitLinkSelection.Enter(data) end)
end)

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

local function disableAutoSpawn()
    if GetResourceState('spawnmanager') == 'started' then
        pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    end
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(250) end
    disableAutoSpawn()
    Wait(250)
    UnitLinkSelection.Enter()
end)

-- Minimal death handling (Config.Death). Replace with an EMS resource later.
CreateThread(function()
    while true do
        Wait(1000)
        if Config.Death.Enabled and UnitLinkClient.spawned then
            local ped = PlayerPedId()
            if IsEntityDead(ped) then
                local delay = (Config.Death.RespawnDelaySeconds or 10) * 1000
                Wait(delay)
                ped = PlayerPedId()
                if UnitLinkClient.spawned and IsEntityDead(ped) then
                    local coords = GetEntityCoords(ped)
                    DoScreenFadeOut(500)
                    while not IsScreenFadedOut() do Wait(0) end
                    -- Same argument pattern as cfx spawnmanager.
                    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, true, false)
                    ped = PlayerPedId()
                    ClearPedBloodDamage(ped)
                    SetEntityHealth(ped, GetEntityMaxHealth(ped))
                    ClearPedTasksImmediately(ped)
                    DoScreenFadeIn(500)
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Client exports (convenience only: never trust these for security decisions;
-- server resources must use the server exports)
---------------------------------------------------------------------------

exports('GetCharacter', function() return UnitLinkClient.character end)
exports('GetCharacterId', function() return UnitLinkClient.character and UnitLinkClient.character.id or nil end)
exports('IsLoaded', function() return UnitLinkClient.loaded end)
exports('IsSpawned', function() return UnitLinkClient.spawned end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    UnitLinkScene.End()
    if not UnitLinkClient.spawned then
        DoScreenFadeIn(0)
    end
end)
