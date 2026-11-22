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

Older exports: `IsOnDuty(source)`, `GetOfficer(source)`, `GetOnDutyOfficers()`, `ClockOut(source, reason)`.

## unitlink-police: local server events

| Event | Arguments |
|---|---|
| `unitlink-police:server:callCreated` | `call` |
| `unitlink-police:server:callUpdated` | `call, action` |
| `unitlink-police:server:callClosed` | `id, reason, by` |
| `unitlink-police:server:unitsChanged` | none |

Client: `unitlink-police:dutyChanged (onDuty, state)`.

## UnitLink network events

| Event | Direction | Purpose |
|---|---|---|
| `unitlink:server:req` | client → server | Every tablet action (`reqId, action, payload`). Each one is checked and rate-limited |
| `unitlink:client:res` | server → client | The reply (`reqId, ok, data`) |
| `unitlink:client:push` | server → client | Live updates: `board`, `note`, `callClosed`, `alertsChanged`, `signal100` |
| `unitlink:server:closed` | client → server | Tablet closed |

{% hint style="warning" %}
Don't trigger `unitlink:server:req` from other scripts. Use the UnitLink-Police exports instead. Every request is checked for on duty, CAD access and a loaded character.
{% endhint %}
