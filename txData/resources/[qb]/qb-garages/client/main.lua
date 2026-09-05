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

-- ===== 3D podgląd pojazdu na obrotnicy (zanim wyciągniesz auto z garażu) =====
-- Local, nie-sieciowy pojazd + skryptowa kamera. Auto się obraca, strzałki
-- lewo/prawo przełączają podglądany pojazd z aktualnej listy garażu.
local previewActive = false
local previewVehicle = nil
local previewCam = nil
local previewList = {}
local previewIndex = 1
local garageMenuContext = nil
local previewFreeCam = false
local isAdminCached = false
local freeCamMenuClosedByUs = false
local pendingCamPoint = nil
local OpenGarageVehicleMenu -- forward declaration, definiowana niżej w pliku

local function DrawPreviewText(text)
    SetTextFont(4)
    SetTextScale(0.40, 0.40)
    SetTextColour(255, 255, 255, 235)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, 0.90)
end

-- Podpowiedź w rogu ekranu dla admina - ustawianie kąta kamery podglądu 3D
local function DrawCornerText(text)
    SetTextFont(4)
    SetTextScale(0.30, 0.30)
    SetTextColour(255, 255, 255, 220)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextOutline()
    SetTextCentre(false)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.015, 0.04)
end

local function RefreshAdminStatus()
    QBCore.Functions.TriggerCallback('qb-garages:server:isGarageAdmin', function(result)
        isAdminCached = result and true or false
    end)
end

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

local function PreviewCamTarget(sp)
    return sp.x, sp.y, sp.z + (Config.VehiclePreview.camFocal or 0.9)
end

local function PreviewOffsetFromHeading(headingDeg, offsetDeg, distance)
    local rad = math.rad(headingDeg + offsetDeg)
    return -math.sin(rad) * distance, math.cos(rad) * distance
end

local function IsPreviewCamClear(cx, cy, cz, tx, ty, tz, ignoreEntity)
    local handle = StartShapeTestRay(cx, cy, cz, tx, ty, tz, 17, ignoreEntity or 0, 7)
    local retval, hit, _, _, entityHit = GetShapeTestResult(handle)
    local deadline = GetGameTimer() + 50
    while retval == 1 and GetGameTimer() < deadline do
        Wait(0)
        retval, hit, _, _, entityHit = GetShapeTestResult(handle)
    end
    if not hit then return true end
    if ignoreEntity and entityHit == ignoreEntity then return true end
    return false
end

local function CurrentPreviewGarage()
    local index = (garageMenuContext and garageMenuContext.index) or currentGarageIndex
    local garage = (garageMenuContext and garageMenuContext.garage) or currentGarage
    return index, garage
end

local function ResolvePreviewCamera(sp, veh, garage)
    if garage and garage.previewCamPoint then
        local c = garage.previewCamPoint
        return c.x, c.y, c.z
    end

    local p = Config.VehiclePreview
    local dist = p.camDistance or 7.0
    local height = p.camHeight or 1.7
    local tx, ty, tz = PreviewCamTarget(sp)
    local heading = sp.h or 0.0
    local offsets = p.camAngleOffsets or { 135.0, -135.0, 90.0, -90.0, 45.0, -45.0, 180.0, 0.0 }

    for _, off in ipairs(offsets) do
        local ox, oy = PreviewOffsetFromHeading(heading, off, dist)
        local cx, cy, cz = sp.x + ox, sp.y + oy, sp.z + height
        if IsPreviewCamClear(cx, cy, cz, tx, ty, tz, veh) then
            return cx, cy, cz
        end
    end

    local ox, oy = PreviewOffsetFromHeading(heading, 135.0, dist + 4.0)
    return sp.x + ox, sp.y + oy, sp.z + height + 2.0
end

