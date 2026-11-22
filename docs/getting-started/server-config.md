# Server Config & Secrets

{% hint style="danger" %}
**Secrets belong in `server.cfg` only.** Never put a token, password or webhook URL in a Lua file that goes to GitHub. Anyone who has a webhook URL can post in that Discord channel.
{% endhint %}

```cfg
# database (oxmysql)
set mysql_connection_string "mysql://user:password@localhost/tsrp?charset=utf8mb4"

# tsrp-core: Discord role sync bot token
set tsrp_discord_token "YOUR_BOT_TOKEN"

# tsrp-core: audit log webhook (optional)
set tsrp_core_log_webhook "https://discord.com/api/webhooks/..."
```

| Setting | Used by | What it's for |
|---|---|---|
| `mysql_connection_string` | oxmysql | Database connection |
| `tsrp_discord_token` | tsrp-core | Gives in-game groups based on Discord roles |
| `tsrp_core_log_webhook` | tsrp-core | Sends staff audit entries to a Discord channel |

## tsrp-police webhooks

tsrp-police reads its webhook URLs from `tsrp-police/config/webhooks.lua`. That file is **server only** (it's never sent to players). In the repo every URL is blank:
* `default`, `duty`, `dispatch`, `panic`, `security`

If you fill them in on your server, **don't commit that file.**

## Permissions (ACE)

```cfg
add_ace group.admin tsrp.bootstrap allow
```

This makes server admins tsrp-core "bootstrap" admins, who can do everything. Department access itself is given per character in the tsrp-core dashboard. See [Permissions & Access](../rules/permissions.md).
