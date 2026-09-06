local QBCore = exports['qb-core']:GetCoreObject()

-- Wezwanie lawety (np. z menu impoundu policji): serwer rozsyla do wszystkich z praca tow
RegisterNetEvent('tow:requestTow', function()
    local vehicle = QBCore.Functions.GetClosestVehicle()
    if not vehicle or vehicle == 0 then
        QBCore.Functions.Notify(Lang:t('error.no_vehicle_nearby'), 'error')
        return
    end
    TriggerServerEvent('tow:sendTowRequest', GetVehicleNumberPlateText(vehicle), GetEntityCoords(PlayerPedId()))
end)

-- qb-phone nie ma eksportu PhoneNotification (stary kod rzucal bledem) - powiadomienie
-- QBCore + powiadomienie w telefonie + blip na 2 minuty
RegisterNetEvent('tow:receiveTowRequest', function(plate, coords)
    local text = Lang:t('info.tow_request_received', { plate = plate })
    QBCore.Functions.Notify(text, 'primary', 8000)
    TriggerEvent('qb-phone:client:CustomNotification', Lang:t('info.tow_request_title'), text, 'fas fa-truck-pickup', '#9f0e63', 10000)

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 68)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Lang:t('info.tow_request_title'))
    EndTextCommandSetBlipName(blip)
    SetTimeout(120000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)
