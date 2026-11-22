# Admin Dashboard (/cadadmin)

`/cadadmin` opens the **Admin Dashboard**, in the same style as the CADs. Only players with the ACE permission `unitlink.admin` can open it. You don't need to be on duty.

```cfg
add_ace group.admin unitlink.admin allow
```

| Screen | What you can do |
|---|---|
| **Overview** | Units on duty, active calls, incidents and work orders, pending applications, warrants, BOLOs, civilians, vehicles, records in the last 24 hours, and recent admin changes |
| **Departments** | Every department, its type, callsign example, duty and supervisor ACE, and who's on duty. **Read only**: departments live in UnitLink-Police config |
| **Applications** | Approve or deny civilian applications. A denial needs a reason, which the civilian sees |
| **Civilians** | Search people, change license status and driver points, set a vehicle to VALID, STOLEN or IMPOUNDED |
| **Laws & Fines** | Change each law's fine and license points. **Reset** puts the default back |
| **Settings** | Fines on/off and expiry, suspension points, warrant approval, Signal 100, report minimums, civilian limits, which applications need approval |
| **Permissions** | Who online has which UnitLink ACE. **Read only**: change them in `server.cfg` |
| **Activity** | Every department's activity log |
| **Audit Log** | Every change made in this dashboard, with who made it |

{% hint style="info" %}
Changes to laws and settings are saved in the database (`ul_settings`), apply right away, and are applied again on every restart. Everything else stays in `config.lua`.
{% endhint %}
