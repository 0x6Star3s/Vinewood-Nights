local QBCore = exports['qb-core']:GetCoreObject()
local PlayerJob = {}
local JobsDone = 0
local NpcOn = false
local CurrentLocation = {}
local CurrentBlip = nil
local LastVehicle = 0
local VehicleSpawned = false
local selectedVeh = nil
local CurrentBlip2 = nil
local CurrentTow = nil
local drawDropOff = false
local insideZone = {}       -- main / vehicle / vehicleArea: gdzie stoi gracz (podpowiedzi E)
local elementsCreated = false

-- Functions

local function hasTowJob()
    return PlayerJob and (PlayerJob.name == "tow" or PlayerJob.name == "mechanic")
end

local function getRandomVehicleLocation()
    local randomVehicle = math.random(1, #Config.Locations["towspots"])
    while (randomVehicle == LastVehicle) do
        Wait(10)
        randomVehicle = math.random(1, #Config.Locations["towspots"])
    end
    return randomVehicle
end

local function drawDropOffMarker()
    CreateThread(function()
        while drawDropOff do
            DrawMarker(2, Config.Locations["dropoff"].coords.x, Config.Locations["dropoff"].coords.y, Config.Locations["dropoff"].coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 200, 0, 0, 222, false, false, false, true, false, false, false)
            Wait(0)
        end
    end)
end

local function getVehicleInDirection(coordFrom, coordTo)
    local rayHandle = CastRayPointToPoint(coordFrom.x, coordFrom.y, coordFrom.z, coordTo.x, coordTo.y, coordTo.z, 10, PlayerPedId(), 0)
    local _, _, _, _, vehicle = GetRaycastResult(rayHandle)
    return vehicle
end

local function isTowVehicle(vehicle)
    if not vehicle or vehicle == 0 then return false end
    for k in pairs(Config.Vehicles) do
        if GetEntityModel(vehicle) == joaat(k) then
            return true
        end
    end
    return false
end

-- Laweta, z ktorej gracz ostatnio wysiadl, o ile stoi w zasiegu holowania od celu
local function nearbyFlatbed(target)
    local flatbed = GetVehiclePedIsIn(PlayerPedId(), true)
    if not isTowVehicle(flatbed) then return 0 end
    if target and target ~= 0 and #(GetEntityCoords(flatbed) - GetEntityCoords(target)) >= 11.0 then return 0 end
    return flatbed
end

local function canAttach(entity)
    return hasTowJob() and CurrentTow == nil and not IsPedInAnyVehicle(PlayerPedId(), false)
        and not isTowVehicle(entity) and nearbyFlatbed(entity) ~= 0
end

-- Wypozyczalnia: menu przez qb-menu (czyli ScaleformUI, jak w warsztacie)
local function MenuGarage()
    local towMenu = {
        { header = Lang:t("menu.header"), isMenuHeader = true },
    }
    for k, label in pairs(Config.Vehicles) do
        towMenu[#towMenu + 1] = {
            header = label,
            txt = Lang:t("menu.rent_txt", { value = Config.BailPrice }),
            params = { event = "qb-tow:client:TakeOutVehicle", args = { vehicle = k } },
        }
    end
    towMenu[#towMenu + 1] = {
        header = NpcOn and Lang:t("menu.npc_off") or Lang:t("menu.npc_on"),
        txt = Lang:t("menu.npc_txt"),
        params = { event = "jobs:client:ToggleNpc" },
    }
    towMenu[#towMenu + 1] = {
        header = Lang:t("menu.close_menu"),
        params = { event = "qb-menu:client:closeMenu" },
    }
    exports['qb-menu']:openMenu(towMenu)
end

local function CreateZone(type, number)
    local loc = type == "towspots" and Config.Locations.towspots[number] or Config.Locations[type]
    local coords = vector3(loc.coords.x, loc.coords.y, loc.coords.z)
    local heading = loc.coords.w or 0.0
    local boxName = type == "towspots" and ("towspot" .. number) or loc.label
    local size = ({ main = 3, vehicle = 5, towspots = 50 })[type]
    local event = ({ main = "qb-tow:client:PaySlip", vehicle = "qb-tow:client:Vehicle" })[type]
    local label = ({ main = Lang:t("label.payslip"), vehicle = Lang:t("label.vehicle") })[type]

    if Config.UseTarget and type ~= "towspots" then
        exports['qb-target']:AddBoxZone(boxName, coords, size, size, {
            minZ = coords.z - 5.0,
            maxZ = coords.z + 5.0,
            name = boxName,
            heading = heading,
            debugPoly = false,
        }, {
            options = {
                { type = "client", event = event, label = label, icon = "fas fa-truck-pickup", job = "tow" },
            },
            distance = 2
        })
    else
        local zone = BoxZone:Create(coords, size, size, {
            minZ = coords.z - 5.0,
            maxZ = coords.z + 5.0,
            name = boxName,
            debugPoly = false,
            heading = heading,
        })
        local zoneCombo = ComboZone:Create({ zone }, { name = boxName, debugPoly = false })
        zoneCombo:onPlayerInOut(function(isPointInside)
            if type == "towspots" then
                if isPointInside then TriggerEvent('qb-tow:client:SpawnNPCVehicle') end
                return
            end
            -- bez targetu: podpowiedz [E] zamiast automatu na wejscie w strefe
            insideZone[type] = isPointInside
            if isPointInside and hasTowJob() then
                exports['qb-core']:DrawText(('[E] %s'):format(label), 'left')
            else
                exports['qb-core']:HideText()
            end
        end)
        if type == "towspots" then
            CurrentLocation.zoneCombo = zoneCombo
        end
    end

    if type == "vehicle" then
        -- szersza strefa: marker na ziemi + zwrot lawety na E, gdy gracz w niej siedzi
        local zoneMark = BoxZone:Create(coords, 20, 20, {
            minZ = coords.z - 5.0,
            maxZ = coords.z + 5.0,
            name = boxName .. "_area",
            debugPoly = false,
            heading = heading,
        })
        local zoneComboV = ComboZone:Create({ zoneMark }, { name = boxName .. "_area", debugPoly = false })
        zoneComboV:onPlayerInOut(function(isPointInside)
            insideZone.vehicleArea = isPointInside
        end)
    end
end

local function deliverVehicle(vehicle)
    DeleteVehicle(vehicle)
    RemoveBlip(CurrentBlip2)
    JobsDone = JobsDone + 1
    VehicleSpawned = false
    QBCore.Functions.Notify(Lang:t("mission.delivered_vehicle"), "success")
    QBCore.Functions.Notify(Lang:t("mission.get_new_vehicle"))

    local randomLocation = getRandomVehicleLocation()
    CurrentLocation.x = Config.Locations["towspots"][randomLocation].coords.x
    CurrentLocation.y = Config.Locations["towspots"][randomLocation].coords.y
    CurrentLocation.z = Config.Locations["towspots"][randomLocation].coords.z
    CurrentLocation.model = Config.Locations["towspots"][randomLocation].model
    CurrentLocation.id = randomLocation
    CreateZone("towspots", randomLocation)

    CurrentBlip = AddBlipForCoord(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z)
    SetBlipColour(CurrentBlip, 3)
    SetBlipRoute(CurrentBlip, true)
    SetBlipRouteColour(CurrentBlip, 3)
end

local function CreateElements()
    if elementsCreated then return end
    elementsCreated = true

    local TowBlip = AddBlipForCoord(Config.Locations["main"].coords.x, Config.Locations["main"].coords.y, Config.Locations["main"].coords.z)
    SetBlipSprite(TowBlip, 477)
    SetBlipDisplay(TowBlip, 4)
    SetBlipScale(TowBlip, 0.6)
    SetBlipAsShortRange(TowBlip, true)
    SetBlipColour(TowBlip, 15)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Config.Locations["main"].label)
    EndTextCommandSetBlipName(TowBlip)

    local TowVehBlip = AddBlipForCoord(Config.Locations["vehicle"].coords.x, Config.Locations["vehicle"].coords.y, Config.Locations["vehicle"].coords.z)
    SetBlipSprite(TowVehBlip, 326)
    SetBlipDisplay(TowVehBlip, 4)
    SetBlipScale(TowVehBlip, 0.6)
    SetBlipAsShortRange(TowVehBlip, true)
    SetBlipColour(TowVehBlip, 15)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Config.Locations["vehicle"].label)
    EndTextCommandSetBlipName(TowVehBlip)

    CreateZone("main")
    CreateZone("vehicle")
