# UnitLink-Perms

Maps Discord roles to UnitLink ACE groups. Give a player a role in Discord and the resource grants the matching in-game permissions; remove the role and the permission is removed on the next refresh.

- Uses plain FiveM ACE; no framework is required.
- Runs independently of the rest of UnitLink, which continues to check permissions such as `unitlink.police.duty`.
- Keeps existing permissions if Discord is unavailable.
- Does not store your bot token in the resource.

## Setup

1. Add a Discord bot to your server. It needs no permissions or privileged intents.

2. Add this to `server.cfg`. Replace `YOUR_BOT_TOKEN` with your bot token and keep it private. Use `set`, not `setr`.

```cfg
## UnitLink-Perms
set unitlink_discord_token "YOUR_BOT_TOKEN"
add_ace resource.UnitLink-Perms command.add_ace allow
add_ace resource.UnitLink-Perms command.add_principal allow
add_ace resource.UnitLink-Perms command.remove_principal allow

ensure UnitLink-Perms
```

3. Open `config.lua` and replace:

   - `YOUR_DISCORD_GUILD_ID` with your Discord server ID.
   - Each `EXAMPLE_*_ROLE_ID` with the matching Discord role ID, or remove examples you do not need.
   - The example groups and permission nodes with the departments and permissions used by your UnitLink resources.

   Enable Discord Developer Mode to copy server and role IDs. Keep every ID in quotes because Discord IDs are too large for Lua numbers.

4. Players must have Discord open when they start FiveM so FiveM can provide their Discord identifier.

## Included examples

The default configuration is deliberately small and safe to publish:

| Example Discord role | Group granted | Permission |
|---|---|---|
| Police Officer | `group.police` | `unitlink.police.duty` |
| Police Supervisor | `group.police_supervisor` | police duty and supervisor access |
| UnitLink Administrator | `group.unitlink_admin` | `unitlink.admin` |
| Police Blacklist | blocks police groups | removes police access |

Use these as a pattern: add a group in `Config.Groups`, then attach that group to a role in `Config.Roles`.

## Console commands

| Command | Result |
|---|---|
| `ulperms` | Lists online players, their Discord IDs, and assigned groups. |
| `ulperms refresh` | Re-checks everyone immediately. |
| `ulperms refresh 12` | Re-checks player ID 12. |

## Server exports

- `exports['UnitLink-Perms']:Refresh(source)` re-checks one player.
- `exports['UnitLink-Perms']:GetGroups(source)` returns the groups assigned by this resource.
- `unitlink-perms:updated (source, groups)` fires whenever a player's assigned groups change.

## Security notes

Never commit your bot token or your production `server.cfg`. If a token is ever committed, reset it in the Discord Developer Portal before using the repository publicly.
