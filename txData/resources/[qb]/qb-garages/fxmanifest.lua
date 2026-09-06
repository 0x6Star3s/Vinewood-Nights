fx_version 'cerulean'
game 'gta5'

description 'QB-Garages'
version '1.2.1'

shared_scripts {
    'config.lua',
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua'
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/ComboZone.lua',
    '@ScaleformUI/ScaleformUI.lua',          -- menu w stylu GTA, to samo co w warsztacie
    '@terrific-customs/client/dragcam.lua',  -- kamera orbitalna z warsztatu (LPM/scroll)
    'client/main.lua',
    'client/adminpanel.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/adminpanel.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'ScaleformUI',
    'ScaleformUI_Assets',
    'terrific-customs',
}

lua54 'yes'