local function ShowPreviewVehicleImpl()
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
    if not hash then
        print("^1[qb-garages]^7 ShowPreviewVehicle: nie udało się załadować modelu " .. tostring(data.vehicle))
        return
    end

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

    if previewFreeCam then return end -- admin ustawia kąt ręcznie, nie nadpisuj kamery

    local _, garage = CurrentPreviewGarage()
    local p = Config.VehiclePreview
    local tx, ty, tz = PreviewCamTarget(sp)
    local cx, cy, cz = ResolvePreviewCamera(sp, previewVehicle, garage)

    -- Kamera jest tylko PRZESTAWIANA (nigdy niszczona/tworzona od nowa), jeśli już
    -- istnieje - unika to migotania/przejścia do widoku gracza między odświeżeniami
    -- (np. po zapisaniu kąta podglądu albo zmianie pojazdu na liście).
    if not previewCam or not DoesCamExist(previewCam) then
        previewCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamFov(previewCam, p.camFov or 45.0)
        SetCamActive(previewCam, true)
        RenderScriptCams(true, true, 0, true, true)
    end
    SetCamCoord(previewCam, cx, cy, cz)
    PointCamAtCoord(previewCam, tx, ty, tz)
end

local function ShowPreviewVehicle()
    local ok, err = pcall(ShowPreviewVehicleImpl)
    if not ok then
        print("^1[qb-garages]^7 Błąd w ShowPreviewVehicle: " .. tostring(err))
    end
end

-- Tryb "orbita kamery wokół auta" - tylko dla admina, tylko podczas podglądu.
-- Postać zostaje dokładnie tam gdzie jest (zamrożona/niewidoczna jak w normalnym
-- podglądzie) - obraca się wyłącznie kamera, sterowana myszką (obrót) i scrollem
-- (zoom), zawsze skierowana na samochód. Menu qb-menu trzyma pełny focus myszy,
-- więc trzeba je na chwilę zamknąć, żeby mysz sterowała kamerą, a nie kursorem NUI.
local orbitYaw = 0.0
local orbitPitch = 15.0
local orbitDistance = 7.0

local function InitOrbitAngles(sp, garage)
    local heading = sp.h or 0.0
    local tx, ty, tz = PreviewCamTarget(sp)

    if garage and garage.previewCamPoint then
        local c = garage.previewCamPoint
        local dx, dy, dz = c.x - tx, c.y - ty, c.z - tz
        local horiz = math.sqrt(dx * dx + dy * dy)
        orbitYaw = math.deg(math.atan(-dx, dy)) % 360.0
        orbitPitch = math.deg(math.atan(dz, horiz))
        orbitDistance = math.max(1.5, math.sqrt(horiz * horiz + dz * dz))
    else
        local p = Config.VehiclePreview
        local dist = p.camDistance or 7.0
        local dz = (p.camHeight or 1.7) - (p.camFocal or 0.9)
        orbitYaw = (heading + 135.0) % 360.0
        orbitPitch = math.deg(math.atan(dz, dist))
        orbitDistance = math.sqrt(dist * dist + dz * dz)
    end
end

-- Bazowe czułości obrotu (stopnie na jednostkę delty myszy) - przemnażane przez
-- Config.VehiclePreview.orbitSensitivity, żeby dało się to dostroić bez edycji kodu.
local ORBIT_YAW_BASE = 200.0
local ORBIT_PITCH_BASE = 120.0

local function UpdateOrbitCam()
    if not previewCam or not DoesCamExist(previewCam) then return end
    local sp = PreviewSpawnPoint()
    if not sp then return end

    local p = Config.VehiclePreview
    local sensitivity = p.orbitSensitivity or 0.35
    local zoomStep = p.orbitZoomStep or 0.6
    local minDist = p.orbitMinDistance or 1.2
    local maxDist = p.orbitMaxDistance or 25.0

    DisableControlAction(0, 1, true)  -- LookLeftRight (mysz X)
    DisableControlAction(0, 2, true)  -- LookUpDown (mysz Y)
    DisableControlAction(0, 15, true) -- scroll w górę
    DisableControlAction(0, 16, true) -- scroll w dół

    local mx = GetDisabledControlNormal(0, 1)
    local my = GetDisabledControlNormal(0, 2)
    orbitYaw = (orbitYaw - mx * ORBIT_YAW_BASE * sensitivity) % 360.0
    orbitPitch = math.max(-80.0, math.min(85.0, orbitPitch - my * ORBIT_PITCH_BASE * sensitivity))

    if IsDisabledControlJustPressed(0, 16) then
        orbitDistance = math.max(minDist, orbitDistance - zoomStep)
    end
    if IsDisabledControlJustPressed(0, 15) then
        orbitDistance = math.min(maxDist, orbitDistance + zoomStep)
    end

    local tx, ty, tz = PreviewCamTarget(sp)
    local rad = math.rad(orbitYaw)
    local pitchRad = math.rad(orbitPitch)
    local horiz = orbitDistance * math.cos(pitchRad)
    local cx = tx - math.sin(rad) * horiz
    local cy = ty + math.cos(rad) * horiz
    local cz = tz + orbitDistance * math.sin(pitchRad)

    SetCamCoord(previewCam, cx, cy, cz)
    PointCamAtCoord(previewCam, tx, ty, tz)
