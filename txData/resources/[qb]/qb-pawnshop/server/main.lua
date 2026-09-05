local QBCore = exports['qb-core']:GetCoreObject()

local function exploitBan(id, reason)
    MySQL.insert('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)',
        {
            GetPlayerName(id),
            QBCore.Functions.GetIdentifier(id, 'license'),
            QBCore.Functions.GetIdentifier(id, 'discord'),
            QBCore.Functions.GetIdentifier(id, 'ip'),
            reason,
            2147483647,
            'qb-pawnshop'
        })
    TriggerEvent('qb-log:server:CreateLog', 'pawnshop', 'Player Banned', 'red',
        string.format('%s was banned by %s for %s', GetPlayerName(id), 'qb-pawnshop', reason), true)
    DropPlayer(id, 'You were permanently banned by the server for: Exploiting')
end

---Cena zawsze z Config.PawnItems - klient nie decyduje ile dostaje
local function GetPawnPrice(itemName)
    for _, v in pairs(Config.PawnItems) do
        if v.item == itemName then return tonumber(v.price) end
    end
end

local function GetMeltingConfig(itemName)
    for _, v in pairs(Config.MeltingItems) do
        if v.item == itemName then return v end
    end
end

-- [src] = { cfg = wpis z Config.MeltingItems, amount = ile, ready = os.time() kiedy gotowe }
local melting = {}

AddEventHandler('playerDropped', function()
    melting[source] = nil
end)

RegisterNetEvent('qb-pawnshop:server:sellPawnItems', function(itemName, itemAmount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local amount = tonumber(itemAmount)
    local price = GetPawnPrice(itemName)
    if not amount or amount <= 0 or amount % 1 ~= 0 or not price then return end

    local totalPrice = amount * price
    itemAmount = amount
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local dist
    for _, value in pairs(Config.PawnLocation) do
        dist = #(playerCoords - value.coords)
        if #(playerCoords - value.coords) < 2 then
            dist = #(playerCoords - value.coords)
            break
        end
    end
    if dist > 5 then exploitBan(src, 'sellPawnItems Exploiting') return end
    if Player.Functions.RemoveItem(itemName, tonumber(itemAmount)) then
        if Config.BankMoney then
            Player.Functions.AddMoney('bank', totalPrice)
        else
            Player.Functions.AddMoney('cash', totalPrice)
        end
        TriggerClientEvent('QBCore:Notify', src, Lang:t('success.sold', { value = tonumber(itemAmount), value2 = QBCore.Shared.Items[itemName].label, value3 = totalPrice }),'success')
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_items'), 'error')
    end
    TriggerClientEvent('qb-pawnshop:client:openMenu', src)
end)

RegisterNetEvent('qb-pawnshop:server:meltItemRemove', function(itemName, itemAmount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local amount = tonumber(itemAmount)
    local cfg = GetMeltingConfig(itemName)
    if not amount or amount <= 0 or amount % 1 ~= 0 or not cfg then return end

    if Player.Functions.RemoveItem(itemName, amount) then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
        local meltTime = amount * cfg.meltTime -- minuty
        melting[src] = { cfg = cfg, amount = amount, ready = os.time() + math.floor(meltTime * 60) }
        TriggerClientEvent('qb-pawnshop:client:startMelting', src, cfg, amount, (meltTime * 60000 / 1000))
        TriggerClientEvent('QBCore:Notify', src, Lang:t('info.melt_wait', { value = meltTime }), 'primary')
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_items'), 'error')
    end
end)

RegisterNetEvent('qb-pawnshop:server:pickupMelted', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local dist
    for _, value in pairs(Config.PawnLocation) do
        dist = #(playerCoords - value.coords)
        if #(playerCoords - value.coords) < 2 then
            dist = #(playerCoords - value.coords)
            break
        end
    end
    if dist > 5 then exploitBan(src, 'pickupMelted Exploiting') return end

    local pending = melting[src]
    if not pending then return end
    if os.time() < pending.ready then return end -- jeszcze sie topi
    melting[src] = nil

    for _, reward in pairs(pending.cfg.rewards) do
        local rewardAmount = reward.amount * pending.amount
        if Player.Functions.AddItem(reward.item, rewardAmount) then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[reward.item], 'add')
            TriggerClientEvent('QBCore:Notify', src, Lang:t('success.items_received',{ value = rewardAmount, value2 = QBCore.Shared.Items[reward.item].label }), 'success')
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.inventory_full', { value = QBCore.Shared.Items[reward.item].label}), 'warning', 7500)
        end
    end
    TriggerClientEvent('qb-pawnshop:client:resetPickup', src)
    TriggerClientEvent('qb-pawnshop:client:openMenu', src)
end)

QBCore.Functions.CreateCallback('qb-pawnshop:server:getInv', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local inventory = Player.PlayerData.items
    return cb(inventory)
end)
