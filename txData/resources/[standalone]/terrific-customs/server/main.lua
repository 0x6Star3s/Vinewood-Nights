local QBCore = exports['qb-core']:GetCoreObject()

local VALID_CATEGORIES = {
    performance = true,
    cosmetic = true,
    wheels = true,
    respray = true,
    tint = true,
    xenon = true,
    neon = true,
    tyresmoke = true,
    plate = true,
    bulletproof = true,
    ecu = true,
    stance = true,
    abs = true,
    repair = true,
}

-- Punkty warsztatow. Config.Shops sluzy tylko jako zestaw startowy - od pierwszego
-- zapisu prawda jest shops.json obok zasobu, dzieki czemu zmiany z gry przezywaja restart.
-- ponytail: plik zamiast tabeli w MySQL - nie ma migracji ani zaleznosci od oxmysql.
local SHOPS_FILE = 'shops.json'
local shops = {}

local function saveShops()
    SaveResourceFile(GetCurrentResourceName(), SHOPS_FILE, json.encode(shops, { indent = true }), -1)
end

local function loadShops()
    local raw = LoadResourceFile(GetCurrentResourceName(), SHOPS_FILE)
    local decoded = raw and json.decode(raw)

    if type(decoded) == 'table' and decoded[1] then
        shops = decoded
        return
    end

    for i, shop in ipairs(Config.Shops) do
        shops[i] = {
            label  = shop.label,
            x      = shop.coords.x,
            y      = shop.coords.y,
            z      = shop.coords.z,
            radius = shop.radius,
        }
    end
    saveShops()
end

-- Ustawienia komputera per tablica rejestracyjna. Handling nie jest czescia
-- wlasciwosci pojazdu, wiec po respawnie trzeba je nalozyc ponownie.
local TUNES_FILE = 'tunes.json'
local tunes = {}

local function saveTunes()
    SaveResourceFile(GetCurrentResourceName(), TUNES_FILE, json.encode(tunes), -1)
end

local function loadTunes()
    local raw = LoadResourceFile(GetCurrentResourceName(), TUNES_FILE)
    local decoded = raw and json.decode(raw)
    tunes = type(decoded) == 'table' and decoded or {}
end

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        loadShops()
        loadTunes()
    end
end)

local function isAtShop(src)
    local coords = GetEntityCoords(GetPlayerPed(src))

    for _, shop in ipairs(shops) do
        if #(coords - vec3(shop.x, shop.y, shop.z)) <= shop.radius + 5.0 then return true end
    end
    return false
end

local function hasJob(player)
    if not Config.RequiredJobs then return true end

    for _, name in ipairs(Config.RequiredJobs) do
        if player.PlayerData.job.name == name then return true end
    end
    return false
end

--- Manager = szef jednej z prac z Config.ManagerJobs albo admin.
local function isManager(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end

    -- HasPermission przyjmuje tabele uprawnien wprost
    if QBCore.Functions.HasPermission(src, Config.ManagerAdminGroups) then return true end

    local job = player.PlayerData.job
    if not job or not job.isboss then return false end

    for _, name in ipairs(Config.ManagerJobs) do
        if job.name == name then return true end
    end
    return false
end

lib.callback.register('terrific-customs:server:pay', function(source, category, mod, index)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return false end

    if not VALID_CATEGORIES[category] then return false end
    if not isAtShop(source) then return false end
    if not hasJob(player) then return false end

    local price = Config.PriceOf(category, mod, index)
    if not price then return false end
    if price <= 0 then return true end -- czesc fabryczna

    for _, account in ipairs(Config.PaymentAccounts) do
        if player.Functions.RemoveMoney(account, price, 'terrific-customs') then return true end
    end

    return false
end)

lib.callback.register('terrific-customs:server:getShops', function()
    if #shops == 0 then loadShops() end -- gdyby klient zdazyl zapytac przed onResourceStart
    return shops
end)

lib.callback.register('terrific-customs:server:isManager', function(source)
    return isManager(source)
end)

lib.callback.register('terrific-customs:server:getTune', function(_, plate)
    if type(plate) ~= 'string' then return nil end
    return tunes[plate]
end)

local KINDS = {
    ecu    = function(knob) return knob.mult and #knob.mult or #knob.absolute end,
    stance = function(knob) return #knob.values end,
    abs    = function(knob) return #knob.values end,
}

local KNOBS = {
    ecu    = function() return Config.Ecu end,
    stance = function() return Config.Stance end,
    abs    = function() return Config.Abs end,
}

RegisterNetEvent('terrific-customs:server:saveTune', function(plate, kind, levels)
    local src = source
    if not isAtShop(src) then return end
    if type(plate) ~= 'string' or type(levels) ~= 'table' then return end

    local countOf = KINDS[kind]
    if not countOf then return end

    local knobs = KNOBS[kind]()
    local clean = {}

    for i, knob in ipairs(knobs) do
        local level = math.floor(tonumber(levels[i]) or 1)
        if level < 1 or level > countOf(knob) then level = 1 end
        clean[i] = level
    end

    plate = plate:sub(1, 12)
    tunes[plate] = tunes[plate] or {}
    tunes[plate][kind] = clean
    saveTunes()
end)

local function broadcast()
    TriggerClientEvent('terrific-customs:client:syncShops', -1, shops)
end

RegisterNetEvent('terrific-customs:server:addShop', function(label, radius)
    local src = source
    if not isManager(src) then return end

    if type(label) ~= 'string' then return end
    label = label:sub(1, 48)
    if label == '' then return end

    radius = tonumber(radius)
    if not radius or radius < 2.0 or radius > 50.0 then return end

    -- wspolrzedne bierzemy z serwera, nie od klienta - inaczej manager moglby
    -- postawic warsztat w dowolnym miejscu na mapie bez ruszania sie z fotela
    local coords = GetEntityCoords(GetPlayerPed(src))

    shops[#shops + 1] = {
        label  = label,
        x      = coords.x,
        y      = coords.y,
        z      = coords.z,
        radius = radius,
    }

    saveShops()
    broadcast()
end)

RegisterNetEvent('terrific-customs:server:removeShop', function(index)
    local src = source
    if not isManager(src) then return end

    index = tonumber(index)
    if not index or not shops[index] then return end

    table.remove(shops, index)
    saveShops()
    broadcast()
end)
