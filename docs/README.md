---
description: The in-game CAD / MDT tablet for Tropical State RP.
---

# Welcome

UnitLink is an in-game **CAD / MDT tablet** for FiveM roleplay servers. It works like a real dispatch console:

UnitLink is the in-game **CAD / MDT tablet** for Tropical State RP. It works like a real dispatch console:

* live calls and units
* call records with notes
* name searches with state returns
* citations, arrests, reports and warrants
* BOLOs
* a searchable code of laws

## Quick links

<table data-view="cards"><thead><tr><th></th><th></th><th data-hidden data-card-target data-type="content-ref"></th></tr></thead><tbody><tr><td><strong>Download</strong></td><td>Get the scripts with git clone</td><td><a href="getting-started/download.md">download.md</a></td></tr><tr><td><strong>Installation</strong></td><td>Folders, start order, first boot</td><td><a href="getting-started/installation.md">installation.md</a></td></tr><tr><td><strong>Using UnitLink</strong></td><td>Every screen explained</td><td><a href="unitlink/overview.md">overview.md</a></td></tr><tr><td><strong>Rules</strong></td><td>Points, warrants, permissions</td><td><a href="rules/citations-and-points.md">citations-and-points.md</a></td></tr><tr><td><strong>Configuration</strong></td><td>Every setting in config.lua</td><td><a href="configuration/ulcore-config.md">ulcore-config.md</a></td></tr><tr><td><strong>Roadmap</strong></td><td>SAFR, DOT, Civilian portal, Admin</td><td><a href="roadmap/overview.md">overview.md</a></td></tr></tbody></table>

## What's in the package

| Resource            | Folder                       | Role                                                    |
| ------------------- | ---------------------------- | ------------------------------------------------------- |
| **UnitLink-CAD**    | `[UnitLink]/UnitLink-CAD`    | The CAD / MDT tablet                                    |
| **UnitLink-Police** | `[UnitLink]/UnitLink-Police` | Duty, units, 911 calls and the CAD exports              |
| **UnitLink-Core**   | `[UnitLink]/UnitLink-Core`   | Characters, groups and departments, licenses (metadata) |
| **UnitLink-UI**     | `[UnitLink]/UnitLink-UI`     | Notifications and menus                                 |

{% hint style="info" %}
**Status:** built and checked offline: the Lua compiles, the NUI was clicked through in a browser, and UnitLink-Core's 262 tests pass. It hasn't been run on a live FXServer yet. Use the [Live Server Checklist](testing/live-server-checklist.md).
{% endhint %}
