fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'UnitLink-HUD'
author 'UnitLink'
description 'UnitLink HUD: duty job line, status rings, compass, speedometer, seatbelt, indicators, voice and clock. Standalone, no money.'
version '1.1.0'

-- Standalone. Works with nothing else running. If they are running:
--   UnitLink-Police : the job line changes when you go on or off duty
--   UnitLink-CAD    : off duty, the job line shows your /civ profile name
--   UnitLink-UI     : notifications and the /hud settings dialog
--   UnitLink-Core   : the HUD waits for a character to spawn

shared_script 'config.lua'

client_scripts {
    'client/vehicle.lua',
    'client/main.lua',
}

server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
