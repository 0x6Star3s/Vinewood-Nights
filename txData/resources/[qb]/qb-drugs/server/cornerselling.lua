local function getAvailableDrugs(source)
    local AvailableDrugs = {}
    local Player = QBCore.Functions.GetPlayer(source)

    if not Player then return nil end

    for i = 1, #Config.CornerSellingDrugsList do
        local item = Player.Functions.GetItemByName(Config.CornerSellingDrugsList[i])

        if item then
            AvailableDrugs[#AvailableDrugs + 1] = {
                item = item.name,
                amount = item.amount,
                label = QBCore.Shared.Items[item.name].label
            }
        end
    end
    return table.type(AvailableDrugs) ~= "empty" and AvailableDrugs or nil
end

lib.callback.register('qb-drugs:server:getAvailableDrugs', function(source)
    return getAvailableDrugs(source)
end)

RegisterNetEvent('qb-drugs:server:giveStealItems', function(drugType)
    local availableDrugs = getAvailableDrugs(source)
    local Player = QBCore.Functions.GetPlayer(source)

    if not availableDrugs or not Player then return end

    drugType = tonumber(drugType)
    if not drugType or not availableDrugs[drugType] then return end

    Player.Functions.AddItem(availableDrugs[drugType].item, math.random(1, 3)) -- ilosc z serwera, nie z klienta
end)

RegisterNetEvent('qb-drugs:server:sellCornerDrugs', function(drugType, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local availableDrugs = getAvailableDrugs(src)

    if not availableDrugs or not Player then return end

    drugType = tonumber(drugType)
    amount = tonumber(amount)
    if not drugType or not availableDrugs[drugType] then return end
    if not amount or amount <= 0 or amount % 1 ~= 0 or amount > 15 then return end

    local item = availableDrugs[drugType].item
    local ddata = Config.DrugsPrice[item]
    if not ddata then return end

    local price = QBCore.Functions.ScalePayout(math.random(ddata.min, ddata.max) * amount) -- cena z serwera + mnoznik (/boost)

    local hasItem = Player.Functions.GetItemByName(item)
    if hasItem and hasItem.amount >= amount and Player.Functions.RemoveItem(item, amount) then
        TriggerClientEvent('QBCore:Notify', src, Lang:t("success.offer_accepted"), 'success')
        Player.Functions.AddMoney('cash', price, "sold-cornerdrugs")
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], "remove")
        TriggerClientEvent('qb-drugs:client:refreshAvailableDrugs', src, getAvailableDrugs(src))
    else
        TriggerClientEvent('qb-drugs:client:cornerselling', src)
    end
end)

RegisterNetEvent('qb-drugs:server:robCornerDrugs', function(drugType, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local availableDrugs = getAvailableDrugs(src)

    if not availableDrugs or not Player then return end

    local item = availableDrugs[drugType].item

    Player.Functions.RemoveItem(item, amount)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], "remove")
    TriggerClientEvent('qb-drugs:client:refreshAvailableDrugs', src, getAvailableDrugs(src))
end)
