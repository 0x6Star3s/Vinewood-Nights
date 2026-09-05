local QBCore = exports['qb-core']:GetCoreObject()

Loot = {
    {'recyclablematerial', math.random(1,3)}, -- spelled correctly
    {'weapon_bat', 1},
    {'phone', math.random(1,2)},
    -- {'xs-condom', 1},  -- invalid item
    {'weed_ak47', math.random(1,13)},
    {'kurkakola', math.random(1,3)},
	{'pokebox', 1},
    {'venusaur', 1},
    {'rainbowvmaxcharizard', 1},
    {'rainbowvmaxpikachu', 1},
    {'snorlaxvmaxrainbow', 1},
    {'pikachuv', 1},
    {'blastoisevmax', 1},
    {'mewtwogx', 1},
}

RegisterServerEvent('qb-trashsearch:server:startDumpsterTimer')
AddEventHandler('qb-trashsearch:server:startDumpsterTimer', function(dumpster)
    startTimer(source, dumpster)
end)

-- ponytail: jeden cooldown na gracza starczy - smietniki to nie kopalnia
local lastSearch = {}

local function CanSearch(src)
    local now = os.time()
    if lastSearch[src] and now - lastSearch[src] < 10 then return false end
    lastSearch[src] = now
    return true
end

AddEventHandler('playerDropped', function()
    lastSearch[source] = nil
end)

RegisterNetEvent('qb-trashsearch:server:recieveItem', function()
    local src = source
    local ply = QBCore.Functions.GetPlayer(src)
    if not ply or not CanSearch(src) then return end

    local chosenrandomItem = Loot[math.random(1, #Loot)]
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[chosenrandomItem[1]], "add")
    ply.Functions.AddItem(chosenrandomItem[1], chosenrandomItem[2])
end)

RegisterNetEvent('qb-trashsearch:server:givemoney', function()
    local src = source
    local ply = QBCore.Functions.GetPlayer(src)
    if not ply or not CanSearch(src) then return end

    ply.Functions.AddMoney("cash", QBCore.Functions.ScalePayout(math.random(21, 39)), 'dumpster-search') -- kwota z serwera + mnoznik (/boost)
end)

function startTimer(id, object)
    local timer = 10 * 1000

    while timer > 0 do
        Wait(10)
        timer = timer - 10
        if timer == 0 then
            TriggerClientEvent('qb-trashsearch:server:removeDumpster', id, object)
        end
    end
end


