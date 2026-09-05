QBConfig = {}

QBConfig.MaxPlayers = GetConvarInt('sv_maxclients', 48) -- Gets max players from config file, default 48
QBConfig.DefaultSpawn = vector4(-1035.71, -2731.87, 12.86, 0.0)
QBConfig.UpdateInterval = 5 -- how often to update player data in minutes
QBConfig.StatusInterval = 5000 -- how often to check hunger/thirst status in milliseconds

QBConfig.Money = {}
QBConfig.Money.MoneyTypes = { cash = 500, bank = 5000, crypto = 0 } -- type = startamount - Add or remove money types for your server (for ex. blackmoney = 0), remember once added it will not be removed from the database!
QBConfig.Money.DontAllowMinus = { 'cash', 'crypto', 'bank' } -- Money that is not allowed going in minus (audyt ekonomii: bank schodzil na minus)
QBConfig.Money.PayCheckTimeOut = 10 -- The time in minutes that it will give the paycheck
QBConfig.Money.PayCheckSociety = false -- If true paycheck will come from the society account that the player is employed at, requires qb-management


-- ==========================================================================================
--  EKONOMIA - JEDNO MIEJSCE DO KRECENIA GALKAMI (audyt ekonomii 2026-09-02, wersja v2.1)
-- ==========================================================================================
--  MNOZNIK ZAROBKOW
--    QBConfig.Economy.Boost         <- x ile mnozone sa WSZYSTKIE dochody z pracy i aktywnosci
--    QBConfig.Economy.DefaultBoost  <- do tej wartosci wraca komenda /boost reset
--    Zmiana w locie (bez restartu, admin):
--        /boost 3        -> ustawia mnoznik na x3
--        /boost reset    -> wraca do DefaultBoost ponizej
--        /ekonomia       -> pokazuje aktualne ustawienia
--    NA PREMIERE: Boost = 1.0 i DevHeists = false, potem wipe sald.
--
--  CZEGO MNOZNIK NIE DOTYKA (celowo - to sa "sinks" albo przeplyw miedzy graczmi):
--    ceny w sklepach, pojazdy, paliwo, meble, przelewy, faktury, bankomat, komis,
--    konta firmowe (qb-management), crypto (qbit) i lupy z napadow (te sa ponizej osobno).
-- ==========================================================================================
QBConfig.Economy = {}
QBConfig.Economy.Boost = 3.0          -- 1.0 = ekonomia docelowa na premiere; dev: 3.0-4.0
QBConfig.Economy.DefaultBoost = 3.0   -- do czego wraca /boost reset
QBConfig.Economy.MinBoost = 1.0
QBConfig.Economy.MaxBoost = 4.0

--  NAPADY NA BANKI - stawki i cooldowny (cooldown w minutach)
--  DevHeists = true  -> szybkie wersje z fazy dev
--  DevHeists = false -> wartosci docelowe na premiere
QBConfig.Economy.DevHeists = true

QBConfig.Economy.Heists = {
    fleeca  = QBConfig.Economy.DevHeists and { payout = 35000,  cooldown = 60,  police = 3 }
                                          or { payout = 25000,  cooldown = 360, police = 3 },
    paleto  = QBConfig.Economy.DevHeists and { payout = 90000,  cooldown = 120, police = 5 }
                                          or { payout = 60000,  cooldown = 540, police = 5 },
    pacific = QBConfig.Economy.DevHeists and { payout = 240000, cooldown = 180, police = 6 }
                                          or { payout = 140000, cooldown = 720, police = 6 },
}

QBConfig.Player = {}
QBConfig.Player.HungerRate = 4.2 -- Rate at which hunger goes down.
QBConfig.Player.ThirstRate = 3.8 -- Rate at which thirst goes down.
QBConfig.Player.Bloodtypes = {
    "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-",
}

QBConfig.Server = {} -- General server config
QBConfig.Server.Closed = false -- Set server closed (no one can join except people with ace permission 'qbadmin.join')
QBConfig.Server.ClosedReason = "Server Closed" -- Reason message to display when people can't join the server
QBConfig.Server.Uptime = 0 -- Time the server has been up.
QBConfig.Server.Whitelist = false -- Enable or disable whitelist on the server
QBConfig.Server.WhitelistPermission = 'admin' -- Permission that's able to enter the server when the whitelist is on
QBConfig.Server.PVP = true -- Enable or disable pvp on the server (Ability to shoot other players)
QBConfig.Server.Discord = "" -- Discord invite link
QBConfig.Server.CheckDuplicateLicense = true -- Check for duplicate rockstar license on join
QBConfig.Server.Permissions = { 'god', 'admin', 'mod' } -- Add as many groups as you want here after creating them in your server.cfg

QBConfig.Commands = {} -- Command Configuration
QBConfig.Commands.OOCColor = {255, 151, 133} -- RGB color code for the OOC command

QBConfig.Notify = {}

QBConfig.Notify.NotificationStyling = {
    group = false, -- Allow notifications to stack with a badge instead of repeating
    position = "right", -- top-left | top-right | bottom-left | bottom-right | top | bottom | left | right | center
    progress = true -- Display Progress Bar
}

-- These are how you define different notification variants
-- The "color" key is background of the notification
-- The "icon" key is the css-icon code, this project uses `Material Icons` & `Font Awesome`
QBConfig.Notify.VariantDefinitions = {
    success = {
        classes = 'success',
        icon = 'task_alt'
    },
    primary = {
        classes = 'primary',
        icon = 'notifications'
    },
    error = {
        classes = 'error',
        icon = 'warning'
    },
    police = {
        classes = 'police',
        icon = 'local_police'
    },
    ambulance = {
        classes = 'ambulance',
        icon = 'fas fa-ambulance'
    }
}