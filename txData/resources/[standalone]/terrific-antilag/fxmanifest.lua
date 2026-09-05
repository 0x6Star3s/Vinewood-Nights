fx_version 'cerulean'
game 'gta5'

name 'terrific-antilag'
description 'Strzaly z wydechu (pops and bangs) dla aut z turbo'
version '1.0.0'

-- Dzwieki (html/sounds/*.ogg) i pomysl na czastki pochodza z yorick-antilag
-- (github.com/yorick2002/yorick-antilag). Repo nie podaje licencji - patrz UPSTREAM-README.md.
-- Kod klienta i serwera napisany od nowa, szczegoly w client.lua.

ui_page 'html/index.html'

client_scripts {
    'config.lua',
    'client.lua',
}

server_scripts {
    'config.lua',
    'server.lua',
}

files {
    'html/index.html',
    'html/sounds/*.ogg',
}

lua54 'yes'
