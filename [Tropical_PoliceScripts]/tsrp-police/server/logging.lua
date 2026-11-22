---------------------------------------------------------------------
-- Logging: console + Discord webhook embeds.
-- Webhooks are queued and sent one at a time; failures are reported to
-- the console and never interrupt gameplay.
---------------------------------------------------------------------
Log = {}

local KINDS = {
    clock_in            = { title = 'Clock In',            color = 0x22c38a, category = 'duty' },
    clock_out           = { title = 'Clock Out',           color = 0x8892a6, category = 'duty' },
    department_change   = { title = 'Department Change',   color = 0x3ba7ff, category = 'duty' },
    session_restored    = { title = 'Session Restored',    color = 0x22c38a, category = 'duty' },
    session_interrupted = { title = 'Session Interrupted', color = 0xf5a524, category = 'duty' },
    permission_denied   = { title = 'Permission Denied',   color = 0xef4b5a, category = 'security' },
    callsign_conflict   = { title = 'Callsign Conflict',   color = 0xf5a524, category = 'security' },
    call_submitted      = { title = '911 Call',            color = 0xef4b5a, category = 'dispatch' },
    call_accepted       = { title = '911 Accepted',        color = 0x3ba7ff, category = 'dispatch' },
    call_cancelled      = { title = '911 Response Cancelled', color = 0xf5a524, category = 'dispatch' },
    call_closed         = { title = '911 Closed',          color = 0x8892a6, category = 'dispatch' },
    call_expired        = { title = '911 Expired',         color = 0x8892a6, category = 'dispatch' },
    panic               = { title = 'OFFICER PANIC',       color = 0xff2030, category = 'panic' },
}

-- Common fields for an officer session
function Log.officer(s, prefix)
    prefix = prefix or ''
    local fields = {
        { name = prefix .. 'Officer', value = ('%s (ID %d)'):format(s.name, s.source), inline = true },
        { name = prefix .. 'Callsign', value = s.callsign, inline = true },
        { name = prefix .. 'Department', value = (Config.Departments[s.department] or {}).short or s.department, inline = true },
    }
    if Config.Logging.includeIdentifiers and s.identifier then
        fields[#fields + 1] = { name = prefix .. 'Identifier', value = s.identifier, inline = false }
    end
    return fields
end

function Log.player(src)
    return { name = 'Player', value = ('%s (ID %d)'):format(Police.displayName(src), src), inline = true }
end

function Log.coords(c)
    if not c then return { name = 'Coords', value = 'unknown', inline = true } end
    return { name = 'Coords', value = ('%.1f, %.1f, %.1f'):format(c.x, c.y, c.z), inline = true }
end

---------------------------------------------------------------------
-- Webhook queue
---------------------------------------------------------------------
local queue = {}
local lastFailureLog = 0

local function urlFor(category)
    local url = Webhooks and (Webhooks[category] ~= '' and Webhooks[category] or Webhooks.default) or ''
    return (type(url) == 'string' and url:find('^https://')) and url or nil
end

CreateThread(function()
    while true do
        local item = table.remove(queue, 1)
        if item then
            local ok, err = pcall(function()
                PerformHttpRequest(item.url, function(status)
                    if (status < 200 or status >= 300) and os.time() - lastFailureLog > 30 then
                        lastFailureLog = os.time()
                        print(('^3[tsrp-police] webhook failed (HTTP %s). Logging continues in console.^7'):format(tostring(status)))
                    end
                end, 'POST', item.body, { ['Content-Type'] = 'application/json' })
            end)
            if not ok then print(('^3[tsrp-police] webhook error: %s^7'):format(tostring(err))) end
            Wait(1100) -- stay under Discord's per-webhook rate limit
        else
            Wait(1000)
        end
    end
end)

---------------------------------------------------------------------
-- Log.event('clock_in', fields, description?)
---------------------------------------------------------------------
function Log.event(kind, fields, description)
    if not (Config.Logging.events or {})[kind] then return end
    local meta = KINDS[kind] or { title = kind, color = 0x8892a6, category = 'default' }
    fields = fields or {}

    if Config.Logging.console then
        local parts = {}
        for _, f in ipairs(fields) do parts[#parts + 1] = f.name .. '=' .. tostring(f.value) end
        print(('[tsrp-police] %s%s%s'):format(meta.title, description and (' - ' .. description) or '', #parts > 0 and (' | ' .. table.concat(parts, ', ')) or ''))
    end

    local url = urlFor(meta.category)
    if not url then return end
    if #queue > 200 then table.remove(queue, 1) end -- never grow without limit

    local ok, body = pcall(json.encode, {
        username = Webhooks.username ~= '' and Webhooks.username or nil,
        avatar_url = Webhooks.avatar ~= '' and Webhooks.avatar or nil,
        embeds = { {
            title = meta.title,
            description = description,
            color = meta.color,
            fields = fields,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            footer = { text = 'tsrp-police' },
        } },
    })
    if ok then queue[#queue + 1] = { url = url, body = body } end
end
