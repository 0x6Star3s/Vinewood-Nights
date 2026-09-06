local QBCore = exports['qb-core']:GetCoreObject()

-- Wezwanie lawety: trafia do wszystkich z praca tow. Bez odpowiedzi zwrotnej -
-- stara wersja pozwalala kazdemu klientowi odpowiadac w imieniu lawety.
RegisterNetEvent('tow:sendTowRequest', function(plate, coords)
    local src = source
    if type(plate) ~= 'string' then return end
    local ok, pos = pcall(function()
        return vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    end)
    if not ok then return end
    plate = plate:sub(1, 8)

    local sent = 0
    for _, playerId in ipairs(QBCore.Functions.GetPlayers()) do
        local player = QBCore.Functions.GetPlayer(playerId)
        if player and player.PlayerData.job.name == 'tow' then
            TriggerClientEvent('tow:receiveTowRequest', playerId, plate, pos)
            sent = sent + 1
        end
    end

    if sent > 0 then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('info.tow_request_sent'), 'success')
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_tow_online'), 'error')
    end
end)
