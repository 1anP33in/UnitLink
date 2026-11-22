---
description: The in-game CAD / MDT tablet for Tropical State RP.
---

# Welcome to UnitLink

{% hint style="warning" %}
**Customize this GitBook first, then delete this box.**

**1. Connect it to GitHub**
1. In GitBook, create a new **Space**, then open **Configure → GitHub Sync**.
2. Pick the repo `1anP33in/tsrp-unitlink-cad`, branch `main`.
3. Choose **GitHub → GitBook** for the first sync. GitBook reads `.gitbook.yaml`, which points it at the `docs/` folder.
4. After that, edits made in GitBook are pushed back to GitHub as commits, and edits pushed to GitHub show up in GitBook.

**2. Rename things.** Search and replace these across `docs/`:

| Replace | With |
|---|---|
| `Tropical State RP` | your server's name |
| `1anP33in/tsrp-unitlink-cad` | your repo, if you fork or rename it |
| `/cad` and `F5` | your command and key, if you change them in `config.lua` |
| `12 points` | your suspension limit (`Config.Licenses.suspendAt`) |

**3. Branding** (in GitBook, under **Customize**):
* **Logo:** upload `unitlink-logo.png` (on the dev PC, in `unitlink-preview/logos/png/`). Use `unitlink-icon.png` as the favicon.
* **Primary color:** `#1B4A8A`, the UnitLink toolbar blue. The accent is `#8FC1FF`.
* **Theme:** dark mode, to match the tablet.
* **Header links:** add your Discord invite and your website.

**4. Groups and pages:** the sidebar is built from `docs/SUMMARY.md`.
* `## Heading` creates a group.
* `* [Page](path.md)` adds a page to that group.
* Indent a line to make it a sub-page.
* To add a page, create the `.md` file and add a line for it in `SUMMARY.md`.

**5. Private or public:** the repo is private, but a GitBook space can be published publicly. Before you publish, check that no page shows secrets: no webhook URLs, tokens or database passwords. None are in these docs by default.
{% endhint %}

UnitLink is the in-game **CAD / MDT tablet** for Tropical State RP. It works like a real dispatch console:
* live calls and units
* call records with notes
* name searches with state returns
* citations, arrests, reports and warrants
* BOLOs
* a searchable code of laws

## Quick links

<table data-view="cards"><thead><tr><th></th><th></th><th data-hidden data-card-target data-type="content-ref"></th></tr></thead><tbody>
<tr><td><strong>Download</strong></td><td>Get the scripts with git clone</td><td><a href="getting-started/download.md">download.md</a></td></tr>
<tr><td><strong>Installation</strong></td><td>Folders, start order, first boot</td><td><a href="getting-started/installation.md">installation.md</a></td></tr>
<tr><td><strong>Using UnitLink</strong></td><td>Every screen explained</td><td><a href="unitlink/overview.md">overview.md</a></td></tr>
<tr><td><strong>Rules</strong></td><td>Points, warrants, permissions</td><td><a href="rules/citations-and-points.md">citations-and-points.md</a></td></tr>
<tr><td><strong>Configuration</strong></td><td>Every setting in config.lua</td><td><a href="configuration/unitlink-config.md">unitlink-config.md</a></td></tr>
<tr><td><strong>Roadmap</strong></td><td>SAFR, DOT, Civilian portal, Admin</td><td><a href="roadmap/overview.md">overview.md</a></td></tr>
</tbody></table>

## What's in the package

| Resource | Folder | Role |
|---|---|---|
| **unitlink** | `[Tropical_PoliceScripts]/unitlink` | The CAD / MDT tablet |
| **tsrp-police** | `[Tropical_PoliceScripts]/tsrp-police` | Duty, units, 911 calls and the CAD exports |
| **tsrp-core** | `[Tropical_Permissions]/tsrp-core` | Characters, groups and departments, licenses (metadata) |
| **tsrp-ui** | `[Tropical_Menus]/tsrp-ui` | Notifications and menus |

{% hint style="info" %}
**Status:** built and checked offline: the Lua compiles, the NUI was clicked through in a browser, and tsrp-core's 262 tests pass. It hasn't been run on a live FXServer yet. Use the [Live Server Checklist](testing/live-server-checklist.md).
{% endhint %}
