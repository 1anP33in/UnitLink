# tsrp-ui

The shared UI kit: notifications, progress bars, dialogs, context, list and radial menus, text UI and mini games.

**Folder:** `[Tropical_Menus]/tsrp-ui`

## What UnitLink uses

**Notifications.** Some examples: warrant waiting for approval, new BOLO, Signal 100 set or cleared.

```lua
-- server
exports['tsrp-ui']:Notify(source, { type = 'info', title = 'UnitLink', message = '...', duration = 4000 })
-- client
exports['tsrp-ui']:Notify({ type = 'success', title = 'UnitLink', message = '...' })
```

If tsrp-ui isn't running, UnitLink still works; the notifications just don't show.

The full API is in the script's own `README.md`.
