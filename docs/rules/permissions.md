# Permissions & Access

Permissions follow the **character**, not the account. They're managed in the tsrp-core dashboard (`/tsrp`).

## Going on duty (tsrp-police)

| Department | Go on duty | Supervisor | Group to assign |
|---|---|---|---|
| SASP | `tsrp.sasp.duty` | `tsrp.sasp.supervisor` | `sasp` / `sasp_supervisor` / `sasp_command` |
| BCSO | `tsrp.bcso.duty` | `tsrp.bcso.supervisor` | `bcso` / … |
| LSP | `tsrp.lsp.duty` | `tsrp.lsp.supervisor` | `lsp` / … |
| DHS | `tsrp.dhs.duty` | `tsrp.dhs.supervisor` | `dhs` / … |
| SAFD | `tsrp.safd.duty` | `tsrp.safd.supervisor` | `safd` / … |
| FAA | `tsrp.faa.duty` | `tsrp.faa.supervisor` | `faa` / … |

`tsrp.police.supervisor` (every LEO supervisor and LEO High Command) works across all departments.

## Opening UnitLink

* On duty, **and**
* the department type has `Config.AccessFlag` (default `receives911`, which means LEO), **and**
* a character is loaded.

## Server-side checks

Every UnitLink request is checked again on the server: on duty, CAD access, character loaded, and a **rate limit** (`Config.RateLimitMs`, default 250 ms). Supervisor-only actions (approving warrants, Signal 100) are checked on the server too.

## Discord roles

tsrp-core can give groups based on Discord roles (`config/discord.lua`). The bot token is set in `server.cfg` as `tsrp_discord_token`.
