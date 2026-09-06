Config = {}

-- Auto strzela dopiero z kupionym antilagiem (zakladka "Komputer sterujacy"
-- w terrific-customs, cena w Config.Prices.antilag). false = kazde auto.
Config.RequireMod = true

Config.Rpm           = 0.85  -- powyzej tylu obrotow puszczenie gazu daje strzal
Config.MinSpeed      = 5.0   -- m/s, zeby nie strzelalo na postoju
Config.FlameSize     = 1.5   -- powyzej 2.5 wyglada absurdalnie
Config.Cooldown      = 90    -- ms miedzy strzalami jednego gracza (limit tez po stronie serwera)
Config.BurstTime     = 450   -- jak dlugo auto strzela po zdjeciu nogi z gazu
Config.HearDistance  = 40.0  -- do ilu metrow slychac i widac
Config.Volume        = 0.7   -- glosnosc u zrodla, dalej cichnie liniowo

Config.ExhaustBones = { 'exhaust', 'exhaust_2', 'exhaust_3', 'exhaust_4' }
