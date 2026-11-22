# Citations & License Points

{% hint style="success" %}
**Tropical State RP has no fines.** Citations add **points** to the driver's license instead.
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

## Points per charge (default)

| Code | Offense | Points |
|---|---|---|
| 2-01 | Speeding (25+ over) | 3 |
| 2-02 | Speeding (1-24 over) | 2 |
| 2-03 | Running a Red Light | 2 |
| 2-04 | Failure to Stop | 1 |
| 2-05 | Illegal U-Turn | 1 |
| 2-06 | No Seatbelt | 1 |
| 2-07 | Reckless Driving | 4 |
| 2-08 | Driving Under the Influence | 6 |
| 2-09 | Driving Without a License | 3 |
| 2-10 | Hit and Run (felony, arrest only) | 6 |
| 2-11 | Driving on a Suspended License | 4 |
| 2-12 | Unroadworthy Vehicle | 1 |

## Where licenses are stored

In tsrp-core character metadata, under the key `licenses`:

```lua
licenses = {
    drivers = { status = 'valid', points = 0 },  -- valid | suspended | revoked | expired | none
    firearm = { status = 'none' },
    pilot   = { status = 'none' },
}
```

Characters that don't have this key use `Config.Licenses.defaults`: driver's license valid, the others none. A future DMV or license script only has to write this key.
