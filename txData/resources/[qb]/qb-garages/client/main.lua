local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local PlayerGang = {}
local PlayerJob = {}

local Markers = false
local HouseMarkers = false
local InputIn = false
local InputOut = false
local currentGarage = nil
local currentGarageIndex = nil
local garageZones = {}
local garageBlips = {}
local lasthouse = nil
local blipsZonesLoaded = false
local storingVehicle = false
local parkingInProgress = false

-- ===== 3D podgląd pojazdu (zanim wyciągniesz auto z garażu) =====
-- Lokalne, nie-sieciowe auto na punkcie spawnu + to samo menu (ScaleformUI) i ta sama
-- kamera (DragCam z terrific-customs) co w warsztacie: LPM obraca, scroll przybliża,
-- spacja = drzwi, V = widok z kabiny. Góra/dół na liście przełącza podglądane auto.
local previewActive = false
local previewVehicle = nil
local previewList = {}
local previewIndex = 1
-- Rośnie przy każdej zmianie auta i przy zamknięciu podglądu. Wywołanie, które czekało
-- na załadowanie modelu, sprawdza go i nie tworzy auta, gdy ktoś nowszy je wyprzedził -
-- inaczej szybkie przewijanie listy stawiało kilka aut w jednym punkcie.
local previewGen = 0
local garageMenuContext = nil
local garageMenu = nil
local OpenGarageVehicleMenu -- forward declaration, definiowana niżej w pliku

CreateThread(function()
    if Config.MenuStyle.bannerDict ~= "" then
        RequestStreamedTextureDict(Config.MenuStyle.bannerDict, false)
    end
end)

local function PreviewSpawnPoint()
    local g = currentGarage or (garageMenuContext and garageMenuContext.garage)
    if not g then return nil end
    local sp = g.previewPoint or g.spawnPoint or g.takeVehicle
    if not sp then return nil end
    return { x = sp.x or 0.0, y = sp.y or 0.0, z = sp.z or 0.0, h = sp.w or 0.0 }
end

local function DeletePreviewVehicle()
    local veh = previewVehicle
    previewVehicle = nil
    if veh and DoesEntityExist(veh) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteEntity(veh)
    end
end

local function LoadPreviewModel(model)
    local hash = (type(model) == "number") and model or GetHashKey(tostring(model))
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function ApplyPreviewMods(veh, data)
    if not data then return end
    local props = nil
    if type(data.mods) == "string" and data.mods ~= "" then
        local ok, decoded = pcall(json.decode, data.mods)
        if ok and type(decoded) == "table" then props = decoded end
    elseif type(data.mods) == "table" then
        props = data.mods
    elseif type(data.properties) == "table" then
        props = data.properties
    end
    if props then
        pcall(function() QBCore.Functions.SetVehicleProperties(veh, props) end)
    end
end

local function ShowPreviewVehicleImpl()
    previewGen = previewGen + 1
    local gen = previewGen
    DeletePreviewVehicle()
    if not Config.VehiclePreview.enabled then return end
    local sp = PreviewSpawnPoint()
    if not sp then
        print("^1[qb-garages]^7 ShowPreviewVehicle: brak spawnPoint/takeVehicle dla bieżącego garażu.")
        return
    end
    local data = previewList[previewIndex]
    if not data or not data.vehicle then
        print("^1[qb-garages]^7 ShowPreviewVehicle: brak danych pojazdu na indeksie " .. tostring(previewIndex))
        return
    end

    local hash = LoadPreviewModel(data.vehicle)
    -- w czasie ładowania modelu gracz mógł przewinąć dalej albo zamknąć menu
    if gen ~= previewGen then return end
    if not hash then
        print("^1[qb-garages]^7 ShowPreviewVehicle: nie udało się załadować modelu " .. tostring(data.vehicle))
        return
    end

    DeletePreviewVehicle()
    previewVehicle = CreateVehicle(hash, sp.x, sp.y, sp.z, sp.h, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(previewVehicle) then previewVehicle = nil return end

    SetEntityAsMissionEntity(previewVehicle, true, true)
    FreezeEntityPosition(previewVehicle, true)
    SetEntityInvincible(previewVehicle, true)
    SetVehicleDirtLevel(previewVehicle, 0.0)
    SetVehicleEngineOn(previewVehicle, false, true, false)
    ApplyPreviewMods(previewVehicle, data)
    if data.plate then
        SetVehicleNumberPlateText(previewVehicle, QBCore.Shared.Trim(data.plate))
    end

    -- Pierwsze auto startuje kamerę, kolejne tylko podmieniają cel - kąt i zoom zostają,
    -- więc przewijanie listy nie szarpie widokiem.
    if not DragCam.setEntity(previewVehicle) then
        DragCam.start(previewVehicle, Config.VehiclePreview.camera)
    end
end

local function ShowPreviewVehicle()
    local ok, err = pcall(ShowPreviewVehicleImpl)
    if not ok then
        print("^1[qb-garages]^7 Błąd w ShowPreviewVehicle: " .. tostring(err))
    end
end

local function StopPreview()
    previewGen = previewGen + 1 -- unieważnia wywołania, które jeszcze czekają na model
    previewActive = false
    previewList = {}
    previewIndex = 1
    garageMenuContext = nil
    DeletePreviewVehicle()
    DragCam.stop()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true)
