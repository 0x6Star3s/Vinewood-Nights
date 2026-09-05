local QBCore = exports['qb-core']:GetCoreObject()

if Config.UseableItems then

    QBCore.Functions.CreateUseableItem("newscam", function(source)
        TriggerClientEvent("Cam:ToggleCam", source)
    end)

    QBCore.Functions.CreateUseableItem("newsmic", function(source)
        TriggerClientEvent("Mic:ToggleMic", source)
    end)

    QBCore.Functions.CreateUseableItem("newsbmic", function(source)
        TriggerClientEvent("Mic:ToggleBMic", source)
    end)

else

    local Player = QBCore.Functions.GetPlayer(source)
    QBCore.Commands.Add("newscam", "Grab a news camera", {}, false, function(source, _)
        if Player.PlayerData.job.name ~= "reporter" then return end
        TriggerClientEvent("Cam:ToggleCam", source)
    end)

    QBCore.Commands.Add("newsmic", "Grab a news microphone", {}, false, function(source, _)
        if Player.PlayerData.job.name ~= "reporter" then return end
        TriggerClientEvent("Mic:ToggleMic", source)
    end)

    QBCore.Commands.Add("newsbmic", "Grab a Boom microphone", {}, false, function(source, _)
        if Player.PlayerData.job.name ~= "reporter" then return end
        TriggerClientEvent("Mic:ToggleBMic", source)
    end)
end

RegisterNetEvent('qb-newsjob:server:FillVehicleTrunk', function(plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.job.name ~= 'reporter' then return end
    if type(plate) ~= 'string' or not Config.UseableItems then return end
    exports['qb-inventory']:SetTrunkItems(plate, Config.VehicleItems)
end)
