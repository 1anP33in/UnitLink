---------------------------------------------------------------------
-- Mini games. All block until finished and return true (passed) or false.
--
-- SkillCheck('medium')                          -- easy | medium | hard
-- SkillCheck({ 'easy', 'medium', 'hard' })      -- one round per entry
-- SkillCheck({ zone = 30, speed = 1.5 }, { 'E', 'Q' })   -- custom, with keys
--
-- SignalBreach('hard')
-- SignalBreach({ nodes = 6, window = 15, speed = 80 }, { speedUp = 1.2, shrink = 0.8, failOnWrongKey = false, keys = { 'W', 'S' }, onNode = function(index) end })
--
-- PatternLock('easy')
-- PatternLock({ grid = 4, length = 7, showSpeed = 300, timeout = 5000, rounds = 2 })
--
-- CancelMinigame()   IsMinigameActive()
---------------------------------------------------------------------
local active = nil

local function run(kind, params, mouse, onNode)
    if active then return false end
    local p = promise.new()
    active = { promise = p, onNode = onNode }
    UI.send('minigame:start', { kind = kind, params = params })
    UI.focus('minigame', mouse)
    local ok = Citizen.Await(p)
    UI.unfocus('minigame')
    active = nil
    return ok == true
end

UI.callback('minigame:done', function(d)
    if active then active.promise:resolve(d.success == true) end
end)

UI.callback('minigame:node', function(d)
    local fn = active and active.onNode
    if fn then CreateThread(function() fn(tonumber(d.index)) end) end
end)

function CancelMinigame()
    if not active then return end
    UI.send('minigame:cancel')
    active.promise:resolve(false)
end

function IsMinigameActive() return active ~= nil end

local function preset(presets, d, fallback)
    if type(d) == 'string' then return presets[d] or presets[fallback] end
    if type(d) == 'table' then return d end
    return presets[fallback]
end

function SkillCheck(difficulty, keys)
    local cfg = Config.SkillCheck
    local list = (type(difficulty) == 'table' and difficulty[1] ~= nil) and difficulty or { difficulty or 'medium' }
    local rounds = {}
    for _, d in ipairs(list) do
        local p = preset(cfg.presets, d, 'medium')
        rounds[#rounds + 1] = { zone = p.zone or 40, speed = (p.speed or 1.0) * cfg.baseSpeed }
    end
    if type(keys) == 'string' then keys = { keys } end
    return run('skill', { rounds = rounds, keys = keys or cfg.keys }, false)
end

function SignalBreach(difficulty, options)
    local cfg = Config.SignalBreach
    local p = preset(cfg.presets, difficulty, 'medium')
    options = options or {}
    return run('breach', {
        nodes = p.nodes or 4, window = p.window or 20, speed = p.speed or 70,
        speedUp = options.speedUp or cfg.speedUp, shrink = options.shrink or cfg.shrink,
        failOnWrongKey = (options.failOnWrongKey == nil) and cfg.failOnWrongKey or options.failOnWrongKey,
        maxSweeps = options.maxSweeps or cfg.maxSweeps,
        keys = options.keys or cfg.keys,
    }, false, options.onNode)
end

function PatternLock(difficulty)
    local p = preset(Config.PatternLock.presets, difficulty, 'medium')
    return run('pattern', {
        grid = p.grid or 3, length = p.length or 5, showSpeed = p.showSpeed or 420,
        timeout = p.timeout or 6000, rounds = p.rounds or 1,
    }, true)
end

exports('SkillCheck', SkillCheck)
exports('SignalBreach', SignalBreach)
exports('PatternLock', PatternLock)
exports('CancelMinigame', CancelMinigame)
exports('IsMinigameActive', IsMinigameActive)
