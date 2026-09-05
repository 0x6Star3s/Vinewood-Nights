local QBCore = exports['qb-core']:GetCoreObject()


-- Wygrana nalezy sie tylko temu, kto faktycznie zdrapal kupon
local scratched = {}

AddEventHandler('playerDropped', function()
    scratched[source] = nil
end)

QBCore.Functions.CreateUseableItem("lotto", function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.RemoveItem(item.name, 1, item.slot) then
        scratched[source] = true
        TriggerClientEvent("qb-lotto:usar", source)
    end
end)


RegisterServerEvent('qb-lotto:win')
AddEventHandler('qb-lotto:win', function()
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	if not Player or not scratched[src] then return end
	scratched[src] = nil

	local money = math.random(100, 200)
	Player.Functions.AddMoney('cash', money, 'lotto-win')
end)
