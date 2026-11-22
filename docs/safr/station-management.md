# Station Management

Click **Station Mgmt** on the toolbar. Everyone can see it, but only **supervisors** (`unitlink.safr.supervisor`) can edit.

| Tab | Shows | Supervisors can |
|---|---|---|
| **Fire Stations** | Each station, its apparatus, and how many units are on duty there | |
| **Apparatus & Vehicles** | Every apparatus: type, station, crew, status | Put it **out of service** or return it. An out-of-service apparatus can't be picked |

{% hint style="info" %}
Who can go on duty as SAFR, and who is a supervisor, comes from **ACE permissions** in `server.cfg`, not from this screen. Stations and apparatus are set in `config.lua` (`Config.Fire`).
{% endhint %}
