fx_version 'cerulean'
game 'gta5'
description 'Terrific Customs - warsztat tuningowy (Benny\'s / LS Customs)'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@ScaleformUI/ScaleformUI.lua',
    'client/dragcam.lua',
    'client/main.lua',
}

server_script 'server/main.lua'

dependencies {
    'ox_lib',
    'qb-core',
    'ScaleformUI',
    'ScaleformUI_Assets',
}

lua54 'yes'
