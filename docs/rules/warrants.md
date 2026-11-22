# Warrants & Supervisor Approval

1. An officer files a **Warrant Request** with probable cause of **at least 20 characters**. The types are **Arrest**, **Search** and **Bench**.
2. **If the officer isn't a supervisor:** the warrant is **pending**, and on-duty supervisors are notified.
3. **A supervisor approves or denies it** under **Alerts**.
4. **Once approved:** the subject shows **WANTED** on every state return.
5. **Mark Served** when it's done.

A warrant filed **by a supervisor** goes active right away.

## Settings

| Setting | Default | Effect |
|---|---|---|
| `Config.WarrantsNeedApproval` | `true` | Set it to `false` to make every warrant active right away |

## Who counts as a supervisor

UnitLink-Police decides. A supervisor has either:
* `unitlink.<dept>.supervisor` (for example `unitlink.sasp.supervisor`), or
* `unitlink.police.supervisor`, which covers every LEO department.

See [Permissions & Access](permissions.md).
