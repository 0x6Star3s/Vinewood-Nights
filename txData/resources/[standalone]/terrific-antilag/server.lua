local nextPop = {} -- src -> timestamp, limit rownolegly do klienckiego

RegisterNetEvent('terrific-antilag:server:pop', function(netId)
    local src = source

    local now = GetGameTimer()
    if (nextPop[src] or 0) > now then return end
    nextPop[src] = now + Config.Cooldown

    if type(netId) ~= 'number' then return end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end

    -- bez tego kazdy klient moglby podpalic dowolne auto na serwerze
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or GetVehiclePedIsIn(ped) ~= vehicle then return end

    local origin = GetEntityCoords(ped)

    for _, target in ipairs(GetPlayers()) do
        local targetPed = GetPlayerPed(target)
        if targetPed ~= 0 and #(GetEntityCoords(targetPed) - origin) <= Config.HearDistance then
            TriggerClientEvent('terrific-antilag:client:pop', target, netId, origin)
        end
    end
end)

AddEventHandler('playerDropped', function()
    nextPop[source] = nil
end)
