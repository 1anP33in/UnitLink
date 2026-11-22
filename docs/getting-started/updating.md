# Updating

## If you cloned the repo

```bash
cd UnitLink
git pull
```

Copy the `[UnitLink]` folder into `resources` again. If you cloned straight into `resources` (Option B on the Download page), `git pull` already updated them.

## Applying the update in game

From the server console or txAdmin:

```
refresh
ensure UnitLink-Core
ensure UnitLink-Police
ensure UnitLink-CAD
```

{% hint style="warning" %}
**Restarting UnitLink-Core or UnitLink-Police takes everyone off duty.** UnitLink-Police fails closed when UnitLink-Core restarts. Do it when it's quiet, or just restart the whole server.
{% endhint %}

Restarting only `UnitLink-CAD` doesn't take anyone off duty. Open tablets are meant to give control back and remove the prop; check this on a live server (item 15 of the [Live Server Checklist](../testing/live-server-checklist.md)).

## Pushing your own changes (maintainers)

From the server's `resources` folder:

```bash
git add -A
git commit -m "Describe what changed"
git push
```

`.gitignore` only tracks the UnitLink scripts, so other resources and `server.cfg` are never uploaded.
