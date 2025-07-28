-- Allowed equip locations for upgradeable items
local ALLOWED_INV_TYPES = {
    INVTYPE_HEAD = true,
    INVTYPE_SHOULDER = true,
    INVTYPE_BACK = true,
    INVTYPE_NECK = true,
    INVTYPE_CHEST = true,
    INVTYPE_WRIST = true,
    INVTYPE_HAND = true,
    INVTYPE_WAIST = true,
    INVTYPE_LEGS = true,
    INVTYPE_FEET = true,
    INVTYPE_FINGER = true,
    INVTYPE_TRINKET = true,
    INVTYPE_WEAPON = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_SHIELD = true,
    INVTYPE_HOLDABLE = true,
    INVTYPE_RANGED = true,
    INVTYPE_THROWN = true,
    INVTYPE_RANGEDRIGHT = true,
    INVTYPE_BOW = true,
    INVTYPE_CROSSBOW = true,
    INVTYPE_GUN = true,
    INVTYPE_WAND = true,
    INVTYPE_DAGGER = true,
    INVTYPE_FIST = true,
    INVTYPE_CLOAK = true,
}

-- Utility: Scan equipped and bag items for upgradeable gear
function NemUpgradeTracker:ScanItems()
    local items = {}
    local bestIlvlBySlot = {}
    -- Helper for updating best ilvls for rings/trinkets
    local function updateBest(slot, ilvl)
        if slot == "INVTYPE_FINGER" or slot == "INVTYPE_TRINKET" then
            bestIlvlBySlot[slot] = bestIlvlBySlot[slot] or {}
            table.insert(bestIlvlBySlot[slot], ilvl)
            -- Remove duplicates
            local seen = {}
            local unique = {}
            for _, v in ipairs(bestIlvlBySlot[slot]) do
                if not seen[v] then
                    table.insert(unique, v)
                    seen[v] = true
                end
            end
            table.sort(unique, function(a, b) return a > b end)
            -- Keep only top 2
            bestIlvlBySlot[slot] = { unique[1], unique[2] }
        else
            if not bestIlvlBySlot[slot] or (ilvl and ilvl > bestIlvlBySlot[slot]) then
                bestIlvlBySlot[slot] = ilvl
            end
        end
    end
    -- Scan equipped slots
    for slot = 1, 19 do -- 1-19 are equipped slots
        local itemLink = GetInventoryItemLink("player", slot)
        if itemLink then
            local itemName, _, itemRarity, itemLevel, _, _, _, _, equipLoc = GetItemInfo(itemLink)
            if equipLoc and itemLevel and ALLOWED_INV_TYPES[equipLoc] then
                updateBest(equipLoc, itemLevel)
            end
            local itemData = self:ParseUpgradeableItem(itemLink, slot, true)
            if itemData then
                table.insert(items, itemData)
                if itemData.equipLoc == "INVTYPE_TRINKET" then
                end
            end
        end
    end
    -- Scan bag slots (using new C_Container API)
    for bag = 0, NUM_BAG_FRAMES do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = C_Container.GetContainerItemLink(bag, slot)
            if itemLink then
                local itemName, _, itemRarity, itemLevel, _, _, _, _, equipLoc = GetItemInfo(itemLink)
                if equipLoc and itemLevel and ALLOWED_INV_TYPES[equipLoc] then
                    updateBest(equipLoc, itemLevel)
                end
                local itemData = self:ParseUpgradeableItem(itemLink, slot, false)
                if itemData then
                    table.insert(items, itemData)
                    if itemData.equipLoc == "INVTYPE_TRINKET" then
                    end
                end
            end
        end
    end
    NemUpgradeTracker.upgradeableItems = items -- Store for later use
    NemUpgradeTracker.BestItemLevelBySlot = bestIlvlBySlot -- Store for discount logic
end

-- Parse item for upgrade info and filter by allowed equip location
function NemUpgradeTracker:ParseUpgradeableItem(itemLink, slot, isEquipped)
    local itemName, _, itemRarity, itemLevel, _, _, _, _, equipLoc = GetItemInfo(itemLink)
    if not equipLoc or not ALLOWED_INV_TYPES[equipLoc] then
        return nil -- Not an allowed item type
    end
    -- Tooltip scanning for upgrade info
    local tooltip = NemUpgradeTrackerTooltip or CreateFrame("GameTooltip", "NemUpgradeTrackerTooltip", nil, "GameTooltipTemplate")
    NemUpgradeTrackerTooltip = tooltip -- cache for reuse
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetHyperlink(itemLink)
    local upgradeLevel, maxLevel, upgradeTier
    for i = 2, tooltip:NumLines() do -- skip line 1 (item name)
        local text = _G["NemUpgradeTrackerTooltipTextLeft"..i]:GetText()
        if text then
            -- Match e.g. 'Upgrade Level: Hero 4/8' or 'Upgrade Level: 4/8'
            local tier, level, max = string.match(text, "Upgrade Level:%s*([%a%s]*)%s*(%d+)%/(%d+)")
            if level and max then
                upgradeLevel = tonumber(level)
                maxLevel = tonumber(max)
                upgradeTier = tier and tier:match("%S") and tier:match("%S.*%S") or nil -- trim spaces
                break
            end
        end
    end
    tooltip:Hide()
    if upgradeLevel and maxLevel and upgradeLevel < maxLevel then
        return {
            itemLink = itemLink,
            slot = slot,
            isEquipped = isEquipped,
            upgradeLevel = upgradeLevel,
            maxLevel = maxLevel,
            upgradeTier = upgradeTier,
            itemName = itemName,
            equipLoc = equipLoc,
            itemLevel = itemLevel,
        }
    end
    return nil
end 