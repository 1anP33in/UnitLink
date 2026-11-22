# UnitLink HUD

A standalone HUD for UnitLink servers. **There is no money anywhere in it**, and it needs no framework. Everything is set in `config.lua`.

## What it shows

| Area | Shows |
|---|---|
| **Top right** | Logo, server ID, **job line**, and status rings (health, armor, stamina, plus hunger and thirst if you turn them on) |
| **Top center** | Compass and street / area |
| **Bottom center** | Speedometer, fuel, gear, seatbelt, engine warning, lights, siren, turn signals (in vehicles) |
| **Bottom right** | Weapon and ammo, voice range and radio channel (pma-voice), in-game clock |

## The job line follows duty

| When | Job line |
|---|---|
| Off duty | `CIV · Civilian · Jane Doe` (the player's active `/civ` profile, from UnitLink-CAD) |
| On duty | `SASP · Trooper · 1A-01` |
| On duty as a supervisor | `SASP · Sergeant · 1S-01` |

- **Duty comes from UnitLink-Police.** The job line changes the moment someone goes on or off duty, or switches department or callsign.
- **Supervisor means the ACE permission** `unitlink.<dept>.supervisor`. Nothing is stored on characters.
- **Titles and colors per department** are set in `Config.Jobs`.

## Install

```cfg
ensure UnitLink-UI       # optional: notifications and the /hud dialog
ensure UnitLink-Police   # optional: duty job line
ensure UnitLink-CAD      # optional: civilian name when off duty
ensure UnitLink-HUD
```

## Commands

| Command | Default key | Does |
|---|---|---|
| `/hud` | | HUD settings: size, minimap on foot, compass. Saved per player |
| `/togglehud` | F7 | Hide or show the HUD (cinematic mode) |
| | B | Seatbelt |
| | ← → ↑ | Left / right turn signal, hazards (driver) |

## Hunger and thirst

They're **off by default**, because a server with no money usually has no food economy. Set `Config.Needs.Enabled = true` to turn them on. Values are saved per account on the server, with no database or framework needed. Food scripts can call:

```lua
exports['UnitLink-HUD']:AddHunger(source, 25)
exports['UnitLink-HUD']:AddThirst(source, 30)
```
