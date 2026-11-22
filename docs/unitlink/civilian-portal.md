# Civilian Portal (/civ)

`/civ` opens the **Civilian Portal**. It's the civilian's tablet, in the same style as the CADs, and nobody needs a permission or to be on duty.

{% hint style="warning" %}
**No money anywhere.** Fines are shown on your record and expire on their own. Nothing is ever taken from you.
{% endhint %}

## Toolbar

| Button | What it does |
|---|---|
| **Dashboard** | Your ID card, licenses and points, warrants, outstanding fines, citations, arrests, vehicles, pending applications, your last 911 calls and your medical history |
| **911** | Call **Police**, **Fire** or **Ambulance**. Your name and location go with the call. **Call Tracking** shows the call number and whether units are assigned |
| **My Records** | Citations (with fine and when it expires), arrests and active warrants |
| **Vehicles** | Register vehicles, report one **stolen** (every department gets a shared BOLO) or **recovered**, remove one. Your businesses are here too |
| **Applications** | Apply for a driver's, firearm or pilot license, a vehicle registration or a business license. See each decision and the reason |
| **Service Requests** | Report potholes, broken signals, debris, abandoned vehicles or ask for roadside help. Each one becomes a **DOT work order** you can follow |
| **Profiles** / **New Profile** | Make and pick the person you're playing (standalone mode) |

## Profiles

In standalone mode you make up to `Config.Civ.maxProfiles` (5) people and pick who you're playing. Officers see that person when they run your name, and the HUD shows their name. New profiles start with a valid driver's license.

With UnitLink-Core, your Core character is used and the Profiles buttons are off.

## Applications

`Config.Civ.approval` decides what needs an admin. By default licenses and businesses wait for an admin in the [Admin Dashboard](../admin/admin-dashboard.md), and vehicle registrations are instant. Admins can change this in game.

* You can't apply for a license you already hold.
* A **suspended** or **revoked** license can only be restored by an admin.
