local QBCore = exports['qb-core']:GetCoreObject()

local BANNER = 'shopui_title_carmod' -- dict i tekstura maja te sama nazwe

local PERFORMANCE = {
    { label = 'Silnik',          mod = 11, desc = 'Wieksza moc i przyspieszenie.' },
    { label = 'Hamulce',         mod = 12, desc = 'Krotsza droga hamowania.' },
    { label = 'Skrzynia biegow', mod = 13, desc = 'Szybsza zmiana przelozen.' },
    { label = 'Zawieszenie',     mod = 15, desc = 'Nizsze nadwozie, lepsze prowadzenie.' },
    { label = 'Pancerz',         mod = 16, desc = 'Wieksza odpornosc nadwozia.' },
    { label = 'Turbo',           mod = 18, toggle = true, desc = 'Doladowanie. Wymagane do strzalow z wydechu.' },
}

local COSMETIC = {
    { label = 'Spojler',             mod = 0 },
    { label = 'Zderzak przedni',     mod = 1 },
    { label = 'Zderzak tylny',       mod = 2 },
    { label = 'Progi',               mod = 3 },
    { label = 'Wydech',              mod = 4 },
    { label = 'Klatka / raty',       mod = 5 },
    { label = 'Grill',               mod = 6 },
    { label = 'Maska',               mod = 7 },
    { label = 'Blotniki',            mod = 8 },
    { label = 'Blotniki prawe',      mod = 9 },
    { label = 'Dach',                mod = 10 },
    { label = 'Klakson',             mod = 14 },
    { label = 'Ramka tablicy',       mod = 25 },
    { label = 'Tablice ozdobne',     mod = 26 },
    { label = 'Wykonczenie wnetrza', mod = 27 },
    { label = 'Ozdoby',              mod = 28 },
    { label = 'Deska rozdzielcza',   mod = 29 },
    { label = 'Zegary',              mod = 30 },
    { label = 'Glosniki w drzwiach', mod = 31 },
    { label = 'Fotele',              mod = 32 },
    { label = 'Kierownica',          mod = 33 },
    { label = 'Galka biegow',        mod = 34 },
    { label = 'Plakietki',           mod = 35 },
    { label = 'Glosniki',            mod = 36 },
    { label = 'Bagaznik',            mod = 37 },
    { label = 'Hydraulika',          mod = 38 },
    { label = 'Blok silnika',        mod = 39 },
    { label = 'Filtr powietrza',     mod = 40 },
    { label = 'Rozporki',            mod = 41 },
    { label = 'Nakladki nadkoli',    mod = 42 },
    { label = 'Anteny',              mod = 43 },
    { label = 'Wykonczenia',         mod = 44 },
    { label = 'Zbiornik paliwa',     mod = 45 },
    { label = 'Szyby',               mod = 46 },
    { label = 'Malowanie (livery)',  mod = 48 },
}

-- Pelna lista typow felg z GTA V (0-12). Poprzednia wersja miala tylko 0-8 i zle etykiety.
local WHEEL_TYPES = {
    { label = 'Sportowe',         id = 0 },
    { label = 'Muscle',           id = 1 },
    { label = 'Lowrider',         id = 2 },
    { label = 'SUV',              id = 3 },
    { label = 'Offroad',          id = 4 },
    { label = 'Tuning',           id = 5 },
    { label = 'Motocyklowe',      id = 6 },
    { label = 'High End',         id = 7 },
    { label = "Benny's Original", id = 8 },
    { label = "Benny's Bespoke",  id = 9 },
    { label = 'Open Wheel',       id = 10 },
    { label = 'Uliczne',          id = 11 },
    { label = 'Torowe',           id = 12 },
}

local COLORS = {
    { label = 'Czarny', id = 0 },           { label = 'Grafitowy', id = 1 },
    { label = 'Metaliczny szary', id = 3 }, { label = 'Srebrny', id = 4 },
    { label = 'Stalowy szary', id = 6 },    { label = 'Ciemnoczerwony', id = 11 },
    { label = 'Czerwony', id = 27 },        { label = 'Pomaranczowy', id = 36 },
    { label = 'Limonkowy', id = 42 },       { label = 'Ciemnozielony', id = 49 },
    { label = 'Morski', id = 64 },          { label = 'Niebieski', id = 70 },
    { label = 'Jasnoniebieski', id = 73 },  { label = 'Granatowy', id = 77 },
    { label = 'Zolty', id = 88 },           { label = 'Bialy', id = 111 },
    { label = 'Kosc sloniowa', id = 112 },  { label = 'Fioletowy', id = 145 },
}

