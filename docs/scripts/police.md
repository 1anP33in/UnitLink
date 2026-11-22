# UnitLink-Police

Duty, units, 911 calls, panic and blips. It's also where UnitLink gets its calls and units.

**Folder:** `[UnitLink]/UnitLink-Police`

## Commands and keys

| Command | Default key | Does |
|---|---|---|
| `/duty` | F6 | Duty menu: department, callsign, status, hours |
| `/duty on <dept> <callsign>` / `/duty off` | | Go on or off duty without the menu |
| `/police` | | Live roster |
| `/calls` | | Active 911 calls |
| `/911 <message>` | | Call emergency services (anyone) |
| `/panic` | | Officer panic |
| | Y / J / U | Accept call / deny call / waypoint |

## How 911 reaches UnitLink

1. A civilian types `/911 ...`.
2. Every on-duty unit gets a 911 card, and the call appears on the UnitLink board with a "911 CALL RECEIVED" note.
3. Accepting the card attaches the unit (status ENRT). Changes made in UnitLink (status, priority) update the card.
4. Calls expire after 20 minutes if nobody closes them.

## CAD exports (added for UnitLink)

`GetCalls`, `GetCall`, `CreateCall`, `UpdateCall`, `AssignUnit`, `UnassignUnit`, `CloseCall`, `GetUnits`, `SetUnitStatus`, `IsSupervisor`. See [Exports & Events](../developers/exports-and-events.md).

## Webhooks

`config/webhooks.lua` (server only). Every URL is blank in the repo.
