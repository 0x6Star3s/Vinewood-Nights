local QBCore = exports['qb-core']:GetCoreObject()
local PaymentTax = 15
local Bail = {}

RegisterNetEvent('qb-tow:server:DoBail', function(bool, vehInfo)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid

    if bool then
        if type(vehInfo) ~= 'string' or not Config.Vehicles[vehInfo] then return end
        local account = Player.PlayerData.money.cash >= Config.BailPrice and 'cash'
            or (Player.PlayerData.money.bank >= Config.BailPrice and 'bank')
        if not account then
            TriggerClientEvent('QBCore:Notify', src, Lang:t("error.no_deposit", {value = Config.BailPrice}), 'error')
            return
        end
        Player.Functions.RemoveMoney(account, Config.BailPrice, "tow-paid-bail")
        Bail[cid] = account -- kaucja wraca tam, skad byla pobrana
        TriggerClientEvent('QBCore:Notify', src, Lang:t(account == 'cash' and "success.paid_with_cash" or "success.paid_with_bank", {value = Config.BailPrice}), 'success')
        TriggerClientEvent('qb-tow:client:SpawnVehicle', src, vehInfo)
    elseif Bail[cid] then
        Player.Functions.AddMoney(Bail[cid], Config.BailPrice, "tow-bail-refund")
        Bail[cid] = nil
        TriggerClientEvent('QBCore:Notify', src, Lang:t("success.refund", {value = Config.BailPrice}), 'success')
    end
end)

RegisterNetEvent('qb-tow:server:nano', function(vehNetID)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local targetVehicle = NetworkGetEntityFromNetworkId(vehNetID)
    if not Player then return end

    local playerPed = GetPlayerPed(src)
    local playerVehicle = GetVehiclePedIsIn(playerPed, true)
    local playerVehicleCoords = GetEntityCoords(playerVehicle)
    local targetVehicleCoords = GetEntityCoords(targetVehicle)
    local dist = #(playerVehicleCoords - targetVehicleCoords)
    if Player.PlayerData.job.name ~= "tow" or dist > 11.0 then
        return DropPlayer(src, Lang:t("info.skick"))
    end

    local chance = math.random(1,100)
    if chance < 26 then
        Player.Functions.AddItem("cryptostick", 1, false)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["cryptostick"], "add")
    end
end)

RegisterNetEvent('qb-tow:server:11101110', function(drops)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    if Player.PlayerData.job.name ~= "tow" or #(playerCoords - vector3(Config.Locations["main"].coords.x, Config.Locations["main"].coords.y, Config.Locations["main"].coords.z)) > 6.0 then
        return DropPlayer(src, Lang:t("info.skick"))
    end

    drops = tonumber(drops)
    if not drops or drops < 1 or drops % 1 ~= 0 or drops > 20 then return end -- ponytail: 20 holowan na kurs starczy

    local bonus = 0
    local DropPrice = math.random(150, 170)
    if drops >= 20 then
        bonus = math.ceil((DropPrice / 10) * 12)
    elseif drops >= 15 then
        bonus = math.ceil((DropPrice / 10) * 10)
    elseif drops >= 10 then
        bonus = math.ceil((DropPrice / 10) * 7)
    elseif drops >= 5 then
        bonus = math.ceil((DropPrice / 10) * 5)
    end
    local price = (DropPrice * drops) + bonus
    local taxAmount = math.ceil((price / 100) * PaymentTax)
    local payment = QBCore.Functions.ScalePayout(price - taxAmount) -- mnoznik ekonomii (/boost)

    Player.Functions.AddJobReputation(1)
    Player.Functions.AddMoney("bank", payment, "tow-salary")
    TriggerClientEvent('QBCore:Notify', src, Lang:t("success.you_earned", {value = payment}), 'success')
end)

QBCore.Commands.Add("npc", Lang:t("info.toggle_npc"), {}, false, function(source)
	TriggerClientEvent("jobs:client:ToggleNpc", source)
end)

QBCore.Commands.Add("tow", Lang:t("info.tow"), {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.name == "tow"  or Player.PlayerData.job.name == "mechanic" then
        TriggerClientEvent("qb-tow:client:TowVehicle", source)
    end
end)
