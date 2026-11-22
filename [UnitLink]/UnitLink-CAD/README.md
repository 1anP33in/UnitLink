# UnitLink CAD

UnitLink is an in-game CAD / MDT tablet for FiveM roleplay servers. It works like a real dispatch console: live calls and units, call records with notes, name searches with state returns, citations, arrests, reports, warrants, BOLOs, and a searchable code of laws.

> **Status:** built and checked offline. Every Lua file compiles with Lua 5.4. The JS parses. The full NUI was clicked through in a browser against a stand-in server: every screen and action, with no errors. It has **not been run on a live FXServer yet**, so go through the testing checklist below.

## How it fits together

| Data | Comes from |
|---|---|
| Calls, units, statuses, attaching, closing | **UnitLink-Police** (new CAD exports). 911 calls show up in UnitLink live, and CAD changes show up on the 911 cards. |
| People: name, date of birth, gender, nationality, height | **Civilian profiles** made with `/civ` (standalone), or **UnitLink-Core** characters if it's running (`Config.Identity = 'auto'`) |
| Licenses and driver points | On the civilian profile, or UnitLink-Core metadata key `licenses` |
| Notes, call history, records, warrants, BOLOs, returns | UnitLink's own `ul_*` MySQL tables |
| Notifications | **UnitLink-UI** |

## Install

1. Put `UnitLink-CAD` in your resources, e.g. `resources/[UnitLink]/UnitLink-CAD`.
2. Use the **UnitLink-Police** from this project. UnitLink needs its CAD exports (see "Changes to other resources"). UnitLink-Core is optional.
3. In `server.cfg`, after everything it depends on:

```cfg
ensure oxmysql
ensure UnitLink-UI
ensure UnitLink-Police
ensure UnitLink-CAD
```

4. Start the server. The `ul_` tables are created automatically (`Config.AutoInstallSql`), or you can run `sql/install.sql` yourself.

## Using it

- **Open:** `/cad` or **F5** (rebindable under Settings → Key Bindings → FiveM).
- **Close:** **Esc** or **✕ Close**.
- **Who can open it:** only on-duty units whose department type receives 911 (LEO by default, via `Config.AccessFlag`).
- **While it's open:** you hold a tablet, and going off duty closes it.

| Screen | What it does |
|---|---|
| **CAD** | Active calls and units, color-coded by status (green available, yellow en route, pink on scene, orange busy, red unavailable, cyan other departments). Change your own status right in the grid or in the status bar. Double-click a call to open it. |
| **Call record** | Nature, priority (editable), address, city, county, caller and units. Buttons for Assign Self / ENRT / ARRVD / Clear Self, GPS, and close. Tabs: **Notes** (live, timestamped, with system entries for attaches, status and edits), **Info**, **State Returns** run on the call, and **Address History** (closed calls within 60 m). |
| **New Call** | Self-initiated call at your position. You're attached automatically and no popup goes to other units. |
| **Civilian ID (`/civ`)** | Anyone. Create up to 5 civilian profiles and pick who you are playing. Officers find these in Search. |
| **Search → State Return** | Name or character ID. The return shows licenses and points, active warrants (red WANTED banner), alerts, and history. Buttons go straight to Citation / Arrest / Report / Warrant / Add Alert. |
| **Returns** | Every name you ran in the last 12 hours. |
| **Forms** | Citation, Arrest Report, Incident Report, Warrant Request. Charges come from the code list (searchable by code, name or abbreviation like "dui"). Click any of your records to read it back. |
| **Alerts** | Warrants waiting for approval (supervisors), active warrants (mark served), and BOLOs (add or remove). |
| **Laws** | The San Andreas Penal Code from `config.lua`. |
| **History** | The last 100 closed calls. Click one to read it. |
| **Signal 100** | Supervisors only (configurable). Shown on every open tablet, and every on-duty unit gets a notification. |
| **Panic** | Sends the UnitLink-Police panic. |

## Rules enforced on the server

- **Every request is checked again:** on duty, CAD access, and a rate limit (`Config.RateLimitMs`). Department and supervisor access are **ACE permissions** (see `aceperms.md` at the repo root).
- **Supervisors are checked by unitlink-police:** `unitlink.<dept>.supervisor` or `unitlink.police.supervisor`.
- **Citations:**
  - They can't contain felonies.
  - Their points are added to the subject's driver license.
  - A license is suspended at `Config.Licenses.suspendAt` points (12).
  - **Fines are on record only:** each charge has a fine, shown on the citation and the state return. **No money is taken**, and the fine expires after `Config.Fines.expireDays` (7).
