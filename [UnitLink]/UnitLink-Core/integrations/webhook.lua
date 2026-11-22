-- UnitLink Core: optional Discord-compatible webhook sink for audit entries (server only).
-- The core never depends on Discord: this file only registers a log sink, and only
-- when Config.Logging.Webhook.Enabled is true.

UnitLink = UnitLink or {}
UnitLink.Integrations = UnitLink.Integrations or {}

local Webhook = {}
UnitLink.Integrations.Webhook = Webhook

local queue, sending = {}, false

local function shouldSend(action)
    local cfg = Config.Logging and Config.Logging.Webhook
    if not cfg or not cfg.Enabled or type(cfg.Url) ~= 'string' or cfg.Url == '' then return false end
    if type(cfg.Actions) == 'table' then
        return UnitLink.Utils.Contains(cfg.Actions, action)
    end
    return true
end

local function describe(entry, redact)
    local actor = entry.actorIdentifier or 'system'
    if redact and actor:find(':') then actor = UnitLink.Utils.Redact(actor) end
    local lines = {
        ('**Action:** `%s`'):format(entry.action),
        ('**Actor:** %s%s'):format(actor, entry.actorCharacterId and (' (character ' .. entry.actorCharacterId .. ')') or ''),
    }
    if entry.targetCharacterId then
        lines[#lines + 1] = ('**Target character:** %s'):format(entry.targetCharacterId)
    end
    if entry.details then
        local encoded = UnitLink.Utils.JsonEncode(entry.details) or '{}'
        if redact then encoded = encoded:gsub('license2?:%x+', function(m) return UnitLink.Utils.Redact(m) end) end
        if #encoded > 1500 then encoded = encoded:sub(1, 1500) .. '...' end
        lines[#lines + 1] = '```json\n' .. encoded .. '\n```'
    end
    return table.concat(lines, '\n')
end

local function pump()
    if sending or #queue == 0 then return end
    sending = true
    local cfg = Config.Logging.Webhook
    local entry = table.remove(queue, 1)
    local body = json.encode({
        username = cfg.Username or 'UnitLink Core',
        embeds = { {
            title = Config.ServerName .. ' audit',
            description = describe(entry, cfg.RedactIdentifiers ~= false),
            color = 3066993,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    })
    PerformHttpRequest(cfg.Url, function(status)
        sending = false
        if status == 429 then
            table.insert(queue, 1, entry) -- rate limited by Discord, retry shortly
            SetTimeout(2000, pump)
        else
            SetTimeout(250, pump)
        end
    end, 'POST', body, { ['Content-Type'] = 'application/json' })
end

function Webhook.Send(entry)
    if not shouldSend(entry.action) then return end
    if #queue > 200 then table.remove(queue, 1) end
    queue[#queue + 1] = entry
    pump()
end
