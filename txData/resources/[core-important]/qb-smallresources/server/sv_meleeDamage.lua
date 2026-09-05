local QBCore = exports['qb-core']:GetCoreObject()

-- USUNIETE 2026-09-02 (audyt, sekcja 3):
--   rodinium-weapons:attackedByCash / processGiveCashAmount - dawaly gotowke z powietrza dowolnemu graczowi
--   cash:roll jako RegisterNetEvent - klient podawal cudze source i kwote
-- Zostaje tylko komenda serwerowa /rollcash (zamiana wlasnej gotowki na item weapon_cash).

local function RollCash(src, amount)
    local Player = QBCore.Functions.GetPlayer(src)
    amount = tonumber(amount)

    if not Player or not amount or amount <= 0 or amount % 1 ~= 0 then return end
    if Player.PlayerData.money['cash'] < amount then return end

    Player.Functions.RemoveMoney('cash', amount, 'Rolled Cash')
    Player.Functions.AddItem('weapon_cash', amount)
end

RegisterCommand("rollcash", function(src, args)
    if src == 0 then return end -- nie z konsoli
    RollCash(src, args[1])
end, false)
