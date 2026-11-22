# UnitLink-Core

The UnitLink framework: characters, groups and departments, permissions, metadata and the admin dashboard.

**Folder:** `[UnitLink]/UnitLink-Core`

## What UnitLink uses

| Export | Used for |
|---|---|
| `GetCharacterId(source)` | Finds who is using the tablet |
| `SearchCharacters(query, limit)` | Name search (read-only, never returns account identifiers) |
| `GetCharacterById(id)` | State returns |
| `GetCharacterMetadata(id, key)` | Reads `licenses` |
| `SetCharacterMetadata(id, key, value)` | Adds points and suspends licenses |

## Admin commands

| Command | Does |
|---|---|
| `/ulcore` | Opens the admin dashboard (`unitlink.admin.access`) |
| `/ulcore addgroup <charId> <group>` / `removegroup` | Gives or removes a department group |
| `/ulcore explain <charId> <node>` | Explains why a permission is allowed or denied |
| `/ulcore discord [serverId]` | Shows what someone's Discord roles give them |
| `/switchcharacter` | Switch character |

## Secrets

| Convar | Used for |
|---|---|
| `unitlink_discord_token` | Discord role sync bot |
| `unitlink_core_log_webhook` | Audit log channel (optional) |

The full reference is in the script's own `README.md`.
