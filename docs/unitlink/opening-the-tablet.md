# Opening the Tablet

| Action | How |
|---|---|
| Open | `/cad` or **F5** |
| Close | **Esc** or **✕ Close** |
| Rebind the key | Settings → Key Bindings → FiveM → "Open UnitLink CAD" |

## Who can open it

1. You must be **on duty** in tsrp-police (`/duty`).
2. Your department type must have the access flag. By default that's `receives911`, which means LEO.
3. A **character must be loaded**.

If any of these isn't true, UnitLink tells you why and doesn't open. SAFR units can't open it by default.

## While it's open

* Your character holds a tablet (turn this off with `Config.TabletAnimation = false`).
* Going **off duty** closes the tablet.
* Restarting the `unitlink` resource while a tablet is open is meant to give control back and remove the prop. This is item 15 on the [Live Server Checklist](../testing/live-server-checklist.md).
