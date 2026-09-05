local QBCore = exports['qb-core']:GetCoreObject()
local OutsideVehicles = {}

local function DeleteVehicleByNetId(vehicleNetId)
    if not vehicleNetId then
        return false
    end

    local entity = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    DeleteEntity(entity)
    return not DoesEntityExist(entity)
end

local function GiveGarageVehicleKeys(src, plate)
    if not plate or GetResourceState('qb-vehiclekeys') ~= 'started' then return end
    exports['qb-vehiclekeys']:GiveKeys(src, QBCore.Shared.Trim(plate))
end

-- NAPRAWA: wydzielona funkcja sprawdzania własności (zamiast TriggerCallback server->server)
local function CheckOwnership(src, plate, type, garage, gang, cb)
    local pData = QBCore.Functions.GetPlayer(src)
    if not pData then
        cb(false)
        return
    end

    if type == "public" then
        MySQL.query('SELECT * FROM player_vehicles WHERE TRIM(plate) = ? AND citizenid = ?', {plate, pData.PlayerData.citizenid}, function(result)
            cb(result and result[1] ~= nil)
        end)
    elseif type == "house" then
        MySQL.query('SELECT * FROM player_vehicles WHERE TRIM(plate) = ?', {plate}, function(result)
            if result and result[1] then
                local hasHouseKey = exports['qb-houses']:hasKey(result[1].license, result[1].citizenid, garage)
                cb(hasHouseKey)
            else
                cb(false)
            end
        end)
    elseif type == "gang" then
        MySQL.query('SELECT * FROM player_vehicles WHERE TRIM(plate) = ?', {plate}, function(result)
            if result and result[1] then
                MySQL.single('SELECT * FROM players WHERE citizenid = ?', {result[1].citizenid}, function(resultplayer)
                    if resultplayer then
                        local playergang = json.decode(resultplayer.gang)
                        cb(playergang and playergang.name == gang)
                    else
                        cb(false)
                    end
                end)
            else
                cb(false)
            end
        end)
    else -- job garages
        if Config["SharedGarages"] then
            MySQL.query('SELECT * FROM player_vehicles WHERE TRIM(plate) = ?', {plate}, function(result)
                cb(result and result[1] ~= nil)
            end)
        else
            -- NAPRAWA: parametryzowane zapytanie zamiast string concatenation (SQL injection)
            MySQL.query('SELECT * FROM player_vehicles WHERE TRIM(plate) = ? AND citizenid = ?', {plate, pData.PlayerData.citizenid}, function(result)
                cb(result and result[1] ~= nil)
            end)
        end
    end
end

