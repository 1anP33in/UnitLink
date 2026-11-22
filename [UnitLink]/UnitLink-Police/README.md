# UnitLink-Police

This is a standalone police duty and emergency dispatch resource for FiveM. It doesn't need ESX, QBCore, Qbox, vRP, an economy or a database.

- Duty menu with UnitLink Core character permissions and typed-in callsigns
- Live officer blips for all departments, with vehicle-aware sprites
- `/police` live roster with response statuses
- `/911` with Accept, Deny and Set Waypoint, and several units per call
- Panic button
- Duty hours tracking with restart recovery
- Discord webhook logging
- Uses **UnitLink-UI** for every notification and menu (UnitLink-UI is not modified)

> **Status:** written and reviewed. A static check confirmed every block is closed and every function that's called is defined. It has **not yet been run on a live server**. Work through the [testing checklist](#testing-checklist) before going live.

---

## Requirements

- An up-to-date FiveM server with **OneSync** on (the default). All positions are read server side.
- **UnitLink-Core** (your framework) for permissions and characters. Standalone ACE mode is still available, see below.
- **UnitLink-UI** (the UI kit in this project).

## Install

1. Copy `UnitLink-Police` into your resources, e.g. `resources/[UnitLink]/UnitLink-Police`. Put `UnitLink-UI` in e.g. `resources/[UnitLink]/UnitLink-UI`.
2. In `server.cfg`, start them **after** unitlink-core:

```cfg
ensure oxmysql
ensure ox_lib
ensure illenium-appearance
ensure UnitLink-Core
ensure UnitLink-UI
ensure UnitLink-Police
```

3. Give characters their department groups in the UnitLink dashboard (below).
4. Optional: paste webhook URLs into `config/webhooks.lua`.
5. Restart the server, then go through the testing checklist.

## Permissions (UnitLink Core)

Duty access uses your framework's **character permissions**. UnitLink-Police calls `exports['UnitLink-Core']:HasPermission(source, node)`, which checks the player's **active character**, every time someone goes on duty or does something privileged. Nothing is cached.

| Department | Go on duty | Supervisor (close any call in the dept) | UnitLink group to assign |
|---|---|---|---|
| SASP | `unitlink.sasp.duty` | `unitlink.sasp.supervisor` | `sasp` / `sasp_supervisor` / `sasp_command` |
| BCSO | `unitlink.bcso.duty` | `unitlink.bcso.supervisor` | `bcso` / … |
| LSP | `unitlink.lsp.duty` | `unitlink.lsp.supervisor` | `lsp` / … |
| DHS | `unitlink.dhs.duty` | `unitlink.dhs.supervisor` | `dhs` / … |
| SAFD | `unitlink.safd.duty` | `unitlink.safd.supervisor` | `safd` / … |
| FAA | `unitlink.faa.duty` | `unitlink.faa.supervisor` | `faa` / … |

The cross-department override `unitlink.police.supervisor` (every LEO supervisor and LEO High Command) can close any 911 call.

**What this means in practice:**
- **Characters, not accounts:** permissions follow the character. If John Doe has the `bcso` group and Mike Smith doesn't, only John Doe can go on duty as BCSO, even though both are on the same account.
- **A character must be loaded** to go on duty. The duty menu shows "No character loaded" otherwise.
- **Switching character clocks you out.** So does a character being unloaded by the framework (`Config.Framework.clockOutOnUnload`).
- **Losing access clocks you out.** When the dashboard changes a character's groups or overrides, on-duty units are re-checked right away, and anyone who lost access is taken off duty with a message.
- **If UnitLink-Core stops, everyone is clocked out,** and nobody can go on duty until it's back. It fails closed.
- **Duty hours are per character,** stored as `char:<id>`.
- **Names on the roster, 911 calls and logs** are the character's name.

Nodes and groups are configured in `config/permissions.lua` (UnitLink-Police) and `config/groups.lua` (UnitLink-Core). Department keys match UnitLink-Core's department ids.

