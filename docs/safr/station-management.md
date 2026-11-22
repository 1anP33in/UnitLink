# Station Management

Click **Station Mgmt** on the toolbar. Everyone can see it, but only **supervisors** (`unitlink.safr.supervisor`) can edit.

| Tab | Shows | Supervisors can |
|---|---|---|
| **Personnel Roster** | Everyone who has used the SAFR CAD: callsign, on or off duty, status, apparatus, certifications, last seen | Edit certifications |
| **Fire Stations** | Each station, its apparatus, and how many units are on duty there | |
| **Apparatus & Vehicles** | Every apparatus: type, station, crew, status | Put it **out of service** or return it. An out-of-service apparatus can't be picked |
| **Certifications** | A grid of members against FF I, FF II, EMT, Paramedic, Driver/Operator, Hazmat Ops and Rescue Tech | Click a cell to grant or remove |

{% hint style="info" %}
Who can go on duty as SAFR, and who is a supervisor, comes from **ACE permissions** in `server.cfg`, not from this screen. Stations, apparatus and the certification list are set in `config.lua` (`Config.Fire`).
{% endhint %}
