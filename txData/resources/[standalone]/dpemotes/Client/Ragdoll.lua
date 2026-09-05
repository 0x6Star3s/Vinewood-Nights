local isInRagdoll = false

Citizen.CreateThread(function()
 while true do
    -- ponytail: SetPedToRagdoll trzyma 1000 ms, wiec 200 ms odswiezania starczy
    Citizen.Wait(isInRagdoll and 200 or 500)
    if isInRagdoll then
      SetPedToRagdoll(PlayerPedId(), 1000, 1000, 0, 0, 0, 0)
    end
  end
end)

Citizen.CreateThread(function()
    while true do
    Citizen.Wait(0)
    if IsControlJustPressed(2, Config.RagdollKeybind) and Config.RagdollEnabled and IsPedOnFoot(PlayerPedId()) then
        if isInRagdoll then
            isInRagdoll = false
        else
            isInRagdoll = true
            Wait(500)
        end
    end
  end
end)

