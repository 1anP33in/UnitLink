# UnitLink-UI

The shared UI kit: notifications, progress bars, dialogs, context, list and radial menus, text UI and mini games.

**Folder:** `[UnitLink]/UnitLink-UI`

## What UnitLink uses

**Notifications.** Some examples: warrant waiting for approval, new BOLO, Signal 100 set or cleared.

```lua
-- server
exports['UnitLink-UI']:Notify(source, { type = 'info', title = 'UnitLink', message = '...', duration = 4000 })
-- client
exports['UnitLink-UI']:Notify({ type = 'success', title = 'UnitLink', message = '...' })
```

If UnitLink-UI isn't running, UnitLink still works; the notifications just don't show.

The full API is in the script's own `README.md`.
