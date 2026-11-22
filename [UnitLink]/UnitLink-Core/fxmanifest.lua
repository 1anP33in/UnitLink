fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'UnitLink-Core'
author 'UnitLink'
description 'UnitLink Core: standalone character, permission and administration framework for UnitLink'
version '1.0.0'

-- oxmysql is required. illenium-appearance is used for appearance editing; UnitLink Core
-- detects it at runtime and falls back to default freemode peds if it is missing.
-- (illenium-appearance itself requires ox_lib. UnitLink Core does not.)
dependencies {
    'oxmysql',
}

shared_scripts {
    'config/config.lua',
    'config/characters.lua',
    'shared/constants.lua',
    'shared/enums.lua',
    'shared/utils.lua',
    'shared/locales.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    -- Server-only configuration. These files never reach clients.
    'config/database.lua',
    'config/bootstrap.lua',
    'config/permissions.lua',
    'config/groups.lua',
    'config/spawn.lua',
    'config/logging.lua',
    'config/discord.lua',

    'integrations/oxmysql.lua',
    'integrations/webhook.lua',
    'integrations/discord.lua',

    'server/logging.lua',
    'server/database.lua',
    'server/ratelimit.lua',
    'server/callbacks.lua',
    'server/players.lua',
    'server/groups.lua',
    'server/permissions.lua',
    'server/identity.lua',
    'server/characters.lua',
    'server/metadata.lua',
    'server/appearance.lua',
    'server/persistence.lua',
    'server/spawn.lua',
    'server/administration.lua',
    'server/commands.lua',
    'server/api.lua',
    'server/main.lua',
}

client_scripts {
    'integrations/illenium.lua',
    'client/main.lua',
    'client/nui.lua',
    'client/scene.lua',
    'client/characters.lua',
    'client/appearance.lua',
    'client/spawn.lua',
    'client/permissions.lua',
    'client/admin.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/css/*.css',
    'nui/js/*.js',
}
