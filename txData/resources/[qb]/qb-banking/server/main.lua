local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    local accts = MySQL.query.await('SELECT * FROM bank_accounts WHERE account_type = ?', { 'Business' })
    if accts[1] ~= nil then
        for _, v in pairs(accts) do
            local acctType = v.business
            if businessAccounts[acctType] == nil then
                businessAccounts[acctType] = {}
            end
            businessAccounts[acctType][tonumber(v.businessid)] = GeneratebusinessAccount(tonumber(v.account_number), tonumber(v.sort_code), tonumber(v.businessid))
        end
    end

    local savings = MySQL.query.await('SELECT * FROM bank_accounts WHERE account_type = ?', { 'Savings' })
    if savings[1] ~= nil then
        for _, v in pairs(savings) do
            savingsAccounts[v.citizenid] = generateSavings(v.citizenid)
        end
    end

    local gangs = MySQL.query.await('SELECT * FROM bank_accounts WHERE account_type = ?', { 'Gang' })
    if gangs[1] ~= nil then
        for _, v in pairs(gangs) do
            gangAccounts[v.gangid] = loadGangAccount(v.gangid)
        end
    end
end)

exports('business', function(acctType, bid)
    if businessAccounts[acctType] then
        if businessAccounts[acctType][tonumber(bid)] then
            return businessAccounts[acctType][tonumber(bid)]
        end
    end
end)

exports('registerAccount', function(cid)
    local _cid = tonumber(cid)
    currentAccounts[_cid] = generateCurrent(_cid)
end)

exports('current', function(cid)
    if currentAccounts[cid] then
        return currentAccounts[cid]
    end
end)

exports('debitcard', function(cardnumber)
    if bankCards[tonumber(cardnumber)] then
        return bankCards[tonumber(cardnumber)]
    else
        return false
    end
end)

exports('savings', function(cid)
    if savingsAccounts[cid] then
        return savingsAccounts[cid]
    end
end)

exports('gang', function(gid)
    if gangAccounts[gid] then
        return gangAccounts[gid]
    end
end)

--[[ -- Only used by the following "qb-banking:initiateTransfer"

local function getCharacterName(cid)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local name = player.PlayerData.name
end

local function checkAccountExists(acct, sc)
    local success
    local cid
    local actype
    local processed = false
    local exists = MySQL.query.await('SELECT * FROM bank_accounts WHERE account_number = ? AND sort_code = ?', { acct, sc })
    if exists[1] ~= nil then
        success = true
        cid = exists[1].character_id
        actype = exists[1].account_type
    else
        success = false
        cid = false
        actype = false
    end
    processed = true
    repeat Wait(0) until processed == true
    return success, cid, actype
end

]]

