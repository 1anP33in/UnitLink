# Exports & Events

## unitlink-police: CAD exports (server)

Actions return `ok, err`.

| Export | Returns / does |
|---|---|
| `GetCalls()` | List of active calls (`id, nature, priority, origin, address, units, createdAt…`) |
| `GetCall(id)` | One call, or `nil` |
| `CreateCall(src, data)` | Creates a self-initiated call |
| `UpdateCall(src, id, fields)` | Changes `priority` / `nature` |
| `AssignUnit(src, id)` / `UnassignUnit(src, id)` | Attaches or detaches the player's unit |
| `CloseCall(src, id)` | Closes the call |
| `GetUnits()` | On-duty units (`source, callsign, dept, status, calls…`) |
| `SetUnitStatus(src, status)` | `available`, `responding`, `onscene`, `busy`, `unavailable` |
| `IsSupervisor(src)` | `true` if the player has `unitlink.<dept>.supervisor` or `unitlink.police.supervisor` |
| `GetDepartments()` | Read-only list of departments with their duty and supervisor ACE (used by the Admin Dashboard) |

Older exports: `IsOnDuty(source)`, `GetOfficer(source)`, `GetOnDutyOfficers()`, `ClockOut(source, reason)`.

## unitlink-police: local server events

| Event | Arguments |
|---|---|
| `unitlink-police:server:callCreated` | `call, callerSource` (the caller's server id for civilian 911 calls) |
| `unitlink-police:server:callUpdated` | `call, action` |
| `unitlink-police:server:callClosed` | `id, reason, by` |
| `unitlink-police:server:unitsChanged` | none |

Client: `unitlink-police:dutyChanged (onDuty, state)`.

## UnitLink-CAD exports (server)

| Export | Returns |
|---|---|
| `GetActiveName(source)` | The name of the civilian profile the player is playing, or `nil` |
| `GetActiveProfile(source)` | `{ id, firstname, lastname, dateofbirth, gender, nationality, height }`, or `nil` |
| `GetIdentityMode()` | `'standalone'` (civilian profiles) or `'core'` (UnitLink-Core) |
| `CreateWorkOrder({ category, description, priority, street, coords, requester })` | Creates a DOT work order (origin `agency`). Returns the number, or `nil` |
| `GetFireIncidents()` | Active SAFR incidents |

UnitLink-Police and UnitLink-HUD use `GetActiveName` to show the player's name.

## UnitLink network events

| Event | Direction | Purpose |
|---|---|---|
| `unitlink:server:req` | client → server | Every tablet action (`reqId, action, payload`). Each one is checked and rate-limited |
| `unitlink:client:res` | server → client | The reply (`reqId, ok, data`) |
| `unitlink:client:push` | server → client | Live updates: `board`, `note`, `callClosed`, `alertsChanged`, `signal100`, `fire*`, `dot*`, `tools*` |
| `unitlink:server:closed` | client → server | Tablet closed |

{% hint style="warning" %}
Don't trigger `unitlink:server:req` from other scripts. Use the UnitLink-Police exports instead. Every request is checked for on duty, CAD access and a loaded character.
{% endhint %}
