Config = Config or {}

--- This function gets triggered whenever one or more PowerStations have been hit
--- @param hits array
--- @return nil
function Config.OnPoliceCameraHit(hits)
    TriggerClientEvent("police:client:SetCamera", -1, hits, false)
end

--- This is called whenever a bank robbery is started, after a hack is done or a card is used, in this function you can do extra stuff after it has started
--- @param bankId number | string
--- @return nil
function Config.OnRobberyStart(bankId)
    local bankName = type(bankId) == "number" and "bankrobbery" or bankId
    TriggerEvent('qb-scoreboard:server:SetActivityBusy', bankName, true)
    if bankName ~= "bankrobbery" then return end
    TriggerEvent('qb-banking:server:SetBankClosed', bankId, true)
end

--- This is called whenever a bank robbery's timeout has ended
--- @param bankId string | number
--- @return nil
function Config.OnRobberyTimeoutEnd(bankId)
    local bankName = type(bankId) == "number" and "bankrobbery" or bankId
    TriggerEvent('qb-scoreboard:server:SetActivityBusy', bankName, false)
    if bankName ~= "bankrobbery" then return end
    TriggerEvent('qb-banking:server:SetBankClosed', bankId, false)
end

--- This will be called once a blackout starts or ends
--- @param isBlackout boolean
--- @return nil
function Config.OnBlackout(isBlackout)
    if isBlackout then
        TriggerClientEvent("police:client:DisableAllCameras", -1)
    else
        TriggerClientEvent("police:client:EnableAllCameras", -1)
    end
end

Config.HitsNeeded = 13 -- The amount of powerstation needed to be hit to cause a blackout
Config.BlackoutTimer = 10 -- The amount of minutes a blackout will take until all power comes back

Config.RewardTypes = {
    [1] = {
        type = "item"
    },
    [2] = {
        type = "money"
    }
}

Config.LockerRewards = {
    ["tier1"] = {
        [1] = {item = "goldchain", minAmount = 5, maxAmount = 15},
    },
    ["tier2"] = {
        [1] = {item = "rolex", minAmount = 5, maxAmount = 15},
    },
    ["tier3"] = {
        [1] = {item = "goldbar", minAmount = 1, maxAmount = 2},
    },
}

Config.LockerRewardsPaleto = {
    ["tier1"] = {
        [1] = {item = "goldchain", minAmount = 10, maxAmount = 20},
    },
    ["tier2"] = {
        [1] = {item = "rolex", minAmount = 10, maxAmount = 20},
    },
    ["tier3"] = {
        [1] = {item = "goldbar", minAmount = 2, maxAmount = 4},
    },
}

Config.LockerRewardsPacific = {
    ["tier1"] = {
        [1] = {item = "goldbar", minAmount = 4, maxAmount = 8},
    },
    ["tier2"] = {
        [1] = {item = "goldbar", minAmount = 4, maxAmount = 8},
    },
    ["tier3"] = {
        [1] = {item = "goldbar", minAmount = 4, maxAmount = 8},
    },
}

Config.CameraHits = {
    [1] = {
        type = {"police", "bank"},
        stationsToHitPolice = {1, 2, 3, 4, 5, 6},
        stationsToHitBank = {1, 2, 11}
    },
    [2] = {
        type = {"police", "bank"},
        stationsToHitPolice = {1, 2, 3, 4, 5, 6},
        stationsToHitBank = {1, 2, 11}
    },
    [3] = {
        type = {"police", "bank"},
        stationsToHitPolice = {1, 2, 3, 4, 5, 6},
        stationsToHitBank = {4, 5, 6, 8}
    },
    [4] = {
        type = {"police", "bank"},
        stationsToHitPolice = {4, 5, 6},
        stationsToHitBank = {12, 13}
    },
    [5] = {
        type = {"police", "bank"},
        stationsToHitPolice = {4, 5, 6},
        stationsToHitBank = {12, 13}
    },
    [6] = {
        type = "police",
        stationsToHitPolice = {4, 5, 6}
    },
    [7] = {
        type = "police",
        stationsToHitPolice = 3
    },
    [8] = {
        type = "police",
        stationsToHitPolice = {4, 5, 6}
    },
    [9] = {
        type = "police",
        stationsToHitPolice = {7, 8}
    },
    [10] = {
        type = "police",
        stationsToHitPolice = {7, 8}
    },
    [11] = {
        type = "police",
        stationsToHitPolice = 9
    },
    [12] = {
        type = "police",
        stationsToHitPolice = 9
    },
    [13] = {
        type = "police",
        stationsToHitPolice = 9
    },
    [14] = {
        type = "police",
        stationsToHitPolice = {9, 10}
    },
    [15] = {
        type = "police",
        stationsToHitPolice = {7, 9, 10}
    },
    [16] = {
        type = "police",
        stationsToHitPolice = {7, 9, 10}
    },
    [17] = {
        type = "police",
        stationsToHitPolice = {9, 10}
    },
    [18] = {
        type = "police",
        stationsToHitPolice = 3
    },
    [19] = {
        type = "police",
        stationsToHitPolice = {{1, 2, 3}, {9, 10}}
    },
    [20] = {
        type = "police",
        stationsToHitPolice = 10
    },
    [21] = {
        type = "police",
        stationsToHitPolice = {1, 2, 11}
    },
    [22] = {
        type = "police",
        stationsToHitPolice = {1, 2, 11}
    },
    [23] = {
        type = "police",
        stationsToHitPolice = {4, 5, 6, 8}
    },
    [24] = {
        type = "police",
        stationsToHitPolice = {12, 13}
    },
    [25] = {
        type = "police",
        stationsToHitPolice = {12, 13}
    }
}

-- ==========================================================================================
-- EKONOMIA NAPADOW - wartosci czytane z jednego miejsca: qb-core/config.lua -> QBConfig.Economy.Heists
-- (przelacznik dev/premiera = QBConfig.Economy.DevHeists). Tu nic nie edytujesz.
-- ==========================================================================================
local QBCoreEconomy = exports['qb-core']:GetCoreObject().Config.Economy

Config.HeistLockerCount = { fleeca = 8, paleto = 8, pacific = 10 }

---@param bankId string 'paleto' | 'pacific' | numer malego banku (fleeca)
---@return table settings, string key
function Config.GetHeistSettings(bankId)
    local key = (bankId == 'paleto' or bankId == 'pacific') and bankId or 'fleeca'
    return QBCoreEconomy.Heists[key], key
end

---Wartosc jednej paczki markedbills, tak zeby caly bank dal +/- payout z configu.
---Polowa schowkow losuje kase (Config.RewardTypes), srednio 2.5 paczki na schowek.
---@param bankId string
---@return number
function Config.GetBillWorth(bankId)
    local settings, key = Config.GetHeistSettings(bankId)
    local expectedBills = Config.HeistLockerCount[key] * 0.5 * 2.5
    local worth = math.floor(settings.payout / expectedBills)
    return math.floor(worth * math.random(90, 110) / 100) -- +/-10% losowosci
end

---Cooldown banku w milisekundach
function Config.GetHeistCooldown(bankId)
    local settings = Config.GetHeistSettings(bankId)
    return settings.cooldown * 60000
end

---Minimalna liczba policjantow na sluzbie (sprawdzane po stronie serwera)
function Config.GetMinimumPolice(bankId)
    local settings = Config.GetHeistSettings(bankId)
    return settings.police or 0
end