### Standalone mode (no framework)

Set `Config.Framework.enabled = false`. The same node strings then become plain FiveM ACE names:

```cfg
add_ace group.bcso unitlink.bcso.duty allow
add_ace group.bcso_supervisor unitlink.bcso.supervisor allow
```

## Configuration

| File | What's in it |
|---|---|
| `config/config.lua` | commands, keybinds, callsign scope, 911, panic, roster, rate limits, persistence, logging, UI |
| `config/departments.lua` | departments, callsign rules, blip colors, department types |
| `config/permissions.lua` | permission node per department, supervisor node, cross-department override |
| `config/blips.lua` | sprites, scale, update interval, visibility toggle |
| `config/webhooks.lua` | Discord webhook URLs (**server only**, never sent to clients) |

### Departments

To add a department, add an entry in `config/departments.lua` and its permission node in `config/permissions.lua` using the same key. You don't need to change any code.

```lua
-- config/departments.lua  (example: a park ranger department)
sapr = {
    order = 7, short = 'SAPR', name = 'San Andreas Park Rangers', type = 'leo', blipColor = 52,
    callsign = { pattern = '^%d%u%-%d%d$', example = '7R-01', minLength = 5, maxLength = 5 },
},
-- config/permissions.lua
sapr = { node = 'unitlink.sapr.duty', supervisor = 'unitlink.sapr.supervisor' },
```

**Department types** (`Config.DepartmentTypes`) decide what each department takes part in. By default:
- **`leo` (SASP, BCSO, LSP, DHS):** listed on the roster, appears on blips, sees blips, receives 911, can use panic, receives panic alerts.
- **`fire` (SAFR):** can go on duty, and its hours are tracked and logged. Everything else is **off**. Flip any flag to include SAFR in 911 calls, blips and so on.

### Callsigns

Each department sets its own rules:
- `pattern`: a Lua pattern, checked after the callsign is converted to upper case. `^%d%u%-%d%d$` means "digit, letter, dash, two digits", so `1A-01` passes.
- `example`: shown to the player when their callsign doesn't match.
- `minLength`, `maxLength`.

Callsigns can only ever contain letters, numbers and `-`.

`Config.Callsign.duplicateScope`:
- `'global'`: a callsign can only be in use once on the whole server.
- `'department'`: two departments may each have their own `1A-01`.

The last callsign used per department is remembered on the player's PC and pre-filled next time.

## Commands and keys

| Command | Default key | What it does |
|---|---|---|
| `/duty` | F6 | Duty menu: go on or off duty, department, callsign, duty time, units on duty, status, blip visibility, total hours |
| `/duty on <dept> <callsign>` | | Go on duty without the menu (works even if UnitLink-UI is down) |
| `/duty off` | | Go off duty |
| `/police` | | Live roster by department |
| `/calls` | (unbound) | Active 911 calls, with **Accept / Deny / Set Waypoint** buttons |
| `/911 <message>` | | Call emergency services (anyone) |
| `/panic` | (unbound) | Officer panic |
| | Y | Accept the newest pending call |
| | J | Deny (dismiss) the newest pending call |
| | U | Set a waypoint to the newest panic (within 60s), otherwise the newest call |

