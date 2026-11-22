# SAFR Overview

The **SAFR (San Andreas Fire & Rescue) CAD** is UnitLink's fire and EMS tablet. It looks and works like the police CAD: the same toolbar, grid tables, dark panels and blue status bar.

| Action | How |
|---|---|
| Open | `/cad` or **F5** while on duty as **SAFR** (`/duty`). Police get the police CAD, SAFR gets this one |
| Close | **Esc** or **✕ Close** |
| Who can go on duty | ACE `unitlink.safr.duty`. Supervisors need `unitlink.safr.supervisor`. See [ACE Permissions](../getting-started/ace-permissions.md) |

## Toolbar

| Button | Opens |
|---|---|
| **CAD** | The live board: active incidents and SAFR units |
| **My Incident** | The incident you're attached to |
| **Patients** | Patient records and medical history. See [Incidents & Patients](incidents-and-patients.md) |
| **Reports** | The 6 SAFR reports. See [Reports](reports.md) |
| **Alerts** | Medical, fire and rescue calls, mutual aid, announcements, MAYDAY. See [Alerts & MAYDAY](alerts-and-mayday.md) |
| **Station Mgmt** | Stations and apparatus. See [Station Management](station-management.md) |
| **History** | The last 100 closed incidents |
| **New Incident** | A self-initiated incident at your position |
| **Assign Self** | Attaches you to the selected incident |
| **Announce** | Station-wide announcement (supervisors) |
| **Mayday** | Firefighter down. Every on-duty unit is alerted |

## The board

**Active Incidents:** incident number, type, nature, location, city, priority, status (PENDING / DISPATCHED / ON SCENE), units, patient count and age.

* Filter by type with the chips: Medical, Fire, Rescue, MVC, Hazmat.
* **Double-click** an incident to open it.

**SAFR Units:** callsign, name, apparatus, station, status, incident and location.

| Status | Color | Notes |
|---|---|---|
| **AVAIL** Available | green | |
| **ENRT** En Route | yellow | Only while attached to an incident |
| **ONSCN** On Scene | pink | Only while attached |
| **TRANS** Transporting | purple | Only while attached |
| **ATHSP** At Hospital | cyan | Only while attached |
| **BUSY** Busy | orange | |
| **OOS** Out of Service | red | |

Change your status in your own row or in the status bar. The status bar also has **Apparatus**, where you pick the engine, medic or ladder you're riding on.

## How civilians call SAFR

| Command | Creates |
|---|---|
| `/911ems <what happened>` | A **MEDICAL** incident (MEDICAL EMERGENCY, priority 2) |
| `/911fire <what is burning>` | A **FIRE** incident (REPORTED FIRE, priority 1) |

* **Where the call goes:** it's created at the caller's position, with their `/civ` name.
* **Who is alerted:** every on-duty SAFR unit gets a red **SAFR dispatch card** (UnitLink-UI).
* **If nobody is on duty:** the caller is told so, and the call is still logged.
* **Spam limit:** one call per player every 60 seconds (`Config.Fire.callCooldown`).
