fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'UnitLink-UI'
author 'UnitLink'
description 'Standalone UI kit: notifications, progress, dialogs, menus, text UI and mini games'
version '1.0.0'

shared_script 'config.lua'

client_scripts {
    'client/core.lua',
    'client/notify.lua',
    'client/progress.lua',
    'client/dialogs.lua',
    'client/context.lua',
    'client/list.lua',
    'client/radial.lua',
    'client/textui.lua',
    'client/minigames.lua',
    'client/test.lua',
}

server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/js/*.js',
}
