-- UnitLink Core: illenium-appearance adapter (client).
--
-- Verified against illenium-appearance v5.7.0 (latest release at the time of writing).
-- Exports used (all client-side, defined in game/util.lua and game/customization.lua):
--   startPlayerCustomization(callback, config)  callback(appearance | nil when cancelled)
--   getPedAppearance(ped)                        -> { model, headBlend, faceFeatures,
--                                                    headOverlays, components, props,
--                                                    hair, tattoos, eyeColor }
--   setPlayerAppearance(appearance)              sets the player model, then the rest
--   setPlayerModel(model)
--
-- config keys read by its NUI (client/defaults.lua GetDefaultConfig):
--   ped, headBlend, faceFeatures, headOverlays, components, componentConfig, props,
--   propConfig, tattoos, enableExit, hasTracker, automaticFade
--
-- UnitLink Core owns the character lifecycle and storage: illenium only edits the ped.
-- We do NOT use illenium's own saving (its 'illenium-appearance:server:saveAppearance'
-- handler needs a qb-core/ESX/ox_core bridge, which UnitLink Core intentionally is not).
-- No illenium files are modified. See README "Illenium Appearance" for details.

UnitLinkAppearance = {}
local A = UnitLinkAppearance

local function resource()
    return Config.Appearance.Resource
end

function A.IsAvailable()
    return GetResourceState(resource()) == 'started'
end

local function modelHash(model)
    if type(model) == 'number' then return model end
    return GetHashKey(model)
end

-- Native fallback used when illenium is missing.
local function nativeSetModel(model)
    local hash = modelHash(model)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(hash) then return false end
    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)
    SetPedDefaultComponentVariation(PlayerPedId())
    return true
end

function A.SetModel(model)
    if A.IsAvailable() then
        local ok = pcall(function() exports[resource()]:setPlayerModel(model) end)
        if ok then return true end
    end
    return nativeSetModel(model)
end

-- Apply a stored appearance to the player ped.
function A.Apply(appearance, fallbackModel)
    if type(appearance) == 'table' and A.IsAvailable() then
        local ok, err = pcall(function() exports[resource()]:setPlayerAppearance(appearance) end)
        if ok then return true end
        print(('[UnitLink-Core] setPlayerAppearance failed: %s'):format(tostring(err)))
    end
    local model = (type(appearance) == 'table' and appearance.model) or fallbackModel
    if model then return nativeSetModel(model) end
    return false
end

-- Current ped appearance (or a minimal one when illenium is missing).
function A.GetCurrent(fallbackModel)
    if A.IsAvailable() then
        local ok, appearance = pcall(function() return exports[resource()]:getPedAppearance(PlayerPedId()) end)
        if ok and type(appearance) == 'table' then return appearance end
    end
    return { model = fallbackModel or Config.Appearance.Models.male }
end

local function buildConfig(sections, allowExit)
    local disabledC = Config.Appearance.DisabledComponents or {}
    local disabledP = Config.Appearance.DisabledProps or {}
    return {
        ped = sections.ped == true,
        headBlend = sections.headBlend == true,
        faceFeatures = sections.faceFeatures == true,
        headOverlays = sections.headOverlays == true,
        components = sections.components == true,
        componentConfig = {
            masks = not disabledC.masks, upperBody = not disabledC.upperBody,
            lowerBody = not disabledC.lowerBody, bags = not disabledC.bags,
            shoes = not disabledC.shoes, scarfAndChains = not disabledC.scarfAndChains,
            bodyArmor = not disabledC.bodyArmor, shirts = not disabledC.shirts,
            decals = not disabledC.decals, jackets = not disabledC.jackets,
        },
        props = sections.props == true,
        propConfig = {
            hats = not disabledP.hats, glasses = not disabledP.glasses, ear = not disabledP.ear,
            watches = not disabledP.watches, bracelets = not disabledP.bracelets,
        },
        tattoos = sections.tattoos == true,
        enableExit = allowExit == true,
        hasTracker = false,
        automaticFade = false,
    }
end

-- Opens the illenium editor and blocks until the player saves or cancels.
-- Returns appearance table, or nil (cancelled / unavailable).
function A.OpenEditorAwait(sections, allowExit)
    if not A.IsAvailable() then return nil, 'unavailable' end
    local p = promise.new()
    local ok, err = pcall(function()
        exports[resource()]:startPlayerCustomization(function(appearance)
            p:resolve(appearance or false)
        end, buildConfig(sections or {}, allowExit))
    end)
    if not ok then
        print(('[UnitLink-Core] startPlayerCustomization failed: %s'):format(tostring(err)))
        return nil, 'error'
    end
    local result = Citizen.Await(p)
    if result == false then return nil, 'cancelled' end
    return result
end