end

local function ExitFreeCamState()
    previewFreeCam = false
    freeCamMenuClosedByUs = false
    pendingCamPoint = nil
    -- Dokończenie w osobnym wątku: to bywa wywoływane z callbacku NUI (klik w menu),
    -- gdzie nie wolno "czekać" (Wait) - ShowPreviewVehicle może czekać na model auta.
    -- Robimy to tutaj też defensywnie przywracając zamrożenie/niewidzialność postaci,
    -- na wypadek gdyby coś w trakcie ustawiania kąta ją zwolniło.
    CreateThread(function()
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false)
        ShowPreviewVehicle()
        if garageMenuContext then
            OpenGarageVehicleMenu()
        end
    end)
end

local function EnterFreeCamState()
    if not previewActive then
        QBCore.Functions.Notify("Otwórz najpierw listę pojazdów w garażu (wyciągnij auto).", "error", 4000)
        return
    end
    if not isAdminCached then
        QBCore.Functions.Notify("Brak uprawnień administratora do ustawiania kąta podglądu.", "error", 4000)
        return
    end
    if previewFreeCam then return end
    if not previewCam or not DoesCamExist(previewCam) then
        QBCore.Functions.Notify("Kamera podglądu nie jest jeszcze gotowa, spróbuj ponownie za chwilę.", "error", 4000)
        return
    end

    local sp = PreviewSpawnPoint()
    if not sp then return end
    local _, garage = CurrentPreviewGarage()
    InitOrbitAngles(sp, garage)

    previewFreeCam = true
    if garageMenuContext then
        freeCamMenuClosedByUs = true
        TriggerEvent("qb-menu:closeMenu")
    end
    QBCore.Functions.Notify("Obracaj kamerą (myszka) i przybliżaj/oddalaj (scroll). F7 = zapisz kąt.", "primary", 6000)
end

-- F6 jako skrót klawiszowy: włącza/wyłącza (bez zapisu)
local function TogglePreviewFreeCam()
    if previewFreeCam then
        ExitFreeCamState()
        QBCore.Functions.Notify("Ustawianie kąta anulowane (bez zapisu).", "primary", 3000)
    else
        EnterFreeCamState()
    end
end

RegisterNetEvent('qb-garages:client:confirmSaveCameraAngle', function()
    local index, garage = CurrentPreviewGarage()
    if index and garage and pendingCamPoint then
        garage.previewCamPoint = vector3(pendingCamPoint.x, pendingCamPoint.y, pendingCamPoint.z) -- natychmiastowy podgląd
        TriggerServerEvent('qb-garages:server:savePreviewCamPoint', index, pendingCamPoint)
        QBCore.Functions.Notify("Zapisano kąt podglądu dla tego garażu.", "success", 3500)
    else
        QBCore.Functions.Notify("Nie udało się zapisać - spróbuj ponownie.", "error", 4000)
    end
    ExitFreeCamState()
end)

RegisterNetEvent('qb-garages:client:resumeFreeCam', function()
    pendingCamPoint = nil
    freeCamMenuClosedByUs = true
    TriggerEvent("qb-menu:closeMenu") -- ukryj menu potwierdzenia, oddaj mysz kamerze (freecam trwa dalej)
end)

RegisterNetEvent('qb-garages:client:cancelFreeCam', function()
    ExitFreeCamState()
    QBCore.Functions.Notify("Anulowano ustawianie kąta.", "primary", 3000)
end)