---Przelew z konta na konto (audyt ekonomii pkt 4: handler byl w calosci zakomentowany).
---Numer konta = IBAN gracza z charinfo.account (ten sam, ktorego uzywa telefon).
RegisterNetEvent('qb-banking:initiateTransfer', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or type(data) ~= 'table' then return end

    local amount = tonumber(data.amount)
    local iban = tostring(data.account or '')
    if not amount or amount <= 0 or amount % 1 ~= 0 or iban == '' then
        TriggerClientEvent('qb-banking:transferError', src, 'Podaj poprawny numer konta i kwote.')
        return
    end

    if iban == Player.PlayerData.charinfo.account then
        TriggerClientEvent('qb-banking:transferError', src, 'To jest Twoje wlasne konto.')
        return
    end

    if Player.PlayerData.money.bank < amount then
        TriggerClientEvent('qb-banking:transferError', src, 'Za malo pieniedzy na koncie.')
        return
    end

    local result = MySQL.query.await('SELECT citizenid, money FROM players WHERE charinfo LIKE ?', { '%"account":"' .. iban .. '"%' })
    if not result or not result[1] then
        TriggerClientEvent('qb-banking:transferError', src, 'Nie znaleziono konta o tym numerze.')
        return
    end

    if not Player.Functions.RemoveMoney('bank', amount, 'bank-transfer-to-' .. result[1].citizenid) then
        TriggerClientEvent('qb-banking:transferError', src, 'Za malo pieniedzy na koncie.')
        return
    end

    local receiver = QBCore.Functions.GetPlayerByCitizenId(result[1].citizenid)
    if receiver then
        receiver.Functions.AddMoney('bank', amount, 'bank-transfer-from-' .. Player.PlayerData.citizenid)
        TriggerClientEvent('QBCore:Notify', receiver.PlayerData.source, ('Przelew przychodzacy: $%s'):format(amount), 'success')
    else
        local money = json.decode(result[1].money)
        money.bank = (money.bank or 0) + amount
        MySQL.update('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), result[1].citizenid })
    end

    TriggerClientEvent('QBCore:Notify', src, ('Przelano $%s na konto %s'):format(amount, iban), 'success')
    TriggerClientEvent('qb-banking:openBankScreen', src)
end)

local function format_int(number)
    local _, _, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
    int = int:reverse():gsub("(%d%d%d)", "%1,")
    return minus .. int:reverse():gsub("^,", "") .. fraction
end

-- Get all bank statements for the current player
local function getBankStatements(cid)
    local bankStatements = MySQL.query.await('SELECT * FROM bank_statements WHERE citizenid = ? ORDER BY record_id DESC LIMIT 30', { cid })
    return bankStatements
end

-- Adds a bank statement to the database
local function addBankStatement(cid, accountType, amountDeposited, amountWithdrawn, accountBalance, statementDescription)
    local time = os.date("%Y-%m-%d %H:%M:%S")
    MySQL.insert('INSERT INTO `bank_statements` (`account`, `citizenid`, `deposited`, `withdraw`, `balance`, `date`, `type`) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        accountType,
        cid,
        amountDeposited,
        amountWithdrawn,
        accountBalance,
        time,
        statementDescription
    })
end

-- Get all bank cards for the current player
local function getBankCard(cid)
    local bankCard = MySQL.query.await('SELECT * FROM bank_cards WHERE citizenid = ? ORDER BY record_id DESC LIMIT 1', { cid })
    return bankCard[1]
end

-- Adds a new bank card to the database, replaces existing card if it exists
local function addNewBankCard(citizenid, cardNumber, cardPin, cardActive, cardLocked, cardType)
    -- The use of REPLACE will act just like INSERT if there are no results that match on the citizenid key
    -- If there are existing results, it will replace the item with the new data
    MySQL.insert('REPLACE INTO bank_cards (`citizenid`, `cardNumber`, `cardPin`, `cardActive`, `cardLocked`, `cardType`) VALUES (?, ?, ?, ?, ?, ?)', {
        citizenid,
        cardNumber,
        cardPin,
        cardActive,
        cardLocked,
        cardType
    })
end

-- Toggle the lock status of a bank card
local function toggleBankCardLock(cid, lockStatus)
    MySQL.update('UPDATE bank_cards SET cardLocked = ? WHERE citizenid = ?', { lockStatus, cid })
end

QBCore.Functions.CreateCallback('qb-banking:getBankingInformation', function(source, cb)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then return cb(nil) end
    local bankStatements = getBankStatements(xPlayer.PlayerData.citizenid)
    local bankCard = getBankCard(xPlayer.PlayerData.citizenid)

    local banking = {
        ['name'] = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname,
        ['bankbalance'] = '$' .. format_int(xPlayer.PlayerData.money['bank']),
        ['cash'] = '$' .. format_int(xPlayer.PlayerData.money['cash']),
        ['accountinfo'] = xPlayer.PlayerData.charinfo.account,
        ['cardInformation'] = bankCard,
        ['statement'] = bankStatements,
    }
    if savingsAccounts[xPlayer.PlayerData.citizenid] then
        local cid = xPlayer.PlayerData.citizenid
        banking['savings'] = {
            ['amount'] = savingsAccounts[cid].GetBalance(),
            ['details'] = savingsAccounts[cid].getAccount(),
            ['statement'] = savingsAccounts[cid].getStatement(),
        }
    end

    cb(banking)
end)

