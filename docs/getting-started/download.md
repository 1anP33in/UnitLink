# Download

{% hint style="info" %}
The repo is **private**. Your GitHub account needs access, and Git needs to be signed in. The easiest way is the GitHub CLI: run `gh auth login` once. A personal access token also works when Git asks for a password.
{% endhint %}

## Option A: git clone (recommended)

```bash
git clone https://github.com/1anP33in/tsrp-unitlink-cad.git
```

You get a `tsrp-unitlink-cad` folder holding:

```
[Tropical_PoliceScripts]/unitlink
[Tropical_PoliceScripts]/tsrp-police
[Tropical_Permissions]/tsrp-core
[Tropical_Menus]/tsrp-ui
```

Copy those `[Category]` folders into your server's `resources` folder.

## Option B: clone straight into a new server

For a fresh server with no `resources` folder yet, run this from the base folder (the one holding `server.cfg`):

```bash
git clone https://github.com/1anP33in/tsrp-unitlink-cad.git resources
```

Updating is then just `git pull` inside `resources`. The repo only tracks these scripts, so any other resources you add aren't touched.

## Option C: ZIP

On GitHub: **Code → Download ZIP**. Extract it and copy the `[Category]` folders into `resources`.

## You also need

* **oxmysql:** get it from its official release. It isn't in this repo.
* **OneSync:** turned on (for unit positions and 911 locations).
* **A MySQL or MariaDB database.**

Next: [Installation](installation.md)
