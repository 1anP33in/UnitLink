# Troubleshooting

| Problem | Check |
|---|---|
| `/cad` says you must be on duty | Go on duty with `/duty` first. |
| `/cad` says no access | Your department type needs `receives911` (`Config.AccessFlag`). SAFR can't open it by default. |
| "You don't have access to any department" | The **character** needs the department group (for example `sasp`) in `/tsrp`. Make sure you're on the right character. |
| Everyone was taken off duty | tsrp-core restarted. tsrp-police fails closed. |
| Name search finds nobody | Type at least 2 characters. Make sure tsrp-core is started. |
| Licenses always show VALID / NONE | The character has no `licenses` metadata yet, so the defaults are used. |
| No notifications | tsrp-ui isn't started, or it starts after the scripts that use it. Check the `ensure` order. |
| 911 location missing, no unit positions | **OneSync** is off. |
| Tables weren't created | Check oxmysql is connected (`mysql_connection_string`), or run `unitlink/sql/install.sql`. |
| tsrp-core logs don't reach Discord | Set `tsrp_core_log_webhook` in `server.cfg`, then restart tsrp-core. |
| A key doesn't work | Rebind it in Settings → Key Bindings → FiveM. |

Still stuck? Copy the errors from the F8 console and the server console and send them to the developers.
