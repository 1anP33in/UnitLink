-- TSRP Core: server callback router.
--
-- Clients send exactly one network event, 'tsrp-core:server:cb' (name, requestId, payload).
-- The router checks the framework is ready, rate-limits globally and per callback,
-- forces the payload to be a table, runs the handler in protected mode and answers
-- with 'tsrp-core:client:cb' (requestId, ok, dataOrError).
--
-- Handlers: function(src, payload) -> true, data | false, errorCode
-- The source is always the real network source; payloads never carry identity.

TSRP = TSRP or {}
local Callbacks = {}
TSRP.Callbacks = Callbacks

local handlers = {}

-- opts.rate      : name of a Config.Security.RateLimits entry (optional)
-- opts.exclusive : true to serialise this callback with other exclusive callbacks
--                  for the same player (session-changing operations)
function Callbacks.Register(name, handler, opts)
    assert(type(name) == 'string' and type(handler) == 'function', 'invalid callback registration')
    if handlers[name] then
        TSRP.Log.Warn('Callback %s registered twice; replacing.', name)
    end
    handlers[name] = {
        fn = handler,
        rate = opts and opts.rate or nil,
        exclusive = opts and opts.exclusive or false,
    }
end

local function reply(src, requestId, ok, data)
    TriggerClientEvent(TSRP.NetEvents.CallbackResponse, src, requestId, ok and true or false, data)
end

RegisterNetEvent(TSRP.NetEvents.Callback, function(name, requestId, payload)
    local src = source
    if type(requestId) ~= 'number' then return end
    if type(name) ~= 'string' or #name > 64 then return end

    if not TSRP.Ready then
        return reply(src, requestId, false, TSRP.Errors.NotReady)
    end

    if not TSRP.RateLimit.CheckNamed(src, 'global') then
        return reply(src, requestId, false, TSRP.Errors.RateLimited)
    end

    local handler = handlers[name]
    if not handler then
        TSRP.Log.Debug('Unknown callback %s from %s', name, src)
        return reply(src, requestId, false, TSRP.Errors.InvalidInput)
    end

    if handler.rate and not TSRP.RateLimit.CheckNamed(src, handler.rate) then
        return reply(src, requestId, false, TSRP.Errors.RateLimited)
    end

    local player = TSRP.Players.Get(src)
    if not player then
        return reply(src, requestId, false, TSRP.Errors.InvalidState)
    end

    if type(payload) ~= 'table' then payload = {} end

    -- Exclusive callbacks (anything that changes the player's session) never run in
    -- parallel for the same player, so two quick clicks cannot load two characters.
    if handler.exclusive then
        if player.busy then
            return reply(src, requestId, false, TSRP.Errors.InvalidState)
        end
        player.busy = true
    end

    local ok, success, data = pcall(handler.fn, src, payload)

    if handler.exclusive then
        local current = TSRP.Players.Get(src)
        if current then current.busy = false end
    end

    if not ok then
        TSRP.Log.Error('Callback %s failed for %s: %s', name, src, tostring(success))
        return reply(src, requestId, false, TSRP.Errors.Internal)
    end
    reply(src, requestId, success, data)
end)
