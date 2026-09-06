local dailyWithdraws = {}
local QBCore = exports['qb-core']:GetCoreObject()

-- Thread

CreateThread(function()
    while true do
        Wait(3600000)
        dailyWithdraws = {}
        TriggerClientEvent('QBCore:Notify', -1, "Limit wypłat z bankomatu odnowiony", "success")
    end
end)

-- Functions

---Karta z bazy (bank_cards): PIN i blokada sa tam, nie w metadanych itemu.
---Zmiana PIN-u w banku nie aktualizuje itemu, wiec item jest tylko "dowodem posiadania".
local function CardRow(citizenid)
    return MySQL.single.await('SELECT cardNumber, cardPin, cardLocked FROM bank_cards WHERE citizenid = ?', { citizenid })
end

local function CardOk(row, cardnumber, pin)
    return row ~= nil
        and tostring(row.cardNumber) == tostring(cardnumber)
        and tostring(row.cardPin) == tostring(pin)
        and (tonumber(row.cardLocked) or 0) == 0
end

---Czy gracz ma przy sobie karte do tego konta (bylo: cid prosto z NUI = wyplata z cudzego konta)
local function HasCardFor(Player, citizenid)
    for _, itemName in ipairs({ 'visa', 'mastercard' }) do
        for _, item in pairs(Player.Functions.GetItemsByName(itemName) or {}) do
            if item.info and item.info.citizenid == citizenid then return true end
        end
    end
    return false
end

-- Event