Every key can be rebound in **Settings → Key Bindings → FiveM** (they're listed as "Police: …"). The keys shown on call cards follow the player's own bindings.

## How 911 works

1. A civilian types `/911 Shots fired near the gas station`.
2. The server checks the message length, the caller's cooldown (60s) and the open-call limit (25). It also reads the caller's position itself; the street name is worked out on each unit's own game.
3. Every on-duty unit that receives 911 gets a card with the call number, caller, description, location, time, status, the units assigned, and **[Y] Accept · [J] Deny · [U] Waypoint**.
4. **Accept:** you're added as a responding unit and your status switches to Responding. Every other unit's card updates, and they get a short "1A-01 is responding" note.
5. **Deny:** the card is dismissed for you only. The call isn't affected.
6. **Set Waypoint:** accepts the call (if you haven't already) and sets your GPS.
7. Any number of units can respond to the same call. Each can **Cancel Response** from `/calls`. Responding units, supervisors and admins can **Close Call**.
8. Calls expire after `callLifetime` (20 minutes). Units who clock out or disconnect are removed from their calls automatically.

### Response status

**Available, Responding, Busy, Unavailable.**
- Accepting a call sets Responding.
- When you're no longer on any open call, you go back to Available, unless you picked Busy or Unavailable yourself.
- You can't pick Available while you're still responding to a call.
- Change it in the duty menu → Status.

## Panic

`/panic` (on-duty LEO only):
- **Goes to every on-duty unit** that receives panic alerts. It's an urgent, flashing card with name, callsign, department, location and time, and **[U]** sets a waypoint.
- **Map:** a red area blip appears at the location for 2 minutes, and the officer's own blip flashes for 60s.
- **Limits:** it has its own 30s cooldown and rate limit, so 911 limits can never block it.

Civilians and off-duty players are refused, and the attempt is logged.

## Blips

- **Who sees what:** officers appear on the map for every on-duty unit that has `seeBlips`. The label shows callsign and department, and the color comes from the department.
- **Sprites:** different for on foot, car, bike, helicopter, plane and boat.
- **Where positions come from:** the server reads positions itself. Clients never report their own location.
- **Network traffic:** only officers who moved more than 3 m (or changed vehicle, heading or status) are sent each update. With no on-duty viewers, nothing is sent at all.
- **Smooth movement:** nearby officers get a blip attached to their player, so it moves smoothly. Distant officers move on each update (every 2.5s by default).
- **Hiding:** officers can hide their own blip from the duty menu (`Config.Blips.allowHide`).
- **Cleanup:** blips are removed when someone clocks out, disconnects, or the resource stops.

## Duty hours storage

| Mode | Survives resource restart | Survives server reboot | Notes |
|---|---|---|---|
| `kvp` (default) | yes | yes | Stored in the server's KVP database. No setup. |
| `json` | yes | yes | Files in `UnitLink-Police/data/`. Easy to read and back up. Keep the `data` folder. |
| `memory` | **no** | **no** | Nothing is saved. The duty menu labels totals "since the last restart". |

What gets recorded per session: identifier (server side only), name, callsign, department, clock-in time, clock-out time, duration and end reason. There's also a running total per officer and the last 500 sessions.

**Recovery:**
- **Resource restart:** officers who are still connected are put **back on duty** with their original start time. Permissions, character and callsign are checked again first. This works within `restoreWindow` (5 minutes).
- **Crash or reboot:** sessions that couldn't be restored are closed as **interrupted**, using the last checkpoint (every 60s). At most one checkpoint interval of duty time is lost.
- **Clean shutdown:** players are dropped first, so their sessions close normally.

## Discord logging

Paste webhook URLs into `config/webhooks.lua`. Each category can have its own channel, or leave it blank to use `default`.

| Category | Events |
|---|---|
| `duty` | clock in, clock out (with duration), department change, restored session, interrupted session |
| `dispatch` | 911 submitted, accepted, response cancelled, closed, expired |
| `panic` | panic alerts |
| `security` | permission denied (duty or panic), callsign conflicts |

- **Format:** embeds with a color per event, a timestamp, and the officer's name, server ID, callsign and department.
- **Identifiers:** player identifiers are only added if `Config.Logging.includeIdentifiers = true`.
- **Turning events off:** use `Config.Logging.events`.
- **Delivery:** webhooks are sent one at a time, about once a second, to stay under Discord's rate limit.
- **Failures:** a failed webhook prints a warning at most every 30s and never affects gameplay. Everything is also printed to the server console.

## UnitLink-UI integration

All UI goes through `integrations/unitlink_ui.lua`. The exports it uses were checked against UnitLink-UI's source:

| Side | UnitLink-UI export | Used for |
|---|---|---|
| server | `Notify(target, data)` | results, errors, confirmations |
| client | `Notify(data)`, `Dispatch(data)`, `RemoveNotify(id)` | 911 cards (updated in place by id), panic cards |
| client | `RegisterContext`, `ShowContext`, `HideContext`, `GetOpenContext` | duty menu, roster, calls menu |
| client | `InputDialog`, `AlertDialog` | callsign entry, off-duty confirmation |

**Limitation:** UnitLink-UI notifications are display-only, with no mouse focus and no buttons. Accept, Deny and Set Waypoint are offered in two ways instead:
- **Keys:** the key hints shown on the call card.
- **Clickable buttons:** in `/calls`, because UnitLink-UI context menus *are* clickable.

**If UnitLink-UI isn't running:**
- **Notifications:** fall back to the native GTA notification feed. A warning is printed once.
- **Menus:** they explain that UnitLink-UI is needed, and `/duty on|off` still works without them.

**Context menu `onExit` / `onBack`:** older copies of UnitLink-UI couldn't run these for menus registered by another resource. The current UnitLink-UI fixes that. UnitLink-Police doesn't rely on them either way: the roster checks whether it's still open instead.

## Security

- **Duty sessions live on the server.** The client only sends requests.
- **Checked on the server, every time:** loaded character, UnitLink permission node, department, callsign format and callsign uniqueness, when going on duty and on every privileged action (closing calls, panic).
- **Never trusted from the client:** officer identity, department, permissions, callsign ownership, call assignments, duty state and position. Positions come from the server.
- **Every network event:** the arguments are type-checked and rate-limited per player. 911 and panic also have their own server-side cooldowns.
- **Text input:** 911 messages and street text are cleaned (no control characters, no `~` color codes, no HTML brackets, length-capped). UnitLink-UI escapes everything it displays.
- **Who gets location data:** officer positions only go to on-duty units with `seeBlips`. 911 caller names and positions only go to on-duty units that receive 911.
- **Private data:** identifiers and webhook URLs never leave the server.

## Server exports

```lua
exports['UnitLink-Police']:IsOnDuty(source)          -- boolean
exports['UnitLink-Police']:GetOfficer(source)        -- { source, name, callsign, department, status, startedAt, blipVisible } or nil
exports['UnitLink-Police']:GetOnDutyOfficers()       -- list of the above
exports['UnitLink-Police']:ClockOut(source, reason)  -- force someone off duty
```

Client: `exports['UnitLink-Police']:IsOnDuty()`, `exports['UnitLink-Police']:GetDutyState()`.

## Troubleshooting

| Problem | Check |
|---|---|
| "You don't have access to any department" | The character needs the department group (e.g. `bcso`) in the UnitLink dashboard. Permissions are per character, so check you're on the right one. |
| "Select a character before going on duty" | No character is loaded yet, or UnitLink-Core isn't started. |
| Everyone was taken off duty | UnitLink-Core stopped or restarted. UnitLink-Police fails closed. |
| Menus don't open, a native notification shows instead | UnitLink-UI isn't started, or it's started after UnitLink-Police. Check `ensure` order and the console. |
| No blips, or 911 says "location could not be found" | OneSync is off. The console prints a warning on start. |
| Webhook never arrives | The URL must start with `https://`. Look for "webhook failed (HTTP …)" in the console. |
| JSON mode: "could not write data/…" | The `UnitLink-Police/data` folder is missing. |
| A key doesn't work | It may be unbound or clash with another script. Rebind it under Settings → Key Bindings → FiveM. |

## Testing checklist

You'll need 3 test accounts: **A** (character with the `sasp` group), **B** (character with `bcso`), and **C** (character with no department group). Optionally add **S** (a `sasp_supervisor` character). Turn on a webhook to check logging.

| # | Test | Expected |
|---|---|---|
| 1 | C runs `/duty` | Menu shows "No departments". `/duty on sasp 1A-01` → "not authorized", and a security log entry |
| 2 | A: `/duty` → Go on duty · SASP → `1A-01` | "On duty as 1A-01 · SASP" (roster shows the character name), clock-in log, blip appears for B (once B is on duty) |
| 3 | B: `/duty` → BCSO → `2B-04` | On duty. A and B see each other's blips in the right colors |
| 4 | B tries callsign `banana`, then `1A` | "Callsign must look like 2B-04" / length error |
| 5 | B tries `1A-01` (A has it), global scope | "Callsign 1A-01 is already in use", callsign conflict log |
| 6 | A: duty menu → Go off duty → confirm | "Off duty. Session: Xm", A's blip disappears for B, clock-out log with duration |
| 7 | A on duty, then disconnects | A disappears from B's map and `/police`, log reason `disconnect` |
| 8 | A and B on duty, walk around | Blips follow, label shows "1A-01 \| SASP" |
| 9 | A gets in a car, helicopter, boat | Sprite changes within one update. Heading shows |
| 10 | C: `/911 test call at the pier` | C: "Your call #1001 was sent". 911 log |
| 11 | A and B both on duty | Both get the #1001 card with caller, message, street, time, "Pending · no units", key hints |
| 12 | B presses **J** | B's card disappears. A's card is unchanged. `/calls` shows "Dismissed" for B |
| 13 | A presses **Y** | A: "Responding to #1001". B gets "1A-01 is responding". Status Responding in `/police` |
| 14 | Third officer presses **U** | Waypoint set, added as a second unit, cards show both units |
| 15 | B opens `/calls` → #1001 → Accept | Three units listed on the call |
| 16 | A: `/calls` → #1001 → Cancel Response | A removed from units. A goes back to Available (or stays Busy if set by hand) |
| 17 | A: `/panic` | B and others get a flashing PANIC card, red area blip, A's blip flashes. **U** sets waypoint. Panic log. A second `/panic` within 30s → cooldown message |
| 18 | C: `/panic` | "Only on-duty officers can use panic", security log |
| 19 | C: `/911` twice within 60s | Second: "Please wait Ns" |
| 20 | Set a bad webhook URL, clock in | Console warning "webhook failed", game works normally |
| 21 | `stop UnitLink-UI`, then `/duty on sasp 1A-01` and `/911 test` | Native GTA notifications, a console warning, nothing breaks. `start UnitLink-UI` → back to normal |
| 22 | With A and B on duty: `restart UnitLink-Police` | Both back on duty with the original start time ("Back on duty after a restart"), blips return |
| 23 | Kill the server process while A is on duty (kvp or json), then start it | Session logged as interrupted, with duration up to the last checkpoint, and added to A's total |
| 24 | A's account switches to a second character without `sasp` while on duty | A is clocked out ("your character changed"), and the new character's duty menu shows no SASP option |
| 25 | Staff remove `sasp` from A's character in the UnitLink dashboard while A is on duty | A is taken off duty right away ("You no longer have access to SASP") |
| 26 | Staff add `bcso` to C's character, then C opens `/duty` | BCSO is now offered without reconnecting |
| 27 | `/duty` at character selection (no character loaded) | Menu shows "No character loaded" |
| 28 | `stop UnitLink-Core` with units on duty | Everyone is clocked out, and `/duty` refuses until UnitLink-Core is started again |

Also try with 10+ units on duty and several open calls. Run `resmon` and check that UnitLink-Police stays near 0.00 ms on clients and the server while nothing is happening.

## Known limitations

- **Not tested on a live server yet.** Statically checked only (see the status note at the top).
- **Keys act on the newest pending call.** To choose an older call, use `/calls`.
- **Duty time on the menu counts up from when it was opened.** The duty time line shows the time when you opened the menu, not a live clock.
- **Re-opening menus flickers.** The roster and calls menus re-open themselves to refresh, so you'll see a short animation when something changes.
- **SAFR is excluded by default.** It doesn't receive 911 calls, blips or panic alerts until you change its department type flags.
- **Sorting by callsign is plain text order.** For example, `10A` sorts before `2A`.
