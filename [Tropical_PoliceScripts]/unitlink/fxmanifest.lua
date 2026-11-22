fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'unitlink'
author 'Tropical State RP'
description 'UnitLink: CAD / MDT for Tropical State RP (calls, units, records, warrants, alerts)'
version '1.0.0'

-- tsrp-police supplies calls and units, tsrp-core supplies characters,
-- tsrp-ui supplies notifications. Start all of them before unitlink.
dependencies {
    'oxmysql',
    'tsrp-core',
    'tsrp-police',
}

shared_script 'config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/bridge.lua',
    'server/calls.lua',
    'server/records.lua',
    'server/alerts.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/js/*.js',
    'sql/install.sql',
}