RegisterNetEvent('qb-atms:server:enteratm', function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end

    local cards = {}
    for _, itemName in ipairs({ 'visa', 'mastercard' }) do
        for _, item in pairs(xPlayer.Functions.GetItemsByName(itemName) or {}) do
            local info = item.info
            if type(info) == 'table' and info.citizenid then
                -- PIN i status zawsze z bazy - NUI porownuje PIN lokalnie, serwer i tak sprawdza ponownie
                local row = CardRow(info.citizenid)
                info.cardActive = row ~= nil
                    and tostring(row.cardNumber) == tostring(info.cardNumber)
                    and (tonumber(row.cardLocked) or 0) == 0
                if info.cardActive then info.cardPin = row.cardPin end
                cards[#cards + 1] = info
            end
        end
    end

    if #cards == 0 then
        TriggerClientEvent('QBCore:Notify', src, "Nie masz karty do bankomatu. Zamów ją w banku, w zakładce karty.", "error", 6000)
        return
    end
    TriggerClientEvent('qb-atms:client:loadATM', src, cards)
end)

RegisterNetEvent('qb-atms:server:doAccountWithdraw', function(data)
    if type(data) ~= 'table' then return end
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end

    local cardHolder = data.cid
    local amount = tonumber(data.amount)
    if not amount or amount <= 0 or amount % 1 ~= 0 then
        return TriggerClientEvent('QBCore:Notify', src, "Kwota musi być większa od zera", "error")
    end

    if type(cardHolder) ~= 'string' or not HasCardFor(xPlayer, cardHolder) then
        return TriggerClientEvent('QBCore:Notify', src, "Nie masz tej karty przy sobie", "error")
    end
    if not CardOk(CardRow(cardHolder), data.cardnumber, data.pin) then
        return TriggerClientEvent('QBCore:Notify', src, "Karta odrzucona: zły PIN albo karta zablokowana", "error")
    end

    dailyWithdraws[cardHolder] = dailyWithdraws[cardHolder] or 0
    if dailyWithdraws[cardHolder] + amount >= Config.DailyLimit then
        return TriggerClientEvent('QBCore:Notify', src, "Osiągnięto dzienny limit wypłat", "error")
    end

    local banking = {}
    local xCH = QBCore.Functions.GetPlayerByCitizenId(cardHolder)
    if xCH ~= nil then
        if xCH.Functions.GetMoney('bank') - amount >= 0 and xCH.Functions.RemoveMoney('bank', amount, 'atm-withdraw') then
            xPlayer.Functions.AddMoney('cash', amount, 'atm-withdraw')
            dailyWithdraws[cardHolder] = dailyWithdraws[cardHolder] + amount
            TriggerClientEvent('QBCore:Notify', src, ("Wypłacono $%s. Dziś wypłacono: $%s"):format(amount, dailyWithdraws[cardHolder]), "success")
        else
            TriggerClientEvent('QBCore:Notify', src, "Za mało pieniędzy na koncie", "error")
        end

        banking['online'] = true
        banking['name'] = xCH.PlayerData.charinfo.firstname .. ' ' .. xCH.PlayerData.charinfo.lastname
        banking['bankbalance'] = xCH.Functions.GetMoney('bank')
        banking['accountinfo'] = xCH.PlayerData.charinfo.account
        banking['cash'] = xPlayer.Functions.GetMoney('cash')
    else
        local row = MySQL.single.await('SELECT money, charinfo FROM players WHERE citizenid = ?', { cardHolder })
        if not row then return end
        local money = json.decode(row.money)
        local charinfo = json.decode(row.charinfo)
        local bankCount = (tonumber(money.bank) or 0) - amount
        if bankCount >= 0 then
            xPlayer.Functions.AddMoney('cash', amount, 'atm-withdraw')
            money.bank = bankCount
            MySQL.update('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), cardHolder })
            dailyWithdraws[cardHolder] = dailyWithdraws[cardHolder] + amount
            TriggerClientEvent('QBCore:Notify', src, ("Wypłacono $%s. Dziś wypłacono: $%s"):format(amount, dailyWithdraws[cardHolder]), "success")
        else
            TriggerClientEvent('QBCore:Notify', src, "Za mało pieniędzy na koncie", "error")
        end

        banking['online'] = false
        banking['name'] = charinfo.firstname .. ' ' .. charinfo.lastname
        banking['bankbalance'] = money.bank
        banking['accountinfo'] = charinfo.account
        banking['cash'] = xPlayer.Functions.GetMoney('cash')
    end
    TriggerClientEvent('qb-atms:client:updateBankInformation', src, banking)
end)

-- Callbacks

QBCore.Functions.CreateCallback('qb-debitcard:server:requestCards', function(source, cb)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    local cards = {}
    if not xPlayer then return cb(cards) end
    for _, itemName in ipairs({ 'visa', 'mastercard' }) do
        for _, v in pairs(xPlayer.Functions.GetItemsByName(itemName) or {}) do
            cards[#cards + 1] = v.info
        end
    end
    cb(cards)
end)

QBCore.Functions.CreateCallback('qb-debitcard:server:deleteCard', function(source, cb, data)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer or type(data) ~= 'table' then return cb(false) end
    local found = xPlayer.Functions.GetCardSlot(data.cardNumber, data.cardType)
    if found ~= nil then
        xPlayer.Functions.RemoveItem(data.cardType, 1, found)
        cb(true)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('qb-atms:server:loadBankAccount', function(source, cb, cid, cardnumber, pin)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer or type(cid) ~= 'string' or not HasCardFor(xPlayer, cid) or not CardOk(CardRow(cid), cardnumber, pin) then
        TriggerClientEvent('QBCore:Notify', source, "Karta odrzucona: zły PIN albo karta zablokowana", "error")
        return cb(nil)
    end

    local banking = {}
    local xCH = QBCore.Functions.GetPlayerByCitizenId(cid)
    if xCH ~= nil then
        banking['online'] = true
        banking['name'] = xCH.PlayerData.charinfo.firstname .. ' ' .. xCH.PlayerData.charinfo.lastname
        banking['bankbalance'] = xCH.Functions.GetMoney('bank')
        banking['accountinfo'] = xCH.PlayerData.charinfo.account
        banking['cash'] = xPlayer.Functions.GetMoney('cash')
    else
        local row = MySQL.single.await('SELECT money, charinfo FROM players WHERE citizenid = ?', { cid })
        if not row then return cb(nil) end
        local money = json.decode(row.money)
        local charinfo = json.decode(row.charinfo)
        banking['online'] = false
        banking['name'] = charinfo.firstname .. ' ' .. charinfo.lastname
        banking['bankbalance'] = money.bank
        banking['accountinfo'] = charinfo.account
        banking['cash'] = xPlayer.Functions.GetMoney('cash')
    end
    cb(banking)
end)

-- Card Items

QBCore.Functions.CreateUseableItem('visa', function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player and Player.Functions.GetItemByName(item.name) then
        TriggerClientEvent('qb-atms:client:checkATM', source)
    end
end)

QBCore.Functions.CreateUseableItem('mastercard', function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player and Player.Functions.GetItemByName(item.name) then
        TriggerClientEvent('qb-atms:client:checkATM', source)
    end
end)
