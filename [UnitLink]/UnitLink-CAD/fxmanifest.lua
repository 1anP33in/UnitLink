fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'UnitLink-CAD'
author 'UnitLink'
description 'UnitLink: CAD / MDT for FiveM roleplay servers (calls, units, records, warrants, alerts, civilian profiles)'
version '1.1.0'

-- Standalone: needs only oxmysql and UnitLink-Police (calls, units, duty).
-- UnitLink-UI (notifications) and UnitLink-Core (characters) are optional:
-- without UnitLink-Core, people come from UnitLink's own civilian profiles (/civ).
-- Start order: oxmysql, UnitLink-UI, UnitLink-Police, UnitLink-CAD.
dependencies {
    'oxmysql',
    'UnitLink-Police',
}

shared_script 'config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/identity.lua',
    'server/bridge.lua',
    'server/common.lua',
    'server/calls.lua',
    'server/records.lua',
    'server/alerts.lua',
    'server/fire.lua',
    'server/dot.lua',
    'server/shared.lua',
    'server/civ.lua',
    'server/admin.lua',
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