-- Creates a new bank card.
-- If the player already has a card it will replace the existing card with the new one
RegisterNetEvent('qb-banking:createBankCard', function(pin)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    -- PIN zostaje 4-znakowym stringiem (z zerami wiodacymi) w bazie, w itemie i w NUI
    pin = tostring(pin or '')
    if not pin:match('^%d%d%d%d$') then return end
    local cid = xPlayer.PlayerData.citizenid
    local cardNumber = math.random(1000000000000000, 9999999999999999)
    xPlayer.Functions.SetCreditCard(cardNumber)
    local info = {}
    local selectedCard = Config.cardTypes[math.random(1, #Config.cardTypes)]
    info.citizenid = cid
    info.name = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname
    info.cardNumber = cardNumber
    info.cardPin = pin
    info.cardActive = true
    info.cardType = selectedCard

    if selectedCard == "visa" then
        xPlayer.Functions.AddItem('visa', 1, nil, info)
    elseif selectedCard == "mastercard" then
        xPlayer.Functions.AddItem('mastercard', 1, nil, info)
    end

    addNewBankCard(cid, cardNumber, info.cardPin, info.cardActive, 0, info.cardType)

    TriggerClientEvent('qb-banking:openBankScreen', src)
    TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.debit_card'))

    TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'lightgreen', "**" .. GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: " .. xPlayer.PlayerData.citizenid .. " | id: " .. xPlayer.PlayerData.source .. ")** successfully ordered a debit card")
end)

RegisterNetEvent('qb-banking:doQuickDeposit', function(amount)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    local currentCash = xPlayer.Functions.GetMoney('cash')
    amount = tonumber(amount)
    if not amount or amount <= 0 or amount % 1 ~= 0 then return end

    if amount <= currentCash then
        xPlayer.Functions.RemoveMoney('cash', tonumber(amount), 'banking-quick-depo')
        local bank = xPlayer.Functions.AddMoney('bank', tonumber(amount), 'banking-quick-depo')
        local newBankBalance = xPlayer.Functions.GetMoney('bank')
        addBankStatement(xPlayer.PlayerData.citizenid, 'Bank', amount, 0, newBankBalance, Lang:t('info.deposit', { amount = amount }))

        if bank then
            TriggerClientEvent('qb-banking:openBankScreen', src)
            TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.cash_deposit', { value = amount }))
            TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'lightgreen', "**" .. GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: " .. xPlayer.PlayerData.citizenid .. " | id: " .. xPlayer.PlayerData.source .. ")** made a cash deposit of $" .. amount .. " successfully.")
        end
    end
end)

RegisterNetEvent('qb-banking:toggleCard', function(toggle)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)

    if not xPlayer then return end

    toggleBankCardLock(xPlayer.PlayerData.citizenid, toggle and 1 or 0)
end)

RegisterNetEvent('qb-banking:doQuickWithdraw', function(amount, _)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    local currentCash = xPlayer.Functions.GetMoney('bank')
    amount = tonumber(amount)
    if not amount or amount <= 0 or amount % 1 ~= 0 then return end

    if amount <= currentCash then
        local cash = xPlayer.Functions.RemoveMoney('bank', amount, 'banking-quick-withdraw')
        xPlayer.Functions.AddMoney('cash', amount, 'banking-quick-withdraw')
        -- wypis dopiero po udanej wyplacie (bylo: przed sprawdzeniem salda)
        addBankStatement(xPlayer.PlayerData.citizenid, 'Bank', 0, amount, xPlayer.Functions.GetMoney('bank'), Lang:t('info.withdraw', { amount = amount }))
        if cash then
            TriggerClientEvent('qb-banking:openBankScreen', src)
            TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.cash_withdrawal', { value = amount }))
            TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'red', "**" .. GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: " .. xPlayer.PlayerData.citizenid .. " | id: " .. xPlayer.PlayerData.source .. ")** made a cash withdrawal of $" .. amount .. " successfully.")
        end
    end
end)

RegisterNetEvent('qb-banking:updatePin', function(currentBankCard, newPin)
    newPin = tostring(newPin or '')
    if newPin:match('^%d%d%d%d$') then
        local src = source
        local xPlayer = QBCore.Functions.GetPlayer(src)
        if not xPlayer then return end

        MySQL.update('UPDATE bank_cards SET cardPin = ? WHERE record_id = ? AND citizenid = ?', {
            newPin,
            type(currentBankCard) == 'table' and currentBankCard.record_id or 0,
            xPlayer.PlayerData.citizenid
        }, function(result)
            if result == 1 then
                TriggerClientEvent('qb-banking:openBankScreen', src)
                TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.updated_pin'))
            else
                TriggerClientEvent('QBCore:Notify', src, 'Error updating pin', "error")
            end
        end)
    end
end)