-- F7: otwórz menu z potwierdzeniem zapisu (nie zapisuje od razu)
local function SavePreviewCamAngle()
    if not previewActive or not isAdminCached then return end
    if not previewFreeCam then
        QBCore.Functions.Notify("Najpierw włącz wolną kamerę (przycisk w menu albo F6).", "error", 4000)
        return
    end
    local index, garage = CurrentPreviewGarage()
    if not index or not garage then
        QBCore.Functions.Notify("Brak aktywnego garażu do zapisu.", "error", 4000)
        return
    end

    if not previewCam or not DoesCamExist(previewCam) then
        QBCore.Functions.Notify("Kamera podglądu nie istnieje.", "error", 4000)
        return
    end
    local camCoord = GetCamCoord(previewCam)
    pendingCamPoint = { x = camCoord.x, y = camCoord.y, z = camCoord.z }

    exports['qb-menu']:openMenu({
        { header = "Zapisać ten kąt podglądu?", isMenuHeader = true },
        {
            header = "💾 Zapisz ten kąt",
            txt = ("Ustawi podgląd 3D dla: %s"):format(garage.label or tostring(index)),
            color = "success",
            params = { event = "qb-garages:client:confirmSaveCameraAngle" }
        },
        {
            header = "↩️ Wróć i popraw kąt",
            txt = "Kontynuuj ustawianie wolnej kamery.",
            params = { event = "qb-garages:client:resumeFreeCam" }
        },
        {
            header = "❌ Anuluj",
            txt = "Wróć do normalnego podglądu bez zapisywania.",
            color = "danger",
            params = { event = "qb-garages:client:cancelFreeCam" }
        },
    })
end

-- Przycisk w menu garażu (nad listą pojazdów), widoczny tylko dla admina
RegisterNetEvent('qb-garages:client:adminStartCameraPick', function()
    EnterFreeCamState()
end)

local function CyclePreview(dir)
    if #previewList == 0 then return end
    previewIndex = previewIndex + dir
    if previewIndex < 1 then previewIndex = #previewList end
    if previewIndex > #previewList then previewIndex = 1 end
    ShowPreviewVehicle()
    if garageMenuContext then
        OpenGarageVehicleMenu()
    end
end

local function StopPreview()
    previewActive = false
    previewFreeCam = false
    previewList = {}
    previewIndex = 1
    garageMenuContext = nil
    DeletePreviewVehicle()
    if previewCam and DoesCamExist(previewCam) then
        DestroyCam(previewCam)
    end
    previewCam = nil
    RenderScriptCams(false, true, 200, true, true)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true)
end

local function StartPreview(list)
    if not Config.VehiclePreview.enabled then return end
    previewList = list or {}
    previewIndex = 1
    previewActive = (#previewList > 0)
    previewFreeCam = false
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false)
    ShowPreviewVehicle()
end

RegisterCommand('garagepreview_freecam', function() TogglePreviewFreeCam() end, false)
RegisterCommand('garagepreview_saveangle', function() SavePreviewCamAngle() end, false)
RegisterKeyMapping('garagepreview_freecam', 'Podgląd garażu: włącz/wyłącz wolną kamerę (admin)', 'keyboard', 'F6')
RegisterKeyMapping('garagepreview_saveangle', 'Podgląd garażu: zapisz obecny kąt kamery (admin)', 'keyboard', 'F7')

local adminHintVisible = true
RegisterCommand('garagepreview_togglehint', function()
    if not isAdminCached then return end
    adminHintVisible = not adminHintVisible
end, false)
RegisterKeyMapping('garagepreview_togglehint', 'Podgląd garażu: pokaż/ukryj plakietkę admina', 'keyboard', 'F8')