end

-- Podczepianie z oka (qb-target) na dowolnym aucie, gdy obok stoi laweta gracza;
-- odczepianie z oka na lawecie. /tow i radial menu dalej dzialaja (raycast przed graczem).
CreateThread(function()
    if not Config.UseTarget then return end
    exports['qb-target']:AddGlobalVehicle({
        options = {
            {
                label = Lang:t("label.attach"),
                icon = "fas fa-truck-pickup",
                action = function(entity) TriggerEvent('qb-tow:client:TowVehicle', entity) end,
                canInteract = function(entity) return canAttach(entity) end,
            },
            {
                label = Lang:t("label.detach"),
                icon = "fas fa-truck-pickup",
                action = function() TriggerEvent('qb-tow:client:TowVehicle') end,
                canInteract = function(entity) return hasTowJob() and CurrentTow ~= nil and isTowVehicle(entity) end,
            },
        },
        distance = 4.0,
    })
end)

-- Events

RegisterNetEvent('qb-tow:client:SpawnVehicle', function()
    local vehicleInfo = selectedVeh
    local coords = Config.Locations["vehicle"].coords
    QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
        local veh = NetToVeh(netId)
        SetVehicleNumberPlateText(veh, "TOWR"..tostring(math.random(1000, 9999)))
        SetEntityHeading(veh, coords.w)
        exports['cdn-fuel']:SetFuel(veh, 100.0)
        SetEntityAsMissionEntity(veh, true, true)
        exports['qb-menu']:closeMenu()
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
        SetVehicleEngineOn(veh, true, true)
        for i = 1, 9, 1 do
            SetVehicleExtra(veh, i, 0)
        end
    end, vehicleInfo, coords, false)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerJob = QBCore.Functions.GetPlayerData().job

    if PlayerJob.name == "tow" then
        CreateElements()
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo

    if PlayerJob.name == "tow" then
        CreateElements()
    end
