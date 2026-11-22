-- UnitLink HUD server. Standalone: no framework, no money.
--   * job line: the client reads UnitLink-Police duty state; the server only
--     supplies the active /civ profile name (UnitLink-CAD) for off-duty players.
--   * hunger / thirst (only if Config.Needs.Enabled): saved per account with
--     server KVP, no database or framework needed.

local players = {} -- [source] = { key, hunger, thirst }

local function clamp(v) return math.max(0, math.min(100, tonumber(v) or 0)) end

local function accountKey(src)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, 8) == 'license:' then return 'unitlink_hud:needs:' .. id:sub(9) end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Civilian name for the off-duty job line
-------------------------------------------------------------------------------
local function civilianName(src)
    if GetResourceState('UnitLink-CAD') ~= 'started' then return nil end
    local ok, name = pcall(function() return exports['UnitLink-CAD']:GetActiveName(src) end)
    return ok and type(name) == 'string' and name or nil
end

RegisterNetEvent('unitlink-hud:server:identity', function()
    local src = source
    TriggerClientEvent('unitlink-hud:client:civName', src, civilianName(src))
end)

-------------------------------------------------------------------------------
-- Hunger / thirst
-------------------------------------------------------------------------------
local function pushNeeds(src)
    local p = players[src]
    if p and Config.Needs.Enabled then
        TriggerClientEvent('unitlink-hud:client:needs', src, p.hunger, p.thirst)
    end
end

local function save(p)
    if not Config.Needs.Enabled or not p or not p.key then return end
    SetResourceKvp(p.key, json.encode({ h = math.floor(p.hunger * 10 + 0.5) / 10, t = math.floor(p.thirst * 10 + 0.5) / 10 }))
end

local function load(src)
    local key = accountKey(src)
    local p = { key = key, hunger = Config.Needs.StartValue, thirst = Config.Needs.StartValue }
    if key then
        local ok, saved = pcall(json.decode, GetResourceKvpString(key) or '')
        if ok and type(saved) == 'table' then
            if saved.h ~= nil then p.hunger = clamp(saved.h) end
            if saved.t ~= nil then p.thirst = clamp(saved.t) end
        end
    end
    players[src] = p
    pushNeeds(src)
end

RegisterNetEvent('unitlink-hud:server:ready', function()
    local src = source
    if Config.Needs.Enabled and not players[src] then load(src) else pushNeeds(src) end
end)

AddEventHandler('playerDropped', function()
    local p = players[source]
    if p then save(p) end
    players[source] = nil
end)

if Config.Needs.Enabled then
    CreateThread(function()
        local minutes = 0
        while true do
            Wait(60000)
            minutes = minutes + 1
            for src, p in pairs(players) do
                p.hunger = clamp(p.hunger - Config.Needs.HungerPerMinute)
                p.thirst = clamp(p.thirst - Config.Needs.ThirstPerMinute)
                pushNeeds(src)
            end
            if minutes % Config.Needs.SaveEveryMinutes == 0 then
                for _, p in pairs(players) do save(p) end
            end
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, p in pairs(players) do save(p) end
end)

-------------------------------------------------------------------------------
-- Exports for food / drink scripts (only do something with Needs enabled)
-------------------------------------------------------------------------------
exports('AddHunger', function(src, amount)
    local p = players[src]; if not p then return false end
    p.hunger = clamp(p.hunger + (tonumber(amount) or 0)); pushNeeds(src); return true
end)

exports('AddThirst', function(src, amount)
    local p = players[src]; if not p then return false end
    p.thirst = clamp(p.thirst + (tonumber(amount) or 0)); pushNeeds(src); return true
end)

exports('SetNeeds', function(src, hunger, thirst)
    local p = players[src]; if not p then return false end
    if hunger ~= nil then p.hunger = clamp(hunger) end
    if thirst ~= nil then p.thirst = clamp(thirst) end
    pushNeeds(src); return true
end)

exports('GetNeeds', function(src)
    local p = players[src]; if not p then return nil end
    return { hunger = p.hunger, thirst = p.thirst }
end)