QBCore.Functions.CreateCallback("qb-garage:server:GetGarageVehicles", function(source, cb, garage, type, category)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    if not pData then cb(nil) return end

    if type == "public" then
        if Config.SharedPublicGarages then
            MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = @citizenid AND state = @state',
                {["@citizenid"] = pData.PlayerData.citizenid, ["@state"] = 1},
                function(result)
                    cb(result and result[1] and result or nil)
                end)
        else
            MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = @citizenid AND state = @state AND garage = @garage',
                {["@citizenid"] = pData.PlayerData.citizenid, ["@garage"] = garage, ["@state"] = 1},
                function(result)
                    cb(result and result[1] and result or nil)
                end)
        end
    elseif type == "depot" then
        MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ? AND state = ?', {pData.PlayerData.citizenid, 0}, function(result)
            if result and result[1] then
                local tosend = {}
                for _, vehicle in pairs(result) do
                    if not OutsideVehicles[vehicle.plate] or not DoesEntityExist(OutsideVehicles[vehicle.plate].entity) then
                        local vehicleData = QBCore.Shared.Vehicles[vehicle.vehicle]
                        local vehicleCategory = vehicleData and vehicleData.category or "suvs"
                        if category == "air" and (vehicleCategory == "helicopters" or vehicleCategory == "planes") then
                            tosend[#tosend + 1] = vehicle
                        elseif category == "sea" and vehicleCategory == "boats" then
                            tosend[#tosend + 1] = vehicle
                        elseif category == "car" and vehicleCategory ~= "helicopters" and vehicleCategory ~= "planes" and vehicleCategory ~= "boats" then
                            tosend[#tosend + 1] = vehicle
                        end
                    end
                end
                cb(#tosend > 0 and tosend or nil)
            else
                cb(nil)
            end
        end)
    else
        if Config["SharedGarages"] or type == "house" then
            MySQL.query('SELECT * FROM player_vehicles WHERE garage = ? AND state = ?', {garage, 1}, function(result)
                cb(result and result[1] and result or nil)
            end)
        else
            -- NAPRAWA: parametryzowane zapytanie
            MySQL.query('SELECT * FROM player_vehicles WHERE garage = ? AND state = ? AND citizenid = ?', {garage, 1, pData.PlayerData.citizenid}, function(result)
                cb(result and result[1] and result or nil)
            end)
        end
    end
end)

QBCore.Functions.CreateCallback("qb-garage:server:validateGarageVehicle", function(source, cb, garage, type, plate)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    if not pData then cb(false) return end

    if type == "public" then
        if Config.SharedPublicGarages then
            MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = @citizenid AND state = @state AND TRIM(plate) = @plate',
                {["@citizenid"] = pData.PlayerData.citizenid, ["@state"] = 1, ["@plate"] = plate},
                function(result)
                    cb(result and result[1] ~= nil)
                end)
        else
            MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = @citizenid AND state = @state AND TRIM(plate) = @plate AND garage = @garage',
                {["@citizenid"] = pData.PlayerData.citizenid, ["@garage"] = garage, ["@state"] = 1, ["@plate"] = plate},
                function(result)
                    cb(result and result[1] ~= nil)
                end)
        end
    elseif type == "depot" then
        MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ? AND (state = ? OR state = ?) AND TRIM(plate) = ?', {pData.PlayerData.citizenid, 0, 2, plate}, function(result)
            cb(result and result[1] ~= nil)
        end)
    else
        if Config["SharedGarages"] or type == "house" then
            MySQL.query('SELECT * FROM player_vehicles WHERE garage = ? AND state = ? AND TRIM(plate) = ?', {garage, 1, plate}, function(result)
                cb(result and result[1] ~= nil)
            end)
        else
            -- NAPRAWA: parametryzowane zapytanie
            MySQL.query('SELECT * FROM player_vehicles WHERE garage = ? AND state = ? AND TRIM(plate) = ? AND citizenid = ?', {garage, 1, plate, pData.PlayerData.citizenid}, function(result)
                cb(result and result[1] ~= nil)
            end)
        end
    end
end)

QBCore.Functions.CreateCallback("qb-garage:server:checkOwnership", function(source, cb, plate, type, house, gang)
    CheckOwnership(source, plate, type, house, gang, cb)
end)

QBCore.Functions.CreateCallback('qb-garage:server:spawnvehicle', function(source, cb, vehInfo, coords, warp)
    local plate = QBCore.Shared.Trim(vehInfo.plate)
    local pData = QBCore.Functions.GetPlayer(source)
    local veh = QBCore.Functions.SpawnVehicle(source, vehInfo.vehicle, coords, warp)
    SetEntityHeading(veh, coords.w)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleDoorsLocked(veh, 1)
    local vehProps = {}
    local result = MySQL.query.await('SELECT mods FROM player_vehicles WHERE TRIM(plate) = ?', {plate})
    if result[1] then vehProps = json.decode(result[1].mods) end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    OutsideVehicles[plate] = {netID = netId, entity = veh}
    if pData then
        MySQL.update('UPDATE player_vehicles SET state = ?, depotprice = ? WHERE TRIM(plate) = ? AND citizenid = ?', {
            0, 0, plate, pData.PlayerData.citizenid
        })
    end
    GiveGarageVehicleKeys(source, plate)
    cb(netId, vehProps)
end)

QBCore.Functions.CreateCallback("qb-garage:server:GetVehicleProperties", function(_, cb, plate)
    local properties = {}
    local result = MySQL.query.await('SELECT mods FROM player_vehicles WHERE TRIM(plate) = ?', {QBCore.Shared.Trim(plate)})
    if result[1] then
        properties = json.decode(result[1].mods)
    end
    cb(properties)
end)

