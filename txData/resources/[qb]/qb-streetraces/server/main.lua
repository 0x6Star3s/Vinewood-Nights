local QBCore = exports['qb-core']:GetCoreObject()

local Races = {}

RegisterNetEvent('qb-streetraces:NewRace', function(RaceTable)
    local src = source
    local RaceId = math.random(1000, 9999)
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer or type(RaceTable) ~= 'table' or type(RaceTable.joined) ~= 'table' then return end

    local amount = tonumber(RaceTable.amount)
    if not amount or amount <= 0 or amount % 1 ~= 0 then return end
    RaceTable.amount = amount
    RaceTable.pot = amount -- pula liczona przez serwer, nie przysylana przez klienta

    if xPlayer.Functions.RemoveMoney('cash', RaceTable.amount, "streetrace-created") then
        Races[RaceId] = RaceTable
        Races[RaceId].creator = QBCore.Functions.GetIdentifier(src, 'license')
        Races[RaceId].joined[#Races[RaceId].joined+1] = QBCore.Functions.GetIdentifier(src, 'license')
        TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
        TriggerClientEvent('qb-streetraces:SetRaceId', src, RaceId)
        TriggerClientEvent('QBCore:Notify', src, "You joind the race for €"..Races[RaceId].amount..",-", 'success')
    end
end)

RegisterNetEvent('qb-streetraces:RaceWon', function(RaceId)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local race = Races[RaceId]
    if not xPlayer or not race or not race.pot or race.pot <= 0 then return end

    -- wygrac moze tylko uczestnik i tylko raz (pula zerowana od razu)
    local license = QBCore.Functions.GetIdentifier(src, 'license')
    local joined = false
    for _, id in pairs(race.joined or {}) do
        if id == license then joined = true break end
    end
    if not joined then return end

    local pot = race.pot
    race.pot = 0
    xPlayer.Functions.AddMoney('cash', pot, "race-won")
    TriggerClientEvent('QBCore:Notify', src, "You won the race and €"..pot..",- recieved", 'success')
    TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
    TriggerClientEvent('qb-streetraces:RaceDone', -1, RaceId, GetPlayerName(src))
end)

RegisterNetEvent('qb-streetraces:JoinRace', function(RaceId)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer or not Races[RaceId] or not Races[RaceId].amount then return end
    local zPlayer = QBCore.Functions.GetPlayer(Races[RaceId].creator)
    if zPlayer ~= nil then
        if xPlayer.PlayerData.money.cash >= Races[RaceId].amount then
            Races[RaceId].pot = Races[RaceId].pot + Races[RaceId].amount
            Races[RaceId].joined[#Races[RaceId].joined+1] = QBCore.Functions.GetIdentifier(src, 'license')
            if xPlayer.Functions.RemoveMoney('cash', Races[RaceId].amount, "streetrace-joined") then
                TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
                TriggerClientEvent('qb-streetraces:SetRaceId', src, RaceId)
                TriggerClientEvent('QBCore:Notify', zPlayer.PlayerData.source, GetPlayerName(src).." Joined the race", 'primary')
            end
        else
            TriggerClientEvent('QBCore:Notify', src, "You dont have enough cash", 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, "The person wo made the race is offline!", 'error')
        Races[RaceId] = {}
    end
end)

QBCore.Commands.Add("createrace", "Start A Street Race", {{name="amount", help="The Stake Amount For The Race."}}, false, function(source, args)
    local src = source
    local amount = tonumber(args[1])
    if GetJoinedRace(QBCore.Functions.GetIdentifier(src, 'license')) == 0 then
        TriggerClientEvent('qb-streetraces:CreateRace', src, amount)
    else
        TriggerClientEvent('QBCore:Notify', src, "You Are Already In A Race", 'error')
    end
end)

QBCore.Commands.Add("stoprace", "Stop The Race You Created", {}, false, function(source, _)
    CancelRace(source)
end)

QBCore.Commands.Add("quitrace", "Get Out Of A Race. (You Will NOT Get Your Money Back!)", {}, false, function(source, _)
    local src = source
    local RaceId = GetJoinedRace(QBCore.Functions.GetIdentifier(src, 'license'))
    if RaceId ~= 0 then
        if GetCreatedRace(QBCore.Functions.GetIdentifier(src, 'license')) ~= RaceId then
            RemoveFromRace(QBCore.Functions.GetIdentifier(src, 'license'))
            TriggerClientEvent('QBCore:Notify', src, "You Have Stepped Out Of The Race! And You Lost Your Money", 'error')
        else
            TriggerClientEvent('QBCore:Notify', src, "/stoprace To Stop The Race", 'error')
        end
    else
        TriggerClientEvent('QBCore:Notify', src, "You Are Not In A Race ", 'error')
    end
end)

QBCore.Commands.Add("startrace", "Start The Race", {}, false, function(source)
    local src = source
    local RaceId = GetCreatedRace(QBCore.Functions.GetIdentifier(src, 'license'))

    if RaceId ~= 0 then

        Races[RaceId].started = true
        TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
        TriggerClientEvent("qb-streetraces:StartRace", -1, RaceId)
    else
        TriggerClientEvent('QBCore:Notify', src, "You Have Not Started A Race", 'error')

    end
end)

function CancelRace(source)
    local RaceId = GetCreatedRace(QBCore.Functions.GetIdentifier(source, 'license'))
    local Player = QBCore.Functions.GetPlayer(source)

    if RaceId ~= 0 then
        for key in pairs(Races) do
            if Races[key] ~= nil and Races[key].creator == Player.PlayerData.license then
                if not Races[key].started then
                    for _, iden in pairs(Races[key].joined) do
                        local xdPlayer = QBCore.Functions.GetPlayer(iden)
                            xdPlayer.Functions.AddMoney('cash', Races[key].amount, "race-cancelled")
                            TriggerClientEvent('QBCore:Notify', xdPlayer.PlayerData.source, "Race Has Stopped, You Got Back $"..Races[key].amount.."", 'error')
                            TriggerClientEvent('qb-streetraces:StopRace', xdPlayer.PlayerData.source)
                            RemoveFromRace(iden)
                    end
                else
                    TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, "The Race Has Already Started", 'error')
                end
                TriggerClientEvent('QBCore:Notify', source, "Race Stopped!", 'error')
                Races[key] = nil
            end
        end
        TriggerClientEvent('qb-streetraces:SetRace', -1, Races)
    else
        TriggerClientEvent('QBCore:Notify', source, "You Have Not Started A Race!", 'error')
    end
end

function RemoveFromRace(identifier)
    for key in pairs(Races) do
        if Races[key] ~= nil and not Races[key].started then
            for i, iden in pairs(Races[key].joined) do
                if iden == identifier then
                    table.remove(Races[key].joined, i)
                end
            end
        end
    end
end

function GetJoinedRace(identifier)
    for key in pairs(Races) do
        if Races[key] ~= nil and not Races[key].started then
            for _, iden in pairs(Races[key].joined) do
                if iden == identifier then
                    return key
                end
            end
        end
    end
    return 0
end

function GetCreatedRace(identifier)
    for key in pairs(Races) do
        if Races[key] ~= nil and Races[key].creator == identifier and not Races[key].started then
            return key
        end
    end
    return 0
end