end)

RegisterNetEvent('jobs:client:ToggleNpc', function()
    if QBCore.Functions.GetPlayerData().job.name == "tow" then
        if CurrentTow ~= nil then
            QBCore.Functions.Notify(Lang:t("error.finish_work"), "error")
            return
        end
        NpcOn = not NpcOn
        if NpcOn then
            local randomLocation = getRandomVehicleLocation()
            CurrentLocation.x = Config.Locations["towspots"][randomLocation].coords.x
            CurrentLocation.y = Config.Locations["towspots"][randomLocation].coords.y
            CurrentLocation.z = Config.Locations["towspots"][randomLocation].coords.z
            CurrentLocation.model = Config.Locations["towspots"][randomLocation].model
            CurrentLocation.id = randomLocation
            CreateZone("towspots", randomLocation)

            CurrentBlip = AddBlipForCoord(CurrentLocation.x, CurrentLocation.y, CurrentLocation.z)
            SetBlipColour(CurrentBlip, 3)
            SetBlipRoute(CurrentBlip, true)
            SetBlipRouteColour(CurrentBlip, 3)
            QBCore.Functions.Notify(Lang:t("mission.npc_started"), "success")
        else
            if DoesBlipExist(CurrentBlip) then
                RemoveBlip(CurrentBlip)
                CurrentLocation = {}
                CurrentBlip = nil
            end
            VehicleSpawned = false
            QBCore.Functions.Notify(Lang:t("mission.npc_stopped"))
        end
    end
end)

