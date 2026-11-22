---------------------------------------------------------------------
-- Discord webhooks (SERVER ONLY - this file is never sent to clients)
-- Leave a category '' to fall back to `default`. All '' = no webhooks.
---------------------------------------------------------------------
Webhooks = {
    default  = '',
    duty     = '', -- clock in / out, department changes, restored sessions
    dispatch = '', -- 911 submitted / accepted / cancelled / closed / expired
    panic    = '', -- panic alerts
    security = '', -- permission denied, callsign conflicts

    username = 'TSRP Police',
    avatar   = '', -- optional image URL
}
