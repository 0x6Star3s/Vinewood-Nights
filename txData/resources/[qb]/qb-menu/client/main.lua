-- qb-menu -> ScaleformUI. Ten sam format danych co dawne qb-menu (header / txt / params),
-- ale menu rysowane w stylu GTA - takie samo jak w warsztacie i garazu. Dzieki temu
-- ~27 zasobow, ktore wolaja exports['qb-menu']:openMenu(...), dostaje jedno menu bez
-- zmiany ich kodu. NUI z html/ jest juz nieuzywane.
local QBCore = exports['qb-core']:GetCoreObject()

local current            -- otwarte UIMenu zbudowane przez openMenu
local headerData         -- dane z showHeader, czekaja na E
local suppressClosed = false -- zamkniecie "techniczne" (wybor pozycji, podmiana menu) nie wola menuClosed

-- Stare menu bylo HTML-em: <br>, <span>, emoji, strzalki. Scaleform tego nie renderuje.
local function clean(text)
    text = tostring(text or '')
    text = text:gsub('<br%s*/?>', '~n~'):gsub('<[^>]->', '')
    -- emoji (4 bajty) i symbole U+2000-2FFF (strzalki, dingbaty) - font GTA ich nie ma;
    -- polskie znaki sa 2-bajtowe (C4/C5) i zostaja
    text = text:gsub('[\240-\244][\128-\191][\128-\191][\128-\191]', '')
    text = text:gsub('\226[\128-\191][\128-\191]', '')
    return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function sortData(data, skipfirst)
    local header = data[1]
    local tempData = data
    if skipfirst then table.remove(tempData, 1) end
    table.sort(tempData, function(a, b) return tostring(a.header) < tostring(b.header) end)
    if skipfirst then table.insert(tempData, 1, header) end
    return tempData
end

-- Dokladnie to, co robilo dawne clickedButton
local function dispatch(params)
    if not params or not params.event then return end
    if params.isServer then
        TriggerServerEvent(params.event, params.args)
    elseif params.isCommand then
        ExecuteCommand(params.event)
    elseif params.isQBCommand then
        TriggerServerEvent('QBCore:CallCommand', params.event, params.args)
    elseif params.isAction then
        params.event(params.args)
    else
        TriggerEvent(params.event, params.args)
    end
end

local function closeCurrent(silent)
    local menu = current
    if not menu then return end
    current = nil
    suppressClosed = silent and true or false
    if menu:Visible() then MenuHandler:CloseAndClearHistory() end
    suppressClosed = false
end

local function hideHeader()
    if not headerData then return end
    headerData = nil
    exports['qb-core']:HideText()
end

local function openMenu(data, sort, skipFirst, options)
    if type(data) ~= 'table' or not next(data) then return end
    if sort then data = sortData(data, skipFirst) end
    hideHeader()
    closeCurrent(true)

    local titleIndex
    for i = 1, #data do
        if type(data[i]) == 'table' and data[i].isMenuHeader then
            titleIndex = i
            break
        end
    end
    local title = titleIndex and clean(data[titleIndex].header) or ''
    if title == '' then title = 'Menu' end

    local menu = UIMenu.New(title, ' ', 50, 50, true)
    menu:MaxItemsOnScreen(10)

    local entries = {} -- indeks pozycji w menu -> wpis z data
    local navActive
    for i = 1, #data do
        local v = data[i]
        if type(v) == 'table' and i ~= titleIndex and not v.hidden then
            local label = clean(v.header)
            if label == '' then label = clean(v.txt) end
            local item = UIMenuItem.New(label ~= '' and label or ' ', clean(v.txt))
            -- kolejne naglowki to etykiety sekcji: widoczne, nie do wybrania
            if v.isMenuHeader or v.disabled then item:Enabled(false) end
            menu:AddItem(item)
            entries[#entries + 1] = v
            if v.params and v.params.navActive then navActive = #entries end
        end
    end
    if #entries == 0 then
        local empty = UIMenuItem.New('Brak opcji', '')
        empty:Enabled(false)
        menu:AddItem(empty)
    end

    menu.OnItemSelect = function(_, _, index)
        local v = entries[index]
        if not v or not v.params then return end
        -- zamykamy PRZED wywolaniem eventu, bo wiekszosc zasobow otwiera z niego podmenu
        if not v.params.keepOpen then closeCurrent(true) end
        dispatch(v.params)
    end

    -- navSelect: pozycja odpala sie juz przy podswietleniu (dawny podglad aut w garazu)
    menu.OnIndexChange = function(_, index)
        local v = entries[index]
        if v and v.params and v.params.navSelect then dispatch(v.params) end
    end

    -- Backspace / ESC / prawy przycisk: to jedyne zamkniecie, o ktorym mowimy innym
    menu.OnMenuClose = function()
        if current == menu then current = nil end
        if not suppressClosed then TriggerEvent('qb-menu:client:menuClosed') end
    end

    current = menu
    menu:Visible(true)
    if navActive then menu:CurrentSelection(navActive) end
end

local function closeMenu()
    hideHeader()
    closeCurrent(false)
end

-- Dawne "pokaz sam naglowek" (salon, lombard, mieszkania, teleporty): zamiast plywajacego
-- przycisku pokazujemy podpowiedz [E] i otwieramy pelne menu po E. Znika po closeMenu().
local function showHeader(data)
    if type(data) ~= 'table' or not next(data) then return end
    closeCurrent(true)

    local label = ''
    for i = 1, #data do
        local v = data[i]
        if type(v) == 'table' and not v.hidden and not v.isMenuHeader then
            label = clean(v.header)
            if label ~= '' then break end
        end
    end
    if label == '' and type(data[1]) == 'table' then label = clean(data[1].header) end

    headerData = data
    exports['qb-core']:DrawText(('[E] %s'):format(label ~= '' and label or 'Menu'), 'left')

    CreateThread(function()
        while headerData == data do
            if not current and IsControlJustReleased(0, 38) then
                headerData = nil
                exports['qb-core']:HideText()
                openMenu(data)
                return
            end
            Wait(0)
        end
    end)
end

-- Events

RegisterNetEvent('qb-menu:client:openMenu', function(data, sort, skipFirst, options)
    openMenu(data, sort, skipFirst, options)
end)

RegisterNetEvent('qb-menu:client:closeMenu', closeMenu)
RegisterNetEvent('qb-menu:closeMenu', closeMenu) -- qb-management woli te nazwe

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then closeMenu() end
end)

-- Exports

exports('openMenu', openMenu)
exports('closeMenu', closeMenu)
exports('showHeader', showHeader)