-- targetVehicle przychodzi z oka qb-target; bez niego (komenda /tow, radial) szukamy auta
-- raycastem przed graczem
RegisterNetEvent('qb-tow:client:TowVehicle', function(targetVehicle)
    local playerped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerped, true)
    if not isTowVehicle(vehicle) then
        QBCore.Functions.Notify(Lang:t("error.not_towing_vehicle"), "error")
        return
    end
    if IsPedInAnyVehicle(playerped, false) then
        QBCore.Functions.Notify(Lang:t("error.leave_truck"), "error")
        return
    end

    if CurrentTow == nil then
        if not targetVehicle or targetVehicle == 0 then
            local coordA = GetEntityCoords(playerped, 1)
            local coordB = GetOffsetFromEntityInWorldCoords(playerped, 0.0, 5.0, 0.0)
            targetVehicle = getVehicleInDirection(coordA, coordB)
        end
        if not targetVehicle or targetVehicle == 0 or not DoesEntityExist(targetVehicle) or targetVehicle == vehicle then
            QBCore.Functions.Notify(Lang:t("error.no_vehicle_in_front"), "error")
            return
        end
        if NpcOn and CurrentLocation.model and GetEntityModel(targetVehicle) ~= joaat(CurrentLocation.model) then
            QBCore.Functions.Notify(Lang:t("error.vehicle_not_correct"), "error")
            return
        end
        if #(GetEntityCoords(vehicle) - GetEntityCoords(targetVehicle)) >= 11.0 then
            QBCore.Functions.Notify(Lang:t("error.too_far_away"), "error")
            return
        end

        QBCore.Functions.Progressbar("towing_vehicle", Lang:t("mission.towing_vehicle"), 5000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = "mini@repair",
            anim = "fixing_a_ped",
            flags = 16,
        }, {}, {}, function() -- Done
            StopAnimTask(playerped, "mini@repair", "fixing_a_ped", 1.0)
            AttachEntityToEntity(targetVehicle, vehicle, GetEntityBoneIndexByName(vehicle, 'bodyshell'), 0.0, -1.5 + -0.85, 0.0 + 1.15, 0, 0, 0, 1, 1, 0, 1, 0, 1)
            FreezeEntityPosition(targetVehicle, true)
            CurrentTow = targetVehicle
            if NpcOn then
                RemoveBlip(CurrentBlip)
                QBCore.Functions.Notify(Lang:t("mission.goto_depot"), "primary", 5000)
                CurrentBlip2 = AddBlipForCoord(Config.Locations["dropoff"].coords.x, Config.Locations["dropoff"].coords.y, Config.Locations["dropoff"].coords.z)
                SetBlipColour(CurrentBlip2, 3)
                SetBlipRoute(CurrentBlip2, true)
                SetBlipRouteColour(CurrentBlip2, 3)
                drawDropOff = true
                drawDropOffMarker()
                local vehNetID = NetworkGetNetworkIdFromEntity(targetVehicle)
                TriggerServerEvent('qb-tow:server:nano', vehNetID)
                if CurrentLocation.zoneCombo then CurrentLocation.zoneCombo:destroy() end
            end
            QBCore.Functions.Notify(Lang:t("mission.vehicle_towed"), "success")
        end, function() -- Cancel
            StopAnimTask(playerped, "mini@repair", "fixing_a_ped", 1.0)
            QBCore.Functions.Notify(Lang:t("error.failed"), "error")
        end)
    else
        QBCore.Functions.Progressbar("untowing_vehicle", Lang:t("mission.untowing_vehicle"), 5000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = "mini@repair",
            anim = "fixing_a_ped",
            flags = 16,
        }, {}, {}, function() -- Done
            StopAnimTask(playerped, "mini@repair", "fixing_a_ped", 1.0)
            FreezeEntityPosition(CurrentTow, false)
            Wait(250)
            AttachEntityToEntity(CurrentTow, vehicle, 20, -0.0, -15.0, 1.0, 0.0, 0.0, 0.0, false, false, false, false, 20, true)
            DetachEntity(CurrentTow, true, true)
            if NpcOn then
                local targetPos = GetEntityCoords(CurrentTow)
                if #(targetPos - vector3(Config.Locations["vehicle"].coords.x, Config.Locations["vehicle"].coords.y, Config.Locations["vehicle"].coords.z)) < 25.0 then
                    deliverVehicle(CurrentTow)
                end
            end
            RemoveBlip(CurrentBlip2)
            CurrentTow = nil
            drawDropOff = false
            QBCore.Functions.Notify(Lang:t("mission.vehicle_takenoff"), "success")
        end, function() -- Cancel
            StopAnimTask(playerped, "mini@repair", "fixing_a_ped", 1.0)
            QBCore.Functions.Notify(Lang:t("error.failed"), "error")
        end)
    end
