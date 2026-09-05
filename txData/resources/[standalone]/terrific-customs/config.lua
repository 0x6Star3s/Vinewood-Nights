Config = {}

-- nil = warsztat dla wszystkich. Lista nazw prac ogranicza dostep, np. { 'bennys', 'mechanic' }
Config.RequiredJobs = nil

-- Skad mozna placic, w tej kolejnosci
Config.PaymentAccounts = { 'cash', 'bank' }

-- Kto moze zarzadzac punktami warsztatow w grze (komenda /warsztaty).
-- Praca musi miec isboss = true, admini wchodza zawsze.
Config.ManagerJobs        = { 'mechanic' }
Config.ManagerAdminGroups = { 'admin', 'god' }
Config.ManagerCommand     = 'warsztaty'
Config.DefaultRadius      = 8.0

-- Zestaw startowy. Po pierwszym zapisie prawda jest shops.json w folderze zasobu,
-- a ta tabela sluzy juz tylko jako seed przy pustym pliku.
Config.Shops = {
    { label = "Benny's Original Motor Works", coords = vec3(-205.4, -1311.0, 31.3),  radius = 8.0 },
    { label = 'Los Santos Customs - Burton',  coords = vec3(-337.0, -136.7, 39.0),   radius = 8.0 },
    { label = 'Los Santos Customs - La Mesa', coords = vec3(731.6, -1088.9, 22.2),   radius = 8.0 },
    { label = 'Los Santos Customs - Airport', coords = vec3(-1155.5, -2007.0, 13.2), radius = 8.0 },
    { label = 'Los Santos Customs - Route 68',coords = vec3(1174.9, 2640.5, 37.8),   radius = 8.0 },
    { label = 'Los Santos Customs - Paleto',  coords = vec3(110.6, 6626.1, 31.8),    radius = 8.0 },
}

-- Kamera orbitalna wokol auta (LPM = obrot, scroll = zoom, E = drzwi, V = widok)
Config.Camera = {
    enabled          = true,
    initial          = 5.0,
    min              = 2.5,
    max              = 10.0,
    scrollIncrements = 0.5,
}

Config.Prices = {
    -- osiagi: cena bazowa mnozona przez poziom (poziom 1 = 1x, poziom 4 = 4x)
    performance = {
        [11] = 6000,  -- silnik
        [12] = 3000,  -- hamulce
        [13] = 4000,  -- skrzynia biegow
        [15] = 3000,  -- zawieszenie
        [16] = 4000,  -- pancerz
        [18] = 12000, -- turbo
    },
    cosmetic    = 1500,
    wheels      = 2500,
    respray     = 1200,
    tint        = 800,
    xenon       = 1500,
    neon        = 2000,
    tyresmoke   = 1800,
    plate       = 500,
    bulletproof = 8000,
    ecu         = 9000, -- za kazdy poziom powyzej fabrycznego
    stance      = 3000, -- j.w.
    abs         = 15000,
    antilag     = 15000,
    traction    = 12000,
    repair      = 5000,
}

-- Komputer sterujacy (dawny tunerlaptop z qb-tunerchip, teraz zakladka w menu).
-- Kazdy suwak mnozy FABRYCZNA wartosc handlingu danego auta, a nie ustawia sztywnej
-- liczby - dzieki temu jeden zestaw poziomow dziala tak samo na kazdym samochodzie.
Config.Ecu = {
    {
        label = 'Moc silnika',
        desc  = 'Sila napedu. Fabrycznie 1.00x.',
        field = 'fInitialDriveForce',
        mult  = { 1.00, 1.08, 1.16, 1.23, 1.30 },
    },
    {
        label = 'Przyspieszenie',
        desc  = 'Bezwladnosc napedu - szybsze reakcje na gaz.',
        field = 'fDriveInertia',
        mult  = { 1.00, 1.06, 1.12, 1.18, 1.25 },
    },
    -- Hamulcow tu nie ma celowo: fBrakeForce zapisuje i przywraca qb-vehiclefailure
    -- przy kazdym wsiadaniu, wiec bilismy sie o to samo pole. Hamulce sa i tak
    -- w zakladce Osiagi jako fabryczny mod nr 12.
    {
        label = 'Przyczepnosc',
        desc  = 'Maksymalna przyczepnosc opon.',
        field = 'fTractionCurveMax',
        mult  = { 1.00, 1.04, 1.08, 1.11, 1.15 },
    },
    {
        -- fDriveBiasFront: 0.0 = tyl, 0.5 = 4x4, 1.0 = przod. Tu ustawiamy wprost,
        -- bo to rozklad napedu, a nie parametr ktory ma sens mnozyc.
        label    = 'Naped',
        desc     = 'Rozklad napedu na osie.',
        field    = 'fDriveBiasFront',
        absolute = { false, 0.0, 0.5, 1.0 },
        names    = { 'Fabryczny', 'Tylny (RWD)', 'Na cztery kola (AWD)', 'Przedni (FWD)' },
    },
}

