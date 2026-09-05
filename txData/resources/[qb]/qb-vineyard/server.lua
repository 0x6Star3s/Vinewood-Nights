local QBCore = exports['qb-core']:GetCoreObject()

-- Zbieranie ma cooldown, a wino/sok dostaje tylko ten, kto wczesniej oddal skladniki
local lastPick = {}
local pendingWine = {}
local pendingJuice = {}

AddEventHandler('playerDropped', function()
    lastPick[source] = nil
    pendingWine[source] = nil
    pendingJuice[source] = nil
end)

RegisterNetEvent('qb-vineyard:server:getGrapes', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local now = os.time()
    if lastPick[source] and now - lastPick[source] < 5 then return end
    lastPick[source] = now

    local amount = math.random(Config.GrapeAmount.min, Config.GrapeAmount.max)
    Player.Functions.AddItem("grape", amount)
    TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items['grape'], "add")
end)

QBCore.Functions.CreateCallback('qb-vineyard:server:loadIngredients', function(source, cb)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
    local grape = Player.Functions.GetItemByName('grapejuice')
	if Player.PlayerData.items ~= nil then
        if grape ~= nil then
            if grape.amount >= 23 then
                Player.Functions.RemoveItem("grapejuice", 23, false)
                TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items['grapejuice'], "remove")
                pendingWine[src] = true
                cb(true)
            else
                TriggerClientEvent('QBCore:Notify', source, Lang:t("error.invalid_items"), 'error')
                cb(false)
            end
        else
            TriggerClientEvent('QBCore:Notify', source, Lang:t("error.invalid_items"), 'error')
            cb(false)
        end
	else
		TriggerClientEvent('QBCore:Notify', source, Lang:t("error.no_items"), "error")
        cb(false)
	end
end)

QBCore.Functions.CreateCallback('qb-vineyard:server:grapeJuice', function(source, cb)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
    local grape = Player.Functions.GetItemByName('grape')
	if Player.PlayerData.items ~= nil then
        if grape ~= nil then
            if grape.amount >= 16 then
                Player.Functions.RemoveItem("grape", 16, false)
                TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items['grape'], "remove")
                pendingJuice[src] = true
                cb(true)
            else
                TriggerClientEvent('QBCore:Notify', source, Lang:t("error.invalid_items"), 'error')
                cb(false)
            end
        else
            TriggerClientEvent('QBCore:Notify', source, Lang:t("error.invalid_items"), 'error')
            cb(false)
        end
	else
		TriggerClientEvent('QBCore:Notify', source, Lang:t("error.no_items"), "error")
        cb(false)
	end
end)

RegisterNetEvent('qb-vineyard:server:receiveWine', function()
	local Player = QBCore.Functions.GetPlayer(tonumber(source))
    if not Player or not pendingWine[source] then return end
    pendingWine[source] = nil

    local amount = math.random(Config.WineAmount.min, Config.WineAmount.max)
	Player.Functions.AddItem("wine", amount, false)
	TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items['wine'], "add")
end)

RegisterNetEvent('qb-vineyard:server:receiveGrapeJuice', function()
	local Player = QBCore.Functions.GetPlayer(tonumber(source))
    if not Player or not pendingJuice[source] then return end
    pendingJuice[source] = nil

    local amount = math.random(Config.GrapeJuiceAmount.min, Config.GrapeJuiceAmount.max)
	Player.Functions.AddItem("grapejuice", amount, false)
	TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items['grapejuice'], "add")
end)