end)

RegisterNetEvent('qb-tow:client:TakeOutVehicle', function(data)
    local coords = Config.Locations["vehicle"].coords
    coords = vector3(coords.x, coords.y, coords.z)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    if #(pos - coords) <= 5 then
        local vehicleInfo = data.vehicle
        TriggerServerEvent('qb-tow:server:DoBail', true, vehicleInfo)
        selectedVeh = vehicleInfo
    else
        QBCore.Functions.Notify(Lang:t("error.too_far_away"), 'error')
    end
end)

-- Oko / E na piechote w strefie lawety: wypozyczalnia
RegisterNetEvent('qb-tow:client:Vehicle', function()
    if CurrentTow then
        QBCore.Functions.Notify(Lang:t("error.finish_work"), "error")
        return
    end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return end
    MenuGarage()
end)

-- E w lawecie w strefie: zwrot lawety i kaucji
RegisterNetEvent('qb-tow:client:ReturnVehicle', function()
    if CurrentTow then
        QBCore.Functions.Notify(Lang:t("error.finish_work"), "error")
        return
    end
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if not isTowVehicle(veh) then return end
    exports['qb-core']:HideText()
    DeleteVehicle(veh)
    TriggerServerEvent('qb-tow:server:DoBail', false)
end)

RegisterNetEvent('qb-tow:client:PaySlip', function()
    if JobsDone > 0 then
        RemoveBlip(CurrentBlip)
        TriggerServerEvent("qb-tow:server:11101110", JobsDone)
        JobsDone = 0
        NpcOn = false
    else
        QBCore.Functions.Notify(Lang:t("error.no_work_done"), "error")
    end
end)

RegisterNetEvent('qb-tow:client:SpawnNPCVehicle', function()
    if not VehicleSpawned then
        QBCore.Functions.TriggerCallback('QBCore:Server:SpawnVehicle', function(netId)
            local veh = NetToVeh(netId)
            exports['cdn-fuel']:SetFuel(veh, 0.0)
            VehicleSpawned = true
        end, CurrentLocation.model, CurrentLocation, false)
    end
end)

-- Threads

-- Marker i podpowiedzi w strefie lawety
CreateThread(function()
    local returnPrompt = false
    while true do
        local sleep = 1000
        if elementsCreated and hasTowJob() then
            if insideZone.vehicleArea then
                sleep = 0
                DrawMarker(2, Config.Locations["vehicle"].coords.x, Config.Locations["vehicle"].coords.y, Config.Locations["vehicle"].coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 200, 0, 0, 222, false, false, false, true, false, false, false)

                local ped = PlayerPedId()
                local veh = GetVehiclePedIsIn(ped, false)
                local inTow = veh ~= 0 and isTowVehicle(veh) and GetPedInVehicleSeat(veh, -1) == ped
                if inTow ~= returnPrompt then
                    returnPrompt = inTow
                    if inTow then
                        exports['qb-core']:DrawText(Lang:t("label.return_vehicle"), 'left')
                    else
                        exports['qb-core']:HideText()
                    end
                end
                if inTow and IsControlJustReleased(0, 38) then
                    TriggerEvent('qb-tow:client:ReturnVehicle')
                end
            elseif returnPrompt then
                returnPrompt = false
                exports['qb-core']:HideText()
            end

            if not Config.UseTarget and (insideZone.main or insideZone.vehicle) then
                sleep = 0
                if IsControlJustReleased(0, 38) and not IsPedInAnyVehicle(PlayerPedId(), false) then
                    TriggerEvent(insideZone.main and 'qb-tow:client:PaySlip' or 'qb-tow:client:Vehicle')
                end
            end
        end
        Wait(sleep)
    end
end)