local TINTS = {
    { label = 'Brak', id = 0 },       { label = 'Czarne', id = 1 },
    { label = 'Ciemny dym', id = 2 }, { label = 'Jasny dym', id = 3 },
    { label = 'Fabryczne', id = 4 },  { label = 'Limuzyna', id = 5 },
    { label = 'Zielone', id = 6 },
}

local XENON = {
    'Bialy', 'Niebieski', 'Elektryczny niebieski', 'Mietowy', 'Limonkowy', 'Zolty', 'Zloty',
    'Pomaranczowy', 'Czerwony', 'Rozowy pastelowy', 'Goracy roz', 'Fioletowy', 'Czarny',
}

local RGB = {
    { label = 'Bialy',        r = 255, g = 255, b = 255 },
    { label = 'Czerwony',     r = 255, g = 0,   b = 0 },
    { label = 'Pomaranczowy', r = 255, g = 128, b = 0 },
    { label = 'Zolty',        r = 255, g = 255, b = 0 },
    { label = 'Zielony',      r = 0,   g = 255, b = 0 },
    { label = 'Morski',       r = 0,   g = 255, b = 255 },
    { label = 'Niebieski',    r = 0,   g = 0,   b = 255 },
    { label = 'Fioletowy',    r = 128, g = 0,   b = 255 },
    { label = 'Rozowy',       r = 255, g = 0,   b = 255 },
}

local PLATE_STYLES = {
    { label = 'Niebiesko-biale', id = 0 },  { label = 'Zolto-czarne', id = 1 },
    { label = 'Zolto-niebieskie', id = 2 }, { label = 'Bialo-niebieskie', id = 3 },
    { label = 'Yankton', id = 4 },
}

local currentShop, promptOpen
local veh, saved, shopOpen
local paying = false -- lib.callback.await yielduje; bez tego spam Enterem placi kilka razy

local function money(amount)
    return ('$%s'):format(amount or 0)
end

local function notify(msg, kind)
    QBCore.Functions.Notify(msg, kind or 'primary')
end

local function pay(category, mod, index)
    return lib.callback.await('terrific-customs:server:pay', false, category, mod, index)
end

local function modLabel(modType, index)
    local label = GetLabelText(GetModTextLabel(veh, modType, index))
    if not label or label == '' or label == 'NULL' then
        label = ('Wariant %s'):format(index + 1)
    end
    return label
end

-- Migawka stanu OPLACONEGO. Podglad moze isc dowolnie daleko - przy wyjsciu
-- wracamy do tej migawki, wiec niezatwierdzone zmiany znikaja i nie kosztuja.
local function commit()
    saved = lib.getVehicleProperties(veh)
end

local function revert()
    if saved and DoesEntityExist(veh) then
        lib.setVehicleProperties(veh, saved)
    end
end


