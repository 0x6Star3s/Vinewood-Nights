-- Strzaly z wydechu. Napisane od nowa; z yorick-antilag zostaly dzwieki
-- i pomysl na czastke veh_backfire na kosciach wydechu.
--
-- Roznice wzgledem oryginalu:
--   * oryginal wysylal 2 eventy serwerowe na kazdy strzal w petli Wait(0),
--     a serwer rozsylal je do WSZYSTKICH graczy - tutaj serwer filtruje po dystansie
--   * oryginal ufal netId od klienta (kazdy mogl podpalic cudze auto) - tutaj serwer
--     sprawdza, czy nadawca faktycznie siedzi w tym pojezdzie
--   * oryginal liczyl glosnosc jako vol/ratio, wiec z bliska szla w nieskonczonosc
--   * oryginal mial sztywna liste modeli aut, tutaj warunkiem jest kupiony mod

local enabled = true
local nextPop = 0

RegisterCommand('antilag', function()
    enabled = not enabled
    PlaySoundFrontend(-1, 'CONFIRM_BEEP', 'HUD_MINI_GAME_SOUNDSET', true)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(enabled and '~g~Antilag wlaczony' or '~r~Antilag wylaczony')
    DrawNotification(false, false)
end, false)

--- Warunki stale. Obroty sprawdzamy osobno, przy wykrywaniu zbocza.
local function canPop(ped, vehicle)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return false end
    if GetVehicleCurrentGear(vehicle) < 1 then return false end
    if IsEntityInAir(vehicle) then return false end
    if GetEntitySpeed(vehicle) < Config.MinSpeed then return false end
    if IsControlPressed(0, 72) then return false end -- hamulec

    -- Antilag to platny mod z warsztatu, nie wyposazenie kazdego auta.
    if Config.RequireMod then
        if GetResourceState('terrific-customs') ~= 'started' then return false end
        local ok, has = pcall(function() return exports['terrific-customs']:HasAntilag(vehicle) end)
        if not ok or not has then return false end
    end

    return true
end

-- Strzal to ZBOCZE: jechales na gazie przy wysokich obrotach i zdjales noge.
-- Sprawdzanie "wysokie obroty i puszczony gaz" jako stanu nie dziala - po zdjeciu
-- nogi obroty lecą w dol w ulamku sekundy i warunek prawie nigdy nie trafia.
CreateThread(function()
    local onThrottle = false
    local burstUntil = 0

    while true do
        local wait = 500
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if enabled and vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            wait = 0
            local now = GetGameTimer()
            local accelerating = IsControlPressed(0, 71)

            if accelerating then
                if GetVehicleCurrentRpm(vehicle) > Config.Rpm then onThrottle = true end
            elseif onThrottle then
                onThrottle = false
                if canPop(ped, vehicle) then burstUntil = now + Config.BurstTime end
            end

            if now < burstUntil and now >= nextPop then
                nextPop = now + Config.Cooldown
                TriggerServerEvent('terrific-antilag:server:pop', VehToNet(vehicle))
                -- kontrolka "AL" na desce rozdzielczej rysuje terrific-customs
                if GetResourceState('terrific-customs') == 'started' then
                    pcall(function() exports['terrific-customs']:FlashAntilag() end)
                end
            end
        else
            onThrottle = false
            burstUntil = 0
        end

        Wait(wait)
    end
end)

RegisterNetEvent('terrific-antilag:client:pop', function(netId, origin)
    if not NetworkDoesEntityExistWithNetworkId(netId) then return end

    local vehicle = NetToVeh(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local distance = #(GetEntityCoords(PlayerPedId()) - origin)
    if distance > Config.HearDistance then return end

    if not HasNamedPtfxAssetLoaded('core') then
        RequestNamedPtfxAsset('core')
        local deadline = GetGameTimer() + 1000
        while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < deadline do
            Wait(0)
        end
        if not HasNamedPtfxAssetLoaded('core') then return end
    end

    -- StartParticleFxNonLoopedOnEntityBone NIE ISTNIEJE w zestawie natywek FiveM
    -- (jest wersja ...OnPedBone i ...OnEntity, ale nie non-looped na kosci encji).
    -- Wersja looped + natychmiastowy stop to ten sam trik, ktorego uzywa qb-tunerchip
    -- przy NOS-ie i oryginalny yorick-antilag.
    for _, bone in ipairs(Config.ExhaustBones) do
        local boneIndex = GetEntityBoneIndexByName(vehicle, bone)
        if boneIndex ~= -1 then
            SetPtfxAssetNextCall('core')
            UseParticleFxAssetNextCall('core')

            local handle = StartParticleFxLoopedOnEntityBone('veh_backfire', vehicle,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0, boneIndex, Config.FlameSize, 0.0, 0.0, 0.0)

            if handle then
                -- true = stop natychmiastowy. Wersja "wygasajaca" moglaby zostawic
                -- zapetlony plomien na stale, jesli natywka zachowa sie inaczej niz
                -- w dokumentacji - a zabity ogien jest mniej szkodliwy niz wieczny.
                StopParticleFxLooped(handle, true)
            end
        end
    end

    -- glosnosc spada liniowo z odlegloscia (oryginal dzielil przez ratio, czyli odwrotnie)
    SendNUIMessage({
        type   = 'pop',
        file   = tostring(math.random(1, 6)),
        volume = Config.Volume * (1.0 - distance / Config.HearDistance),
    })
end)