- **Warrants:** they need a probable cause of at least 20 characters. Officers' warrants wait for supervisor approval (`Config.WarrantsNeedApproval`). Supervisors' warrants go active right away.
- **Arrest and incident reports:** need a narrative of at least 20 characters.
- **Text from players:** cleaned and length-capped. All SQL is parameterized.
- **Nothing private is sent to the tablet:** no account identifiers, only what the CAD shows.

## Licenses

Licenses are stored on the civilian profile (standalone) or in UnitLink-Core character metadata, key `licenses`, with the same shape:

```lua
licenses = {
    drivers = { status = 'valid', points = 0 },  -- valid | suspended | revoked | expired | none
    firearm = { status = 'none' },
    pilot   = { status = 'none' },
}
```

People without licenses use `Config.Licenses.defaults` (driver's license valid, others none). A future DMV or license script only has to write this key.

## Changes to other resources

| Resource | Change |
|---|---|
| **UnitLink-Police** | New **On Scene** status. Calls now have `nature`, `priority` and `origin`. New server exports `GetCalls`, `GetCall`, `CreateCall`, `UpdateCall`, `AssignUnit`, `UnassignUnit`, `CloseCall`, `GetUnits`, `SetUnitStatus`, `IsSupervisor`. New local events `unitlink-police:server:callCreated / callUpdated / callClosed / unitsChanged`. The 911 flow and the cards haven't changed. |
| **UnitLink-Core** | New read-only exports `SearchCharacters(query, limit)` and `GetCharacterById(id)`. They never return account identifiers. All 262 UnitLink-Core tests still pass. |

## Preview

The browser preview isn't part of this resource or the GitHub repo. It lives on the dev PC in `D:\Fivem Server\Development\Fivem-uis and menus\unitlink-preview\`. It runs this real tablet against a stand-in server (`tools/mock.js`) with sample data. After changing anything in `html/` or the laws in `config.lua`, rebuild it:

```bash
python tools/build_preview.py
```

(Needs `pip install lupa`. The game doesn't load the preview.)

The preview also has **mockups** of what UnitLink could grow into. None of these are in the Lua yet:

- **SAFR (Fire & Rescue) CAD:** incidents, apparatus, patients, patient care reports (PCRs), Mayday, mutual aid and station management.
- **DOT work orders:** jobs, fleet, equipment, road closures and road alerts.
- **Civilian portal:** dashboard, 911 with live tracking, records, applications and service requests.
- **Admin dashboard:** departments, sub-departments, ranks and permissions, employees, system settings and audit history.
- **Shared tools:** global search, unit messaging, BOLOs, incident linking, activity log and employee profiles.

Every screen uses this tablet's style. Switch between them with the box in the menu bar.

## Logos

These are in the preview's `logos/` folder on the dev PC (SVG, with transparent PNGs in `logos/png/`):

- `unitlink-icon` and `unitlink-logo`: the UnitLink app icon, and the icon with the name written beside it.
- `sadoj-seal`: the San Andreas Department of Justice seal.

To render the PNGs again after editing an SVG, run `python logos/build_logos.py` (needs Microsoft Edge).

## Testing checklist

1. Off duty: `/cad` says you must be on duty. A SAFR unit gets the SAFR Fire & Rescue CAD instead of the police CAD.
2. On duty as SASP: `/cad` opens, you hold a tablet, and your unit shows as AVAIL.
3. A civilian does `/911 test`. The call appears on the CAD board within a second, with a "911 CALL RECEIVED" note.
4. Accept with **Y** (UnitLink-Police card). The CAD shows you attached and ENRT, with a system note.
5. In the CAD: ARRVD. The status turns pink and a note is added. Change the priority, and the note and the 911 card both update.
6. A second officer adds a note, and it appears live on your open call.
7. New Call (traffic stop). It's created at your location, you're attached, and other units get no popup.
8. Close the call. It goes to History, the units go back to AVAIL, and it's read-only when reopened.
9. Make a civilian profile with `/civ`. Search it by name and by ID, and run the return.
10. A citation with a felony is refused. A citation for speeding adds points. At 12+ points the license shows SUSPENDED.
11. A warrant from a non-supervisor is pending, and supervisors get a notification. A supervisor approves it, the subject shows WANTED, then "Mark Served".
12. Add a BOLO. Every on-duty unit is notified. Remove it.
13. Signal 100 from a supervisor shows on every tablet. A non-supervisor can't set it.
14. Go off duty with the tablet open. It closes.
15. `restart UnitLink-CAD` with the tablet open. Control comes back and the prop is removed.
