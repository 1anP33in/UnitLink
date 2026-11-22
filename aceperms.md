# UnitLink ACE Permissions

UnitLink uses **plain FiveM ACE permissions only**. Permissions belong to a player's **account** (their license). **Nothing is stored on characters**, and there is no in-game permission editor. You set everything in `server.cfg`, and changes apply the next time a player does something, with no restart needed for checks.

> This file is for the server owner. Copy the blocks you need into `server.cfg`, then swap in real license identifiers.

---

## 1. How it works

| Line | Meaning |
|---|---|
| `add_ace group.sasp unitlink.sasp.duty allow` | Members of the group `group.sasp` may do `unitlink.sasp.duty` |
| `add_principal group.sasp_supervisor group.sasp` | Supervisors also get everything SASP members get |
| `add_principal identifier.license:abc123 group.sasp` | Puts that player (by license) in `group.sasp` |

- **A parent node allows its children.** `unitlink.sasp` allows `unitlink.sasp.duty` and `unitlink.sasp.supervisor`.
- **Finding a player's license:** in **txAdmin**, open Players, click the player and copy the `license:` identifier. You can also find it in the server console when they join.
- **Use `license:`, not `license2:`.**

---

## 2. Every permission UnitLink checks

| Permission | Used by | Lets the player |
|---|---|---|
| `unitlink.sasp.duty` | UnitLink-Police | Go on duty as **SASP** (San Andreas State Police) |
| `unitlink.sasp.supervisor` | Police, CAD, HUD | SASP supervisor: close any SASP 911 call, approve warrants, set Signal 100, "Sergeant" on the HUD |
| `unitlink.bcso.duty` | UnitLink-Police | Go on duty as **BCSO** (Blaine County Sheriff's Office) |
| `unitlink.bcso.supervisor` | Police, CAD, HUD | BCSO supervisor |
| `unitlink.lsp.duty` | UnitLink-Police | Go on duty as **LSP** (Los Santos Police) |
| `unitlink.lsp.supervisor` | Police, CAD, HUD | LSP supervisor |
| `unitlink.dhs.duty` | UnitLink-Police | Go on duty as **DHS** |
| `unitlink.dhs.supervisor` | Police, CAD, HUD | DHS supervisor |
| `unitlink.safr.duty` | UnitLink-Police | Go on duty as **SAFR** (Fire & Rescue). Opens the SAFR CAD with `/cad` |
| `unitlink.safr.supervisor` | Police, CAD, HUD | SAFR supervisor: station announcements, close any incident, clear any MAYDAY, edit certifications, put apparatus out of service, "Captain" on the HUD |
| `unitlink.faa.duty` | UnitLink-Police | Go on duty as **FAA** |
| `unitlink.faa.supervisor` | Police, HUD | FAA supervisor |
| `unitlink.police.supervisor` | Police, CAD | **Every** LEO department: close any 911 call, approve any warrant |

**What needs no permission:**
- **Civilians:** `/911`, `/911fire`, `/911ems`, `/civ` (making civilian profiles), the HUD.
- **The CAD:** `/cad` opens the police CAD for LEO on duty and the SAFR CAD for SAFR on duty, so duty is the gate.

> **Coming with later phases:** DOT, the Civilian Portal and the Admin Dashboard will add nodes such as `unitlink.dot.*` and `unitlink.admin`. This file will be updated with each phase.

---

## 3. Ready to paste: groups

Paste this once. It sets up a member, supervisor and command group for each department. Supervisors inherit the member permissions, and command gets the whole department.

```cfg
## ---------- UnitLink: department groups ----------
# SASP
add_ace group.sasp            unitlink.sasp.duty       allow
add_ace group.sasp_supervisor unitlink.sasp.supervisor allow
add_principal group.sasp_supervisor group.sasp
add_ace group.sasp_command    unitlink.sasp            allow
add_principal group.sasp_command group.sasp_supervisor

# BCSO
add_ace group.bcso            unitlink.bcso.duty       allow
add_ace group.bcso_supervisor unitlink.bcso.supervisor allow
add_principal group.bcso_supervisor group.bcso
add_ace group.bcso_command    unitlink.bcso            allow
add_principal group.bcso_command group.bcso_supervisor

# LSP
add_ace group.lsp             unitlink.lsp.duty        allow
add_ace group.lsp_supervisor  unitlink.lsp.supervisor  allow
add_principal group.lsp_supervisor group.lsp
add_ace group.lsp_command     unitlink.lsp             allow
add_principal group.lsp_command group.lsp_supervisor

# DHS
add_ace group.dhs             unitlink.dhs.duty        allow
add_ace group.dhs_supervisor  unitlink.dhs.supervisor  allow
add_principal group.dhs_supervisor group.dhs
add_ace group.dhs_command     unitlink.dhs             allow
add_principal group.dhs_command group.dhs_supervisor

# SAFR (Fire & Rescue)
add_ace group.safr            unitlink.safr.duty       allow
add_ace group.safd_supervisor unitlink.safr.supervisor allow
add_principal group.safd_supervisor group.safr
add_ace group.safd_command    unitlink.safr            allow
add_principal group.safd_command group.safd_supervisor

# FAA
add_ace group.faa             unitlink.faa.duty        allow
add_ace group.faa_supervisor  unitlink.faa.supervisor  allow
add_principal group.faa_supervisor group.faa
add_ace group.faa_command     unitlink.faa             allow
add_principal group.faa_command group.faa_supervisor

# LEO High Command: supervisor across every police department
add_ace group.leo_command unitlink.police.supervisor allow
add_principal group.leo_command group.sasp_command
add_principal group.leo_command group.bcso_command
add_principal group.leo_command group.lsp_command
add_principal group.leo_command group.dhs_command

# Server admins get everything in UnitLink
add_ace group.admin unitlink allow
```

---

## 4. Ready to paste: people

Put players in groups by license. One line per person per group:

```cfg
## ---------- UnitLink: members ----------
# Trooper (SASP member)
add_principal identifier.license:REPLACE_WITH_LICENSE group.sasp

# Sergeant (SASP supervisor, also gets SASP duty)
add_principal identifier.license:REPLACE_WITH_LICENSE group.sasp_supervisor

# A player in two departments (SASP and SAFR)
add_principal identifier.license:REPLACE_WITH_LICENSE group.sasp
add_principal identifier.license:REPLACE_WITH_LICENSE group.safr

# Chief of Police over every LEO department
add_principal identifier.license:REPLACE_WITH_LICENSE group.leo_command
```

To **remove** someone, delete their line and restart the server. You can also run `remove_principal identifier.license:... group.sasp` in the server console, which applies straight away.

---

## 5. Quick checks

| Problem | Fix |
|---|---|
| "You don't have access to any department" | The player's license isn't in a department group, or you used `license2:` instead of `license:` |
| A supervisor can't approve warrants | They need `group.<dept>_supervisor`, not just `group.<dept>` |
| Changes did nothing | `add_principal` lines in `server.cfg` only load on server start. Use the console to apply them straight away |
| Test what someone has | In the server console: `test_ace identifier.license:abc123 unitlink.sasp.duty` |

UnitLink-Police must stay in **standalone mode** (`Config.Framework.enabled = false`, the default) for ACE to be used.