--- Pozycja ze strzalkami: <- / -> = podglad na aucie, Enter = kupno.
---@param label string
---@param desc string
---@param entries table lista { text, price, category, mod, index, apply }
---@param current number indeks startowy (1-based)
local function listItem(label, desc, entries, current)
    -- UIMenuListItem dziedziczy po UIMenuDynamicListItem, ktory rzuca bledem na
    -- RightLabel - cena musi siedziec w samej wartosci miedzy strzalkami.
    -- LeftBadge nie jest blokowany, wiec ikonka auta zostaje.
    local texts = {}
    for i = 1, #entries do
        local entry = entries[i]
        texts[i] = (entry.price or 0) > 0
            and ('%s  %s'):format(entry.text, money(entry.price))
            or entry.text
    end

    current = (current and current >= 1 and current <= #entries) and current or 1

    local item = UIMenuListItem.New(label, texts, current, desc)
    if current > 1 then item:LeftBadge(BadgeStyle.CAR) end

    local bought = current

    item.OnListChanged = function(_, _, index)
        entries[index].apply()
    end

    item.OnListSelected = function(_, it, index)
        if paying then return end
        local entry = entries[index]

        if (entry.price or 0) > 0 then
            paying = true
            local ok = pay(entry.category, entry.mod, entry.index)
            paying = false

            if not ok then
                notify('Nie stac Cie na te czesc.', 'error')
                it:Index(bought)
                entries[bought].apply()
                return
            end
        end

        entry.apply()
        bought = index
        if entry.commit then entry.commit() end
        commit()
        it:LeftBadge(index > 1 and BadgeStyle.CAR or BadgeStyle.NONE)
        notify(('%s: gotowe.'):format(label), 'success')
    end

    return item
end

local function newMenu(title, subtitle)
    local menu = UIMenu.New(title, subtitle, 50, 50, true, BANNER, BANNER, false)
    menu:MaxItemsOnScreen(10)
    -- Kolko myszy zostaje kamerze. ScaleformUI czyta 241/242 (CursorScroll), a dragcam
    -- 14/15 (WeaponWheel) - to ten sam fizyczny scroll, wiec bez tego menu przewijalo
    -- sie razem z zoomem. Po liscie chodzi sie strzalkami (172/173), te dzialaja dalej.
    menu:MouseWheelControlEnabled(false)
    return menu
end

-- ---------- kategorie ----------

local function modEntries(part, category)
    local entries = { {
        text = 'Fabryczne', price = 0, category = category, mod = part.mod, index = -1,
        apply = function()
            SetVehicleModKit(veh, 0)
            if part.toggle then
                ToggleVehicleMod(veh, part.mod, false)
            else
                SetVehicleMod(veh, part.mod, -1, false)
            end
        end,
    } }

    if part.toggle then
        entries[2] = {
            text = 'Zamontowane', price = Config.PriceOf(category, part.mod, 0),
            category = category, mod = part.mod, index = 0,
            apply = function()
                SetVehicleModKit(veh, 0)
                ToggleVehicleMod(veh, part.mod, true)
            end,
        }
        return entries
    end

    for i = 0, GetNumVehicleMods(veh, part.mod) - 1 do
        local index = i
        entries[#entries + 1] = {
            text = category == 'performance' and ('Poziom %s'):format(index + 1) or modLabel(part.mod, index),
            price = Config.PriceOf(category, part.mod, index),
            category = category, mod = part.mod, index = index,
            apply = function()
                SetVehicleModKit(veh, 0)
                SetVehicleMod(veh, part.mod, index, false)
            end,
        }
    end

    return entries
end

local function partsMenu(title, parts, category)
    local menu = newMenu(title, 'STRZALKI = PODGLAD, ENTER = KUP')

    for _, part in ipairs(parts) do
        local available = part.toggle and 1 or GetNumVehicleMods(veh, part.mod)
        if available > 0 then
            local current = part.toggle
                and (IsToggleModOn(veh, part.mod) and 2 or 1)
                or (GetVehicleMod(veh, part.mod) + 2)
            menu:AddItem(listItem(part.label, part.desc or '', modEntries(part, category), current))
        end
    end

    if #menu.Items == 0 then
        menu:AddItem(UIMenuItem.New('Ten pojazd nie ma tu nic do zmiany'))
    end

    return menu
end

local function wheelsMenu()
    local menu = newMenu('Felgi', 'STRZALKI = PODGLAD, ENTER = KUP')
    local originalType = GetVehicleWheelType(veh)
    local originalMod = GetVehicleMod(veh, 23)

    for _, wheelType in ipairs(WHEEL_TYPES) do
        SetVehicleModKit(veh, 0)
        SetVehicleWheelType(veh, wheelType.id)

        local count = GetNumVehicleMods(veh, 23)
        if count > 0 then
            local entries = { {
                text = 'Fabryczne', price = 0, category = 'wheels', mod = 23, index = -1,
                apply = function()
                    SetVehicleModKit(veh, 0)
                    SetVehicleWheelType(veh, wheelType.id)
                    SetVehicleMod(veh, 23, -1, false)
                    SetVehicleMod(veh, 24, -1, false)
                end,
            } }

            for i = 0, count - 1 do
                local index = i
                entries[#entries + 1] = {
                    text = modLabel(23, index), price = Config.PriceOf('wheels'),
                    category = 'wheels', mod = 23, index = index,
                    apply = function()
                        SetVehicleModKit(veh, 0)
                        SetVehicleWheelType(veh, wheelType.id)
                        SetVehicleMod(veh, 23, index, false)
                        SetVehicleMod(veh, 24, index, false) -- tylne kola motocykli
                    end,
                }
            end

            local current = (wheelType.id == originalType) and (GetVehicleMod(veh, 23) + 2) or 1
            menu:AddItem(listItem(wheelType.label, ('%s modeli'):format(count), entries, current))
        end
    end

    -- przelaczanie typow bylo potrzebne, zeby policzyc modele - teraz cofamy oba pola,
    -- inaczej auto zostaje z ostatnim testowanym typem felg
    SetVehicleModKit(veh, 0)
    SetVehicleWheelType(veh, originalType)
    SetVehicleMod(veh, 23, originalMod, false)
    SetVehicleMod(veh, 24, originalMod, false)

    if #menu.Items == 0 then
        menu:AddItem(UIMenuItem.New('Ten pojazd nie ma felg do zmiany'))
    end

    return menu
end

local function colorEntries(slot)
    local entries = {}
    for _, color in ipairs(COLORS) do
        entries[#entries + 1] = {
            text = color.label, price = Config.PriceOf('respray'), category = 'respray',
            apply = function()
                local primary, secondary = GetVehicleColours(veh)
                if slot == 'primary' then
                    SetVehicleColours(veh, color.id, secondary)
                else
                    SetVehicleColours(veh, primary, color.id)
                end
            end,
        }
    end
    return entries
end

local function paintMenu()
    local menu = newMenu('Lakier', 'STRZALKI = PODGLAD, ENTER = KUP')
    menu:AddItem(listItem('Kolor podstawowy', 'Glowny kolor nadwozia.', colorEntries('primary'), 1))
    menu:AddItem(listItem('Kolor dodatkowy', 'Detale i pasy.', colorEntries('secondary'), 1))
    return menu
end

local function extrasMenu()
    local menu = newMenu('Oswietlenie i dodatki', 'STRZALKI = PODGLAD, ENTER = KUP')

    local tints = {}
    for _, tint in ipairs(TINTS) do
        tints[#tints + 1] = {
            text = tint.label, price = tint.id == 0 and 0 or Config.PriceOf('tint'), category = 'tint',
            apply = function() SetVehicleWindowTint(veh, tint.id) end,
        }
    end
    menu:AddItem(listItem('Przyciemniane szyby', 'Folia na szybach.', tints, 1))

    local xenons = { {
        text = 'Fabryczne', price = 0, category = 'xenon',
        apply = function()
            SetVehicleModKit(veh, 0)
            ToggleVehicleMod(veh, 22, false)
        end,
    } }
    for i = 1, #XENON do
        local colorId = i - 1
        xenons[#xenons + 1] = {
            text = XENON[i], price = Config.PriceOf('xenon'), category = 'xenon',
            apply = function()
                SetVehicleModKit(veh, 0)
                ToggleVehicleMod(veh, 22, true)
                SetVehicleHeadlightsColour(veh, colorId)
            end,
        }
    end
    menu:AddItem(listItem('Ksenony', 'Kolor swiatel przednich.', xenons, 1))

    local neons = { {
        text = 'Wylaczone', price = 0, category = 'neon',
        apply = function()
            for side = 0, 3 do SetVehicleNeonLightEnabled(veh, side, false) end
        end,
    } }
    for _, color in ipairs(RGB) do
        neons[#neons + 1] = {
            text = color.label, price = Config.PriceOf('neon'), category = 'neon',
            apply = function()
                for side = 0, 3 do SetVehicleNeonLightEnabled(veh, side, true) end
                SetVehicleNeonLightsColour(veh, color.r, color.g, color.b)
            end,
        }
    end
    menu:AddItem(listItem('Neony', 'Podswietlenie podwozia z czterech stron.', neons, 1))

    local smoke = { {
        text = 'Brak', price = 0, category = 'tyresmoke',
        apply = function()
            SetVehicleModKit(veh, 0)
            ToggleVehicleMod(veh, 20, false)
        end,
    } }
    for _, color in ipairs(RGB) do
        smoke[#smoke + 1] = {
            text = color.label, price = Config.PriceOf('tyresmoke'), category = 'tyresmoke',
            apply = function()
                SetVehicleModKit(veh, 0)
                ToggleVehicleMod(veh, 20, true)
                SetVehicleTyreSmokeColor(veh, color.r, color.g, color.b)
            end,
        }
    end
    menu:AddItem(listItem('Dym z opon', 'Kolor dymu przy buksowaniu.', smoke, 1))

    local plates = {}
    for _, style in ipairs(PLATE_STYLES) do
        plates[#plates + 1] = {
            text = style.label, price = Config.PriceOf('plate'), category = 'plate',
            apply = function() SetVehicleNumberPlateTextIndex(veh, style.id) end,
        }
    end
    menu:AddItem(listItem('Tablice rejestracyjne', 'Wzor tablicy.', plates,
        GetVehicleNumberPlateTextIndex(veh) + 1))

    menu:AddItem(listItem('Opony kuloodporne', 'Opony nie lapia gumy od strzalow.', {
        { text = 'Zwykle', price = 0, category = 'bulletproof',
          apply = function() SetVehicleTyresCanBurst(veh, true) end },
        { text = 'Kuloodporne', price = Config.PriceOf('bulletproof'), category = 'bulletproof',
          apply = function() SetVehicleTyresCanBurst(veh, false) end },
    }, GetVehicleTyresCanBurst(veh) and 1 or 2))

    return menu
end

-- ---------- komputer sterujacy (dawny tunerlaptop) ----------

local ecuBaseline = {} -- entity -> { [pole handlingu] = wartosc fabryczna }
local ecuPaid     = {} -- entity -> oplacone poziomy
local ecuPreview           -- poziomy widoczne w podgladzie, zerowane przy wejsciu do warsztatu
local absPaid   = {}       -- entity -> { 1 = brak, 2 = zamontowany }

--- Fabryczna wartosc pola. Czytamy raz na pojazd i juz nigdy jej nie nadpisujemy,
--- inaczej kolejne tuningi mnozylyby sie po sobie.
local function ecuStock(vehicle, field)
    local store = ecuBaseline[vehicle]
    if not store then
        store = {}
        ecuBaseline[vehicle] = store
    end
    if store[field] == nil then
        store[field] = GetVehicleHandlingFloat(vehicle, 'CHandlingData', field)
    end
    return store[field]
end

local function levelDefaults(knobs)
    local levels = {}
    for i = 1, #knobs do levels[i] = 1 end
    return levels
end

local function levelCopy(knobs, levels)
    local copy = {}
    for i = 1, #knobs do copy[i] = levels[i] or 1 end
    return copy
end

local function applyEcu(vehicle, levels)
    if not DoesEntityExist(vehicle) then return end

    for i, knob in ipairs(Config.Ecu) do
        local level = levels[i] or 1
        local stock = ecuStock(vehicle, knob.field)
        local value

        if knob.absolute then
            local target = knob.absolute[level]
            value = (target == false) and stock or target
        else
            value = stock * (knob.mult[level] or 1.0)
        end

        SetVehicleHandlingFloat(vehicle, 'CHandlingData', knob.field, value + 0.0)
    end
end

local function ecuMenu()
    local menu = newMenu('Komputer sterujacy', 'STRZALKI = PODGLAD, ENTER = KUP')
    local paid = ecuPaid[veh] or levelDefaults(Config.Ecu)

    for i, knob in ipairs(Config.Ecu) do
        local knobIndex = i
        local count = knob.mult and #knob.mult or #knob.absolute
        local entries = {}

        for level = 1, count do
            local lvl = level
            entries[level] = {
                text     = knob.names and knob.names[lvl] or ('Poziom %s'):format(lvl),
                price    = Config.PriceOf('ecu', nil, lvl - 1),
                category = 'ecu',
                index    = lvl - 1,
                apply    = function()
                    ecuPreview[knobIndex] = lvl
                    applyEcu(veh, ecuPreview)
                end,
                commit   = function()
                    ecuPaid[veh] = levelCopy(Config.Ecu, ecuPreview)
                    TriggerServerEvent('terrific-customs:server:saveTune',
                        GetVehicleNumberPlateText(veh), 'ecu', ecuPaid[veh])
                end,
            }
        end

        menu:AddItem(listItem(knob.label, knob.desc, entries, paid[i] or 1))
    end

    -- ABS siedzi w tej samej zakladce, bo to tez elektronika, ale ma wlasny rodzaj
    -- zapisu i nie dotyka handlingu - wlacza tylko petle pulsujaca hamulcem.
    local absKnob = Config.Abs[1]
    local absEntries = {}

    for level = 1, #absKnob.values do
        local lvl = level
        absEntries[level] = {
            text     = absKnob.names[lvl],
            price    = Config.PriceOf('abs', nil, lvl - 1),
            category = 'abs',
            index    = lvl - 1,
            -- ABS nic nie robi z pojazdem, wiec podglad nie ma czego pokazac -
            -- dziala dopiero po zakupie, przy hamowaniu w ruchu
            apply    = function() end,
            commit   = function()
                absPaid[veh] = { lvl }
                TriggerServerEvent('terrific-customs:server:saveTune',
                    GetVehicleNumberPlateText(veh), 'abs', absPaid[veh])
            end,
        }
    end

    menu:AddItem(listItem(absKnob.label, absKnob.desc, absEntries, (absPaid[veh] or { 1 })[1]))

    return menu
end

-- ---------- dystanse i pochylenie kol ----------

-- Natywki FiveM, bez vstancera. Wartosci dokladamy do fabrycznego ustawienia kola,
-- symetrycznie: lewe w minus, prawe w plus.
local stanceBaseline = {} -- entity -> { x = {..}, y = {..} }
local stancePaid     = {}
local stancePreview

local function stanceStock(vehicle)
    local store = stanceBaseline[vehicle]
    if store then return store end

    store = { x = {}, y = {} }
    for i = 0, GetVehicleNumberOfWheels(vehicle) - 1 do
        store.x[i] = GetVehicleWheelXOffset(vehicle, i)
        store.y[i] = GetVehicleWheelYRotation(vehicle, i)
    end

    stanceBaseline[vehicle] = store
    return store
end

local function applyStance(vehicle, levels)
    if not DoesEntityExist(vehicle) then return end

    local stock = stanceStock(vehicle)
    local value = {}
    for i, knob in ipairs(Config.Stance) do
        value[knob.key] = knob.values[levels[i] or 1] or 0.0
    end

    for i = 0, GetVehicleNumberOfWheels(vehicle) - 1 do
        local front = i < 2          -- 0/1 to przednia os, reszta liczy sie jako tyl
        local left  = (i % 2) == 0
        local spacing = front and value.frontSpacing or value.rearSpacing
        local camber  = front and value.frontCamber or value.rearCamber

        SetVehicleWheelXOffset(vehicle, i, stock.x[i] + (left and -spacing or spacing))
        SetVehicleWheelYRotation(vehicle, i, stock.y[i] + (left and -camber or camber))
    end
end

local function stanceMenu()
    local menu = newMenu('Dystanse i pochylenie', 'STRZALKI = PODGLAD, ENTER = KUP')
    local paid = stancePaid[veh] or levelDefaults(Config.Stance)

    for i, knob in ipairs(Config.Stance) do
        local knobIndex = i
        local entries = {}

        for level = 1, #knob.values do
            local lvl = level
            entries[level] = {
                text     = lvl == 1 and 'Fabrycznie' or ('+%.2f'):format(knob.values[lvl]),
                price    = Config.PriceOf('stance', nil, lvl - 1),
                category = 'stance',
                index    = lvl - 1,
                apply    = function()
                    stancePreview[knobIndex] = lvl
                    applyStance(veh, stancePreview)
                end,
                commit   = function()
                    stancePaid[veh] = levelCopy(Config.Stance, stancePreview)
                    TriggerServerEvent('terrific-customs:server:saveTune',
                        GetVehicleNumberPlateText(veh), 'stance', stancePaid[veh])
                end,
            }
        end

        menu:AddItem(listItem(knob.label, knob.desc, entries, paid[i] or 1))
    end

    return menu
end

-- ABS: gdy przy hamowaniu kolo kreci sie znacznie wolniej niz jedzie auto, znaczy ze
-- sie zablokowalo - puszczamy hamulec na ta klatke i kolo znow lapie przyczepnosc.
-- Stan hamulca czytamy przez IsDisabledControlPressed, bo sami go tu wylaczamy
-- i zwykly IsControlPressed zwracalby wtedy false, przerywajac pulsowanie.
CreateThread(function()
    while true do
        local wait = 250
        local vehicle = GetVehiclePedIsIn(cache.ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == cache.ped
            and (absPaid[vehicle] or { 1 })[1] == 2 then
            wait = 0

            local speed = GetEntitySpeed(vehicle)

            -- tylko przy jezdzie do przodu, inaczej zablokowalibysmy cofanie
            if speed > Config.AbsMinSpeed and GetEntitySpeedVector(vehicle, true).y > 0.0
                and IsDisabledControlPressed(0, 72) then

                local locked = false
                for i = 0, GetVehicleNumberOfWheels(vehicle) - 1 do
                    if math.abs(GetVehicleWheelSpeed(vehicle, i)) < speed * Config.AbsLockRatio then
                        locked = true
                        break
                    end
                end

                if locked then
                    DisableControlAction(0, 72, true)
                    SetVehicleBrakeLights(vehicle, true) -- swiatla maja sie palic mimo pulsowania
                end
            end
        end

        Wait(wait)
    end
end)

local function stanceIsStock(levels)
    for i = 1, #Config.Stance do
        if (levels[i] or 1) ~= 1 then return false end
    end
    return true
end

-- Gra przelicza pozycje kol przy kazdej aktualizacji fizyki i kasuje nasze offsety -
-- dlatego stance bylo widac tylko na postoju, a w ruchu kola wracaly do fabrycznych.
-- Jedyne wyjscie to nakladac je co klatke; dokladnie to robi vstancer. Dotyczy tylko
-- auta pod graczem, czyli 8 natywek na klatke i to wylacznie gdy cos jest ustawione.
CreateThread(function()
    while true do
        local wait = 500
        local vehicle = GetVehiclePedIsIn(cache.ped, false)

        if vehicle ~= 0 then
            local levels = (shopOpen and veh == vehicle and stancePreview) or stancePaid[vehicle]

            if levels and not stanceIsStock(levels) then
                applyStance(vehicle, levels)
                wait = 0
            end
        end

        Wait(wait)
    end
end)

-- Ani handling, ani ustawienie kol nie sa czescia wlasciwosci pojazdu, wiec po
-- respawnie trzeba je nalozyc z powrotem. Pytamy serwer przy kazdej zmianie auta
-- pod kierowca. Fabryczne wartosci sa zapamietane per encja, wiec nic sie nie kumuluje.
CreateThread(function()
    local last = 0

    while true do
        Wait(1000)

        local vehicle = GetVehiclePedIsIn(cache.ped, false)

        if vehicle == 0 then
            last = 0
        elseif vehicle ~= last and GetPedInVehicleSeat(vehicle, -1) == cache.ped then
            last = vehicle

            local plate = GetVehicleNumberPlateText(vehicle)
            local stored = plate and lib.callback.await('terrific-customs:server:getTune', false, plate)

            if stored then
                if stored.ecu then
                    ecuPaid[vehicle] = levelCopy(Config.Ecu, stored.ecu)
                    applyEcu(vehicle, ecuPaid[vehicle])
                end
                if stored.stance then
                    stancePaid[vehicle] = levelCopy(Config.Stance, stored.stance)
                    applyStance(vehicle, stancePaid[vehicle])
                end
                if stored.abs then
                    absPaid[vehicle] = levelCopy(Config.Abs, stored.abs)
                end
            end
        end
    end
end)

-- ---------- menu glowne ----------

local function openShop(vehicle)
    veh = vehicle
    SetVehicleModKit(veh, 0)
    commit()
    ecuPreview = levelCopy(Config.Ecu, ecuPaid[veh] or levelDefaults(Config.Ecu))
    stancePreview = levelCopy(Config.Stance, stancePaid[veh] or levelDefaults(Config.Stance))

    local main = newMenu(currentShop and currentShop.label or 'Warsztat', 'TUNING')

    local submenus = {
        { title = 'Osiagi', desc = 'Silnik, hamulce, skrzynia, turbo.',
          build = function() return partsMenu('Osiagi', PERFORMANCE, 'performance') end },
        { title = 'Wyglad', desc = 'Zderzaki, spojlery, maski, wnetrze.',
          build = function() return partsMenu('Wyglad', COSMETIC, 'cosmetic') end },
        { title = 'Felgi', desc = 'Wszystkie 13 typow felg.', build = wheelsMenu },
        { title = 'Lakier', desc = 'Kolor podstawowy i dodatkowy.', build = paintMenu },
        { title = 'Oswietlenie i dodatki', desc = 'Szyby, ksenony, neony, dym, tablice.',
          build = extrasMenu },
        { title = 'Komputer sterujacy', desc = 'Moc, przyspieszenie, przyczepnosc, naped.',
          build = ecuMenu },
        { title = 'Dystanse i pochylenie', desc = 'Rozstaw kol i camber, przod i tyl osobno.',
          build = stanceMenu },
    }

    local targets = {}
    for _, sub in ipairs(submenus) do
        local item = UIMenuItem.New(sub.title, sub.desc)
        main:AddItem(item)
        targets[item] = sub.build()
    end

    local repairItem = UIMenuItem.New('Naprawa pojazdu', 'Blacharka, silnik i lakier na 100 procent.')
    repairItem:RightLabel(money(Config.PriceOf('repair')))
    main:AddItem(repairItem)

    main.OnItemSelect = function(menu, item)
        if targets[item] then
            menu:SwitchTo(targets[item], 1, true)
        elseif item == repairItem then
            if paying then return end
            paying = true
            local ok = pay('repair')
            paying = false
            if not ok then return notify('Nie stac Cie na naprawe.', 'error') end
            SetVehicleFixed(veh)
            SetVehicleDeformationFixed(veh)
            SetVehicleUndriveable(veh, false)
            SetVehicleEngineHealth(veh, 1000.0)
            SetVehicleBodyHealth(veh, 1000.0)
            commit()
            notify('Pojazd naprawiony.', 'success')
        end
    end

    shopOpen = true
    main:Visible(true)

    if Config.Camera.enabled then
        DragCam.start(veh, Config.Camera)
    end

    -- ScaleformUI nie daje jednego "zamknieto caly warsztat" - podmenu tez wolaja
    -- OnMenuClose. Dwa puste odczyty z rzedu = gracz naprawde wyszedl.
    CreateThread(function()
        local closed = 0
        while shopOpen do
            Wait(200)
            if MenuHandler:IsAnyMenuOpen() then
                closed = 0
            else
                closed = closed + 1
                if closed >= 2 then shopOpen = false end
            end
        end

        DragCam.stop()
        revert()
        -- kasujemy niezaplacony podglad: setVehicleProperties nie zna ani handlingu, ani kol
        applyEcu(veh, ecuPaid[veh] or levelDefaults(Config.Ecu))
        applyStance(veh, stancePaid[veh] or levelDefaults(Config.Stance))
        veh, saved, ecuPreview, stancePreview = nil, nil, nil, nil
    end)
end

-- ---------- strefy warsztatow ----------

local zones = {}
local shops = {}

local function canUseShop()
    if not Config.RequiredJobs then return true end

    local job = QBCore.Functions.GetPlayerData().job
    if not job then return false end

    for _, name in ipairs(Config.RequiredJobs) do
        if job.name == name then return true end
    end
    return false
end

local function isDriving()
    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= cache.ped then return false end
    return true, vehicle
end

local function clearPrompt()
    if promptOpen then
        promptOpen = false
        lib.hideTextUI()
    end
end

--- Strefy powstaja z listy z serwera, nie z Config.Shops - dzieki temu manager
--- moze dodawac i kasowac punkty bez restartu zasobu.
local function rebuildZones()
    for i = 1, #zones do zones[i]:remove() end
    zones = {}

    currentShop = nil
    clearPrompt()

    for _, entry in ipairs(shops) do
        local shop = entry
        zones[#zones + 1] = lib.zones.sphere({
            coords = vec3(shop.x, shop.y, shop.z),
            radius = shop.radius,
            onEnter = function() currentShop = shop end,
            onExit = function()
                currentShop = nil
                clearPrompt()
            end,
            inside = function()
                if shopOpen then return end

                local driving, vehicle = isDriving()
                local show = driving and canUseShop()

                if show ~= promptOpen then
                    promptOpen = show
                    if show then
                        lib.showTextUI(('[E] %s'):format(shop.label))
                    else
                        lib.hideTextUI()
                    end
                end

                if show and IsControlJustReleased(0, 38) then -- E
                    clearPrompt()
                    openShop(vehicle)
                end
            end,
        })
    end
end

RegisterNetEvent('terrific-customs:client:syncShops', function(list)
    shops = list or {}
    rebuildZones()
end)

-- Banner ladujemy osobno: lib.requestStreamedTextureDict czeka do 500 klatek,
-- a przez to strefy powstawaly z kilkusekundowym poslizgiem po starcie.
CreateThread(function()
    lib.requestStreamedTextureDict(BANNER)
end)

CreateThread(function()
    shops = lib.callback.await('terrific-customs:server:getShops', false) or {}
    rebuildZones()
end)

-- ---------- menu managera ----------

local function managerMenu()
    local menu = newMenu('Zarzadzanie warsztatami', 'PUNKTY TUNINGU')

    local addItem = UIMenuItem.New('Dodaj punkt tutaj',
        'Warsztat powstanie dokladnie tam, gdzie teraz stoisz.')
    addItem:RightLabel('+')
    menu:AddItem(addItem)

    local removable = {}

    if #shops == 0 then
        menu:AddItem(UIMenuItem.New('Brak punktow', 'Dodaj pierwszy pozycja wyzej.'))
    else
        for i, shop in ipairs(shops) do
            local distance = #(GetEntityCoords(cache.ped) - vec3(shop.x, shop.y, shop.z))
            local item = UIMenuItem.New(shop.label,
                ('Promien %.1f m, stad %d m. Enter usuwa ten punkt.'):format(shop.radius, math.floor(distance)))
            item:RightLabel('USUN')
            menu:AddItem(item)
            removable[item] = i
        end
    end

    menu.OnItemSelect = function(self, item)
        if item == addItem then
            self:Visible(false)

            local input = lib.inputDialog('Nowy warsztat', {
                { type = 'input',  label = 'Nazwa', required = true, max = 48 },
                { type = 'number', label = 'Promien (m)', default = Config.DefaultRadius, min = 2, max = 50 },
            })

            if not input or not input[1] then return end
            TriggerServerEvent('terrific-customs:server:addShop', input[1], input[2] or Config.DefaultRadius)
            notify('Punkt dodany.', 'success')
        elseif removable[item] then
            TriggerServerEvent('terrific-customs:server:removeShop', removable[item])
            self:Visible(false)
            notify('Punkt usuniety.', 'success')
        end
    end

    menu:Visible(true)
end

RegisterCommand('warsztatdebug', function()
    local coords = GetEntityCoords(cache.ped)
    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    local driver = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == cache.ped

    print(('[terrific-customs] stref: %s | punktow z serwera: %s'):format(#zones, #shops))
    print(('[terrific-customs] w pojezdzie: %s | za kierownica: %s | praca ok: %s')
        :format(vehicle ~= 0, driver, canUseShop()))
    print(('[terrific-customs] currentShop: %s | shopOpen: %s')
        :format(currentShop and currentShop.label or 'brak', tostring(shopOpen)))

    for i, shop in ipairs(shops) do
        local distance = #(coords - vec3(shop.x, shop.y, shop.z))
        print(('[terrific-customs] %s. %s - %.1f m (promien %.1f) %s')
            :format(i, shop.label, distance, shop.radius,
                distance <= shop.radius and '<< JESTES W SRODKU' or ''))
    end
end, false)

RegisterCommand(Config.ManagerCommand, function()
    -- CreateThread, bo lib.callback.await yielduje, a handler komendy sam w sobie
    -- nie jest korutyna
    CreateThread(function()
        -- serwer i tak sprawdza uprawnienia przy kazdym dodaniu i usunieciu;
        -- to pytanie jest tylko po to, zeby nie otwierac menu komus bez dostepu
        if not lib.callback.await('terrific-customs:server:isManager', false) then
            return notify('Nie masz uprawnien do zarzadzania warsztatami.', 'error')
        end
        managerMenu()
    end)
end, false)
