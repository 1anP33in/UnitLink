# Installation

{% stepper %}
{% step %}
### Put the folders in place

Keep the `[UnitLink]` category folder, exactly like this:

```
resources/
└── [UnitLink]/
    ├── UnitLink-UI
    ├── UnitLink-Police
    ├── UnitLink-CAD
    ├── UnitLink-HUD
    └── UnitLink-Core      (optional)
```
{% endstep %}

{% step %}
### Start order in server.cfg

Each script needs the ones above it, so the order matters. This is the **standalone** setup, with no framework:

```cfg
ensure oxmysql
ensure UnitLink-UI
ensure UnitLink-Police
ensure UnitLink-CAD
ensure UnitLink-HUD
```

UnitLink-Core is **optional**. Only add `ensure UnitLink-Core` (after oxmysql) if you want its character system. Without it, people come from `/civ` profiles and permissions are ACE.
{% endstep %}

{% step %}
### Add your secrets

Database, Discord bot token and webhooks go in `server.cfg`. See [Server Config & Secrets](server-config.md).
{% endstep %}

{% step %}
### First start

Start the server. The database tables are created automatically:
* UnitLink creates its `ul_*` tables (`Config.AutoInstallSql = true`).
* UnitLink-Police stores duty hours itself (and UnitLink-Core makes its own tables if you run it).

If you'd rather create UnitLink's tables yourself, run `UnitLink-CAD/sql/install.sql`.
{% endstep %}

{% step %}
### Give people access

Add ACE permissions in `server.cfg`. Copy the groups from [ACE Permissions](ace-permissions.md), then add each officer's license:

```cfg
add_principal identifier.license:REPLACE_WITH_LICENSE group.sasp
```

They can then go on duty with `/duty` and open UnitLink with `/cad` or **F5**. Civilians make their profile with `/civ`.
{% endstep %}
{% endstepper %}

Next: [Server Config & Secrets](server-config.md)
