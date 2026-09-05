local QBCore = exports['qb-core']:GetCoreObject()
local DATA_FILE = "garages_data.json"

local function IsAdmin(src)
    if src == 0 then return true end -- konsola serwera
    local permission = (Config.AdminPanel and Config.AdminPanel.permission) or "admin"
    if QBCore.Functions.HasPermission(src, permission) then return true end
    if IsPlayerAceAllowed(src, "qb-garages.admin") then return true end
    return false
end

local function sanitizeKey(key)
    if type(key) ~= "string" then return nil end
    key = key:gsub("[^%w_%-]", ""):sub(1, 50)
    if key == "" then return nil end
    return key
end

local function vec3ToTable(v)
    if not v then return nil end
    return { x = v.x, y = v.y, z = v.z }
end

local function vec4ToTable(v)
    if not v then return nil end
    return { x = v.x, y = v.y, z = v.z, w = v.w or 0.0 }
end

local function garageToPlain(g)
    return {
        label = g.label,
        type = g.type,
        vehicle = g.vehicle,
        job = g.job,
        jobType = g.jobType,
        showBlip = g.showBlip and true or false,
        blipName = g.blipName,
        blipNumber = g.blipNumber,
        blipColor = g.blipColor,
        takeVehicle = vec3ToTable(g.takeVehicle),
        putVehicle = vec3ToTable(g.putVehicle),
        spawnPoint = vec4ToTable(g.spawnPoint),
        previewPoint = vec4ToTable(g.previewPoint),
        previewCamPoint = vec3ToTable(g.previewCamPoint),
    }
end

local function toNum(n, fallback)
    n = tonumber(n)
    if n == nil then return fallback end
    return n + 0.0
end

local function plainToGarage(p)
    local tv = p.takeVehicle
    local pv = p.putVehicle
    local sp = p.spawnPoint

    return {
        label = (type(p.label) == "string" and p.label ~= "") and p.label or "Garaż",
        type = p.type or "public",
        vehicle = p.vehicle or "car",
        job = (type(p.job) == "string" and p.job ~= "") and p.job or nil,
        jobType = (type(p.jobType) == "string" and p.jobType ~= "") and p.jobType or nil,
        showBlip = p.showBlip and true or false,
        blipName = (type(p.blipName) == "string" and p.blipName ~= "") and p.blipName or "Parking",
        blipNumber = tonumber(p.blipNumber) or 357,
        blipColor = tonumber(p.blipColor) or 3,
        takeVehicle = tv and vector3(toNum(tv.x, 0.0), toNum(tv.y, 0.0), toNum(tv.z, 0.0)) or nil,
        putVehicle = pv and vector3(toNum(pv.x, 0.0), toNum(pv.y, 0.0), toNum(pv.z, 0.0)) or nil,
        spawnPoint = sp and vector4(toNum(sp.x, 0.0), toNum(sp.y, 0.0), toNum(sp.z, 0.0), toNum(sp.w, 0.0)) or nil,
        previewPoint = p.previewPoint and vector4(
            toNum(p.previewPoint.x, 0.0), toNum(p.previewPoint.y, 0.0),
            toNum(p.previewPoint.z, 0.0), toNum(p.previewPoint.w, 0.0)
        ) or nil,
        previewCamPoint = p.previewCamPoint and vector3(
            toNum(p.previewCamPoint.x, 0.0), toNum(p.previewCamPoint.y, 0.0), toNum(p.previewCamPoint.z, 0.0)
        ) or nil,
    }
end

local function dumpAllPlain()
    local out = {}
    for k, v in pairs(Config.Garages) do
        out[k] = garageToPlain(v)
    end
    return out
end

local function saveToDisk()
    SaveResourceFile(GetCurrentResourceName(), DATA_FILE, json.encode(dumpAllPlain()), -1)
end

local function broadcastGarages()
    TriggerClientEvent('qb-garages:client:setGarageConfig', -1, Config.Garages)
end

local function loadFromDisk()
    local raw = LoadResourceFile(GetCurrentResourceName(), DATA_FILE)
    if not raw or raw == "" then
        saveToDisk() -- pierwszy start: zapisz obecne garaże z config.lua jako plik danych
        return
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= "table" then
        print("^1[qb-garages]^7 Nie udało się wczytać " .. DATA_FILE .. ", używam config.lua")
        return
    end

    local newGarages = {}
    for key, plain in pairs(decoded) do
        if type(plain) == "table" and plain.takeVehicle and plain.spawnPoint then
            newGarages[key] = plainToGarage(plain)
        end
    end

    if next(newGarages) then
        Config.Garages = newGarages
    end
end

CreateThread(function()
    loadFromDisk()
    broadcastGarages()
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    TriggerClientEvent('qb-garages:client:setGarageConfig', Player.PlayerData.source, Config.Garages)
end)

QBCore.Functions.CreateCallback('qb-garages:server:isGarageAdmin', function(source, cb)
    cb(IsAdmin(source))
end)

-- Zapis samej pozycji kamery podglądu 3D (tryb "ustaw kąt, chodząc koło auta")
RegisterNetEvent('qb-garages:server:savePreviewCamPoint', function(key, camPoint)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('qb-garages:client:adminPanelDenied', src)
        return
    end

    key = sanitizeKey(key)
    local garage = key and Config.Garages[key]
    if not garage or type(camPoint) ~= "table" then
        TriggerClientEvent('qb-garages:client:garageSaveResult', src, false, "Nie udało się zapisać kąta podglądu.")
        return
    end

    garage.previewCamPoint = vector3(toNum(camPoint.x, 0.0), toNum(camPoint.y, 0.0), toNum(camPoint.z, 0.0))
    saveToDisk()
    broadcastGarages()
    TriggerClientEvent('qb-garages:client:garageSaveResult', src, true, ("Zapisano kąt podglądu dla: %s"):format(garage.label))
end)

RegisterNetEvent('qb-garages:server:requestAdminPanel', function()
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('qb-garages:client:adminPanelDenied', src)
        return
    end
    TriggerClientEvent('qb-garages:client:openAdminPanel', src, dumpAllPlain())
end)

RegisterNetEvent('qb-garages:server:saveGarage', function(key, plainGarage)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('qb-garages:client:adminPanelDenied', src)
        return
    end

    key = sanitizeKey(key)
    if not key or type(plainGarage) ~= "table" then
        TriggerClientEvent('qb-garages:client:garageSaveResult', src, false, "Nieprawidłowe dane garażu.")
        return
    end

    if not plainGarage.takeVehicle or not plainGarage.spawnPoint then
        TriggerClientEvent('qb-garages:client:garageSaveResult', src, false, "Brakuje wymaganych pozycji (mapa / spawn).")
        return
    end

    Config.Garages[key] = plainToGarage(plainGarage)
    saveToDisk()
    broadcastGarages()
    TriggerClientEvent('qb-garages:client:garageSaveResult', src, true, ("Zapisano garaż: %s"):format(Config.Garages[key].label))
end)

RegisterNetEvent('qb-garages:server:deleteGarage', function(key)
    local src = source
    if not IsAdmin(src) then
        TriggerClientEvent('qb-garages:client:adminPanelDenied', src)
        return
    end

    key = sanitizeKey(key)
    if not key or not Config.Garages[key] then
        TriggerClientEvent('qb-garages:client:garageSaveResult', src, false, "Nie znaleziono garażu do usunięcia.")
        return
    end

    Config.Garages[key] = nil
    saveToDisk()
    broadcastGarages()
    TriggerClientEvent('qb-garages:client:garageSaveResult', src, true, "Usunięto garaż.")
end)
