---------------------------------------------------------------------
-- Officer panic button. Own cooldown and rate limit, completely separate
-- from 911, so a panic is never dropped because of 911 limits.
---------------------------------------------------------------------
local lastPanicAt = {} -- [source] = os.time()
local panicId = 0

Police.net('panic', 'panic', function(src, street)
    local P = Config.Panic
    if not Config.Enabled or not P.enabled then
        return Police.notify(src, 'Panic is disabled.', 'error', 'Panic')
    end

    local s = Duty.get(src)
    if not s or not Utils.deptHas(s.department, 'canPanic') then
        Log.event('permission_denied', { Log.player(src) }, 'Tried to use panic while not an on-duty officer')
        return Police.notify(src, 'Only on-duty officers can use panic.', 'error', 'Panic')
    end

    local now = os.time()
    local wait = (lastPanicAt[src] or 0) + P.cooldown - now
    if wait > 0 then
        return Police.notify(src, ('Panic is on cooldown for **%ds**.'):format(wait), 'warning', 'Panic')
    end

    local coords = Police.coords(src)
    if not coords then
        return Police.notify(src, 'Your location could not be found. Try again.', 'error', 'Panic')
    end
    lastPanicAt[src] = now
    panicId = panicId + 1

    local payload = {
        id = panicId, src = src,
        callsign = s.callsign, name = s.name,
        department = Config.Departments[s.department].short,
        coords = coords,
        street = Utils.sanitize(street, 80) or 'Unknown location',
        time = os.date('%H:%M', now),
    }

    local sent = 0
    Duty.each('receivesPanic', function(unit)
        if unit ~= src then
            sent = sent + 1
            Police.toClient(unit, 'panic', payload)
        end
    end)
    Roster.setPanic(src, P.blipFlashTime or 60)

    local fields = Log.officer(s)
    fields[#fields + 1] = { name = 'Location', value = payload.street, inline = true }
    fields[#fields + 1] = Log.coords(coords)
    fields[#fields + 1] = { name = 'Units alerted', value = tostring(sent), inline = true }
    Log.event('panic', fields)

    Police.notify(src, ('Panic sent to **%d** unit%s.'):format(sent, sent == 1 and '' or 's'), sent > 0 and 'warning' or 'error', 'Panic')
end)

Police.on('playerDropped', function(src) lastPanicAt[src] = nil end)
