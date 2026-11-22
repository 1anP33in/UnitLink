# tsrp-core

The Tropical State RP framework: characters, groups and departments, permissions, metadata and the admin dashboard.

**Folder:** `[Tropical_Permissions]/tsrp-core`

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
| `/tsrp` | Opens the admin dashboard (`tsrp.admin.access`) |
| `/tsrp addgroup <charId> <group>` / `removegroup` | Gives or removes a department group |
| `/tsrp explain <charId> <node>` | Explains why a permission is allowed or denied |
| `/tsrp discord [serverId]` | Shows what someone's Discord roles give them |
| `/switchcharacter` | Switch character |

## Secrets

| Convar | Used for |
|---|---|
| `tsrp_discord_token` | Discord role sync bot |
| `tsrp_core_log_webhook` | Audit log channel (optional) |

The full reference is in the script's own `README.md`.
