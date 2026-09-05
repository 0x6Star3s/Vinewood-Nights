-- Wylaczanie "action mode" (bylo w dwoch identycznych petlach co 1 ms - audyt 2026-09-02)
CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        if IsPedUsingActionMode(ped) then
            SetPedUsingActionMode(ped, false, -1, 'DEFAULT_ACTION')
        end
    end
end)
