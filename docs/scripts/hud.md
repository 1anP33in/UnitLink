# UnitLink-HUD

A standalone HUD with **no money anywhere**. It works with nothing else running.

**Folder:** `[UnitLink]/UnitLink-HUD`

## Job line follows duty

| When | Shows |
|---|---|
| Off duty | `CIV · Civilian · Jane Doe` (your `/civ` profile) |
| On duty | `SASP · Trooper · 1A-01` |
| Supervisor on duty | `SASP · Sergeant · 1S-01` |

- **Supervisor** means the ACE permission `unitlink.<dept>.supervisor`.
- **Titles and colors** are set in `Config.Jobs`.
- **When it updates:** as soon as you go on or off duty, or change department or callsign.

## Everything else

| Part | Shows |
|---|---|
| Status rings | Health, armor, stamina. Hunger and thirst are **off by default** (`Config.Needs.Enabled`) |
| Compass, street | Top center |
| Vehicle | Speed, fuel, gear, seatbelt (**B**), engine warning, lights, siren, turn signals (arrow keys) |
| Weapon, voice, clock | Bottom right. The voice range and radio channel come from pma-voice |

## Commands

| Command | Key | Does |
|---|---|---|
| `/hud` | | Size, minimap on foot, compass. Saved per player |
| `/togglehud` | F7 | Hide or show (cinematic) |
