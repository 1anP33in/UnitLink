# ACE Permissions

UnitLink uses **plain FiveM ACE permissions only**. They belong to a player's **account** (their license), never to a character, and you set them in `server.cfg`. Nothing needs a restart: UnitLink checks the permission every time it is used.

{% hint style="info" %}
The same file is `aceperms.md` at the root of the GitHub repo.
{% endhint %}

Below are **a few examples** to copy. The comments show how to add the rest.

```cfg
## =====================================================================
## UnitLink permissions (examples). Paste into server.cfg and edit.
## =====================================================================
##
## How a line works:
##   add_ace <group> <permission> allow       -> the group gets the permission
##   add_principal <player or group> <group>  -> the player (or group) joins the group
##
## A parent permission allows everything under it:
##   unitlink.sasp  allows  unitlink.sasp.duty  and  unitlink.sasp.supervisor
##
## Find a player's license in txAdmin: Players > click the player > copy "license:...".
## Use license: (not license2:).

## ---------- Example 1: a department (SASP) ----------
add_ace group.sasp unitlink.sasp.duty allow                     # can go on duty as SASP
add_ace group.sasp_supervisor unitlink.sasp.supervisor allow    # SASP supervisor tools
add_principal group.sasp_supervisor group.sasp                  # supervisors can also go on duty

## ---------- Example 2: Fire & Rescue (SAFR) ----------
add_ace group.safr unitlink.safr.duty allow                     # SAFR tablet with /cad
add_ace group.safr_supervisor unitlink.safr.supervisor allow    # announcements, apparatus out of service, MAYDAY clear
add_principal group.safr_supervisor group.safr

## ---------- Example 3: the UnitLink Admin Dashboard (/cadadmin) ----------
add_ace group.admin unitlink.admin allow

## ---------- Example 4: put players in groups ----------
add_principal identifier.license:0000000000000000000000000000000000000000 group.sasp
add_principal identifier.license:1111111111111111111111111111111111111111 group.safr_supervisor

## ---------------------------------------------------------------------
## Adding more
## ---------------------------------------------------------------------
## Every department works the same way. Copy Example 1 and change "sasp"
## to the department key:
##
##   sasp  San Andreas State Police          bcso  Blaine County Sheriff's Office
##   lsp   Los Santos Police                 dhs   Department of Homeland Security
##   safr  San Andreas Fire & Rescue         dot   Department of Transportation
##   faa   Federal Aviation Administration
##
##   unitlink.<key>.duty         go on duty as that department
##   unitlink.<key>.supervisor   that department's supervisor tools
##
## A command / high command group that gets the whole department:
##   add_ace group.dot_command unitlink.dot allow
##
## Supervisor of EVERY police department (close any 911 call, approve any warrant):
##   add_ace group.leo_command unitlink.police.supervisor allow
##
## Your own new department: add it in UnitLink-Police config/departments.lua
## and config/permissions.lua, then give its new unitlink.<key>.duty here.
```

## What needs no permission

- Civilians: `/911`, `/911fire`, `/911ems` and `/civ` (the Civilian Portal).
- The HUD.
- `/cad`: being on duty is the gate. It opens the police CAD, the SAFR CAD or the DOT tablet for your department.

## Checking it worked

- In the server console: `test_ace player.<id> unitlink.sasp.duty`.
- In game: open `/cadadmin` and go to **Permissions**. It shows who online has which UnitLink permission (read only).