-- Kwota z klienta: tylko dodatnia liczba calkowita (ujemna dawala pieniadze z powietrza)
local function validAmount(amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 or amount % 1 ~= 0 then return nil end
    return amount
end

RegisterNetEvent('qb-banking:savingsDeposit', function(amount)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    local savings = savingsAccounts[xPlayer.PlayerData.citizenid]
    amount = validAmount(amount)
    if not savings or not amount then return end
    local currentBank = xPlayer.Functions.GetMoney('bank')

    if amount <= currentBank and xPlayer.Functions.RemoveMoney('bank', amount, 'savings-deposit') then
        savings.AddMoney(amount, Lang:t('info.current_to_savings'))
        TriggerClientEvent('qb-banking:openBankScreen', src)
        TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.savings_deposit', { value = tostring(amount) }))
        TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'lightgreen', "**" .. GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: " .. xPlayer.PlayerData.citizenid .. " | id: " .. xPlayer.PlayerData.source .. ")** made a savings deposit of $" .. tostring(amount) .. " successfully..")
    end
end)

RegisterNetEvent('qb-banking:savingsWithdraw', function(amount)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    local savings = savingsAccounts[xPlayer.PlayerData.citizenid]
    amount = validAmount(amount)
    if not savings or not amount then return end
    local currentSavings = savings.GetBalance()

    if amount <= currentSavings then
        savings.RemoveMoney(amount, Lang:t('info.savings_to_current'))
        xPlayer.Functions.AddMoney('bank', amount, 'savings-withdraw')
        TriggerClientEvent('qb-banking:openBankScreen', src)
        TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.savings_withdrawal', { value = tostring(amount) }))
        TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'red', "**" .. GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: " .. xPlayer.PlayerData.citizenid .. " | id: " .. xPlayer.PlayerData.source .. ")** made a savings withdrawal of $" .. tostring(amount) .. " successfully.")
    end
end)

RegisterNetEvent('qb-banking:createSavingsAccount', function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer or savingsAccounts[xPlayer.PlayerData.citizenid] then return end
    local success = createSavingsAccount(xPlayer.PlayerData.citizenid)
    repeat Wait(0) until success ~= nil
    TriggerClientEvent('qb-banking:openBankScreen', src)
    TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.opened_savings'))
    TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', "lightgreen", "**" .. GetPlayerName(xPlayer.PlayerData.source) .. " (citizenid: " .. xPlayer.PlayerData.citizenid .. " | id: " .. xPlayer.PlayerData.source .. ")** opened a savings account")
end)


QBCore.Commands.Add('givecash', Lang:t('command.givecash'), { { name = 'id', help = 'Player ID' }, { name = 'amount', help = 'Amount' } }, true, function(source, args)
    local src = source
    local id = tonumber(args[1])
    local amount = math.ceil(tonumber(args[2]))

    if id and amount then
        local xPlayer = QBCore.Functions.GetPlayer(src)
        local xReciv = QBCore.Functions.GetPlayer(id)

        if xReciv and xPlayer then
            if not xPlayer.PlayerData.metadata["isdead"] then
                local distance = xPlayer.PlayerData.metadata["inlaststand"] and 3.0 or 10.0
                if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(id))) < distance then
                    if amount > 0 then
                        if xPlayer.Functions.RemoveMoney('cash', amount) then
                            if xReciv.Functions.AddMoney('cash', amount) then
                                TriggerClientEvent('QBCore:Notify', src, Lang:t('success.give_cash', { id = tostring(id), cash = tostring(amount) }), "success")
                                TriggerClientEvent('QBCore:Notify', id, Lang:t('success.received_cash', { id = tostring(src), cash = tostring(amount) }), "success")
                            else
                                -- Return player cash
                                xPlayer.Functions.AddMoney('cash', amount)
                                TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_give'), "error")
                            end
                        else
                            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_enough'), "error")
                        end
                    else
                        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.invalid_amount'), "error")
                    end
                else
                    TriggerClientEvent('QBCore:Notify', src, Lang:t('error.too_far_away'), "error")
                end
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t('error.dead'), "error")
            end
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t('error.wrong_id'), "error")
        end
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.givecash'), "error")
    end
end)
