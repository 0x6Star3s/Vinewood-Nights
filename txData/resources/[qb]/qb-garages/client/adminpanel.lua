local QBCore = exports['qb-core']:GetCoreObject()
local panelOpen = false

local function round4(n)
    if type(n) ~= "number" then return 0.0 end
    return math.floor(n * 10000 + 0.5) / 10000
end

local function OpenPanel(garages)
    panelOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "open",
        garages = garages,
    })
end

local function ClosePanel()
    if not panelOpen then return end
    panelOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
end

RegisterNetEvent('qb-garages:client:openAdminPanel', function(garages)
    OpenPanel(garages)
end)

RegisterNetEvent('qb-garages:client:adminPanelDenied', function()
    QBCore.Functions.Notify("Brak uprawnień administratora.", "error", 4000)
end)

RegisterCommand(Config.AdminPanel and Config.AdminPanel.command or "garageadmin", function()
    TriggerServerEvent('qb-garages:server:requestAdminPanel')
end, false)

TriggerEvent('chat:addSuggestion', '/' .. (Config.AdminPanel and Config.AdminPanel.command or "garageadmin"), 'Otwórz panel administracyjny garaży (tylko admin)')

RegisterNUICallback('close', function(_, cb)
    ClosePanel()
    cb('ok')
end)

RegisterNUICallback('getPosition', function(_, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    cb({
        x = round4(coords.x),
        y = round4(coords.y),
        z = round4(coords.z),
        w = round4(GetEntityHeading(ped)),
    })
end)

RegisterNUICallback('teleport', function(data, cb)
    if not data or not data.x or not data.y or not data.z then
        cb('error')
        return
    end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        SetEntityCoordsNoOffset(GetVehiclePedIsIn(ped, false), data.x + 0.0, data.y + 0.0, data.z + 0.0, false, false, false)
    else
        SetEntityCoordsNoOffset(ped, data.x + 0.0, data.y + 0.0, data.z + 0.0, false, false, false)
    end
    if data.w then
        SetEntityHeading(ped, data.w + 0.0)
    end
    cb('ok')
end)

RegisterNUICallback('saveGarage', function(data, cb)
    if data and data.key and data.garage then
        TriggerServerEvent('qb-garages:server:saveGarage', data.key, data.garage)
    end
    cb('ok')
end)

RegisterNUICallback('deleteGarage', function(data, cb)
    if data and data.key then
        TriggerServerEvent('qb-garages:server:deleteGarage', data.key)
    end
    cb('ok')
end)

RegisterNetEvent('qb-garages:client:garageSaveResult', function(success, message)
    QBCore.Functions.Notify(message, success and "success" or "error", success and 3000 or 5000)
    SendNUIMessage({ action = "toast", ok = success, message = message })
end)

CreateThread(function()
    while true do
        local sleep = 200
        if panelOpen then
            sleep = 0
            if IsControlJustPressed(0, 322) then -- ESC
                ClosePanel()
            end
        end
        Wait(sleep)
    end
end)
