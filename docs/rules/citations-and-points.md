# Citations & License Points

{% hint style="success" %}
**No money is ever taken.** Citations add **points** to the driver's license. Each charge also has a **fine**, but the fine is only written on the record and **expires** after a set time (7 days by default). Nothing is charged to anyone.
{% endhint %}

## How it works

1. An officer files a **citation** with one or more charges.
2. The points for each charge (from the laws in `config.lua`) are added to the subject's driver's license.
3. At **12 points** (`Config.Licenses.suspendAt`), a valid license becomes **SUSPENDED**.
4. State returns show the points in red once they reach 75% of the limit (9 of 12).

## Rules

* **No felonies on a citation.** A felony charge must go on an arrest report.
* A citation needs **at least one charge**.
* Points are added on the server, so the tablet can't fake them.

## Fines

| Setting | Default | Meaning |
|---|---|---|
| `Config.Fines.enabled` | `true` | Show fines on citations |
| `Config.Fines.expireDays` | `7` | Days a fine stays **OUTSTANDING** before it shows as **EXPIRED** |
| `Config.Fines.symbol` | `$` | Currency symbol shown |

- **Citation form:** shows the fine total as you add charges.
- **After filing:** the officer sees, for example, "Fine $750 on record, expires in 7 days."
- **State return:** a **FINES** section lists each fine as OUTSTANDING (with its expiry date) or EXPIRED.
- **Felonies** have no fine, because they're arrest-only.

## Points and fines per charge (default)

| Code | Offense | Points | Fine |
|---|---|---|---|
| 2-01 | Speeding (25+ over) | 3 | $750 |
| 2-02 | Speeding (1-24 over) | 2 | $250 |
| 2-03 | Running a Red Light | 2 | $200 |
| 2-04 | Failure to Stop | 1 | $150 |
| 2-05 | Illegal U-Turn | 1 | $100 |
| 2-06 | No Seatbelt | 1 | $100 |
| 2-07 | Reckless Driving | 4 | $1,000 |
| 2-08 | Driving Under the Influence | 6 | $1,500 |
| 2-09 | Driving Without a License | 3 | $500 |
| 2-10 | Hit and Run (felony, arrest only) | 6 | none |
| 2-11 | Driving on a Suspended License | 4 | $1,000 |
| 2-12 | Unroadworthy Vehicle | 1 | $150 |

## Where licenses are stored

On the person's **civilian profile** (standalone, see [Civilian Portal](../unitlink/civilian-portal.md)), or in UnitLink-Core character metadata under the key `licenses` if you run UnitLink-Core. Same shape either way:

```lua
licenses = {
    drivers = { status = 'valid', points = 0 },  -- valid | suspended | revoked | expired | none
    firearm = { status = 'none' },
    pilot   = { status = 'none' },
}
```

Characters that don't have this key use `Config.Licenses.defaults`: driver's license valid, the others none. A future DMV or license script only has to write this key.