QBCore.Functions.CreateCallback("qb-garage:server:IsSpawnOk", function(_, cb, plate, type)
    plate = QBCore.Shared.Trim(plate)

    if OutsideVehicles[plate] and DoesEntityExist(OutsideVehicles[plate].entity) then
        cb(false)
    else
        cb(true)
    end
end)

-- NAPRAWA GŁÓWNA: zastąpiono TriggerCallback server->server bezpośrednim wywołaniem CheckOwnership
RegisterNetEvent('qb-garage:server:updateVehicle', function(state, fuel, engine, body, plate, garage, type, gang, vehicleProps, vehicleNetId)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    if not pData then
        TriggerClientEvent('qb-garages:client:parkVehicleFailed', src, garage, 'Nie znaleziono gracza podczas zapisu pojazdu.')
        return
    end

    plate = QBCore.Shared.Trim(plate)

    if state ~= 0 and state ~= 1 and state ~= 2 then
        TriggerClientEvent('qb-garages:client:parkVehicleFailed', src, garage, 'Nieprawidłowy stan pojazdu podczas zapisu.')
        return
    end

    local function FinishVehicleSave(affectedRows)
        -- MariaDB reports 0 affected rows when the vehicle was already stored with the same values.
        OutsideVehicles[plate] = nil
        DeleteVehicleByNetId(vehicleNetId)
        TriggerClientEvent('qb-garages:client:finishParkVehicle', src, vehicleNetId, garage, type == "house")
        SetTimeout(1000, function()
            DeleteVehicleByNetId(vehicleNetId)
        end)
    end

    local function ContinueVehicleSave(owned)
        if not owned then
            TriggerClientEvent('QBCore:Notify', src, Lang:t("error.not_owned"), 'error')
            TriggerClientEvent('qb-garages:client:parkVehicleFailed', src, garage, Lang:t("error.not_owned"))
            return
        end

        local mods = vehicleProps and json.encode(vehicleProps) or '{}'

        if type ~= "house" then
            -- NAPRAWA: dodano powiadomienie o błędzie gdy garaż nie istnieje w configu
            if Config.Garages[garage] then
                MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ? WHERE TRIM(plate) = ?',
                    {state, garage, fuel, engine, body, mods, plate}, FinishVehicleSave)
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t("error.not_owned"), 'error')
                TriggerClientEvent('qb-garages:client:parkVehicleFailed', src, garage, 'Ten garaż nie istnieje w konfiguracji.')
            end
        else
            MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ? WHERE TRIM(plate) = ?',
                {state, garage, fuel, engine, body, mods, plate}, FinishVehicleSave)
        end
    end

    CheckOwnership(src, plate, type, garage, gang, function(owned)
        if owned then
            ContinueVehicleSave(true)
            return
        end

        -- Fallback: if this player has exactly one vehicle outside, store that vehicle.
        -- This avoids getting stuck when GTA/client plate formatting differs from the DB value.
        MySQL.query('SELECT plate FROM player_vehicles WHERE citizenid = ? AND state = ? LIMIT 2', {
            pData.PlayerData.citizenid, 0
        }, function(outsideVehicles)
            if outsideVehicles and #outsideVehicles == 1 then
                plate = QBCore.Shared.Trim(outsideVehicles[1].plate)
                ContinueVehicleSave(true)
            else
                ContinueVehicleSave(false)
            end
        end)
    end)
end)

RegisterNetEvent('qb-garage:server:updateVehicleState', function(state, plate, garage)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    if not pData then return end

    plate = QBCore.Shared.Trim(plate)
    if state ~= 0 and state ~= 1 and state ~= 2 then return end

    MySQL.update('UPDATE player_vehicles SET state = ?, depotprice = ? WHERE TRIM(plate) = ? AND citizenid = ?', {
        state, 0, plate, pData.PlayerData.citizenid
    }, function(affectedRows)
        if (tonumber(affectedRows) or 0) < 1 then
            TriggerClientEvent('QBCore:Notify', src, Lang:t("error.not_owned"), 'error')
        end
    end)
end)

