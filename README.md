# UnitLink CAD · Tropical State RP

UnitLink is the in-game CAD / MDT tablet for **Tropical State RP**, together with the TSRP scripts it needs. This repo mirrors the server's `resources` folder, so every script sits in the same category folder it uses on the server.

> **Status:** built and checked offline. The Lua compiles, the NUI was clicked through in a browser, and tsrp-core's 262 tests pass. It has **not been run on a live FXServer yet.** See the testing checklist in [the UnitLink README](<[Tropical_PoliceScripts]/unitlink/README.md>).

## Scripts

| Resource | Folder | What it does for UnitLink |
|---|---|---|
| **unitlink** | `[Tropical_PoliceScripts]/unitlink` | The CAD / MDT tablet (`/cad` or F5) |
| **tsrp-police** | `[Tropical_PoliceScripts]/tsrp-police` | Calls, units, statuses, attaching and closing calls (CAD exports). 911 calls show up in UnitLink live, and changes made in the CAD show up on the 911 cards |
| **tsrp-core** | `[Tropical_Permissions]/tsrp-core` | People (name, date of birth, gender, nationality, height) through `SearchCharacters` / `GetCharacterById`. Licenses and driver points come from character metadata, key `licenses` |
| **tsrp-ui** | `[Tropical_Menus]/tsrp-ui` | Notifications |

Notes, call history, records, warrants, BOLOs and state returns are kept in UnitLink's own `ul_*` MySQL tables, through **oxmysql**. oxmysql isn't in this repo; get it from its official release.

Each resource has its own README with the full details. The full documentation, ready to import into GitBook, is in [`docs/`](docs).

## Download

This repo is **private**. Your GitHub account needs access to it, and Git needs to be signed in. The easiest way to sign in is the GitHub CLI (`gh auth login`); a personal access token also works when Git asks for a password.

**Option A: git clone (recommended, easy to update)**

```bash
git clone https://github.com/1anP33in/tsrp-unitlink-cad.git
```

This creates a `tsrp-unitlink-cad` folder holding the `[Category]` folders. Copy those into your server's `resources` folder.

To get the newest version later:

```bash
cd tsrp-unitlink-cad
git pull
```

Then copy the folders over again.

**Option B: clone straight into a new server's resources folder**

For a fresh server that has no `resources` folder yet, run this from the server's base folder (the one that holds `server.cfg`):

```bash
git clone https://github.com/1anP33in/tsrp-unitlink-cad.git resources
```

After that, `git pull` inside `resources` updates the scripts in place. The repo's `.gitignore` only tracks these scripts, so any other resources you add aren't affected.

**Option C: ZIP download**

On GitHub, click **Code → Download ZIP**, extract it, and copy the `[Category]` folders into `resources`.

## Install

1. Put the folders in your server's `resources` folder, keeping the `[Category]` folders (see **Download**).
2. In `server.cfg`, in this order:

```cfg
ensure oxmysql
ensure tsrp-core
ensure tsrp-ui
ensure tsrp-police
ensure unitlink
```

3. Secrets go **only in `server.cfg`**, never in these files:

```cfg
set mysql_connection_string "mysql://user:password@localhost/tsrp?charset=utf8mb4"
set tsrp_discord_token "YOUR_BOT_TOKEN"                                   # tsrp-core Discord role sync
set tsrp_core_log_webhook "https://discord.com/api/webhooks/..."          # tsrp-core audit log (optional)
```

4. Optional: tsrp-police's webhook URLs go in `tsrp-police/config/webhooks.lua`. They're blank in this repo, so keep real ones out of commits.
5. Start the server. The database tables are created automatically.

## UnitLink at a glance

