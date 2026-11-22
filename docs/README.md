---
description: The in-game CAD / MDT tablet for FiveM roleplay servers.
---

# Welcome

UnitLink is an in-game **CAD / MDT tablet** for FiveM roleplay servers. It works like a real dispatch console:

* live calls and units
* call records with notes
* name searches with state returns
* citations, arrests, reports and warrants
* BOLOs
* a searchable code of laws

It runs **standalone**, with no framework and **no money**. People are civilian profiles players make with `/civ`, and permissions are FiveM **ACE only**.

## Quick links

<table data-view="cards"><thead><tr><th></th><th></th><th data-hidden data-card-target data-type="content-ref"></th></tr></thead><tbody><tr><td><strong>Download</strong></td><td>Get the scripts with git clone</td><td><a href="getting-started/download.md">download.md</a></td></tr><tr><td><strong>Installation</strong></td><td>Folders, start order, first boot</td><td><a href="getting-started/installation.md">installation.md</a></td></tr><tr><td><strong>ACE Permissions</strong></td><td>Examples for server.cfg</td><td><a href="getting-started/ace-permissions.md">ace-permissions.md</a></td></tr><tr><td><strong>Using UnitLink</strong></td><td>Every screen explained</td><td><a href="unitlink/overview.md">overview.md</a></td></tr><tr><td><strong>Rules</strong></td><td>Points, fines, warrants, permissions</td><td><a href="rules/citations-and-points.md">citations-and-points.md</a></td></tr><tr><td><strong>Admin Dashboard</strong></td><td>Applications, laws, settings</td><td><a href="admin/admin-dashboard.md">admin-dashboard.md</a></td></tr></tbody></table>

## What's in the package

| Resource | Folder | Role |
| --- | --- | --- |
| **UnitLink-CAD** | `[UnitLink]/UnitLink-CAD` | The police CAD, **SAFR Fire & Rescue**, **DOT Work Orders**, the **Civilian Portal** (`/civ`), the **Admin Dashboard** (`/cadadmin`) and **Shared Tools** |
| **UnitLink-Police** | `[UnitLink]/UnitLink-Police` | Duty, units, 911 calls and the CAD exports (ACE permissions) |
| **UnitLink-UI** | `[UnitLink]/UnitLink-UI` | Notifications and menus |
| **UnitLink-HUD** | `[UnitLink]/UnitLink-HUD` | Standalone HUD, no money. The job line changes when you go on duty |
| **UnitLink-Core** *(optional)* | `[UnitLink]/UnitLink-Core` | Character framework, only if you want it |

{% hint style="info" %}
**Status:** built and checked offline. The Lua compiles, every tablet was clicked through in a browser against the real server code, and the server logic passed its tests against a test database (identity, SAFR, DOT, shared tools, Civilian Portal and Admin). It hasn't been run on a live FXServer yet. Use the [Live Server Checklist](testing/live-server-checklist.md).
{% endhint %}
