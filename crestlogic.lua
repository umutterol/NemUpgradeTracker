NemUpgradeTracker.UPGRADE_COSTS = {
    -- This table is now unused, logic is based on ilvl ranges below
}

-- Mapping from upgrade tier to crest type
local TIER_TO_CREST = {
    ["Adventurer"] = "weathered",
    ["Veteran"] = "carved",
    ["Champion"] = "runed",
    ["Hero"] = "gilded",
    ["Myth"] = "gilded",
}

-- Valorstone costs per upgrade by slot type
NemUpgradeTracker.VALORSTONE_COSTS = {
    ["one_hand"] = {75, 95, 115, 135, 155, 180, 210, 240},
    ["two_hand"] = {90, 110, 130, 155, 180, 210, 245, 285},
    ["chest"]    = {85, 105, 125, 145, 170, 200, 230, 260},
    ["legs"]     = {85, 105, 125, 145, 170, 200, 230, 260},
    ["gloves"]   = {65, 85, 105, 125, 150, 180, 200, 210},
    ["boots"]    = {65, 85, 105, 125, 150, 180, 200, 210},
    ["ring"]     = {60, 75, 95, 115, 135, 160, 180, 195},
    ["cloak"]    = {60, 75, 95, 115, 135, 160, 180, 195},
}

-- Helper: Get slot type for Valorstone calculation
local function GetSlotType(equipLoc)
    if equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND" or equipLoc == "INVTYPE_WEAPONOFFHAND" then
        return "one_hand"
    elseif equipLoc == "INVTYPE_2HWEAPON" then
        return "two_hand"
    elseif equipLoc == "INVTYPE_CHEST" then
        return "chest"
    elseif equipLoc == "INVTYPE_LEGS" then
        return "legs"
    elseif equipLoc == "INVTYPE_HAND" then
        return "gloves"
    elseif equipLoc == "INVTYPE_FEET" then
        return "boots"
    elseif equipLoc == "INVTYPE_FINGER" then
        return "ring"
    elseif equipLoc == "INVTYPE_BACK" then
        return "cloak"
    else
        return "one_hand" -- Default fallback
    end
end

-- Helper: Get Valorstone discount based on ilvl difference (warband-wide)
local function GetValorstoneDiscount(ilvlDiff)
    if ilvlDiff >= 3 then
        return 0.60
    elseif ilvlDiff == 2 then
        return 0.45
    elseif ilvlDiff == 1 then
        return 0.30
    else
        return 0.0
    end
end

-- Helper: Get crest type for a given ilvl (Season 2 logic)
local function GetCrestTypeForIlvl(ilvl)
    if ilvl <= 632 then return "weathered"
    elseif ilvl <= 645 then return "carved"
    elseif ilvl <= 658 then return "runed"
    elseif ilvl >= 659 then return "gilded"
    end
end

function NemUpgradeTracker:CalculateCrestNeeds(item)
    if not item or not item.upgradeLevel or not item.maxLevel or not item.itemLevel then
        print("[NemUpgradeTracker] Invalid item for crest calculation.")
        return
    end
    local bestIlvlData = NemUpgradeTracker.BestItemLevelBySlot and NemUpgradeTracker.BestItemLevelBySlot[item.equipLoc]
    local currentIlvl = item.itemLevel
    local crestTotals = {}
    local valorstoneTotal = 0
    local discounted = false
    local upgradesNeeded = item.maxLevel - item.upgradeLevel
    local stepIlvl = currentIlvl
    local slotType = GetSlotType(item.equipLoc)
    
    for i = 1, upgradesNeeded do
        local ilvlInc = (i == 5) and 4 or 3
        stepIlvl = stepIlvl + ilvlInc
        local crestType = GetCrestTypeForIlvl(stepIlvl)
        local isDiscounted = false
        if item.equipLoc == "INVTYPE_FINGER" or item.equipLoc == "INVTYPE_TRINKET" then
            if type(bestIlvlData) == "table" and #bestIlvlData >= 2 and bestIlvlData[1] and bestIlvlData[2] then
                isDiscounted = (stepIlvl <= bestIlvlData[2])
            end
        else
            if type(bestIlvlData) == "number" then
                isDiscounted = (stepIlvl <= bestIlvlData)
            end
        end
        local cost = (crestType and not isDiscounted) and 15 or 0
        if cost > 0 then
            crestTotals[crestType] = (crestTotals[crestType] or 0) + cost
        end
        
        -- Calculate Valorstone cost (warband-wide discount)
        local valorstoneCost = 0
        if not isDiscounted then
            local baseCost = NemUpgradeTracker.VALORSTONE_COSTS[slotType] and NemUpgradeTracker.VALORSTONE_COSTS[slotType][item.upgradeLevel + i] or 0
            if baseCost > 0 then
                -- Get the highest ilvl for discount calculation
                local bestIlvl = 0
                if type(bestIlvlData) == "table" then
                    bestIlvl = bestIlvlData[1] or 0
                else
                    bestIlvl = bestIlvlData or 0
                end
                local ilvlDiff = bestIlvl - stepIlvl
                local discount = GetValorstoneDiscount(ilvlDiff)
                valorstoneCost = math.floor(baseCost * (1 - discount))
            end
        end
        valorstoneTotal = valorstoneTotal + valorstoneCost
        
        if isDiscounted then discounted = true end
    end
    
    -- Add Valorstone to crest totals
    if valorstoneTotal > 0 then
        crestTotals.valorstone = valorstoneTotal
    end
    
    --print(string.format("[NemUpgradeTracker] Crest needs for %s:", item.itemName or "?"))
    for crest, total in pairs(crestTotals) do
        --print(string.format("  %s: %d", crest, total))
    end
    if discounted then
       -- print("  (Discounts applied for some upgrades based on best ilvl in slot)")
    end
    if not next(crestTotals) then
        --print("  No costs needed (all upgrades discounted or item maxed)")
    end
    return crestTotals
end 