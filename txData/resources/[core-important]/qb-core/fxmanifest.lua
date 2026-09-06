fx_version 'cerulean'
game 'gta5'

description 'QB-Core'
version '1.2.6'

shared_scripts {
    'config.lua',
    'shared/locale.lua',
    'locale/en.lua',
    'locale/*.lua',
    'shared/main.lua',
    'shared/items.lua',
    'shared/jobs.lua',
    'shared/vehicles.lua',
    'shared/gangs.lua',
    'shared/weapons.lua',
    'shared/locations.lua'
}

client_scripts {
    '@ox_lib/init.lua', -- lib.showTextUI dla client/drawtext.lua (jedna podpowiedz E na serwerze)
    'client/main.lua',
    'client/functions.lua',
    'client/loops.lua',
    'client/events.lua',
    'client/drawtext.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/functions.lua',
    'server/player.lua',
    'server/events.lua',
    'server/commands.lua',
    'server/exports.lua',
    'server/debug.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/css/drawtext.css',
    'html/js/*.js'
}

dependencies {
    'oxmysql',
    'ox_lib',
}

lua54 'yes'
