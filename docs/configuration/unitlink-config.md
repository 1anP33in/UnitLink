# UnitLink Config

All settings are in `[UnitLink]/UnitLink-CAD/config.lua`.

## General

| Setting | Default | What it does |
|---|---|---|
| `Config.Name` | `'UnitLink'` | The name shown on the tablet |
| `Config.Command` | `'cad'` | Chat command that opens it |
| `Config.Key` | `'F5'` | Default key (players can rebind it) |
| `Config.TabletAnimation` | `true` | Hold a tablet while it's open |
| `Config.AutoInstallSql` | `true` | Create the `ul_*` tables on start |
| `Config.RateLimitMs` | `250` | Minimum time between requests from one player |
| `Config.AccessFlag` | `'receives911'` | The UnitLink-Police department flag needed to open it |

## Unit statuses

Each CAD code is mapped to a UnitLink-Police status:

| Code | UnitLink-Police status | Notes |
|---|---|---|
| `AVAIL` | `available` | |
| `ENRT` | `responding` | Only while on a call |
| `ARRVD` | `onscene` | Only while on a call |
| `BUSY` | `busy` | |
| `UNAV` | `unavailable` | |

## Lists

| Setting | Used for |
|---|---|
| `Config.Natures` | Call nature dropdown |
| `Config.ReportTypes` | Incident report types |
| `Config.Bookings` | Where people are booked on arrest reports |
| `Config.WarrantTypes` | Arrest, Search, Bench |
| `Config.AlertTypes` | BOLO, Caution, Armed & Dangerous… |

## Rules

| Setting | Default | What it does |
|---|---|---|
| `Config.Licenses.metadataKey` | `'licenses'` | The UnitLink-Core metadata key licenses are stored under |
| `Config.Licenses.defaults` | drivers valid, others none | Used for characters with no licenses stored |
| `Config.Licenses.suspendAt` | `12` | Points that suspend a driver's license |
| `Config.WarrantsNeedApproval` | `true` | Officers' warrants wait for a supervisor |
| `Config.Signal100SupervisorOnly` | `true` | Only supervisors can set Signal 100 |

After editing, run `ensure UnitLink-CAD` (or restart the server).