end

local function StartPreview(list)
    if not Config.VehiclePreview.enabled then return end
    previewList = list or {}
    previewIndex = 1
    previewActive = (#previewList > 0)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false)
    ShowPreviewVehicle()
end
-- ===== koniec podglądu 3D =====

local function GetGarageFuel(vehicle)
    if GetResourceState('cdn-fuel') == 'started' then
        local ok, fuel = pcall(function()
            return exports['cdn-fuel']:GetFuel(vehicle)
        end)
        if ok and fuel then return fuel end
    end

    if GetResourceState('LegacyFuel') == 'started' then
        local ok, fuel = pcall(function()
            return exports['LegacyFuel']:GetFuel(vehicle)
        end)
        if ok and fuel then return fuel end
    end

    return GetVehicleFuelLevel(vehicle)
end

local function SetGarageFuel(vehicle, fuel)
    if GetResourceState('cdn-fuel') == 'started' then
        local ok, err = pcall(function()
            exports['cdn-fuel']:SetFuel(vehicle, fuel)
        end)
        if ok then return end
    end

    if GetResourceState('LegacyFuel') == 'started' then
        local ok, err = pcall(function()
            exports['LegacyFuel']:SetFuel(vehicle, fuel)
        end)
        if ok then return end
    end

    SetVehicleFuelLevel(vehicle, fuel + 0.0)
end

local function DrawGarageMarker(coords, color, scale)
    local marker = Config.GarageMarkers
    if not marker then return end
    scale = scale or marker.scale

    DrawMarker(
        marker.type,
        coords.x, coords.y, coords.z + (marker.zOffset or 0.0),
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        scale.x, scale.y, scale.z,
        color.r, color.g, color.b, color.a,
        false, true, 2, false, nil, nil, false
    )
end


--Menus
-- Jeden krok zamiast dwóch: E przy garażu od razu otwiera listę aut.
local function MenuGarage(type, garage, indexgarage)
    -- ScaleformUI nie zabiera klawiatury jak NUI, więc E w trakcie podglądu doszłoby tutaj
    -- i otworzyło drugie menu na pierwszym
    if garageMenu or previewActive then return end
    exports['qb-core']:HideText()
    TriggerEvent("qb-garages:client:VehicleList", { type = type, garage = garage, index = indexgarage })
end

local function RefreshGarageHints(garage)
    if previewActive or garageMenuContext then
        exports['qb-core']:HideText()
        return
    end
    if not garage then return end

    local ped = PlayerPedId()
    local inVeh = IsPedInAnyVehicle(ped, false)

    if inVeh then
        local nearPut = false
        if garage.putVehicle then
            nearPut = #(GetEntityCoords(ped) - garage.putVehicle) <= (Config.GarageMarkers.putInteractDistance or 6.0)
        end
        if InputIn or nearPut then
            local text = Lang:t("info.park_e")
            if garage.label and garage.type ~= "house" then
                text = text .. "<br>" .. garage.label
            end
            exports['qb-core']:DrawText(text, 'left')
            return
        end
    elseif InputOut then
        local text
        if garage.type == "house" then
            text = Lang:t("info.car_e")
        else
            text = Lang:t("info." .. garage.vehicle .. "_e")
            if garage.label then
                text = text .. "<br>" .. garage.label
            end
        end
        exports['qb-core']:DrawText(text, 'left')
        return
    end

    exports['qb-core']:HideText()
end

local function ClearMenu()
    StopPreview()
    if garageMenu then
        garageMenu = nil
        MenuHandler:CloseAndClearHistory()
    end
end

local function closeMenuFull()
    ClearMenu()
end

RegisterNetEvent('qb-garages:client:closeGarageMenu', function()
    closeMenuFull()
    if currentGarage then
        Wait(100)
        RefreshGarageHints(currentGarage)
    end
end)
local function DestroyZone(type, index)
    if garageZones[type .. "_" .. index] then
        garageZones[type .. "_" .. index].zonecombo:destroy()
        garageZones[type .. "_" .. index].zone:destroy()
        garageZones[type .. "_" .. index] = nil
    end
end

local function CreateZone(type, garage, index)
    local size
    local coords
    local heading
    local minz
    local maxz

    if type == 'in' then
        size = 8
        coords = vector3(garage.putVehicle.x, garage.putVehicle.y, garage.putVehicle.z)
        heading = garage.spawnPoint.w
        minz = coords.z - 1.0
        maxz = coords.z + 2.0
    elseif type == 'out' then
        size = 2
        coords = vector3(garage.takeVehicle.x, garage.takeVehicle.y, garage.takeVehicle.z)
        heading = garage.spawnPoint.w
        minz = coords.z - 1.0
        maxz = coords.z + 2.0
    elseif type == 'marker' then
        size = 60
        coords = vector3(garage.takeVehicle.x, garage.takeVehicle.y, garage.takeVehicle.z)
        heading = garage.spawnPoint.w
        minz = coords.z - 7.5
        maxz = coords.z + 7.0
    elseif type == 'hmarker' then
        size = 20
        coords = vector3(garage.takeVehicle.x, garage.takeVehicle.y, garage.takeVehicle.z)
        heading = garage.takeVehicle.w
        minz = coords.z - 4.0
        maxz = coords.z + 2.0
    elseif type == 'house' then
        size = 2
        coords = vector3(garage.takeVehicle.x, garage.takeVehicle.y, garage.takeVehicle.z)
        heading = garage.takeVehicle.w
        minz = coords.z - 1.0
        maxz = coords.z + 2.0
    end

    DestroyZone(type, index)

    garageZones[type .. "_" .. index] = {}
    garageZones[type .. "_" .. index].zone = BoxZone:Create(
        coords, size, size, {
        minZ = minz,
        maxZ = maxz,
        name = type,
        debugPoly = false,
        heading = heading
    })

    garageZones[type .. "_" .. index].zonecombo = ComboZone:Create({ garageZones[type .. "_" .. index].zone },
        { name = "box" .. type, debugPoly = false })
    garageZones[type .. "_" .. index].zonecombo:onPlayerInOut(function(isPointInside)
        if isPointInside then
            if type == "in" then
                InputIn = true
                RefreshGarageHints(garage)
            elseif type == "out" then
                InputOut = true
                RefreshGarageHints(garage)
            elseif type == "marker" then
                currentGarage = garage
                currentGarageIndex = index
                CreateZone("out", garage, index)
                if garage.type ~= "depot" then
                    CreateZone("in", garage, index)
                    Markers = true
                else
                    HouseMarkers = true
                end
            elseif type == "hmarker" then
                currentGarage = garage
                currentGarage.type = "house"
                currentGarageIndex = index
                CreateZone("house", garage, index)
                HouseMarkers = true
            elseif type == "house" then
                if IsPedInAnyVehicle(PlayerPedId(), false) then
                    InputIn = true
                    InputOut = false
                    RefreshGarageHints(garage)
                else
                    InputOut = true
                    InputIn = false
                    RefreshGarageHints(garage)
                end
            end
        else
            if type == "marker" then
                if parkingInProgress then return end
                if currentGarage == garage then
                    if garage.type ~= "depot" then
                        Markers = false
                    else
                        HouseMarkers = false
                    end
                    DestroyZone("in", index)
                    DestroyZone("out", index)
                    currentGarage = nil
                    currentGarageIndex = nil
                end
            elseif type == "hmarker" then
                if parkingInProgress then return end
                HouseMarkers = false
                DestroyZone("house", index)
            elseif type == "house" then
                exports['qb-core']:HideText()
                InputIn = false
                InputOut = false
            elseif type == "in" then
                exports['qb-core']:HideText()
                InputIn = false
            elseif type == "out" then
                closeMenuFull()
                exports['qb-core']:HideText()
                InputOut = false
            end
        end
    end)
end

local function doCarDamage(currentVehicle, veh)
    local engine = veh.engine + 0.0
    local body = veh.body + 0.0

    if Config.VisuallyDamageCars then
        -- mods bywa '{}' (auto tuż po zakupie albo od admina) - wtedy nie ma czego odtwarzać
        local data = json.decode(veh.mods or '{}') or {}

        for k, v in pairs(data.doorStatus or {}) do
            if v then
                SetVehicleDoorBroken(currentVehicle, tonumber(k), true)
            end
        end
        for k, v in pairs(data.tireBurstState or {}) do
            if v then
                SetVehicleTyreBurst(currentVehicle, tonumber(k), true)
            end
        end
        for k, v in pairs(data.windowStatus or {}) do
            if not v then
                SmashVehicleWindow(currentVehicle, tonumber(k))
            end
        end
    end
    SetVehicleEngineHealth(currentVehicle, engine)
    SetVehicleBodyHealth(currentVehicle, body)
end

local function CheckPlayers(vehicle, garage)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    for i = -1, 5, 1 do
        local seat = GetPedInVehicleSeat(vehicle, i)
        if seat and seat ~= 0 then
            ClearPedTasksImmediately(seat)
            TaskLeaveVehicle(seat, vehicle, 0)
            if garage then
                local coords = garage.takeVehicle
                SetEntityCoords(seat, coords.x, coords.y, coords.z)
            end
        end
    end

    SetVehicleDoorsLocked(vehicle, 2)
    Wait(500)

    local timeout = GetGameTimer() + 2000
    while DoesEntityExist(vehicle) and NetworkGetEntityOwner(vehicle) ~= PlayerId() and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(vehicle)
        Wait(50)
    end

    SetEntityAsMissionEntity(vehicle, true, true)

    for _ = 1, 10 do
        if not DoesEntityExist(vehicle) then return true end

        DeleteVehicle(vehicle)
        DeleteEntity(vehicle)
        Wait(100)
    end

    return not DoesEntityExist(vehicle)
end

-- Functions
local function round(num, numDecimalPlaces)
    return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

local function VehicleLabel(v)
    local vd = QBCore.Shared.Vehicles[v.vehicle]
    if not vd then return v.vehicle or "?" end
    if vd.brand and vd.brand ~= "" then return vd.brand .. " " .. vd.name end
    return vd.name
end

local function pct(value)
    return math.floor((tonumber(value) or 0) / 10)
end

-- Cena odzyskania: mandat z bazy, a gdy zerowy - stawka z configu.
local function RecoverPrice(v)
    local price = tonumber(v.depotprice) or 0
    if price <= 0 then price = Config.Recover.fallbackPrice or 0 end
    return price
end

function OpenGarageVehicleMenu()
    exports['qb-core']:HideText()
    local ctx = garageMenuContext
    if not ctx then return end

    local style = Config.MenuStyle
    local bannerColor = SColor.FromRgb(style.banner.r, style.banner.g, style.banner.b)
    local menu = UIMenu.New(ctx.header, ctx.type == "depot" and "ODZYSKAJ POJAZD" or "WYBIERZ POJAZD", 50, 50, true, style.bannerDict, style.bannerTexture, false)
    menu:MaxItemsOnScreen(10)
    -- Kółko myszy zostaje kamerze (zoom), po liście chodzi się strzałkami - jak w warsztacie.
    menu:MouseWheelControlEnabled(false)
    menu:SetBannerColor(bannerColor)
    menu:SubtitleColor(style.subtitle)
    menu:CounterColor(bannerColor)

    for _, v in ipairs(ctx.vehicles) do
        local item = UIMenuItem.New(VehicleLabel(v),
            ("Tablica %s  |  Paliwo %d%%  |  Silnik %d%%  |  Karoseria %d%%"):format(
                v.plate or "?", math.floor(tonumber(v.fuel) or 0), pct(v.engine), pct(v.body)))
        if ctx.type == "depot" then
            item:RightLabel(("$%d"):format(RecoverPrice(v)))
        else
            item:RightLabel(v.plate or "")
        end
        menu:AddItem(item)
    end

    menu.OnIndexChange = function(_, index)
        if index == previewIndex or not ctx.vehicles[index] then return end
        previewIndex = index
        ShowPreviewVehicle()
    end

    menu.OnItemSelect = function(_, _, index)
        local vehicle = ctx.vehicles[index]
        if not vehicle then return end
        local payload = { vehicle = vehicle, type = ctx.type, garage = ctx.garage, index = ctx.index }
        ClearMenu() -- zamyka menu i kończy podgląd, zanim auto pojawi się na spawnie
        if ctx.type == "depot" then
            TriggerEvent("qb-garages:client:TakeOutDepot", payload)
        else
            TriggerEvent("qb-garages:client:takeOutGarage", payload)
        end
    end

    -- Backspace / ESC. Visible(false) też tu trafia, StopPreview jest idempotentne.
    menu.OnMenuClose = function()
        garageMenu = nil
        StopPreview()
        if currentGarage then RefreshGarageHints(currentGarage) end
    end

    garageMenu = menu
    menu:Visible(true)
end

RegisterNetEvent("qb-garages:client:VehicleList", function(data)
    local type = data.type
    local garage = data.garage
    local indexgarage = data.index

    QBCore.Functions.TriggerCallback("qb-garage:server:GetGarageVehicles", function(result)
        if result == nil then
            QBCore.Functions.Notify(Lang:t("error.no_vehicles"), "error", 5000)
        else
            local shownVehicles = {}
            for _, v in pairs(result) do
                shownVehicles[#shownVehicles + 1] = v
            end

            garageMenuContext = {
                type = type,
                garage = garage,
                index = indexgarage,
                vehicles = shownVehicles,
                header = garage.label or "Garaż",
            }

            currentGarage = garage
            currentGarageIndex = indexgarage
            previewIndex = 1
            OpenGarageVehicleMenu()
            StartPreview(shownVehicles)
        end
    end, indexgarage, type, garage.vehicle)
end)
RegisterNetEvent('qb-garages:client:takeOutGarage', function(data)
    StopPreview()
    local type = data.type
    local vehicle = data.vehicle
    local garage = data.garage
    local index = data.index
    QBCore.Functions.TriggerCallback('qb-garage:server:IsSpawnOk', function(spawn)
        if spawn then
            local location
            if type == "house" then
                if garage.takeVehicle.h then garage.takeVehicle.w = garage.takeVehicle.h end -- backward compatibility
                location = garage.takeVehicle
            else
                location = garage.spawnPoint
            end
            QBCore.Functions.TriggerCallback('qb-garage:server:spawnvehicle', function(netId, properties)
                local veh = NetToVeh(netId)
                QBCore.Functions.SetVehicleProperties(veh, properties)
                SetGarageFuel(veh, vehicle.fuel)
                doCarDamage(veh, vehicle)
                TriggerServerEvent('qb-garage:server:updateVehicleState', 0, vehicle.plate, index)
                closeMenuFull()
                TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
                SetVehicleEngineOn(veh, true, true)
                if type == "house" then
                    InputOut = false
                    InputIn = true
                end
            end, vehicle, location, true)
        else
            QBCore.Functions.Notify(Lang:t("error.not_impound"), "error", 5000)
        end
    end, vehicle.plate, type)
end)

local function RestoreGarageInteraction(garageName, garage)
    garage = garage or Config.Garages[garageName] or currentGarage
    if not garage or not garageName then return end

    currentGarage = garage
    currentGarageIndex = garageName

    DestroyZone("in", garageName)
    DestroyZone("out", garageName)
    CreateZone("in", garage, garageName)

    if garage.type ~= "depot" then
        CreateZone("out", garage, garageName)
        Markers = true
        HouseMarkers = false
    else
        HouseMarkers = true
        Markers = false
    end

    InputIn = false
    InputOut = true
end

local function enterVehicle(veh, indexgarage, type, garage)
    if storingVehicle then
        return
    end

    local plate = QBCore.Functions.GetPlate(veh)
    if GetVehicleNumberOfPassengers(veh) == 0 then
        local bodyDamage = math.ceil(GetVehicleBodyHealth(veh))
        local engineDamage = math.ceil(GetVehicleEngineHealth(veh))
        local totalFuel = GetGarageFuel(veh)
        local vehicleProps = QBCore.Functions.GetVehicleProperties(veh)
        local vehicleNetId = NetworkGetNetworkIdFromEntity(veh)
        storingVehicle = true
        parkingInProgress = true
        SetTimeout(8000, function()
            if parkingInProgress then
                storingVehicle = false
                parkingInProgress = false
                RestoreGarageInteraction(indexgarage, garage)
                QBCore.Functions.Notify('Nie udało się potwierdzić zapisu pojazdu. Spróbuj ponownie.', 'error', 5000)
            end
        end)
        TriggerServerEvent("qb-vehicletuning:server:SaveVehicleProps", vehicleProps)
        TriggerServerEvent('qb-garage:server:updateVehicle', 1, totalFuel, engineDamage, bodyDamage, plate, indexgarage, type, PlayerGang.name, vehicleProps, vehicleNetId)
    else
        QBCore.Functions.Notify(Lang:t("error.vehicle_occupied"), "error", 5000)
    end
end

RegisterNetEvent('qb-garages:client:parkVehicleFailed', function(garageName, message)
    storingVehicle = false
    parkingInProgress = false
    RestoreGarageInteraction(garageName)
    QBCore.Functions.Notify(message or 'Nie udało się zapisać pojazdu do garażu.', 'error', 5000)
end)

RegisterNetEvent('qb-garages:client:finishParkVehicle', function(vehicleNetId, garageName, isHouse)
    local garage = Config.Garages[garageName] or currentGarage
    local veh = vehicleNetId and NetToVeh(vehicleNetId) or 0
    if veh == 0 and IsPedInAnyVehicle(PlayerPedId(), false) then
        veh = GetVehiclePedIsIn(PlayerPedId(), false)
    end

    if veh ~= 0 then
        local plate = QBCore.Functions.GetPlate(veh)
        local deleted = CheckPlayers(veh, garage)
        if plate then
            TriggerServerEvent('qb-garage:server:UpdateOutsideVehicle', plate, nil)
        end
        if not deleted then
            storingVehicle = false
            QBCore.Functions.Notify('Pojazd zapisany, ale nie udało się go usunąć z mapy.', 'error', 5000)
        end
    else
        storingVehicle = false
    end

    storingVehicle = false

    RestoreGarageInteraction(garageName, garage)

    parkingInProgress = false

    if isHouse then
        InputOut = true
        InputIn = false
    end

    QBCore.Functions.Notify(Lang:t("success.vehicle_parked"), "primary", 4500)
end)

local function blipZoneGen(index, setloc)
    local Garage = AddBlipForCoord(setloc.takeVehicle.x, setloc.takeVehicle.y, setloc.takeVehicle.z)
    SetBlipSprite(Garage, setloc.blipNumber)
    SetBlipDisplay(Garage, 4)
    SetBlipScale(Garage, 0.60)
    SetBlipAsShortRange(Garage, true)
    SetBlipColour(Garage, setloc.blipColor)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(setloc.blipName)
    EndTextCommandSetBlipName(Garage)
    garageBlips[index] = Garage
end

local function ClearAllBlipsAndZones()
    for index, blip in pairs(garageBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        garageBlips[index] = nil
    end
    for key, data in pairs(garageZones) do
        if data.zonecombo then data.zonecombo:destroy() end
        if data.zone then data.zone:destroy() end
        garageZones[key] = nil
    end
end

function CreateBlipsZones()
    if blipsZonesLoaded then return end
    PlayerData = QBCore.Functions.GetPlayerData()
    PlayerGang = PlayerData.gang
    PlayerJob = PlayerData.job
    if not PlayerJob or not PlayerGang then return end -- przed zalogowaniem; OnPlayerLoaded wywola ponownie
    for index, garage in pairs(Config.Garages) do
        if garage.showBlip then
            blipZoneGen(index, garage)
        end
        if garage.type == "job" then
            if PlayerJob.name == garage.job or PlayerJob.type == garage.jobType then
                CreateZone("marker", garage, index)
            end
        elseif garage.type == "gang" then
            if PlayerGang.name == garage.job then
                CreateZone("marker", garage, index)
            end
        else
            CreateZone("marker", garage, index)
        end
    end
    blipsZonesLoaded = true
end

-- Wywoływane po zapisie zmian w panelu administracyjnym garaży (na żywo, bez restartu)
RegisterNetEvent('qb-garages:client:setGarageConfig', function(newGarages)
    if type(newGarages) ~= "table" then return end
    closeMenuFull()
    currentGarage = nil
    currentGarageIndex = nil
    Markers = false
    HouseMarkers = false
    ClearAllBlipsAndZones()
    Config.Garages = newGarages
    blipsZonesLoaded = false
    CreateBlipsZones()
end)

RegisterNetEvent('qb-garages:client:setHouseGarage', function(house, hasKey)
    if Config.HouseGarages[house] then
        if lasthouse ~= house then
            if lasthouse then
                DestroyZone("hmarker", lasthouse)
            end
            if hasKey and Config.HouseGarages[house].takeVehicle.x then
                CreateZone("hmarker", Config.HouseGarages[house], house)
                lasthouse = house
            end
        end
    end
end)

RegisterNetEvent('qb-garages:client:houseGarageConfig', function(garageConfig)
    Config.HouseGarages = garageConfig
end)

RegisterNetEvent('qb-garages:client:addHouseGarage', function(house, garageInfo)
    Config.HouseGarages[house] = garageInfo
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    CreateBlipsZones()
end)

AddEventHandler("onResourceStart", function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateBlipsZones()
end)

-- Zabezpieczenie: gdyby ktoś zrestartował ten resource w trakcie podglądu,
-- gracz nie może zostać zamrożony/niewidzialny na stałe.
AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    ClearMenu()
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gang)
    PlayerGang = gang
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerJob = job
end)

RegisterNetEvent('qb-garages:client:TakeOutDepot', function(data)
    StopPreview()
    local vehicle = data.vehicle

    if RecoverPrice(vehicle) > 0 then
        TriggerServerEvent("qb-garage:server:PayDepotPrice", data)
    else
        TriggerEvent("qb-garages:client:takeOutGarage", data)
    end
end)

local function TryStoreNearbyVehicle(index, garage)
    if storingVehicle then return true end
    if not garage.putVehicle or not IsPedInAnyVehicle(PlayerPedId(), false) then return false end

    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then
        return false
    end

    local distance = #(GetEntityCoords(vehicle) - garage.putVehicle)
    if distance > (Config.GarageMarkers.putInteractDistance or 6.0) then
        return false
    end

    local vehClass = GetVehicleClass(vehicle)
    local canStoreType = false

    if garage.vehicle == "car" or not garage.vehicle then
        canStoreType = vehClass ~= 10 and vehClass ~= 14 and vehClass ~= 15 and vehClass ~= 16 and vehClass ~= 20
    elseif garage.vehicle == "air" then
        canStoreType = vehClass == 15 or vehClass == 16
    elseif garage.vehicle == "sea" then
        canStoreType = vehClass == 14
    elseif garage.vehicle == "rig" then
        canStoreType = vehClass == 10 or vehClass == 11 or vehClass == 12 or vehClass == 20
    end

    if not canStoreType then
        QBCore.Functions.Notify(Lang:t("error.not_correct_type"), "error", 3500)
        return true
    end

    if garage.type == "job" and PlayerJob.name ~= garage.job and PlayerJob.type ~= garage.jobType then
        return true
    end
    if garage.type == "gang" and PlayerGang.name ~= garage.job and PlayerJob.type ~= garage.jobType then
        return true
    end

    enterVehicle(vehicle, index, garage.type, garage)
    return true
end

-- Threads
CreateThread(function()
    while true do
        local sleep = 750

        if IsPedInAnyVehicle(PlayerPedId(), false) then
            for index, garage in pairs(Config.Garages) do
                if garage.putVehicle then
                    local distance = #(GetEntityCoords(GetVehiclePedIsIn(PlayerPedId(), false)) - garage.putVehicle)
                    if distance <= (Config.GarageMarkers.putInteractDistance or 6.0) then
                        sleep = 0
                        if IsControlJustReleased(0, 38) and TryStoreNearbyVehicle(index, garage) then
                            break
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    local sleep
    while true do
        sleep = 2000
        if currentGarage ~= nil then
            local canStoreNearby = false
            if Markers then
                if currentGarage.putVehicle then
                    DrawGarageMarker(currentGarage.putVehicle, Config.GarageMarkers.putColor, Config.GarageMarkers.putScale)
                end
                DrawGarageMarker(currentGarage.takeVehicle, Config.GarageMarkers.takeColor)
                sleep = 0
            elseif HouseMarkers then
                DrawGarageMarker(currentGarage.takeVehicle, Config.GarageMarkers.takeColor)
                sleep = 0
            end
            if InputOut and currentGarage.takeVehicle then
                local color = currentGarage.type == "depot" and (Config.GarageMarkers.depotColor or Config.GarageMarkers.takeColor) or Config.GarageMarkers.takeColor
                DrawGarageMarker(currentGarage.takeVehicle, color)
                sleep = 0
            end
            if currentGarage.putVehicle and IsPedInAnyVehicle(PlayerPedId(), false) then
                local distance = #(GetEntityCoords(PlayerPedId()) - currentGarage.putVehicle)
                canStoreNearby = distance <= (Config.GarageMarkers.putInteractDistance or 6.0)
                if canStoreNearby then
                    RefreshGarageHints(currentGarage)
                    sleep = 0
                elseif InputOut and not IsPedInAnyVehicle(PlayerPedId(), false) then
                    RefreshGarageHints(currentGarage)
                    sleep = 0
                end
            end
            if InputIn or InputOut or canStoreNearby then
                if IsControlJustReleased(0, 38) then
                    if storingVehicle then
                        QBCore.Functions.Notify('Zapisywanie pojazdu do garażu...', 'primary', 2500)
                    elseif InputIn or canStoreNearby then
                        local ped = PlayerPedId()
                        local curVeh = GetVehiclePedIsIn(ped)
                        if curVeh == 0 then
                            QBCore.Functions.Notify("Musisz siedzieć w pojeździe, żeby schować go do garażu.", "error", 3500)
                        else
                            local vehClass = GetVehicleClass(curVeh)
                            --Check vehicle type for garage
                            if currentGarage.vehicle == "car" or not currentGarage.vehicle then
                                if vehClass ~= 10 and vehClass ~= 14 and vehClass ~= 15 and vehClass ~= 16 and vehClass ~= 20 then
                                    if currentGarage.type == "job" then
                                        if PlayerJob.name == currentGarage.job or PlayerJob.type == currentGarage.jobType then
                                            enterVehicle(curVeh, currentGarageIndex, currentGarage.type, currentGarage)
                                        end
                                    elseif currentGarage.type == "gang" then
                                        if PlayerGang.name == currentGarage.job or PlayerJob.type == currentGarage.jobType then
                                            enterVehicle(curVeh, currentGarageIndex, currentGarage.type, currentGarage)
                                        end
                                    else
                                        enterVehicle(curVeh, currentGarageIndex, currentGarage.type, currentGarage)
                                    end
                                else
                                    QBCore.Functions.Notify(Lang:t("error.not_correct_type"), "error", 3500)
                                end
                            elseif currentGarage.vehicle == "air" then
                                if vehClass == 15 or vehClass == 16 then
                                    if currentGarage.type == "job" then
                                        if PlayerJob.name == currentGarage.job or PlayerJob.type == currentGarage.jobType then
                                            enterVehicle(curVeh, currentGarageIndex, currentGarage.type, currentGarage)
                                        end
                                    elseif currentGarage.type == "gang" then
                                        if PlayerGang.name == currentGarage.job or PlayerJob.type == currentGarage.jobType then
                                            enterVehicle(curVeh, currentGarageIndex, currentGarage.type, currentGarage)
                                        end
                                    else
                                        enterVehicle(curVeh, currentGarageIndex, currentGarage.type, currentGarage)
                                    end
                                else
                                    QBCore.Functions.Notify(Lang:t("error.not_correct_type"), "error", 3500)
                                end
                            elseif currentGarage.vehicle == "sea" then
                                if vehClass == 14 then
                                    if currentGarage.type == "job" then
                                        if PlayerJob.name == currentGarage.job then
                                            enterVehicle(curVeh, currentGarageIndex, currentGarage.type, currentGarage)
                                        end
                                    elseif currentGarage.type == "gang" then
                                        if PlayerGang.name == currentGarage.job then
                                            enterVehicle(curVeh, currentGarageIndex, currentGarage.type, currentGarage)
                                        end
                                    else
                                        enterVehicle(curVeh, currentGarageIndex, currentGarage.type, currentGarage)
                                    end
                                else
                                    QBCore.Functions.Notify(Lang:t("error.not_correct_type"), "error", 3500)
                                end
                            elseif currentGarage.vehicle == "rig" then
                                if vehClass == 10 or vehClass == 11 or vehClass == 12 or vehClass == 20 then
                                    if currentGarage.type == "job" then
                                        if PlayerJob.name == currentGarage.job then
                                            enterVehicle(curVeh, currentGarageIndex, currentGarage.type, currentGarage)
                                        end
                                    elseif currentGarage.type == "gang" then
                                        if PlayerGang.name == currentGarage.job then
                                            enterVehicle(curVeh, currentGarageIndex, currentGarage.type, currentGarage)
                                        end
                                    else
                                        enterVehicle(curVeh, currentGarageIndex, currentGarage.type, currentGarage)
                                    end
                                else
                                    QBCore.Functions.Notify(Lang:t("error.not_correct_type"), "error", 3500)
                                end
                            else
                                QBCore.Functions.Notify(Lang:t("error.not_correct_type"), "error", 3500)
                            end
                        end
                    elseif InputOut then
                        if currentGarage.type == "job" then
                            if PlayerJob.name == currentGarage.job then
                                MenuGarage(currentGarage.type, currentGarage, currentGarageIndex)
                            end
                        elseif currentGarage.type == "gang" then
                            if PlayerGang.name == currentGarage.job then
                                MenuGarage(currentGarage.type, currentGarage, currentGarageIndex)
                            end
                        else
                            MenuGarage(currentGarage.type, currentGarage, currentGarageIndex)
                        end
                    end
                end
                sleep = 0
            end
        end
        Wait(sleep)
    end
end)