- **Who can use it:** only on-duty units whose department receives 911 (LEO by default).
- **Screens:**
  - **CAD:** live board of calls and units, color-coded by status.
  - **Call records:** live notes, ENRT/ARRVD, GPS and address history.
  - **New Call:** a self-initiated call at your position.
  - **Name search:** state returns showing licenses, driver points, warrants and alerts.
  - **Forms:** citations, arrest reports, incident reports and warrant requests.
  - **Alerts:** warrant approvals, active warrants and BOLOs.
  - **Laws:** the searchable Tropical State code.
  - **History:** the last 100 closed calls.
  - **Signal 100 and Panic.**
- **Rules the server enforces:**
  - Citations carry **points and no fines**, and a license is **suspended at 12 points**.
  - Felonies must be filed as an arrest report.
  - **Warrants need a supervisor's approval.**
  - Narratives need at least 20 characters.
  - Every request is checked again on the server and rate-limited.

## Future

These are designed and working as **browser preview mockups only**. None of them are in the Lua yet. Every one uses the same look as the Police CAD: blue toolbar of tile buttons, gray panels, data tables and blue status bar.

### SAFR: Fire & Rescue CAD
- **Board:** live incidents and apparatus. Unit statuses are Available, En Route, On Scene, Transporting, At Hospital, Busy and Out of Service.
- **Incident records:** call type (Medical, Fire, Rescue, MVC, Hazmat), priority, caller, apparatus and personnel, patient count and timestamped notes.
- **Patient records:** injury, severity, treatment, where they were taken, condition, and each person's medical history.
- **Reports:** Patient Care Report, Fire Incident, Rescue, Vehicle Collision, Hazmat and Hospital Transport.
- **Alerts:** medical, fire and rescue calls, mutual aid requests, **Mayday** and station announcements.
- **Management:** stations, apparatus, callsigns, ranks, certifications and personnel roster.

### DOT: Work Orders
- **Board:** live DOT units and work orders, with filters for roadside, traffic control, vehicle recovery, maintenance and construction.
- **Work orders:** number, job type, description, priority, location, assigned crew, required equipment, status and completion notes.
- **Fleet & Equipment:** vehicles assigned to employees (tow, service and maintenance trucks), equipment checkout and return, and maintenance records.
- **Reports:** road hazard, vehicle recovery, road closure request (supervisor approval), road inspection, maintenance completion and equipment damage.
- **Road alerts:** closures, major highway hazards, traffic control requests, emergency roadside requests and active construction zones.

### Civilian Portal
- **Dashboard:** profile, driver's / firearm / pilot licenses, vehicles, warrants, citations, arrests and medical history.
- **911:** choose Police, Fire, Medical or DOT. The caller's details are attached automatically, and the call goes to the right department's board. The caller can follow its status live and see updates from dispatch.
- **Records:** citations, arrests, warrants, licenses, vehicles, businesses and service requests.
- **Applications:** driver's, firearm and pilot licenses, business registration, vehicle registration and renewals, with automatic checks (for example, a firearm license is denied while the person has an active warrant).
- **Service requests:** roadside assistance, road hazards, non-emergency help and public works.

### Central Admin Dashboard
- **Departments:** create, edit and delete departments; logo, abbreviation and color; turn them on or off; choose which call types each one receives; CAD access and visibility.
- **Sub-departments:** each has its own ranks, permissions, callsign format, unit statuses and members.
- **Ranks & permissions:** rank order and a grid of permissions per rank (supervisor, approve warrants, Signal 100, announcements, roster, records, medical access, closing calls).
- **Employees:** search, create accounts, put one person in several departments, set ranks and callsigns, suspend, remove access, and see their activity.
- **System config:** call types, priorities, unit statuses, citation points, license point limits, report rules, notifications, and which departments can see which records.
- **Audit history:** every admin change.

### Shared across all departments
Global search (people, vehicles, calls, reports), live notifications, unit messaging, activity logs, shared or department-only BOLOs, linking one incident across several departments, GPS to calls and work orders, employee profiles, audit history, and a permission system based on rank and department.

New departments planned for these mockups include the **San Andreas Department of Justice** (District Attorney's Office and Superior Court).
