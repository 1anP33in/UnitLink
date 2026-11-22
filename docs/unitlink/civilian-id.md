# Civilian ID (/civ)

On a standalone server, people come from **civilian profiles**. Players make these themselves with `/civ`. When an officer runs a name, these are the people they find.

| Action | How |
|---|---|
| Open | `/civ` (anyone, no duty needed) |
| Close | **Esc** or **✕ Close** |

## My Profiles

- **Profile list:** your profiles (up to 5 by default, `Config.Civ.maxProfiles`), with name, date of birth, sex and driver's license status.
- **ID card:** the selected profile, shown in the same green state-return style the CAD uses: identity, licenses and points.
- **Play as:** makes this profile the person you're playing. The profile you're playing shows ★ in the list.
- **Delete Profile:** click twice to confirm. Records officers already filed stay on file.

## New Profile

First name, last name, date of birth (age 16 to 100), sex, nationality and height (120 to 230 cm). New profiles start with a **valid driver's license** and no firearm or pilot license.

## Where the profile is used

- **The CAD:** officers find the profile by name or ID, and citations add points to *this* profile's license.
- **UnitLink-Police:** when you go on duty, the roster and 911 calls show your profile's name, falling back to your FiveM name if you haven't picked one.
- **UnitLink-HUD:** off duty, the job line reads `CIV · Civilian · <your name>`.

{% hint style="info" %}
If UnitLink-Core is running and `Config.Identity = 'auto'`, people come from UnitLink-Core characters instead, and `/civ` just tells you so.
{% endhint %}
