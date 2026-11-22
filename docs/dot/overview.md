# DOT Overview

The **DOT (Department of Transportation) tablet** handles work orders, roadside requests, the fleet and road closures. It looks and works like the police CAD.

| Action | How |
|---|---|
| Open | `/cad` or **F5** while on duty as **DOT** (`/duty`) |
| Close | **Esc** or **✕ Close** |
| Who can go on duty | ACE `unitlink.dot.duty`. Supervisors need `unitlink.dot.supervisor`. See [ACE Permissions](../getting-started/ace-permissions.md) |

## Toolbar

| Button | Opens |
|---|---|
| **Job Board** | Open work orders and DOT units, with filter chips (Roadside, Traffic control, Recovery, Maintenance, Construction) |
| **My Job** | The work order you're attached to |
| **Fleet & Equip** | Vehicles, equipment inventory, maintenance records. See [Fleet & Road Alerts](fleet-and-road-alerts.md) |
| **Reports** | The 6 DOT reports |
| **Road Alerts** | Closures, highway hazards, traffic control, roadside requests, construction zones, announcements |
| **History** | The last 100 completed work orders |
| **New Job** | A self-initiated work order at your position |
| **Assign Self** | Attaches you to the selected work order |
| **Tools** | The [Shared Tools](../unitlink/shared-tools.md) window |
| **Announce** | Department announcement (supervisors) |

The status bar holds your **unit status** (AVAIL, ENRT, ONSCN, WORK, BUSY, UNAV) and the **vehicle** you're driving.

## Work orders

Numbers start at **WO-5001**. A work order has a category, description, priority (1 to 3), location, who requested it, required equipment, assigned crew, job status (OPEN, ASSIGNED, IN PROGRESS, ON HOLD) and completion notes.

* Attaching sets the job to **ASSIGNED**. Setting your status to **WORK** sets it to **IN PROGRESS**.
* Tabs: **Activity** (timestamped notes), **Completion**, **Info**, **Location History** (earlier jobs within 60 m).
* **Completing** needs completion notes of at least 20 characters (`Config.Dot.minNarrative`). Only units on the job or a supervisor can complete it.
* Where work orders come from: **CAD** (self-initiated), **civilian service requests** from the [Civilian Portal](../unitlink/civilian-portal.md), or **other resources** with the `CreateWorkOrder` export.

## Reports

| Report | Number | What happens |
|---|---|---|
| Road Hazard | `RHZ-` | A **HIGH** severity hazard is broadcast to every on-duty unit |
| Vehicle Recovery | `VRR-` | Filed on the work order |
| Road Closure Request | `RCR-` | A supervisor's closure is **ACTIVE** at once; anyone else's waits as **REQUESTED** until a supervisor approves it |
| Road Inspection | `RIN-` | Filed |
| Maintenance Completion | `MCR-` | Filed |
| Equipment Damage | `EDR-` | "Not serviceable" takes the vehicle **out of service** and opens a maintenance record |

Everything is set in `UnitLink-CAD/config.lua` under `Config.Dot`: categories, filters, statuses, dispositions, fleet, equipment, closure reasons and the report forms.
