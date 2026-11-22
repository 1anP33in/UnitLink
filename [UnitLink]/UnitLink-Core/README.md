# UnitLink Core 1.0.0

UnitLink Core is the framework behind UnitLink. It's standalone: no QBCore, ESX, Qbox or other roleplay framework, and none of their code.

It handles:

- Persistent accounts, keyed by Rockstar license
- **3 character slots** per account: create, select, delete and switch without reconnecting
- Per-character appearance through **illenium-appearance**
- **Character-specific** permission groups, with multiple groups per character, recursive inheritance and explicit allow/deny overrides
- Bootstrap admin access at the account level, kept separate from character permissions
- Admin commands and an NUI admin dashboard
- Spawn selection, including last location
- Character metadata, developer exports and lifecycle events
- Server-side validation, rate limiting and an audit log, with optional webhook output

> **Status.** Every Lua file compiles under Lua 5.4. The automated suite in `tests/` passes 195/195: it runs the real server code against FiveM stubs and an in-memory database fake. The NUI screens were checked in a browser with mock data. **None of it has run on a live FXServer with MySQL and illenium-appearance yet.** Work through the [in-game testing checklist](#in-game-testing-checklist) before you open the server to players.

---

## Contents

1. [Requirements](#requirements)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Character system](#character-system)
5. [Illenium Appearance](#illenium-appearance)
6. [Permission system](#permission-system) (including [Discord role sync](#discord-role-sync))
7. [Bootstrap admins](#bootstrap-admins)
8. [Administration](#administration)
9. [Export reference](#export-reference)
10. [Event reference](#event-reference)
11. [Security model](#security-model)
12. [Testing](#testing)
13. [Troubleshooting](#troubleshooting)
14. [Known limitations](#known-limitations)

---

## Requirements

| Dependency | Why | Notes |
|---|---|---|
| FXServer (recent artifact), **OneSync on** | Server-side positions, routing buckets | OneSync is the default on current artifacts |
| MySQL 5.7+ or MariaDB 10.3+ | Storage | InnoDB, utf8mb4 |
| [oxmysql](https://github.com/overextended/oxmysql) | Database driver | Hard dependency |
| [illenium-appearance](https://github.com/iLLeniumStudios/illenium-appearance) **v5.x release** | Appearance editor | Checked against **v5.7.0**. Use a release, not `main` |
| ox_lib | **Required by illenium-appearance**, not by UnitLink Core | Must start before illenium-appearance |
| spawnmanager (cfx default) | Optional | UnitLink Core turns its auto-spawn off |

UnitLink Core doesn't use ox_lib itself.

## Installation

1. Copy `UnitLink-Core` into your resources folder.
2. **Database.** UnitLink Core creates any missing tables on start when `Config.Database.AutoInstall = true` (the default). You can import `sql/install.sql` yourself instead. Every statement is `CREATE TABLE IF NOT EXISTS`, so running it again is safe.
3. **server.cfg:**

```cfg
set mysql_connection_string "mysql://user:password@localhost/unitlink?charset=utf8mb4"

ensure oxmysql
ensure ox_lib
ensure illenium-appearance
ensure UnitLink-Core

# Optional: anyone with this ACE is a bootstrap admin (see Bootstrap admins)
# add_ace identifier.license:YOUR_LICENSE unitlink.bootstrap allow
```

4. Remove or stop `basic-gamemode` if you run it. It force-spawns players, and UnitLink Core owns spawning.
5. Start the server and watch for `[UnitLink-Core] Ready.` in the console.
6. Set up the first owner. See [Bootstrap admins](#bootstrap-admins).

**Loading screen.** When character selection is ready, UnitLink Core fires `hickory_loadscreen:shutdown`, which HCRP-Loading listens for. It then calls `ShutdownLoadingScreenNui()` itself after `Config.LoadingScreen.ForceShutdownAfterMs`. If you use HCRP-Loading, set `AUTO_SHUTDOWN = false` in its `client.lua` so it doesn't close early on its 5-second safety timer.

## Configuration

| File | Side | Contents |
|---|---|---|
| `config/config.lua` | shared | Server name, commands, selection scene, appearance sections, death handler, loading screen |
| `config/characters.lua` | shared | Slots, name/age/height rules, genders, nationalities |
| `config/database.lua` | server | Auto-install, autosave interval, audit retention |
| `config/bootstrap.lua` | server | Bootstrap admin licenses and ACE |
| `config/permissions.lua` | server | Permission node registry, security switches, rate limits |
| `config/groups.lua` | server | Default groups (seeded into the DB), default character groups |
| `config/spawn.lua` | server | Spawn locations, restrictions, last location |
| `config/logging.lua` | server | Console audit output; Discord webhook to `#🔐・UnitLink-Core-logs` (on) |
| `config/discord.lua` | server | Discord role → group mapping and sync settings |

Server-only config files are listed under `server_scripts`, so clients never download them.

## Character system

**Lifecycle:** connect → account row upserted → character selection (in a private routing bucket) → select or create → *(new characters: appearance creator)* → spawn selection → in the world.

- **Slots.** `Config.Characters.MaxSlots`, default 3, is clamped to `HardSlotLimit`, also 3. A unique `(identifier, slot)` key in the database backs this up.
- **Character IDs.** These are `BIGINT AUTO_INCREMENT` values starting at 1000, generated by MySQL. The client never supplies one when creating.
- **Validation.** Every check runs on the server in `server/identity.lua`:
  - Names: letters only, with single inner spaces, hyphens or apostrophes; length limits from config.
  - Date of birth: must be a real date (leap years included), with an age between `Age.Min` and `Age.Max`.
  - Gender, nationality and height: must come from the configured lists and ranges.
  - Full names: unique server-wide (optional).
- **Selection.** The cards show name, ID, date of birth, nationality, gender, height and highest group. Clicking a card previews that character's appearance on the scene ped. The server checks you own the character first.
- **Deletion.** The player must type the character's full name. The server deletes with `WHERE id = ? AND identifier = ?`, so a player can only ever delete their own characters. Groups, overrides and appearance are removed by `ON DELETE CASCADE`.
- **Switching.** `/switchcharacter` needs `unitlink.character.switch` on the active character; `civilian` has it by default. The server saves the position, unloads the character (clearing its groups, permission cache and appearance session), fires `characterUnloaded`, then returns the player to selection. Loading the next character fires `characterSwitched`.
- **Return to selection.** Before spawning, the player can step back from the spawn picker. This needs no permission, because the character never entered the world.
- **One session per account.** A second connection with the same license is refused, so one character can never be active twice. An in-memory `characterId → source` index enforces the same rule.

### Persistence

| Data | Written |
|---|---|
| Character fields, groups, overrides, metadata, appearance | Immediately, when they change |
| Last position | On unload, on disconnect, every `AutosaveInterval` (default 300 s), and queued on resource stop. Positions are read **server-side** from the ped; client coordinates are never trusted. A 10-second in-memory cache covers disconnects where the ped is already gone. |

## Illenium Appearance

I checked illenium-appearance **v5.7.0** against its source before writing the adapter. These are the facts that matter:

- Its client exports include `startPlayerCustomization(callback, config)`, `getPedAppearance(ped)`, `setPlayerAppearance(appearance)` and `setPlayerModel(model)`. The callback receives the appearance table on save, or `nil` on cancel.
- It only bridges to **qb-core, ESX and ox_core**. Its own saving path (`illenium-appearance:server:saveAppearance`), clothing shops, outfits and `/reloadskin` all depend on those bridges. Without one, those features don't work.
- It depends on **ox_lib** (`@ox_lib/init.lua`).

**How UnitLink Core uses it** (`integrations/illenium.lua`, client):

- UnitLink Core controls the lifecycle and storage. Illenium only edits the ped.
- **New characters:** the freemode model is set by gender, then `startPlayerCustomization` opens with `enableExit = false` and the sections in `Config.Appearance.NewCharacterSections`.
- **Saving:** the result goes to the server, which stores it against the **server's own active character ID**. The client never sends a character ID, so one character's appearance can't overwrite another's. Saves are only accepted while the server has an appearance session open. Unknown keys are stripped, the payload is size-limited, and the model can't change unless the `ped` section was enabled.
- **Loading and switching:** `setPlayerAppearance` applies the stored appearance for whichever character the server loaded.
- **Later changes:** use `/appearance` (needs `unitlink.appearance.edit`) or the export `OpenAppearanceEditor(source, sections)`, for example from a future clothing shop.
- If illenium isn't running, new characters get a plain freemode ped and the server logs a warning.

**No illenium files are modified.** Its built-in shops, outfits and `/reloadskin` won't save in this setup, because they need a framework bridge. Build UnitLink clothing and barber shops on `OpenAppearanceEditor` instead.

## Permission system

Permissions belong to **characters**, not accounts. If one account owns John (LEO), Mike (SAFR) and James (civilian), it gets LEO, SAFR or civilian permissions depending on which character is loaded. Nothing carries over between them; the test suite checks this.

### Groups

Groups have an internal `name`, a display `label`, a `description`, a `priority`, `inherits`, permission `nodes` and `metadata`. A character can hold several groups.

`inherits` means "this group also gets every permission of these groups". Senior groups inherit the ones below them:

```
owner ─► co_owner ─► head_management ─► management ─► junior_management ─► trial_management
      ─► head_admin ─► senior_admin ─► admin ─► head_moderator ─► senior_moderator ─► moderator
      ─► trial_moderator ─► support ─► staff
developer (separate from the staff ladder)
leo_command ─► leo_supervisor ─► leo
safr_command ─► safr_supervisor ─► safr
civilian (default for new characters)
```

Whitelist, donator and perk groups (`whitelist_leo`, `whitelist_gang`, `donator` ◄ `vip_premium` ◄ `vip_elite` ◄ `vip_ultimate`, the `pack_*` groups, `speed_bypass`, `booster`) only grant nodes such as `unitlink.pack.sports`, for other resources to check. See [Discord role sync](#discord-role-sync) for where all of these come from.

#### Departments

The departments match the your Discord server Discord server. They're defined in `Config.Departments` (`config/groups.lua`), and each one gets three groups:

| Department | Groups | Builds on | Discord roles |
|---|---|---|---|
| San Andreas State Police | `sasp`, `sasp_supervisor`, `sasp_command` | `leo` | San Andreas State Police, SASP \| Supervisor, SASP \| High Command |
| Blaine County Sheriff's Office | `bcso`, `bcso_supervisor`, `bcso_command` | `leo` | Blaine County Sheriff's Office, BCSO \| … |
| Los Santos Police | `lsp`, `lsp_supervisor`, `lsp_command` | `leo` | Los Santos Police, LSP \| … |
| Department of Homeland Security | `dhs`, `dhs_supervisor`, `dhs_command` | `leo` | TRP \| Department of Homeland Security, DHS \| … |
| San Andreas Fire Department | `safd`, `safd_supervisor`, `safd_command` | `safr` | San Andreas Fire Department, SAFD \| … |
| Federal Aviation Administration | `faa`, `faa_supervisor`, `faa_command` | none | Federal Aviation Administration, FAA \| … |

```
sasp_command ─► sasp_supervisor ─► sasp ─► leo
                sasp_supervisor ─► leo_supervisor
```

- Assign characters the **department** group, not `leo` or `safr`. Those are shared bases, so anything gated on `unitlink.police.duty` (such as the Mission Row spawn) works for every police department.
- Each department has its own nodes: `unitlink.<dept>.duty`, `.supervisor` and `.roster`.
- `<dept>_command` gets `unitlink.<dept>.*`, which covers its own department only.
- Cross-department command (Discord "UnitLink | Department High Command") is `leo_command` or `safr_command`.

Groups are seeded with `SeedMode = 'missing'`. A server that already started with the old config will add the new department groups, but won't rewrite the descriptions of `leo` and `safr`.

Every write is validated. The server rejects cycles (including a group inheriting itself), unknown parent groups, inheriting the same group twice, invalid names and invalid nodes. Expansion is also cycle-safe and depth-limited, in case the database was edited by hand.

### Discord role sync

`integrations/discord.lua` reads each player's roles on the your Discord server Discord and turns them into groups. The mapping is in `config/discord.lua`, one line per role, keyed by role ID so renaming a role doesn't break it.

| Kind | Discord roles | What happens in game |
|---|---|---|
| `groups` (account) | Staff ranks, whitelists, donator tiers, perk packs | The group applies to **every character** on the account while they have the role. Staff can't assign these by hand (`discord_managed`) |
| `unlocks` (department) | SASP, BCSO, LSP, DHS, SAFD and FAA ranks; FTO; Department Supervisor and High Command | The role makes the group **available**. Staff (or department command with `unitlink.admin.permissions`) still choose which character gets it in `/ulcore`. Assigning it to someone without the role fails with `discord_role_required` |
| `blocks` (blacklist) | Blacklisted LEO, Staff, Public Officer, Development Team; LEO Cooldown; Suspended Staff | While they have the role, the listed groups, and every group that inherits them, are switched off on all their characters |

How it behaves:

- **Nothing from Discord is stored in the database.** Roles are applied whenever permissions are built. Remove a role on Discord and the matching access goes at the next refresh. Give it back and it returns, including department groups still saved on the character.
- **Refresh timing:** roles are re-read when the player joins, each time they return to character selection, every `RefreshSeconds` (5 minutes), on `/ulcore discord sync`, and through the `RefreshDiscordRoles` export.
- **No Discord linked** (Discord wasn't open when they launched FiveM) means no roles: civilian only. Set `RequireDiscord = true` to refuse them instead, and `RequireMembership = true` to also refuse people who aren't in the Discord server.
- **Discord unreachable:** the player keeps the roles from the last successful check. A player whose roles were never loaded has none.
- **Off switch:** if the `unitlink_discord_token` convar isn't set, the sync is inactive and UnitLink-Core works exactly as before, with groups assigned by hand. Bootstrap admins work either way.

**Setup:** add the "UnitLink - Core" bot token to `server.cfg` as `set unitlink_discord_token "..."`. The bot needs to be in the server, but needs no permissions and no privileged intents. On start the console prints `Discord sync connected to your Discord server`. A wrong token or a bot that isn't in the server shows as an error instead.

**Changing the mapping:** edit `Roles` in `config/discord.lua`. To find a role ID, turn on Developer Mode in Discord, then go to Server Settings → Roles, right-click the role and choose Copy Role ID. Unknown groups and duplicate IDs are reported on start.

### Nodes

Nodes are lowercase and dot-separated, for example `unitlink.police.duty`. A trailing `*` is a wildcard (`unitlink.police.*`), and `*` alone means everything. Other resources can use any well-formed node without changing UnitLink Core. They can register nodes with `RegisterPermissionNode` so the nodes show up in the dashboard.

### Resolution order (deterministic)

For `HasPermission(character, 'a.b.c')`, the candidates are checked from most to least specific: `a.b.c`, `a.b.*`, `a.*`, `*`.

1. **Character overrides.** The first candidate with an override decides the result: allow means true, deny means false. Overrides always beat groups, so an explicit deny can never be bypassed by a group grant. A more specific override beats a broader one: deny `a.*` plus allow `a.b.c` allows `a.b.c` and denies `a.b.d`.
2. **Group grants.** If any effective group (assigned groups plus everything they inherit) grants any candidate, the result is true.
3. Otherwise the result is **false**. With no character loaded, every check is false.

The dashboard's **Explain** tool, `/ulcore explain` and the `ExplainPermission` export all report which rule decided the result, which node matched, and which group it came through.

### Caching

Effective permissions are built once when a character loads and kept in memory. `HasPermission` never queries MySQL. The cache is rebuilt immediately when that character's groups or overrides change, or when any group definition changes, so it can't go stale. Changes reach online players straight away.

### Storage

The tables are `unitlink_groups`, `unitlink_group_inheritance`, `unitlink_group_permissions`, `unitlink_character_groups` and `unitlink_character_permission_overrides`, all keyed by character ID.

## Bootstrap admins

Bootstrap access belongs to the **account**. It's defined only in server-side config, never by client input or character permissions:

- `Config.Bootstrap.Licenses` in `config/bootstrap.lua`, or
- the ACE `unitlink.bootstrap` (`add_ace identifier.license:xxx unitlink.bootstrap allow`).

Bootstrap admins can always open the dashboard and manage everything, even if no character has an admin group. That way the server can't lock itself out. Bootstrap access **doesn't** grant character permissions: `HasPermission` ignores it.

**First owner setup:**

1. Join and create a character, then note its ID (shown on the card, e.g. `#1000`).
2. In the **server console**, run `ulcore addgroup 1000 owner`. The console is always fully trusted.

## Administration

### Commands

| Command | Needs |
|---|---|
| `/ulcore` | `unitlink.admin.access`. Opens the dashboard |
| `/ulcore players` / `character [id]` / `groups` / `permissions [id]` | Opens the dashboard at that section |
| `/ulcore explain <charId> <node>` | `unitlink.admin.characters` or `unitlink.admin.permissions` |
| `/ulcore addgroup <charId> <group>` / `removegroup` | `unitlink.admin.permissions` plus the hierarchy rules below |
| `/ulcore allow <charId> <node>` / `deny` / `clear` | `unitlink.admin.permissions` plus the hierarchy rules below |
| `/ulcore chars <serverId\|license>` | `unitlink.admin.characters` (licenses also need `unitlink.admin.identifiers`) |
| `/ulcore reloadgroups` | Bootstrap admin or console |
| `/ulcore discord [serverId]` / `discord sync [serverId]` | `unitlink.admin.players`. Shows what a player's Discord roles give them, or re-reads roles now |
| `/switchcharacter` | `unitlink.character.switch` |
| `/appearance` | `unitlink.appearance.edit` |

Every subcommand also works from the server console as `ulcore ...`.

### Admin nodes

| Node | Allows |
|---|---|
| `unitlink.admin.access` | Opening the dashboard |
| `unitlink.admin.players` | Viewing connected players |
| `unitlink.admin.identifiers` | Seeing licenses (otherwise shown as a short hash) |
| `unitlink.admin.characters` | Viewing and editing character records and metadata |
| `unitlink.admin.permissions` | Assigning groups and overrides |
| `unitlink.admin.groups` | Creating, editing and deleting groups |
| `unitlink.admin.audit` | Reading the audit log |

### Hierarchy rules (non-bootstrap admins)

Each of these can be switched off in `Config.Security`.

- You can't change your **own** character's record, groups or overrides.
- You can only manage characters whose highest group priority is **below** yours.
- You can only assign groups with a priority **below** yours.
- You can only grant or deny nodes **you hold yourself**.
- You can only create, edit or delete groups **below** your priority.

### Dashboard

| Section | What it does |
|---|---|
| **Overview** | Connected players, loaded characters, active sessions, registered characters and accounts, available slots, group count |
| **Players** | Live list showing state, active character and groups. Click a row to open that character |
| **Characters** | Search by name, ID or license. Edit identity fields; add and remove groups; set and clear allow/deny overrides; see effective permissions with their source; explain any node; edit JSON metadata |
| **Groups** | Create and edit groups (label, description, priority, inheritance, nodes). Delete a group, moving its characters to another group if any hold it. Built-in groups and groups others inherit from can't be deleted |
| **Permissions** | Searchable node registry and the Explain tool |
| **Audit log** | Filter by action or character ID, with paging |

The dashboard hides buttons you can't use, but every request is checked again on the server.

## Export reference

Server exports are called with `exports['UnitLink-Core']:Name(...)`. Getters return copies.

| Export | Returns |
|---|---|
| `GetPlayer(source)` | `{ source, identifier, accountId, name, state, loaded, spawned, characterId, character, groups, permissions }` or `nil` |
| `GetCharacter(source)` | `{ id, slot, firstname, lastname, fullname, dateofbirth, gender, nationality, height, createdAt, metadata }` or `nil` |
| `GetCharacterId(source)` | number or `nil` |
| `GetSourceFromCharacterId(characterId)` | server ID or `nil` |
| `IsPlayerLoaded(source)` / `IsPlayerSpawned(source)` | boolean |
| `GetActivePlayers()` | `{ { source, characterId }, ... }` |
| `HasPermission(source, node)` | boolean (active character; `false` if none) |
| `RefreshDiscordRoles(source)` | Re-reads the player's Discord roles now. Returns `false` if the sync is off |
| `HasGroup(source, group, directOnly?)` | boolean. Counts inherited groups unless `directOnly` |
| `GetGroups(source, includeInherited?)` | array of group names |
| `GetPermissions(source)` | array of the nodes the character effectively holds (wildcards included) |
| `CharacterHasPermission(characterId, node)` | boolean; works for offline characters |
| `ExplainPermission(characterId, node)` | `{ allowed, reason, explanation }` |
| `GetGroupDefinition(name)` / `GetGroupList()` | group definition(s) |
| `IsBootstrapAdmin(source)` | boolean |
| `RegisterPermissionNode(node, description)` | boolean |
| `GetMetadata(source, key)` / `SetMetadata(source, key, value)` | value / `true` or `false, err` |
| `GetCharacterMetadata(characterId, key?)` / `SetCharacterMetadata(characterId, key, value)` | same, by character ID (no key returns all metadata) |
| `SearchCharacters(query, limit?)` | read-only name or ID search over every character, online or not. Returns `{ id, firstname, lastname, dateofbirth, gender, nationality, height }` rows, never identifiers. Max 50. Used by UnitLink. |
| `GetCharacterById(characterId)` | one character's public fields (same shape), or `nil` |
| `AddGroup(characterId, group, actorSource?)` | `true` or `false, err` |
| `RemoveGroup(characterId, group, actorSource?)` | `true` or `false, err` |
| `GrantPermission(characterId, node, actorSource?)` | Explicit **allow** override |
| `DenyPermission(characterId, node, actorSource?)` | Explicit **deny** override |
| `RevokePermission(characterId, node, actorSource?)` | **Removes** the override (alias: `ClearPermissionOverride`) |
| `OpenAppearanceEditor(source, sections?)` | Opens illenium for the active character |
| `ForceCharacterSelection(source)` | Saves, unloads and sends the player to selection |
| `GetVersion()` | `'1.0.0'` |

**`actorSource` on mutations.** If you pass a player's server ID, UnitLink Core checks that player is allowed to make the change, exactly as if they used the dashboard. If you leave it out, the call is treated as trusted resource code and audited as `resource:<name>`. To limit which resources may call mutations at all, set `Config.Security.MutationResourceAllowlist`.

**Error codes** are stable strings from `shared/enums.lua`: `not_found`, `unauthorized`, `hierarchy`, `unknown_group`, `duplicate`, `inheritance_cycle`, `database_error`, and so on.

**Client exports** (UI hints only; never use them for security): `GetCharacter()`, `GetCharacterId()`, `IsLoaded()`, `IsSpawned()`, `HasPermission(node)`, `HasGroup(group)`, `GetGroups(includeInherited)`.

## Event reference

**Server, local events.** Listen with `AddEventHandler`. **Never** `RegisterNetEvent` these names: that would let clients fake them.

| Event | Arguments |
|---|---|
| `unitlink-core:server:ready` | none |
| `unitlink-core:server:characterCreated` | `source, characterId, character` |
| `unitlink-core:server:characterDeleted` | `source, characterId` |
| `unitlink-core:server:characterLoaded` | `source, characterId, character` |
| `unitlink-core:server:characterSpawned` | `source, characterId, spawnId` |
| `unitlink-core:server:characterUnloaded` | `source, characterId, reason` (`switch`, `dropped`, `back`, `forced`) |
| `unitlink-core:server:characterSwitched` | `source, oldCharacterId, newCharacterId` |
| `unitlink-core:server:permissionsUpdated` | `characterId, source\|nil` |
| `unitlink-core:server:groupAssigned` / `groupRemoved` | `characterId, group, actor` |
| `unitlink-core:server:groupsChanged` | `groupName, action` |
| `unitlink-core:server:metadataUpdated` | `characterId, key, value` |
| `unitlink-core:server:audit` | `entry` (`action`, `actorIdentifier`, `actorCharacterId`, `targetCharacterId`, `details`, `timestamp`) |

**Client events.** Sent by the server; listen with `RegisterNetEvent` + `AddEventHandler` in client scripts.

| Event | Arguments |
|---|---|
| `unitlink-core:client:characterLoaded` | `character` (public fields) |
| `unitlink-core:client:characterSpawned` | `spawnId` |
| `unitlink-core:client:characterUnloaded` | `characterId` |
| `unitlink-core:client:permissionsUpdated` | `{ groups, effectiveGroups, permissions }` |

**State bags:** `Player(src).state['unitlink-core:characterId']` and `['unitlink-core:loaded']` are replicated to clients.

**Example:**

```lua
-- server.lua in another resource
AddEventHandler('unitlink-core:server:characterLoaded', function(src, characterId, character)
    if exports['UnitLink-Core']:HasPermission(src, 'unitlink.police.duty') then
        print(character.fullname .. ' can go on duty')
    end
end)
```

## Security model

- **One network entry point.** Clients reach the server only through `unitlink-core:server:cb`. That router checks the framework is ready, applies a global rate limit and a per-callback rate limit, forces the payload to be a table, runs the handler in `pcall`, and serialises session-changing calls per player so a double-click can't load two characters.
- **The server owns identity and ownership.** The account comes from `GetPlayerIdentifierByType` on the server. Every character query on a player's behalf includes `AND identifier = ?`. After each database wait, the session is checked again in case the player disconnected meanwhile.
- **Never trusted from the client:** character IDs for ownership, account identifiers, groups, nodes, admin status and coordinates. Spawns are chosen by ID only.
- **All SQL is parameterised.** Values are always passed as parameters. The only things built into SQL text are fixed column names from a hard-coded list (character edits) and an integer the server clamps itself (the audit page offset). Multi-row changes run in transactions: character creation with default groups, group writes, group deletion with reassignment, and seeding.
- **NUI.** The admin dashboard and selection only render text through `textContent`, so player-typed names or metadata can't inject markup.
- **Audit log** (`unitlink_audit_log`) records creates, deletes, loads, switches, edits, metadata edits by admins, appearance saves, group assign/remove/create/update/delete, override allow/deny/clear, dashboard opens and denied admin requests. Ordinary players never see identifiers. Admins without `unitlink.admin.identifiers` see a short hash instead.
- **Webhook output** is optional (`config/logging.lua`) and redacts identifiers by default. The URL is a secret. It's read from the `unitlink_core_log_webhook` convar, so put it in `server.cfg` (`set unitlink_core_log_webhook "https://discord.com/api/webhooks/..."`), never in the Lua files.

## Testing

### Automated (no server needed)

```powershell
pip install lupa
```

```powershell
python -P tests/run.py
```

This compiles every Lua file with Lua 5.4. It then runs `tests/tests.lua`: the real server files, loaded in manifest order, against FiveM stubs and an in-memory fake of the oxmysql adapter. Current result: **195 passed, 0 failed.**

What the suite covers, using the numbering from the original spec:

| Spec items | Covered |
|---|---|
| 1-2 | Account creation; a duplicate session is refused |
| 3-6 | Three characters created; the fourth is rejected |
| 7, 9 | Selecting an owned character; character data persists across a reconnect |
| 8, 10 | Disconnect/reconnect cleanup; appearance persists across a reconnect |
| 11 | Switching (permissions don't carry over); return to selection |
| 12 | Delete with name confirmation; cascade |
| 13, 23 | Loading, previewing or deleting another account's character is rejected |
| 14-20 | Per-character groups; different permissions per character; inheritance; cycle rejection; explicit deny/allow; live cache refresh after changes |
| 21-22 | Unauthorized and hierarchy-violating group assignment rejected; dashboard requests from non-admins rejected |
| 24 | Database failures return `database_error` without crashing |
| Also | Input validation (names, dates, leap years, ages, heights, injection strings); spawn restrictions; raw coordinates refused; appearance model lock and key stripping; rate limiting; not-ready handling; metadata validation |

**What the automated tests do not cover:** real MySQL behaviour (the SQL itself, foreign keys, transactions), natives and anything visual in the game, the illenium editor, and multiple real clients at once. Item 25 (resource restarts) and the live parts of items 8 and 24 need a real server.

### In-game testing checklist

- [ ] Server starts; console shows `[UnitLink-Core] Ready.` and the tables exist
- [ ] New player sees character selection (loading screen closes, scene ped visible)
- [ ] Create three characters; the fourth slot doesn't exist / is rejected
- [ ] New character opens the illenium editor without an exit button; saving leads to spawn selection
- [ ] Spawn at Legion Square; walk somewhere; disconnect, reconnect; "Last Location" appears and works
- [ ] Each character keeps its own appearance after switching (`/switchcharacter`) and after reconnecting
- [ ] Delete requires typing the name; deleted character is gone after reconnect
- [ ] Console: `ulcore addgroup <id> owner`; `/ulcore` opens the dashboard
- [ ] Give character A `leo`, character B `safr` on the same account; check `/ulcore explain` for each
- [ ] Deny override on a node an online player holds takes effect without relog
- [ ] Create a group, try to make it inherit its own child (rejected), delete it with reassignment
- [ ] Non-admin `/ulcore` is refused and audited
- [ ] Two players online at once: each sees only their own characters; neither sees the other during selection
- [ ] `restart UnitLink-Core` with players online: they return to character selection; data intact
- [ ] Stop MySQL briefly: actions fail with an error message, nothing crashes; recovers when MySQL is back
- [ ] `/appearance` with `unitlink.appearance.edit` saves; cancelling restores the old look
- [ ] Mission Row spawn only appears for characters with `unitlink.police.duty`

## Troubleshooting

| Symptom | Fix |
|---|---|
| "still starting up" on connect | Check the console for database errors and `mysql_connection_string` |
| `Missing database tables` | Turn on `AutoInstall` or import `sql/install.sql` |
| Black screen after joining | The loading screen didn't close. Check `Config.LoadingScreen`; make sure no other resource keeps the screen faded |
| Players spawn before selection | Stop `basic-gamemode` / any auto-spawn resource |
| Plain ped, no editor | `illenium-appearance` or `ox_lib` isn't started; check the warnings in the console |
| Appearance shops don't save | Expected: illenium's shops need a framework bridge. Use `OpenAppearanceEditor` |
| "You cannot manage someone at or above your own rank" | Hierarchy rules; use a higher group, a bootstrap admin or the console |
| Locked out of admin | Add your license to `config/bootstrap.lua` or use the server console |

## Known limitations

- Not yet run on a live server. See the status note at the top.
- Illenium's own shops, outfits and `/reloadskin` aren't bridged. Future UnitLink shop resources should call `OpenAppearanceEditor`.
- The death handler is a minimal auto-respawn placeholder (`Config.Death`). Replace it with an EMS resource.
- On `onResourceStop`, saves are queued but not awaited. Autosave and save-on-disconnect cover normal operation.
- Group internal names can't be renamed (labels can). Create a new group and delete the old one with reassignment.
- Spawn and selection coordinates are standard GTA locations. Adjust them in `config/spawn.lua` and `config/config.lua` for your map.

## File layout

```
UnitLink-Core/
├── fxmanifest.lua
├── config/        config.lua, characters.lua (shared) + server-only files
├── shared/        constants, enums, utils (pure), locales
├── server/        players, characters, identity, appearance, metadata, groups,
│                  permissions, persistence, spawn, administration, commands,
│                  callbacks, ratelimit, logging, database, api (exports), main
├── client/        main (callbacks/state), nui, scene, characters, appearance,
│                  spawn, permissions, admin
├── integrations/  oxmysql.lua, illenium.lua, webhook.lua
├── nui/           index.html, css/, js/ (api, app, characters, creation, spawn, admin)
├── sql/           install.sql
└── tests/         run.py, tests.lua (not loaded by FiveM)
```

Open `nui/index.html#selection`, `#spawn` or `#admin` from a local web server to preview the screens with mock data.
