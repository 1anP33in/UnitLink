# Permissions & Access

UnitLink uses **FiveM ACE permissions only**. They belong to the player's **account** (license), never to a character, and are set in `server.cfg`.

{% hint style="success" %}
Ready-to-paste groups and every permission are on the [ACE Permissions](../getting-started/ace-permissions.md) page.
{% endhint %}

## Going on duty

| Department | Go on duty | Supervisor |
|---|---|---|
| SASP | `unitlink.sasp.duty` | `unitlink.sasp.supervisor` |
| BCSO | `unitlink.bcso.duty` | `unitlink.bcso.supervisor` |
| LSP | `unitlink.lsp.duty` | `unitlink.lsp.supervisor` |
| DHS | `unitlink.dhs.duty` | `unitlink.dhs.supervisor` |
| SAFR | `unitlink.safr.duty` | `unitlink.safr.supervisor` |
| FAA | `unitlink.faa.duty` | `unitlink.faa.supervisor` |

`unitlink.police.supervisor` makes someone a supervisor across every LEO department.

```cfg
add_ace group.sasp unitlink.sasp.duty allow
add_principal identifier.license:abc123 group.sasp
```

## Opening the CAD

You need to be **on duty** in a department whose type receives 911 (`Config.AccessFlag`, LEO by default). There's no separate CAD permission: being on duty is the gate.

## Server-side checks

Every UnitLink request is checked again on the server: on duty, CAD access, and a rate limit (`Config.RateLimitMs`, 250 ms). Supervisor-only actions, like approving warrants and Signal 100, check the supervisor permission on the server too.

## Optional: UnitLink-Core

If you run UnitLink-Core and want departments to follow characters instead, set `Config.Framework.enabled = true` in UnitLink-Police. The same names then become UnitLink-Core character permissions. The standalone default is ACE.
