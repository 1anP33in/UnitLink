# Overview

UnitLink is laid out like a real dispatch console, the way Imperial-style CADs are:
* **Menu bar** along the top.
* **Blue toolbar** of tile buttons below it.
* **Quick-link bar** under the toolbar.
* **Main screen** in the middle.
* **Status bar** at the bottom: your status, active call, number of state returns, unit, Signal 100 and the clock.

## Toolbar

| Button | Opens |
|---|---|
| **Back / Previous** | Moves through the screens you've visited |
| **CAD** | The live board: [CAD Board](cad-board.md) |
| **Search** | Name search: [Name Search](name-search.md) |
| **Returns** | Every name you ran in the last 12 hours |
| **Forms** | Citations, arrests, reports, warrants: [Forms](forms.md) |
| **My Call** | Your attached call |
| **New Call** | A self-initiated call at your position |
| **Assign Self** | Attaches you to the selected call |
| **Alerts** | Warrants and BOLOs: [Alerts](alerts.md) |
| **Laws** | The Tropical State code: [Laws](laws-and-history.md) |
| **History** | The last 100 closed calls |
| **Signal 100** | Emergency radio traffic only: [Signal 100](signal-100-and-panic.md) |
| **Panic** | Sends the tsrp-police panic |

## Where the data comes from

| Data | Comes from |
|---|---|
| Calls, units, statuses, attaching, closing | **tsrp-police** (CAD exports). 911 calls show up in UnitLink live, and changes made in the CAD show up on the 911 cards. |
| People: name, date of birth, gender, nationality, height | **tsrp-core** (`SearchCharacters`, `GetCharacterById`) |
| Licenses and driver points | **tsrp-core** character metadata, key `licenses` |
| Notes, call history, records, warrants, BOLOs, returns | UnitLink's own `ul_*` MySQL tables |
| Notifications | **tsrp-ui** |
