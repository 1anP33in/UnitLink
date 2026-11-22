fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'UnitLink-Police'
author 'UnitLink'
description 'Standalone police duty, live blips, roster, 911 dispatch and panic system'
version '1.0.0'

-- UnitLink-UI provides the UI but is NOT a hard `dependency`, so this resource
-- still runs (with native GTA notifications) if UnitLink-UI is stopped.
-- Ensure UnitLink-UI BEFORE UnitLink-Police in server.cfg.

shared_scripts {
    'config/config.lua',
    'config/departments.lua',
    'config/permissions.lua',
    'config/blips.lua',
    'shared/constants.lua',
    'shared/utils.lua',
    'integrations/unitlink_ui.lua',
}

server_scripts {
    'config/webhooks.lua', -- server only: webhook URLs never reach clients
    'integrations/unitlink_core.lua',
    'server/main.lua',
    'server/logging.lua',
    'server/permissions.lua',
    'server/persistence.lua',
    'server/duty.lua',
    'server/roster.lua',
    'server/dispatch.lua',
    'server/panic.lua',
}

client_scripts {
    'client/main.lua',
    'client/duty.lua',
    'client/roster.lua',
    'client/blips.lua',
    'client/dispatch.lua',
    'client/panic.lua',
    'client/keybinds.lua',
}
