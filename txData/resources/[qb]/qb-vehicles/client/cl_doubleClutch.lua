local function Info()
    local PlayerPed = PlayerPedId()
    local plyVeh = GetVehiclePedIsIn(PlayerPed, false)
    local IsDriver = GetPedInVehicleSeat(plyVeh, -1) == PlayerPed
    local Car = IsThisModelACar(GetEntityModel(plyVeh))
    local returnValue = plyVeh ~= 0 and plyVeh ~= nil and IsDriver and Car
    return returnValue, plyVeh
end

local Driver, plyVeh = Info()
local isEnabled = true

function toggleDoubleClutchBlock(toggle)
    isEnabled = toggle
end
exports('toggleDoubleClutchBlock', toggleDoubleClutchBlock)

Citizen.CreateThread(function()
    while true do
        Driver, plyVeh = Info()
        if Driver and isEnabled then
            -- tylko 1. bieg: "< 3" lapalo tez bieg wsteczny (gear 0) i legalne przyspieszanie mocnych aut
            -- w 2. biegu powyzej 50 mph, przez co np. 707-konny Charger nie mogl przekroczyc 80 km/h
            if GetVehicleCurrentGear(plyVeh) == 1 and GetVehicleCurrentRpm(plyVeh) == 1.0 and math.ceil(GetEntitySpeed(plyVeh) * 2.236936) > 50 then
              local maxGears = GetVehicleHandlingInt(plyVeh, "CHandlingData", "nInitialDriveGears")

              while GetVehicleCurrentRpm(plyVeh) > 0.6 and maxGears > 3 do
                SetVehicleCurrentRpm(plyVeh, 0.3)
                Citizen.Wait(1)
              end
              
              Citizen.Wait(800)
            end
        end
        Citizen.Wait(500)
    end
end)

--- if current gear is less than 3 and the speed is over 50, double clutch will be slightly interupted somewhat like you failed timing a double clutch previously.

local active = 0
local limited = nil  -- auto, ktoremu ustawilismy limit; bez tego zostawal na nim po wyjsciu kierowcy

local function clearLimit()
    if limited and DoesEntityExist(limited) then
        SetVehicleMaxSpeed(limited, 0.0)
    end
    limited, active = nil, 0
end

Citizen.CreateThread(function()
    while true do
        if Driver then
            -- IsEntityInAir zamiast progu kompresji 0.07: auta o krotkim skoku zawieszenia
            -- (16charger ma 0.105 m przy medianie floty 0.200) mialy ten warunek spelniony
            -- na plaskiej drodze, wiec limit predkosci zapinal sie w normalnej jezdzie
            if IsEntityInAir(plyVeh) then
                local carSpeed = GetEntitySpeed(plyVeh)
                if carSpeed > 30.0 then
                    active = 15
                    limited = plyVeh
                    SetVehicleMaxSpeed(plyVeh, carSpeed)
                end
            end
            Citizen.Wait(20)
            if active > 1 then
                active = active - 1
            else
                if active == 1 then clearLimit() end
                Citizen.Wait(150)
            end
        else
            clearLimit()  -- wyjscie z auta w trakcie odliczania nie moze zostawiac limitu na pojezdzie
            Citizen.Wait(1000)
        end
    end
end)