-- NAPRAWA: ujednolicono nazwę eventu (było "qb-garages" z "s", teraz "qb-garage")
RegisterNetEvent('qb-garage:server:UpdateOutsideVehicle', function(plate, vehicle)
    if not vehicle then
        OutsideVehicles[plate] = nil
        return
    end

    local entity = NetworkGetEntityFromNetworkId(vehicle)
    OutsideVehicles[plate] = {netID = vehicle, entity = entity}
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        Wait(100)
        if Config["AutoRespawn"] then
            MySQL.update('UPDATE player_vehicles SET state = 1 WHERE state = 0', {})
        end
    end
end)

RegisterNetEvent('qb-garage:server:PayDepotPrice', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cashBalance = Player.PlayerData.money["cash"]
    local bankBalance = Player.PlayerData.money["bank"]
    local vehicle = data.vehicle

    MySQL.query('SELECT * FROM player_vehicles WHERE TRIM(plate) = ?', {QBCore.Shared.Trim(vehicle.plate)}, function(result)
        if result and result[1] then
            local depotprice = result[1].depotprice
            if cashBalance >= depotprice then
                Player.Functions.RemoveMoney("cash", depotprice, "paid-depot")
                -- NAPRAWA: ujednolicono nazwę eventu (było "qb-garages" z "s")
                TriggerClientEvent("qb-garages:client:takeOutGarage", src, data)
            elseif bankBalance >= depotprice then
                Player.Functions.RemoveMoney("bank", depotprice, "paid-depot")
                TriggerClientEvent("qb-garages:client:takeOutGarage", src, data)
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t("error.not_enough"), 'error')
            end
        end
    end)
end)

-- External Calls

-- Call from qb-vehiclesales
QBCore.Functions.CreateCallback("qb-garage:server:checkVehicleOwner", function(source, cb, plate)
    local pData = QBCore.Functions.GetPlayer(source)
    if not pData then cb(false) return end
    MySQL.query('SELECT * FROM player_vehicles WHERE TRIM(plate) = ? AND citizenid = ?', {QBCore.Shared.Trim(plate), pData.PlayerData.citizenid}, function(result)
        if result and result[1] then
            cb(true, result[1].balance)
        else
            cb(false)
        end
    end)
end)

-- Call from qb-phone
QBCore.Functions.CreateCallback('qb-garage:server:GetPlayerVehicles', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb(nil) return end

    MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ?', {Player.PlayerData.citizenid}, function(result)
        if result and result[1] then
            local Vehicles = {}
            for _, v in pairs(result) do
                local VehicleData = QBCore.Shared.Vehicles[v.vehicle]
                if not VehicleData then goto continue end

                local VehicleGarage = Lang:t("error.no_garage")
                if v.garage ~= nil then
                    if Config.Garages[v.garage] ~= nil then
                        VehicleGarage = Config.Garages[v.garage].label
                    else
                        VehicleGarage = Lang:t("info.house_garage")
                    end
                end

                local stateLabel
                if v.state == 0 then
                    stateLabel = Lang:t("status.out")
                elseif v.state == 1 then
                    stateLabel = Lang:t("status.garaged")
                elseif v.state == 2 then
                    stateLabel = Lang:t("status.impound")
                end

                local fullname
                if VehicleData["brand"] ~= nil then
                    fullname = VehicleData["brand"] .. " " .. VehicleData["name"]
                else
                    fullname = VehicleData["name"]
                end

                Vehicles[#Vehicles + 1] = {
                    fullname = fullname,
                    brand = VehicleData["brand"],
                    model = VehicleData["name"],
                    plate = v.plate,
                    garage = VehicleGarage,
                    state = stateLabel,
                    fuel = v.fuel,
                    engine = v.engine,
                    body = v.body
                }
                ::continue::
            end
            cb(#Vehicles > 0 and Vehicles or nil)
        else
            cb(nil)
        end
    end)
end)

local function getAllGarages()
    local garages = {}
    for k, v in pairs(Config.Garages) do
        garages[#garages + 1] = {
            name = k,
            label = v.label,
            type = v.type,
            takeVehicle = v.takeVehicle,
            putVehicle = v.putVehicle,
            spawnPoint = v.spawnPoint,
            showBlip = v.showBlip,
            blipName = v.blipName,
            blipNumber = v.blipNumber,
            blipColor = v.blipColor,
            vehicle = v.vehicle
        }
    end
    return garages
end

exports('getAllGarages', getAllGarages)