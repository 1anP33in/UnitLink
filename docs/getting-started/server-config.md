# Server Config & Secrets

{% hint style="danger" %}
**Secrets belong in `server.cfg` only.** Never put a token, password or webhook URL in a Lua file that goes to GitHub. Anyone who has a webhook URL can post in that Discord channel.
{% endhint %}

```cfg
# database (oxmysql)
set mysql_connection_string "mysql://user:password@localhost/ulcore?charset=utf8mb4"

# unitlink-core: Discord role sync bot token
set unitlink_discord_token "YOUR_BOT_TOKEN"

# unitlink-core: audit log webhook (optional)
set unitlink_core_log_webhook "https://discord.com/api/webhooks/..."
```

| Setting | Used by | What it's for |
|---|---|---|
| `mysql_connection_string` | oxmysql | Database connection |
| `unitlink_discord_token` | UnitLink-Core | Gives in-game groups based on Discord roles |
| `unitlink_core_log_webhook` | UnitLink-Core | Sends staff audit entries to a Discord channel |

## UnitLink-Police webhooks

UnitLink-Police reads its webhook URLs from `UnitLink-Police/config/webhooks.lua`. That file is **server only** (it's never sent to players). In the repo every URL is blank:
* `default`, `duty`, `dispatch`, `panic`, `security`

If you fill them in on your server, **don't commit that file.**

## Permissions (ACE)

```cfg
add_ace group.admin unitlink.bootstrap allow
```

This makes server admins UnitLink-Core "bootstrap" admins, who can do everything. Department access itself is given per character in the UnitLink-Core dashboard. See [Permissions & Access](../rules/permissions.md).