CreateThread(function()
    local LEFT, RIGHT = 174, 175
    while true do
        if previewActive then
            local p = Config.VehiclePreview
            if previewFreeCam then
                UpdateOrbitCam()
            end
            if previewVehicle and DoesEntityExist(previewVehicle) and not previewFreeCam then
                local h = (GetEntityHeading(previewVehicle) + (p.spinSpeed or 10.0) * GetFrameTime()) % 360.0
                SetEntityHeading(previewVehicle, h)
            end
            if p.cycleLeftRight and not previewFreeCam then
                if IsControlJustPressed(0, LEFT) then CyclePreview(-1) end
                if IsControlJustPressed(0, RIGHT) then CyclePreview(1) end
            end
            if isAdminCached and adminHintVisible then
                if previewFreeCam then
                    DrawCornerText("~y~Ustawianie kąta podglądu~s~~n~Mysz = obrót kamery wokół auta~n~Scroll = przybliż/oddal~n~~g~F7~s~ - otwórz zapis~n~~r~F6~s~ - anuluj, wróć do listy~n~~s~F8~s~ - ukryj tę plakietkę")
                else
                    DrawCornerText("~s~🛡️ ADMIN~s~~n~Masz tu funkcje pomocnicze (menu garażu)~n~~s~F8~s~ - ukryj")
                end
            end
            local data = previewList[previewIndex]
            if data and not previewFreeCam then
                local vd = QBCore.Shared.Vehicles[data.vehicle]
                local name = (vd and vd.name) or data.vehicle or "?"
                DrawPreviewText(("~b~%s~s~   %s    ~y~Wybierz pojazd z listy~s~   ~g~Potwierdź na dole~s~"):format(name, data.plate or ""))
            end
            Wait(0)
        else
            Wait(300)
        end
    end
end)
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
local function MenuGarage(type, garage, indexgarage)
    local header
    local leave
    if type == "house" then
        header = Lang:t("menu.header." .. type .. "_car", { value = garage.label })
        leave = Lang:t("menu.leave.car")
    else
        header = Lang:t("menu.header." .. type .. "_" .. garage.vehicle, { value = garage.label })
        leave = Lang:t("menu.leave." .. garage.vehicle)
    end

    exports['qb-core']:HideText()

    exports['qb-menu']:openMenu({
        {
            header = header,
            isMenuHeader = true
        },
        {
            header = Lang:t("menu.header.vehicles"),
            txt = Lang:t("menu.text.vehicles"),
            params = {
                event = "qb-garages:client:VehicleList",
                args = {
                    type = type,
                    garage = garage,
                    index = indexgarage,
                }
            }
        },
        {
            header = leave,
            txt = "",
            color = "danger",
            params = {
                event = "qb-garages:client:closeGarageMenu",
            }
        },
    })
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
    TriggerEvent("qb-menu:closeMenu")
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

