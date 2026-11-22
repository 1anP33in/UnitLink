-- TSRP Core: console logging and the administrative audit log.

TSRP = TSRP or {}
local Log = {}
TSRP.Log = Log

local PREFIX = '^5[tsrp-core]^7 '

function Log.Info(msg, ...)
    print(PREFIX .. (select('#', ...) > 0 and msg:format(...) or msg))
end

function Log.Warn(msg, ...)
    print(PREFIX .. '^3' .. (select('#', ...) > 0 and msg:format(...) or msg) .. '^7')
end

function Log.Error(msg, ...)
    print(PREFIX .. '^1' .. (select('#', ...) > 0 and msg:format(...) or msg) .. '^7')
end

function Log.Debug(msg, ...)
    if Config.Debug then
        print(PREFIX .. '^8' .. (select('#', ...) > 0 and msg:format(...) or msg) .. '^7')
    end
end

local sinks = {}

-- Register a function(entry) that receives every audit entry. Used by the webhook
-- integration; other resources should listen to 'tsrp-core:server:audit' instead.
function Log.AddSink(fn)
    if type(fn) == 'function' then sinks[#sinks + 1] = fn end
end

-- Describe who did something. actor may be:
--   number > 0 : a player server id
--   0 or nil   : the server console / system
--   string     : a free-form actor such as 'resource:my-resource'
function Log.ResolveActor(actor)
    if type(actor) == 'number' and actor > 0 then
        local player = TSRP.Players and TSRP.Players.Get(actor)
        if player then
            return player.identifier, player.characterId
        end
        return 'player:' .. actor, nil
    elseif type(actor) == 'string' then
        return actor, nil
    end
    return 'console', nil
end

-- Write an audit entry.
--   action            : TSRP.AuditActions value
--   actor             : see ResolveActor
--   targetCharacterId : number or nil
--   details           : JSON-safe table or nil
function Log.Audit(action, actor, targetCharacterId, details)
    local actorIdentifier, actorCharacterId = Log.ResolveActor(actor)
    local entry = {
        action = action,
        actorIdentifier = actorIdentifier,
        actorCharacterId = actorCharacterId,
        targetCharacterId = targetCharacterId,
        details = details,
        timestamp = os.time(),
    }

    TSRP.DB.insertAsync(
        'INSERT INTO tsrp_audit_log (actor_identifier, actor_character_id, target_character_id, action, details) VALUES (?, ?, ?, ?, ?)',
        { actorIdentifier, actorCharacterId, targetCharacterId, action, details and TSRP.Utils.JsonEncode(details) or nil }
    )

    if Config.Logging and Config.Logging.Console then
        Log.Info('^2audit^7 %s by %s%s%s', action,
            (actorIdentifier and actorIdentifier:find(':') and TSRP.Utils.Redact(actorIdentifier)) or tostring(actorIdentifier),
            actorCharacterId and (' (char ' .. actorCharacterId .. ')') or '',
            targetCharacterId and (' -> char ' .. targetCharacterId) or '')
    end

    for i = 1, #sinks do
        local ok, err = pcall(sinks[i], entry)
        if not ok then Log.Error('Log sink failed: %s', tostring(err)) end
    end

    TriggerEvent(TSRP.ServerEvents.Audit, entry)
end
