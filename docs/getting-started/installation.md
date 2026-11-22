# Installation

{% stepper %}
{% step %}
### Put the folders in place

Keep the category folders, exactly like this:

```
resources/
├── [Tropical_Permissions]/tsrp-core
├── [Tropical_Menus]/tsrp-ui
└── [Tropical_PoliceScripts]/
    ├── tsrp-police
    └── unitlink
```
{% endstep %}

{% step %}
### Start order in server.cfg

Each script needs the ones above it, so the order matters:

```cfg
ensure oxmysql
ensure tsrp-core
ensure tsrp-ui
ensure tsrp-police
ensure unitlink
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
* tsrp-core and tsrp-police create their own.

If you'd rather create UnitLink's tables yourself, run `unitlink/sql/install.sql`.
{% endstep %}

{% step %}
### Give people access

In the tsrp-core dashboard (`/tsrp`), give a character a department group, for example `sasp`. They can then go on duty with `/duty` and open UnitLink with `/cad` or **F5**.
{% endstep %}
{% endstepper %}

Next: [Server Config & Secrets](server-config.md)