-- qb-menu zamyka NUI (ESC / X / przycisk wyjścia) -> wyłącz podgląd 3D.
-- Wyjątek: gdy TO MY sami zamknęliśmy menu na czas trybu wolnej kamery (F6),
-- podgląd ma zostać aktywny - menu wraca po F6/F7 (patrz ExitFreeCamState).
AddEventHandler("qb-menu:client:menuClosed", function()
    if freeCamMenuClosedByUs then
        freeCamMenuClosedByUs = false
        return
    end
    if previewActive then StopPreview() end
    if currentGarage then RefreshGarageHints(currentGarage) end
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
        local data = json.decode(veh.mods)

        for k, v in pairs(data.doorStatus) do
            if v then
                SetVehicleDoorBroken(currentVehicle, tonumber(k), true)
            end
        end
        for k, v in pairs(data.tireBurstState) do
            if v then
                SetVehicleTyreBurst(currentVehicle, tonumber(k), true)
            end
        end
        for k, v in pairs(data.windowStatus) do
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

function OpenGarageVehicleMenu()
    exports['qb-core']:HideText()
    local ctx = garageMenuContext
    if not ctx then return end

    local MenuGarageOptions = {
        {
            header = ctx.header,
            isMenuHeader = true
        },
    }

    for i, v in ipairs(ctx.vehicles) do
        local enginePercent = round(v.engine / 10, 0)
        local bodyPercent = round(v.body / 10, 0)
        local currentFuel = v.fuel
        local vehicleData = QBCore.Shared.Vehicles[v.vehicle]
        local vname = vehicleData and vehicleData.name or v.vehicle
        local stateText = v.state
        if type(v.state) == "number" then
            if v.state == 0 then
                stateText = Lang:t("status.out")
            elseif v.state == 1 then
                stateText = Lang:t("status.garaged")
            elseif v.state == 2 then
                stateText = Lang:t("status.impound")
            end
        end

        local prefix = (i == previewIndex) and "▶ " or ""
        local menuHeader
        local txt

        if ctx.type == "depot" and vname ~= nil then
            menuHeader = prefix .. Lang:t('menu.header.depot', { value = vname, value2 = v.depotprice })
            txt = Lang:t('menu.text.depot', { value = v.plate, value2 = currentFuel, value3 = enginePercent, value4 = bodyPercent })
        else
            menuHeader = prefix .. Lang:t('menu.header.garage', { value = vname, value2 = v.plate })
            txt = Lang:t('menu.text.garage', { value = stateText, value2 = currentFuel, value3 = enginePercent, value4 = bodyPercent })
        end

        MenuGarageOptions[#MenuGarageOptions + 1] = {
            header = menuHeader,
            txt = txt,
            disabled = false,
            params = {
                event = "qb-garages:client:selectPreviewVehicle",
                args = { index = i },
                keepOpen = true,
                navSelect = true,               -- strzałki góra/dół od razu pokazują auto
                navActive = (i == previewIndex), -- po odświeżeniu menu zaznaczenie zostaje tu
            }
        }
    end

    local selected = ctx.vehicles[previewIndex]
    local selectedName = selected and (QBCore.Shared.Vehicles[selected.vehicle] and QBCore.Shared.Vehicles[selected.vehicle].name or selected.vehicle) or "?"

    if isAdminCached then
        MenuGarageOptions[#MenuGarageOptions + 1] = {
            header = "🎥 Ustaw kamerę podglądu",
            txt = "[Admin] Zamknij to menu i obróć kamerę wokół auta, żeby wybrać kąt.",
            color = "admin",
            params = {
                event = "qb-garages:client:adminStartCameraPick",
            }
        }
    end

    MenuGarageOptions[#MenuGarageOptions + 1] = {
        header = "Wyciągnij pojazd",
        txt = ("Potwierdź wyciągnięcie: %s [%s]"):format(selectedName, selected and selected.plate or "?"),
        color = "success",
        params = {
            event = "qb-garages:client:confirmTakeOutGarage",
            args = {},
        }
    }

    MenuGarageOptions[#MenuGarageOptions + 1] = {
        header = ctx.leave,
        txt = "",
        color = "danger",
        params = {
            event = "qb-garages:client:closeGarageMenu",
        }
    }

    exports['qb-menu']:openMenu(MenuGarageOptions, false, false, { position = 'right' })
end

RegisterNetEvent("qb-garages:client:selectPreviewVehicle", function(data)
    if not garageMenuContext or not data or not data.index then return end
    if not garageMenuContext.vehicles[data.index] then return end
    previewIndex = data.index
    ShowPreviewVehicle()
    OpenGarageVehicleMenu()
end)

RegisterNetEvent("qb-garages:client:confirmTakeOutGarage", function()
    local ctx = garageMenuContext
    if not ctx then return end
    local vehicle = ctx.vehicles[previewIndex]
    if not vehicle then return end

    local payload = {
        vehicle = vehicle,
        type = ctx.type,
        garage = ctx.garage,
        index = ctx.index,
    }

    if ctx.type == "depot" then
        TriggerEvent("qb-garages:client:TakeOutDepot", payload)
    else
        TriggerEvent("qb-garages:client:takeOutGarage", payload)
    end
end)

RegisterNetEvent("qb-garages:client:VehicleList", function(data)
    local type = data.type
    local garage = data.garage
    local indexgarage = data.index
    local header
    local leave
    if type == "house" then
        header = Lang:t("menu.header." .. type .. "_car", { value = garage.label })
        leave = Lang:t("menu.leave.car")
    else
        header = Lang:t("menu.header." .. type .. "_" .. garage.vehicle, { value = garage.label })
        leave = Lang:t("menu.leave." .. garage.vehicle)
    end

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
                header = header,
                leave = leave,
            }

            currentGarage = garage
            currentGarageIndex = indexgarage
            previewIndex = 1
            StartPreview(shownVehicles)
            OpenGarageVehicleMenu()
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
    RefreshAdminStatus()
end)

AddEventHandler("onResourceStart", function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateBlipsZones()
    RefreshAdminStatus()
end)

-- Zabezpieczenie: gdyby ktoś zrestartował ten resource w trakcie podglądu/ustawiania
-- kamery, gracz nie może zostać zamrożony/niewidzialny na stałe.
AddEventHandler("onResourceStop", function(res)
    if res ~= GetCurrentResourceName() then return end
    RenderScriptCams(false, true, 0, true, true)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true)
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

    if vehicle.depotprice ~= 0 then
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
