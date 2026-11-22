Police = Police or {}

-- Officer response statuses
Police.Status = {
    AVAILABLE   = 'available',
    RESPONDING  = 'responding',
    ONSCENE     = 'onscene',
    BUSY        = 'busy',
    UNAVAILABLE = 'unavailable',
}

Police.StatusInfo = {
    available   = { label = 'Available',   color = '#22c38a', icon = 'check' },
    responding  = { label = 'Responding',  color = '#3ba7ff', icon = 'car' },
    onscene     = { label = 'On Scene',    color = '#c084fc', icon = 'pin' },
    busy        = { label = 'Busy',        color = '#f5a524', icon = 'clock' },
    unavailable = { label = 'Unavailable', color = '#ef4b5a', icon = 'ban' },
}

-- Statuses an officer can pick by hand (Responding is automatic)
Police.ManualStatuses = { available = true, busy = true, unavailable = true }

-- 911 call states
Police.CallStatus = {
    PENDING = 'pending', -- no units assigned
    ACTIVE  = 'active',  -- at least one unit responding
}

Police.CallStatusInfo = {
    pending = { label = 'Pending', color = '#f5a524' },
    active  = { label = 'Active',  color = '#3ba7ff' },
}

-- Compact vehicle codes used in blip updates
Police.Vehicle = { FOOT = 0, CAR = 1, BIKE = 2, HELI = 3, PLANE = 4, BOAT = 5 }

-- Player-facing error text
Police.Errors = {
    disabled           = 'The police system is currently disabled.',
    already_on_duty    = 'You are already on duty.',
    not_on_duty        = 'You are not on duty.',
    invalid_department = 'That department does not exist.',
    not_authorized     = 'You are not authorized for that department.',
    no_departments     = "You don't have access to any department.",
    no_character       = 'Select a character before going on duty.',
    callsign_missing   = 'Enter a callsign.',
    callsign_length    = 'Callsign must be %d-%d characters.',
    callsign_chars     = 'Callsign can only use letters, numbers and "-".',
    callsign_format    = 'Callsign must look like %s.',
    callsign_taken     = 'Callsign %s is already in use.',
    nothing_changed    = 'You are already on duty with that department and callsign.',
    no_access          = "You don't have access to that.",
    rate_limited       = 'Slow down a little.',
}

function Police.errorText(code, ...)
    local text = Police.Errors[code] or tostring(code)
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then return formatted end
    end
    return text
end
