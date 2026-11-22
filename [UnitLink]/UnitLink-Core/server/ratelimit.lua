-- UnitLink Core: per-player sliding-window rate limiter.

UnitLink = UnitLink or {}
local RateLimit = {}
UnitLink.RateLimit = RateLimit

local buckets = {} -- [src] = { [key] = { timestamps... } }

-- Returns true when the request is allowed.
function RateLimit.Check(src, key, max, windowMs)
    if not src or src == 0 then return true end
    local now = GetGameTimer()
    local perPlayer = buckets[src]
    if not perPlayer then
        perPlayer = {}
        buckets[src] = perPlayer
    end
    local list = perPlayer[key]
    if not list then
        list = {}
        perPlayer[key] = list
    end
    local cutoff = now - windowMs
    local kept = 0
    for i = 1, #list do
        if list[i] > cutoff then
            kept = kept + 1
            list[kept] = list[i]
        end
    end
    for i = #list, kept + 1, -1 do list[i] = nil end
    if kept >= max then return false end
    list[kept + 1] = now
    return true
end

-- Uses a named limit from Config.Security.RateLimits.
function RateLimit.CheckNamed(src, name)
    local limit = Config.Security.RateLimits[name]
    if not limit then return true end
    return RateLimit.Check(src, name, limit[1], limit[2])
end

function RateLimit.Clear(src)
    buckets[src] = nil
end