-- Dystanse i pochylenie kol. Wartosci sa DODAWANE do fabrycznego ustawienia kola,
-- osobno dla przodu i tylu, symetrycznie na obie strony.
Config.Stance = {
    {
        label  = 'Dystanse przod',
        desc   = 'Rozstaw przednich kol na zewnatrz.',
        key    = 'frontSpacing',
        values = { 0.0, 0.02, 0.04, 0.06, 0.08, 0.10 },
    },
    {
        label  = 'Dystanse tyl',
        desc   = 'Rozstaw tylnych kol na zewnatrz.',
        key    = 'rearSpacing',
        values = { 0.0, 0.02, 0.04, 0.06, 0.08, 0.10 },
    },
    {
        label  = 'Pochylenie przod',
        desc   = 'Ujemny camber przednich kol.',
        key    = 'frontCamber',
        values = { 0.0, 0.03, 0.06, 0.09, 0.12, 0.15 },
    },
    {
        label  = 'Pochylenie tyl',
        desc   = 'Ujemny camber tylnych kol.',
        key    = 'rearCamber',
        values = { 0.0, 0.03, 0.06, 0.09, 0.12, 0.15 },
    },
}

-- ABS. Ksztalt tabeli taki sam jak Config.Stance, zeby serwer walidowal go tym
-- samym kodem - stad jednoelementowa lista zamiast zwyklego boola.
Config.Abs = {
    {
        label  = 'ABS',
        desc   = 'Puszcza hamulec gdy kola sie blokuja - auto hamuje krocej i da sie skrecac.',
        values = { false, true },
        names  = { 'Brak', 'Zamontowany' },
    },
}

-- Antilag (strzaly z wydechu). Ta sama mechanika co ABS: nic nie robi z pojazdem,
-- tylko odblokowuje zasob terrific-antilag na tym aucie.
Config.Antilag = {
    {
        label  = 'Antilag',
        desc   = 'Strzaly i plomienie z wydechu przy zdejmowaniu gazu na wysokich obrotach.',
        values = { false, true },
        names  = { 'Brak', 'Zamontowany' },
    },
}

-- Kontrola trakcji. Tnie moment obrotowy, gdy kola buksuja. Kierowca moze ja wylaczyc
-- w aucie (radialne menu -> Kontrola trakcji), tak jak przyciskiem TC OFF w prawdziwym aucie.
Config.Traction = {
    {
        label  = 'Kontrola trakcji',
        desc   = 'Tnie moc, gdy kola buksuja. W aucie wylaczysz ja radialnym menu.',
        values = { false, true },
        names  = { 'Brak', 'Zamontowana' },
    },
}

Config.TractionMinSpeed  = 2.0  -- m/s, ponizej nie ingeruje (ruszanie, manewrowanie)
Config.TractionSlipRatio = 1.25 -- kolo szybsze niz tyle x predkosc auta = buksuje
Config.TractionCut       = 0.35 -- mnoznik momentu w chwili buksowania

-- Kontrolki na ekranie, jak na desce rozdzielczej: przygaszone = system zamontowany,
-- jasne = wlasnie dziala. Przesun x/y, jesli zaslaniaja Twoj HUD.
Config.Telltales = {
    enabled = true,
    x       = 0.217, -- pod srodkiem tarczy licznika; kolejne kontrolki ida w prawo co 0.030
    y       = 0.938, -- ponizej tarczy licznika; ikony gracza koncza sie na x ~0.19, wiec nie koliduja
}

Config.AbsMinSpeed  = 4.0  -- m/s, ponizej ABS nie ingeruje (manewrowanie, cofanie)
Config.AbsLockRatio = 0.45 -- kolo wolniejsze niz tyle x predkosc auta = zablokowane

-- Jedno zrodlo prawdy dla klienta (podglad ceny) i serwera (pobranie kasy)
function Config.PriceOf(category, mod, index)
    if index and index < 0 then return 0 end -- czesc fabryczna = za darmo

    -- ECU: poziom 1 (index 0) jest fabryczny i darmowy, kazdy kolejny kosztuje krotnosc bazy
    if category == 'ecu' then
        return Config.Prices.ecu * (index or 0)
    end

    if category == 'stance' then
        return Config.Prices.stance * (index or 0)
    end

    if category == 'abs' then
        return Config.Prices.abs * (index or 0)
    end

    if category == 'antilag' then
        return Config.Prices.antilag * (index or 0)
    end

    if category == 'traction' then
        return Config.Prices.traction * (index or 0)
    end

    if category == 'performance' then
        local base = Config.Prices.performance[mod]
        if not base then return nil end
        return base * ((index or 0) + 1)
    end

    return Config.Prices[category]
end
