local INPUT_AIM = 0
local UseFPS = false
local justpressed = 0

-- Wymuszanie widoku FPS/TPP.
-- Blokada kontroli walki wrecz (140/141/142) siedzi w ignore.lua - bylo tu w dwoch kopiach (audyt 2026-09-02).
CreateThread(function()
    while true do
        Wait(0)

        if IsControlPressed(0, INPUT_AIM) then
            justpressed = justpressed + 1
        end

        if IsControlJustReleased(0, INPUT_AIM) then
            if justpressed < 15 then
                UseFPS = true
            end
            justpressed = 0
        end

        if GetFollowPedCamViewMode() == 1 or GetFollowVehicleCamViewMode() == 1 then
            SetFollowPedCamViewMode(0)
            SetFollowVehicleCamViewMode(0)
        end

        if UseFPS then
            if GetFollowPedCamViewMode() == 0 or GetFollowVehicleCamViewMode() == 0 then
                SetFollowPedCamViewMode(4)
                SetFollowVehicleCamViewMode(4)
            else
                SetFollowPedCamViewMode(0)
                SetFollowVehicleCamViewMode(0)
            end
            UseFPS = false
        end
    end
end)
