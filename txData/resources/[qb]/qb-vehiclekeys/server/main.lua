-----------------------
----   Variables   ----
-----------------------
local QBCore = exports['qb-core']:GetCoreObject()
local VehicleList = {}

-----------------------
----   Threads     ----
-----------------------

-----------------------
---- Server Events ----
-----------------------

-- Event to give keys. receiver can either be a single id, or a table of ids.
-- Must already have keys to the vehicle, trigger the event from the server, or pass forcegive paramter as true.
RegisterNetEvent('qb-vehiclekeys:server:GiveVehicleKeys', function(receiver, plate)
    local giver = source

    if HasKeys(giver, plate) then
        TriggerClientEvent('QBCore:Notify', giver, Lang:t("notify.vgkeys"), 'success')
        if type(receiver) == 'table' then
            for _,r in ipairs(receiver) do
                GiveKeys(receiver[r], plate)
            end
        else
            GiveKeys(receiver, plate)
        end
    else
        TriggerClientEvent('QBCore:Notify', giver, Lang:t("notify.ydhk"), "error")
    end
end)

---Czy gracz stoi/siedzi przy aucie o tej tablicy (bylo: klucze do dowolnej tablicy z konsoli F8)
local function IsNearPlate(src, plate)
    local target = QBCore.Shared.Trim(tostring(plate))
    local coords = GetEntityCoords(GetPlayerPed(src))

    for _, vehicle in ipairs(GetAllVehicles()) do
        if QBCore.Shared.Trim(GetVehicleNumberPlateText(vehicle)) == target
            and #(coords - GetEntityCoords(vehicle)) < 8.0 then
            return true
        end
    end
    return false
end

RegisterNetEvent('qb-vehiclekeys:server:AcquireVehicleKeys', function(plate)
    local src = source
    if type(plate) ~= 'string' or not IsNearPlate(src, plate) then return end
    GiveKeys(src, plate)
end)

RegisterNetEvent('qb-vehiclekeys:server:breakLockpick', function(itemName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    if not (itemName == "lockpick" or itemName == "advancedlockpick") then return end
    if Player.Functions.RemoveItem(itemName, 1) then
        TriggerClientEvent("inventory:client:ItemBox", source, QBCore.Shared.Items[itemName], "remove")
    end
end)

RegisterNetEvent('qb-vehiclekeys:server:setVehLockState', function(vehNetId, state)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(vehNetId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    -- otworzyc/zamknac moze tylko ktos z kluczami
    local plate = QBCore.Shared.Trim(GetVehicleNumberPlateText(vehicle))
    if not HasKeys(src, plate) then return end

    SetVehicleDoorsLocked(vehicle, state)
end)

QBCore.Functions.CreateCallback('qb-vehiclekeys:server:GetVehicleKeys', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    local keysList = {}
    for plate, citizenids in pairs (VehicleList) do
        if citizenids[citizenid] then
            keysList[plate] = true
        end
    end
    cb(keysList)
end)

QBCore.Functions.CreateCallback('qb-vehiclekeys:server:checkPlayerOwned', function(source, cb, plate)
    local playerOwned = false
    local Player = QBCore.Functions.GetPlayer(source)

    if VehicleList[plate] then
        playerOwned = true
    elseif Player then
        local result = MySQL.single.await('SELECT plate FROM player_vehicles WHERE plate = ? AND citizenid = ? LIMIT 1', {
            plate,
            Player.PlayerData.citizenid
        })

        if result then
            playerOwned = true
            GiveKeys(source, plate)
        end
    end

    cb(playerOwned)
end)

-----------------------
----   Functions   ----
-----------------------

function GiveKeys(id, plate)
    local Player = QBCore.Functions.GetPlayer(id)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid
    if not plate then
        if GetVehiclePedIsIn(GetPlayerPed(id), false) ~= 0 then
            plate = QBCore.Shared.Trim(GetVehicleNumberPlateText(GetVehiclePedIsIn(GetPlayerPed(id), false)))
        else
            return
        end
    end
    if not VehicleList[plate] then VehicleList[plate] = {} end
    VehicleList[plate][citizenid] = true
    TriggerClientEvent('QBCore:Notify', id, Lang:t("notify.vgetkeys"))
    TriggerClientEvent('qb-vehiclekeys:client:AddKeys', id, plate)
end
exports('GiveKeys', GiveKeys)

function RemoveKeys(id, plate)
    local citizenid = QBCore.Functions.GetPlayer(id).PlayerData.citizenid

    if VehicleList[plate] and VehicleList[plate][citizenid] then
        VehicleList[plate][citizenid] = nil
    end

    TriggerClientEvent('qb-vehiclekeys:client:RemoveKeys', id, plate)
end
exports('RemoveKeys', RemoveKeys)

function HasKeys(id, plate)
    local citizenid = QBCore.Functions.GetPlayer(id).PlayerData.citizenid
    if VehicleList[plate] and VehicleList[plate][citizenid] then
        return true
    end
    return false
end
exports('HasKeys', HasKeys)

QBCore.Commands.Add("givekeys", Lang:t("addcom.givekeys"), {{name = Lang:t("addcom.givekeys_id"), help = Lang:t("addcom.givekeys_id_help")}}, false, function(source, args)
	local src = source
    TriggerClientEvent('qb-vehiclekeys:client:GiveKeys', src, tonumber(args[1]))
end)

QBCore.Commands.Add("addkeys", Lang:t("addcom.addkeys"), {{name = Lang:t("addcom.addkeys_id"), help = Lang:t("addcom.addkeys_id_help")}, {name = Lang:t("addcom.addkeys_plate"), help = Lang:t("addcom.addkeys_plate_help")}}, true, function(source, args)
	local src = source
    if not args[1] or not args[2] then
        TriggerClientEvent('QBCore:Notify', src, Lang:t("notify.fpid"))
        return
    end
    GiveKeys(tonumber(args[1]), args[2])
end, 'admin')

QBCore.Commands.Add("removekeys", Lang:t("addcom.rkeys"), {{name = Lang:t("addcom.rkeys_id"), help = Lang:t("addcom.rkeys_id_help")}, {name = Lang:t("addcom.rkeys_plate"), help = Lang:t("addcom.rkeys_plate_help")}}, true, function(source, args)
	local src = source
    if not args[1] or not args[2] then
        TriggerClientEvent('QBCore:Notify', src, Lang:t("notify.fpid"))
        return
    end
    RemoveKeys(tonumber(args[1]), args[2])
end, 'admin')
