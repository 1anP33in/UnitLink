# Permissions & Access

Permissions follow the **character**, not the account. They're managed in the UnitLink-Core dashboard (`/ulcore`).

## Going on duty (UnitLink-Police)

| Department | Go on duty | Supervisor | Group to assign |
|---|---|---|---|
| SASP | `unitlink.sasp.duty` | `unitlink.sasp.supervisor` | `sasp` / `sasp_supervisor` / `sasp_command` |
| BCSO | `unitlink.bcso.duty` | `unitlink.bcso.supervisor` | `bcso` / … |
| LSP | `unitlink.lsp.duty` | `unitlink.lsp.supervisor` | `lsp` / … |
| DHS | `unitlink.dhs.duty` | `unitlink.dhs.supervisor` | `dhs` / … |
| SAFD | `unitlink.safd.duty` | `unitlink.safd.supervisor` | `safd` / … |
| FAA | `unitlink.faa.duty` | `unitlink.faa.supervisor` | `faa` / … |

`unitlink.police.supervisor` (every LEO supervisor and LEO High Command) works across all departments.

## Opening UnitLink

* On duty, **and**
* the department type has `Config.AccessFlag` (default `receives911`, which means LEO), **and**
* a character is loaded.

## Server-side checks

Every UnitLink request is checked again on the server: on duty, CAD access, character loaded, and a **rate limit** (`Config.RateLimitMs`, default 250 ms). Supervisor-only actions (approving warrants, Signal 100) are checked on the server too.

## Discord roles

UnitLink-Core can give groups based on Discord roles (`config/discord.lua`). The bot token is set in `server.cfg` as `unitlink_discord_token`.
