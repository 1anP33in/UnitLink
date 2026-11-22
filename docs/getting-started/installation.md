# Installation

{% stepper %}
{% step %}
### Put the folders in place

Keep the `[UnitLink]` category folder, exactly like this:

```
resources/
└── [UnitLink]/
    ├── UnitLink-Core
    ├── UnitLink-UI
    ├── UnitLink-Police
    └── UnitLink-CAD
```
{% endstep %}

{% step %}
### Start order in server.cfg

Each script needs the ones above it, so the order matters:

```cfg
ensure oxmysql
ensure UnitLink-Core
ensure UnitLink-UI
ensure UnitLink-Police
ensure UnitLink-CAD
```
{% endstep %}

{% step %}
### Add your secrets

Database, Discord bot token and webhooks go in `server.cfg`. See [Server Config & Secrets](server-config.md).
{% endstep %}

{% step %}
### First start

Start the server. The database tables are created automatically:
* UnitLink creates its `ul_*` tables (`Config.AutoInstallSql = true`).
* UnitLink-Core and UnitLink-Police create their own.

If you'd rather create UnitLink's tables yourself, run `UnitLink-CAD/sql/install.sql`.
{% endstep %}

{% step %}
### Give people access

In the UnitLink-Core dashboard (`/ulcore`), give a character a department group, for example `sasp`. They can then go on duty with `/duty` and open UnitLink with `/cad` or **F5**.
{% endstep %}
{% endstepper %}

Next: [Server Config & Secrets](server-config.md)
