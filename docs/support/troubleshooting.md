# Troubleshooting

| Problem | Check |
|---|---|
| `/cad` says you must be on duty | Go on duty with `/duty` first. |
| `/cad` says no access | Your department type needs `receives911` (`Config.AccessFlag`). SAFR can't open it by default. |
| "You don't have access to any department" | The player's **license** needs a department group in `server.cfg`, for example `add_principal identifier.license:... group.sasp`. See [ACE Permissions](../getting-started/ace-permissions.md). |
| Name search finds nobody (standalone) | People only exist once players make a profile with `/civ`. |
| Everyone was taken off duty | UnitLink-Core restarted. UnitLink-Police fails closed. |
| Name search finds nobody | Type at least 2 characters. Make sure UnitLink-Core is started. |
| Licenses always show VALID / NONE | The character has no `licenses` metadata yet, so the defaults are used. |
| No notifications | UnitLink-UI isn't started, or it starts after the scripts that use it. Check the `ensure` order. |
| 911 location missing, no unit positions | **OneSync** is off. |
| Tables weren't created | Check oxmysql is connected (`mysql_connection_string`), or run `UnitLink-CAD/sql/install.sql`. |
| UnitLink-Core logs don't reach Discord | Set `unitlink_core_log_webhook` in `server.cfg`, then restart UnitLink-Core. |
| A key doesn't work | Rebind it in Settings → Key Bindings → FiveM. |

Still stuck? Copy the errors from the F8 console and the server console and send them to the developers.
