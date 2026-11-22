fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'UnitLink-CAD'
author 'UnitLink'
description 'UnitLink: CAD / MDT for FiveM roleplay servers (calls, units, records, warrants, alerts)'
version '1.0.0'

-- UnitLink-Police supplies calls and units, UnitLink-Core supplies characters,
-- UnitLink-UI supplies notifications. Start all of them before unitlink.
dependencies {
    'oxmysql',
    'UnitLink-Core',
    'UnitLink-Police',
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
