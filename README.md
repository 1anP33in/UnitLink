# UnitLink CAD / MDT

UnitLink is an in-game CAD / MDT tablet for FiveM roleplay servers, together with the UnitLink scripts it needs. This repo mirrors the server's `resources` folder, so every script sits in the same category folder it uses on the server.

> **Status:** built and checked offline. The Lua compiles, every tablet was clicked through in a browser against the real server code, and the server logic passed its tests against a test database. It has **not been run on a live FXServer yet.** See the testing checklist in [the UnitLink README](<[UnitLink]/UnitLink-CAD/README.md>).

## Scripts

| Resource | Folder | What it does for UnitLink |
|---|---|---|
| **UnitLink-CAD** | `[UnitLink]/UnitLink-CAD` | The CAD / MDT tablets (`/cad` or F5): the **police CAD**, the **SAFR Fire & Rescue CAD** and **DOT Work Orders**, each with **Shared Tools**. Also the **Civilian Portal** (`/civ`), the **Admin Dashboard** (`/cadadmin`), and `/911fire`, `/911ems` |
| **UnitLink-Police** | `[UnitLink]/UnitLink-Police` | Calls, units, statuses, attaching and closing calls (CAD exports). 911 calls show up in UnitLink live, and changes made in the CAD show up on the 911 cards |
| **UnitLink-Core** *(optional)* | `[UnitLink]/UnitLink-Core` | Character framework. Only needed if you want UnitLink-Core characters; without it, UnitLink is fully standalone |
| **UnitLink-UI** | `[UnitLink]/UnitLink-UI` | Notifications |
| **UnitLink-HUD** | `[UnitLink]/UnitLink-HUD` | Standalone HUD with **no money**. The job line changes when you go on duty |

**Standalone by default:** no framework and no money. People are **civilian profiles** that players make with `/civ`, and permissions are **FiveM ACE only**, on the account and never on characters (see [`aceperms.md`](aceperms.md)). Notes, call history, records, warrants, BOLOs, returns and civilian profiles are kept in UnitLink's own `ul_*` MySQL tables, through **oxmysql**. oxmysql isn't in this repo; get it from its official release.

Each resource has its own README with the full details. The full documentation, ready to import into GitBook, is in [`docs/`](docs).

## Download

This repo is **private**. Your GitHub account needs access to it, and Git needs to be signed in. The easiest way to sign in is the GitHub CLI (`gh auth login`); a personal access token also works when Git asks for a password.

**Option A: git clone (recommended, easy to update)**

```bash
git clone https://github.com/1anP33in/UnitLink.git
```

This creates a `UnitLink` folder holding the `[UnitLink]` folder. Copy that into your server's `resources` folder.

To get the newest version later:

```bash
cd UnitLink
git pull
```

Then copy the folders over again.

**Option B: clone straight into a new server's resources folder**

For a fresh server that has no `resources` folder yet, run this from the server's base folder (the one that holds `server.cfg`):

```bash
git clone https://github.com/1anP33in/UnitLink.git resources
```

After that, `git pull` inside `resources` updates the scripts in place. The repo's `.gitignore` only tracks these scripts, so any other resources you add aren't affected.

**Option C: ZIP download**

On GitHub, click **Code → Download ZIP**, extract it, and copy the `[UnitLink]` folder into `resources`.

## Install

1. Put the folders in your server's `resources` folder, keeping the `[UnitLink]` folder (see **Download**).
2. In `server.cfg`, in this order:

```cfg
ensure oxmysql
ensure UnitLink-UI
ensure UnitLink-Police
ensure UnitLink-CAD
ensure UnitLink-HUD
# ensure UnitLink-Core   (optional, after oxmysql, only if you want its characters)
```

3. Secrets go **only in `server.cfg`**, never in these files:

```cfg
set mysql_connection_string "mysql://user:password@localhost/unitlink?charset=utf8mb4"
set unitlink_discord_token "YOUR_BOT_TOKEN"                                   # UnitLink-Core Discord role sync
set unitlink_core_log_webhook "https://discord.com/api/webhooks/..."          # UnitLink-Core audit log (optional)
```

4. Optional: UnitLink-Police's webhook URLs go in `UnitLink-Police/config/webhooks.lua`. They're blank in this repo, so keep real ones out of commits.
5. Start the server. The database tables are created automatically.
6. Give officers access with ACE permissions: follow the examples in [`aceperms.md`](aceperms.md) and add each officer's license. Civilians make their profile in game with `/civ`.

## UnitLink at a glance

- **Who can use it:** only on-duty units whose department receives 911 (LEO by default).
- **Screens:**
  - **CAD:** live board of calls and units, color-coded by status.
  - **Call records:** live notes, ENRT/ARRVD, GPS and address history.
  - **New Call:** a self-initiated call at your position.
  - **Name search:** state returns showing licenses, driver points, warrants and alerts.
  - **Forms:** citations, arrest reports, incident reports and warrant requests.
  - **Alerts:** warrant approvals, active warrants and BOLOs.
  - **Laws:** the searchable San Andreas Penal Code.
  - **History:** the last 100 closed calls.
  - **Signal 100 and Panic.**
- **Rules the server enforces:**
  - Citations carry **points**, and a license is **suspended at 12 points**. Fines are **written on the record only**: no money is ever taken, and they expire after 7 days.
  - Felonies must be filed as an arrest report.
  - **Warrants need a supervisor's approval.**
  - Narratives need at least 20 characters.
  - Every request is checked again on the server and rate-limited.

## Departments and dashboards

Every screen uses the same look as the Police CAD: blue toolbar of tile buttons, gray panels, data tables and blue status bar.

### SAFR: Fire & Rescue CAD
- **Board:** live incidents and apparatus. Unit statuses are Available, En Route, On Scene, Transporting, At Hospital, Busy and Out of Service.
- **Incidents and patients:** call type, priority, caller, apparatus, patient records and each person's medical history.
- **Reports, alerts, MAYDAY, mutual aid, station management** (stations, apparatus out of service).

### DOT: Work Orders
- **Job board** with filters, **work orders** (WO-5001 and up) with equipment, crew, status and completion notes.
- **Fleet & equipment:** vehicles, equipment checkout and return, maintenance records.
- **Reports:** road hazard, vehicle recovery, road closure request (supervisor approval), road inspection, maintenance completion, equipment damage.
- **Road alerts:** closures, highway hazards, traffic control, roadside requests, construction zones, announcements.

### Civilian Portal (`/civ`)
- **Dashboard:** ID, licenses and points, warrants, fines (records only, they expire), citations, arrests, vehicles, medical history.
- **911** to Police, Fire or Ambulance with **call tracking**, and **service requests** that become DOT work orders.
- **Vehicles** (report stolen posts a shared BOLO), **businesses** and **applications** for licenses, registrations and business licenses.

### Admin Dashboard (`/cadadmin`, ACE `unitlink.admin`)
- Overview, departments and permissions (**read only**), the applications queue, civilian licenses and vehicles, **laws & fines**, settings, activity and an **audit log** of every change.

### Shared Tools (every department tablet)
Global search, messages to all units / a department / one unit, shared BOLOs, incident links across departments, and activity logs.

## Ideas for later

The **San Andreas Department of Justice** (District Attorney's Office and Superior Court), named ranks, and license renewals.
