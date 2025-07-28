-- UI Frame and Components
local frame = nil
local totalCostFrame = nil
local itemListFrame = nil
local craftedInputFrame = nil

-- Data storage (will be initialized in LoadSavedData)
NemUpgradeTracker.selectedItems = {}
NemUpgradeTracker.craftedItems = {}

-- Currency tracking for notifications
NemUpgradeTracker.lastCurrencyCounts = {}

-- Key level crest rewards table
NemUpgradeTracker.KEY_LEVEL_CRESTS = {
    [2] = { type = "runed", amount = 10 },
    [3] = { type = "runed", amount = 12 },
    [4] = { type = "runed", amount = 14 },
    [5] = { type = "runed", amount = 16 },
    [6] = { type = "runed", amount = 18 },
    [7] = { type = "gilded", amount = 10 },
    [8] = { type = "gilded", amount = 12 },
    [9] = { type = "gilded", amount = 14 },
    [10] = { type = "gilded", amount = 16 },
    [11] = { type = "gilded", amount = 18 },
    [12] = { type = "gilded", amount = 20 },
}

-- Default values for higher keys (extrapolation)
for i = 13, 30 do
    NemUpgradeTracker.KEY_LEVEL_CRESTS[i] = { type = "gilded", amount = 20 }
end

function NemUpgradeTracker:LoadSavedData()
    -- Load selected items
    NemUpgradeTracker.selectedItems = NemUpgradeTrackerDB.selectedItems or {}
    
    -- Load crafted items
    NemUpgradeTracker.craftedItems = NemUpgradeTrackerDB.craftedItems or {
        carved = 0,
        weathered = 0,
        runed = 0,
        gilded = 0
    }
    
    if NemUpgradeTrackerDB then
        local selectedCount = 0
        for _ in pairs(NemUpgradeTracker.selectedItems) do
            selectedCount = selectedCount + 1
        end
        local craftedCount = 0
        for crestType, count in pairs(NemUpgradeTracker.craftedItems) do
            if count > 0 then
                craftedCount = craftedCount + 1
            end
        end
    end
end

-- Crest types in order of progression
CREST_ORDER = { "carved", "weathered", "runed", "gilded", "valorstone" }

-- Crest currency IDs (for Valorstone and tooltips)
CREST_ICONS = {
    carved = 3108,    -- Carved Undermine Crest (lowest tier)
    weathered = 3107, -- Weathered Undermine Crest
    runed = 3109,     -- Runed Undermine Crest
    gilded = 3110,    -- Gilded Undermine Crest (highest tier)
    valorstone = 3008 -- Valorstone
}

-- Crest item IDs (for inventory counting)
CREST_ITEM_IDS = {
    carved = 3108,    -- Carved Undermine Crest item ID
    weathered = 3107, -- Weathered Undermine Crest item ID
    runed = 3109,     -- Runed Undermine Crest item ID
    gilded = 3110,    -- Gilded Undermine Crest item ID
    valorstone = 3008 -- Valorstone (uses currency ID)
}

function NemUpgradeTracker:GetCrestIcon(crestType)
    local currencyID = CREST_ICONS[crestType]
    if currencyID then
        local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if currencyInfo and currencyInfo.iconFileID then
            return currencyInfo.iconFileID
        end
    end
    return "Interface\\Icons\\inv_misc_questionmark"
end

function NemUpgradeTracker:GetItemIcon(itemLink)
    if itemLink then
        local itemID = string.match(itemLink, "item:(%d+)")
        if itemID then
            return GetItemIcon(tonumber(itemID)) or "Interface\\Icons\\inv_misc_questionmark"
        end
    end
    return "Interface\\Icons\\inv_misc_questionmark"
end

function NemUpgradeTracker:ShowSelectionUI()
    -- Load saved data before creating UI
    self:LoadSavedData()
    
    if frame then
        frame:Show()
        self:RefreshUI()
        return
    end
    
    -- Create main frame
    frame = CreateFrame("Frame", "NemUpgradeTrackerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(1000, 720)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -10)
    title:SetText("NemUpgradeTracker")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    
    self:CreateTotalCostSection()
    self:CreateItemListSection()
    self:CreateCraftedInputSection()
    
    frame:Show()
    self:RefreshUI()
    
    -- Debug: Check if data is preserved after UI creation
    local selectedCount = 0
    for _ in pairs(NemUpgradeTracker.selectedItems) do
        selectedCount = selectedCount + 1
    end
end

function NemUpgradeTracker:CreateTotalCostSection()
    totalCostFrame = CreateFrame("Frame", nil, frame)
    totalCostFrame:SetSize(550, 60)
    totalCostFrame:SetPoint("TOP", frame, "TOP", 0, -40)
    
    local title = totalCostFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER", totalCostFrame, "CENTER", -10, 25)
    title:SetText("Total Requirements")
    
    -- Create crest icons with numbers (ordered by tier, horizontally centered)
    local totalWidth = #CREST_ORDER * 80 -- 80 pixels per crest (icon + cost)
    local startX = (550 - totalWidth) / 2 -- Center the row
    
    for i, crestType in ipairs(CREST_ORDER) do
        local iconFrame = CreateFrame("Frame", nil, totalCostFrame)
        iconFrame:SetSize(30, 30)
        iconFrame:SetPoint("TOPLEFT", totalCostFrame, "TOPLEFT", startX + (i-1) * 80, -20)
        
        local icon = iconFrame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        icon:SetTexture(NemUpgradeTracker:GetCrestIcon(crestType))
        
        -- Make icon hoverable with tooltip
        iconFrame:EnableMouse(true)
        iconFrame:SetScript("OnEnter", function(self)
            local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(CREST_ICONS[crestType])
            if currencyInfo then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(currencyInfo.name or crestType:gsub("^%l", string.upper))
                GameTooltip:Show()
            end
        end)
        iconFrame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        local count = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        count:SetPoint("LEFT", iconFrame, "RIGHT", 5, 0)
        count:SetText("0")
        count:SetTextColor(1, 1, 1)
        count:SetFont("Fonts\\FRIZQT__.TTF", 16) -- Same size as icon
        
        iconFrame.crestType = crestType
        iconFrame.countText = count
    end
end

function NemUpgradeTracker:CreateItemListSection()
    itemListFrame = CreateFrame("Frame", nil, frame)
    itemListFrame:SetSize(480, 550) -- Increased height to go down further
    itemListFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -120)
    
    local title = itemListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", itemListFrame, "TOPLEFT", 0, 0)
    title:SetText("Upgradeable Items:")
    
    -- Scroll frame for items
    local scrollFrame = CreateFrame("ScrollFrame", nil, itemListFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(450, 550) -- Increased height to match container
    scrollFrame:SetPoint("TOPLEFT", itemListFrame, "TOPLEFT", 0, -20)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(440, 1000) -- Will be adjusted dynamically
    scrollFrame:SetScrollChild(content)
    
    itemListFrame.scrollFrame = scrollFrame
    itemListFrame.content = content
end

function NemUpgradeTracker:CreateCraftedInputSection()
    craftedInputFrame = CreateFrame("Frame", nil, frame)
    craftedInputFrame:SetSize(480, 350) -- Increased height for estimation section
    craftedInputFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -120)
    
    local title = craftedInputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", craftedInputFrame, "TOPLEFT", 0, 0)
    title:SetText("Crafted Items:")
    
    local yOffset = -30
    for i, crestType in ipairs({"carved", "weathered", "runed", "gilded"}) do
        local row = CreateFrame("Frame", nil, craftedInputFrame)
        row:SetSize(480, 30)
        row:SetPoint("TOPLEFT", craftedInputFrame, "TOPLEFT", 0, yOffset)
        
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(25, 25)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        icon:SetTexture(NemUpgradeTracker:GetCrestIcon(crestType))
        
        -- Make icon hoverable with tooltip
        icon:GetParent():EnableMouse(true)
        icon:GetParent():SetScript("OnEnter", function(self)
            local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(CREST_ICONS[crestType])
            if currencyInfo then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(currencyInfo.name or crestType:gsub("^%l", string.upper))
                GameTooltip:Show()
            end
        end)
        icon:GetParent():SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", icon, "RIGHT", 10, 0)
        label:SetText(crestType:gsub("^%l", string.upper))
        
        local input = CreateFrame("EditBox", "NemUpgradeTrackerCraftedInput" .. crestType, row, "InputBoxTemplate")
        input:SetSize(80, 20)
        input:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        input:SetAutoFocus(false)
        input:SetText(tostring(NemUpgradeTracker.craftedItems[crestType] or 0))
        input:SetScript("OnTextChanged", function(self)
            NemUpgradeTracker:OnCraftedInputChange(crestType, self:GetText())
        end)
        input:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
        input:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        
        row.input = input
        
        yOffset = yOffset - 40
    end
    
    -- Add dungeon estimation section
    local estimationTitle = craftedInputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    estimationTitle:SetPoint("TOP", craftedInputFrame, "TOP", 0, yOffset + 0)
    estimationTitle:SetText("Dungeon Estimations")
    estimationTitle:SetTextColor(1, 1, 0)
    
    yOffset = yOffset - 50
    
    -- Key level section (slider)
    local keyLevelLabel = craftedInputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keyLevelLabel:SetPoint("TOPLEFT", craftedInputFrame, "TOPLEFT", 0, yOffset)
    keyLevelLabel:SetText("Key level for estimation:")
    
    local keyLevelSlider = CreateFrame("Slider", "NemUpgradeTrackerKeyLevelSlider", craftedInputFrame, "OptionsSliderTemplate")
    keyLevelSlider:SetOrientation("HORIZONTAL")
    keyLevelSlider:SetMinMaxValues(2, 12)
    keyLevelSlider:SetValueStep(1)
    keyLevelSlider:SetObeyStepOnDrag(true)
    keyLevelSlider:SetWidth(220)
    keyLevelSlider:SetHeight(20)
    keyLevelSlider:SetPoint("LEFT", keyLevelLabel, "RIGHT", 10, 0)
    keyLevelSlider:SetValue(NemUpgradeTrackerDB.keyLevel or 20)
    
    -- Left label (2)
    local leftLabel = craftedInputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leftLabel:SetPoint("BOTTOMLEFT", keyLevelSlider, "TOPLEFT", 0, 2)
    leftLabel:SetText("2")
    
    -- Right label (12)
    local rightLabel = craftedInputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rightLabel:SetPoint("BOTTOMRIGHT", keyLevelSlider, "TOPRIGHT", 0, 2)
    rightLabel:SetText("12")
    
    -- Current value label
    local valueLabel = craftedInputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueLabel:SetPoint("BOTTOM", keyLevelSlider, "TOP", 0, 2)
    valueLabel:SetText("+" .. (NemUpgradeTrackerDB.keyLevel or 20))
    
    keyLevelSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        NemUpgradeTrackerDB.keyLevel = value
        valueLabel:SetText("+" .. value)
        NemUpgradeTracker:UpdateDungeonEstimations()
    end)
    
    yOffset = yOffset - 40
    
    -- Estimation results
    if craftedInputFrame.estimationResults then
        craftedInputFrame.estimationResults:Hide()
        craftedInputFrame.estimationResults = nil
    end
    local estimationResults = craftedInputFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    estimationResults:SetPoint("TOP", craftedInputFrame, "TOP", 0, yOffset)
    estimationResults:SetWidth(craftedInputFrame:GetWidth() - 40)
    estimationResults:SetJustifyH("CENTER")
    estimationResults:SetTextColor(1, 1, 0)
    craftedInputFrame.estimationResults = estimationResults
    
    craftedInputFrame.estimationResults:SetText("Use the slider above to set your key level.")
    craftedInputFrame.estimationResults:SetTextColor(0.8, 0.8, 0.8)
    
    -- Store slider for later access
    craftedInputFrame.keyLevelSlider = keyLevelSlider
    craftedInputFrame.keyLevelValueLabel = valueLabel
    
    -- Update estimations
    NemUpgradeTracker:UpdateDungeonEstimations()
end

function NemUpgradeTracker:RefreshUI()
    if not frame then return end
    
    self:UpdateTotalCost()
    self:UpdateItemList()
    self:CheckCurrencyGains() -- Check for currency gains on refresh
end

function NemUpgradeTracker:UpdateTotalCost()
    -- Calculate total crests needed from selected items
    local totals = { carved = 0, weathered = 0, runed = 0, gilded = 0, valorstone = 0 }
    
    -- Debug: Print current selections
    local selectedCount = 0
    for itemID, isSelected in pairs(NemUpgradeTracker.selectedItems) do
        if isSelected then
            selectedCount = selectedCount + 1
        end
    end
    
    for itemID, isSelected in pairs(NemUpgradeTracker.selectedItems) do
        if isSelected then
            -- Find item in upgradeableItems
            for _, item in ipairs(NemUpgradeTracker.upgradeableItems or {}) do
                if item.itemLink == itemID then
                    local crestNeeds = self:CalculateCrestNeeds(item)
                    if crestNeeds then
                        for crestType, count in pairs(crestNeeds) do
                            totals[crestType] = (totals[crestType] or 0) + count
                        end
                    end
                    break
                end
            end
        end
    end
    
    -- Add crafted item costs (90 crests per crafted item)
    for crestType, count in pairs(NemUpgradeTracker.craftedItems) do
        if count > 0 then
            totals[crestType] = (totals[crestType] or 0) + (count * 90)
        end
    end
    
    -- Get current inventory counts and calculate missing amounts
    local missing = {}
    for crestType, required in pairs(totals) do
        local current = 0
        -- Get count from currency API (all crests are currencies)
        local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(CREST_ICONS[crestType])
        if currencyInfo then
            current = currencyInfo.quantity or 0
        end
        missing[crestType] = math.max(0, required - current)
    end
    
    -- Update display with missing amounts
    for i, child in ipairs({totalCostFrame:GetChildren()}) do
        if child.crestType and child.countText then
            child.countText:SetText(tostring(missing[child.crestType] or 0))
        end
    end
end

function NemUpgradeTracker:UpdateItemList()
    if not itemListFrame.content then return end
    
    -- Clear existing items
    for i = itemListFrame.content:GetNumChildren(), 1, -1 do
        local child = select(i, itemListFrame.content:GetChildren())
        child:Hide()
        child:SetParent(nil)
    end
    
    local items = NemUpgradeTracker.upgradeableItems or {}
    if #items == 0 then return end
    
    -- Sort: equipped first, then by ilvl
    table.sort(items, function(a, b)
        if a.isEquipped ~= b.isEquipped then
            return a.isEquipped
        end
        return (a.itemLevel or 0) > (b.itemLevel or 0)
    end)
    
    local yOffset = 0
    for i, item in ipairs(items) do
        local itemFrame = CreateFrame("Frame", nil, itemListFrame.content)
        itemFrame:SetSize(440, 30) -- Adjusted size for left column
        itemFrame:SetPoint("TOPLEFT", itemListFrame.content, "TOPLEFT", 0, yOffset)
        
        local checkbox = CreateFrame("CheckButton", nil, itemFrame, "UICheckButtonTemplate")
        checkbox:SetPoint("LEFT", itemFrame, "LEFT", 0, 0)
        checkbox:SetChecked(NemUpgradeTracker.selectedItems[item.itemLink] or false)
        checkbox:SetScript("OnClick", function(self)
            if self:GetChecked() then
                NemUpgradeTracker.selectedItems[item.itemLink] = true
            else
                NemUpgradeTracker.selectedItems[item.itemLink] = nil
            end
            NemUpgradeTracker:UpdateTotalCost()
            NemUpgradeTracker:UpdateDungeonEstimations()
            NemUpgradeTracker:SaveSelections()
        end)
        
        local icon = itemFrame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(25, 25)
        icon:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
        icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        icon:SetTexture(NemUpgradeTracker:GetItemIcon(item.itemLink))
        
        -- Make item icon hoverable with tooltip
        itemFrame:EnableMouse(true)
        itemFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(item.itemLink)
            GameTooltip:Show()
        end)
        itemFrame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        
        local name = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        name:SetText(item.itemName or "Unknown")
        
        -- Set color based on item rarity
        local rarity = select(3, GetItemInfo(item.itemLink))
        if rarity then
            local r, g, b = GetItemQualityColor(rarity)
            name:SetTextColor(r, g, b)
        end
        
        local upgradeInfo = itemFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        upgradeInfo:SetPoint("LEFT", name, "RIGHT", 10, 0)
        upgradeInfo:SetText(string.format("%d -> %d", item.itemLevel or 0, (item.itemLevel or 0) + ((item.maxLevel - item.upgradeLevel) * 3)))
        
        yOffset = yOffset - 35
    end
    
    itemListFrame.content:SetHeight(math.abs(yOffset))
end

function NemUpgradeTracker:OnCraftedInputChange(crestType, text)
    -- Handle crafted item input changes
    local value = tonumber(text) or 0
    
    -- Validate input: only allow positive integers
    if value < 0 then
        value = 0
    else
        value = math.floor(value) -- Ensure integer
    end
    
    -- Update the input box with the validated value
    local input = _G["NemUpgradeTrackerCraftedInput" .. crestType]
    if input then
        input:SetText(tostring(value))
    end
    
    NemUpgradeTracker.craftedItems[crestType] = value
    NemUpgradeTracker:UpdateTotalCost()
    NemUpgradeTracker:UpdateDungeonEstimations()
    NemUpgradeTracker:SaveSelections()
end 

function NemUpgradeTracker:SaveSelections()
    -- Save selected items
    NemUpgradeTrackerDB.selectedItems = NemUpgradeTracker.selectedItems
    
    -- Save crafted items
    NemUpgradeTrackerDB.craftedItems = NemUpgradeTracker.craftedItems
    
    local selectedCount = 0
    for itemLink, isSelected in pairs(NemUpgradeTracker.selectedItems) do
        if isSelected then
            selectedCount = selectedCount + 1
        end
    end
    
    local craftedCount = 0
    for crestType, count in pairs(NemUpgradeTracker.craftedItems) do
        if count > 0 then
            craftedCount = craftedCount + 1
        end
    end
    
end

function NemUpgradeTracker:DebugSavedData()
    print("[NemUpgradeTracker] === DEBUG SAVED DATA ===")
    print("[NemUpgradeTracker] NemUpgradeTrackerDB exists:", NemUpgradeTrackerDB ~= nil)
    if NemUpgradeTrackerDB then
        local selectedCount = 0
        for _ in pairs(NemUpgradeTracker.selectedItems) do
            selectedCount = selectedCount + 1
        end
        local craftedCount = 0
        for crestType, count in pairs(NemUpgradeTracker.craftedItems) do
            if count > 0 then
                craftedCount = craftedCount + 1
            end
        end
    end
    print("[NemUpgradeTracker] === END DEBUG ===")
end 

function NemUpgradeTracker:CheckCurrencyGains()
    local currentCounts = {}
    local hasChanges = false
    
    -- Get current currency counts
    for crestType, currencyID in pairs(CREST_ICONS) do
        local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if currencyInfo then
            currentCounts[crestType] = currencyInfo.quantity or 0
        end
    end
    
    -- Check for changes
    for crestType, currentCount in pairs(currentCounts) do
        local lastCount = NemUpgradeTracker.lastCurrencyCounts[crestType] or 0
        if currentCount > lastCount then
            hasChanges = true
            break
        end
    end
    
    -- Update stored counts
    NemUpgradeTracker.lastCurrencyCounts = currentCounts
    
    -- Show notification if there were gains and we have selected items
    if next(NemUpgradeTracker.selectedItems) then
        self:ShowProgressNotification()
    end
end

function NemUpgradeTracker:GetCrestDisplayInfo(crestType)
    local colorMap = {
        carved = "|cff8b5c2a",      -- brownish
        weathered = "|cffb0c4de",   -- light blue/gray
        runed = "|cff3399ff",      -- blue
        gilded = "|cffffd700",     -- gold
        valorstone = "|cffb22222", -- red
    }
    local icon = ""
    local iconFileID = self:GetCrestIcon(crestType)
    if iconFileID and type(iconFileID) == "number" then
        icon = "|T" .. iconFileID .. ":14:14:0:0:64:64:5:59:5:59|t "
    end
    local color = colorMap[crestType] or "|cffffffff"
    local name = crestType:gsub("^%l", string.upper)
    if crestType == "valorstone" then name = "Valorstone" end
    return icon, color, name
end

function NemUpgradeTracker:ShowProgressNotification()
    -- Calculate what we still need
    local totals = { carved = 0, weathered = 0, runed = 0, gilded = 0, valorstone = 0 }
    -- Get requirements from selected items
    for itemID, isSelected in pairs(NemUpgradeTracker.selectedItems) do
        if isSelected then
            for _, item in ipairs(NemUpgradeTracker.upgradeableItems or {}) do
                if item.itemLink == itemID then
                    local crestNeeds = self:CalculateCrestNeeds(item)
                    if crestNeeds then
                        for crestType, count in pairs(crestNeeds) do
                            totals[crestType] = (totals[crestType] or 0) + count
                        end
                    end
                    break
                end
            end
        end
    end
    -- Add crafted item costs
    for crestType, count in pairs(NemUpgradeTracker.craftedItems) do
        if count > 0 then
            totals[crestType] = (totals[crestType] or 0) + (count * 90)
        end
    end
    -- Calculate missing amounts
    local missing = {}
    local totalMissing = 0
    local missingText = {}
    for crestType, required in pairs(totals) do
        local current = 0
        local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(CREST_ICONS[crestType])
        if currencyInfo then
            current = currencyInfo.quantity or 0
        end
        local missingCount = math.max(0, required - current)
        missing[crestType] = missingCount
        if missingCount > 0 then
            totalMissing = totalMissing + missingCount
            local icon, color, name = self:GetCrestDisplayInfo(crestType)
            table.insert(missingText, string.format("%s%s|r %s%s|r", color, missingCount, icon, name))
        end
    end
    -- Show notification if we still need anything
    if totalMissing > 0 then
        local message = string.format("You need %s more for your target!", table.concat(missingText, ", "))
        print("|cFF00FF00[NemUpgradeTracker]|r " .. message)
    else
        print("|cFF00FF00[NemUpgradeTracker]|r You have everything you need for your target!")
    end
end 

function NemUpgradeTracker:OnDungeonGainChange(type, text)
    local value = tonumber(text) or 0
    if value < 0 then value = 0 end
    value = math.floor(value)
    
    if type == "crest" then
        NemUpgradeTrackerDB.lastCrestGain = value
    elseif type == "valor" then
        NemUpgradeTrackerDB.lastValorGain = value
    end
    
    -- Update the input box with the validated value
    local input = _G["NemUpgradeTracker" .. (type == "crest" and "CrestGainInput" or "ValorGainInput")]
    if input then
        input:SetText(tostring(value))
    end
    
    self:UpdateDungeonEstimations()
end

function NemUpgradeTracker:OnKeyLevelChange(text)
    local value = tonumber(text) or 20
    if value < 1 then value = 1 end
    if value > 30 then value = 30 end
    value = math.floor(value)
    
    NemUpgradeTrackerDB.keyLevel = value
    
    -- Update the input box with the validated value
    local input = _G["NemUpgradeTrackerKeyLevelInput"]
    if input then
        input:SetText(tostring(value))
    end
    
    self:UpdateDungeonEstimations()
end

function NemUpgradeTracker:UpdateDungeonEstimations()
    if not craftedInputFrame or not craftedInputFrame.estimationResults then return end
    
    local keyLevel = NemUpgradeTrackerDB.keyLevel or 20
    
    -- Get crest rewards for this key level
    local keyRewards = NemUpgradeTracker.KEY_LEVEL_CRESTS[keyLevel]
    if not keyRewards then
        craftedInputFrame.estimationResults:SetText("|cffff3333Invalid key level. Please enter 2-30.|r")
        return
    end
    
    -- Calculate what we need
    local totals = { carved = 0, weathered = 0, runed = 0, gilded = 0, valorstone = 0 }
    
    -- Get requirements from selected items
    for itemID, isSelected in pairs(NemUpgradeTracker.selectedItems) do
        if isSelected then
            for _, item in ipairs(NemUpgradeTracker.upgradeableItems or {}) do
                if item.itemLink == itemID then
                    local crestNeeds = self:CalculateCrestNeeds(item)
                    if crestNeeds then
                        for crestType, count in pairs(crestNeeds) do
                            totals[crestType] = (totals[crestType] or 0) + count
                        end
                    end
                    break
                end
            end
        end
    end
    
    -- Add crafted item costs
    for crestType, count in pairs(NemUpgradeTracker.craftedItems) do
        if count > 0 then
            totals[crestType] = (totals[crestType] or 0) + (count * 90)
        end
    end
    
    -- Calculate missing amounts
    local missing = {}
    local totalMissingCrests = 0
    local totalMissingValor = 0
    
    for crestType, required in pairs(totals) do
        local current = 0
        local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(CREST_ICONS[crestType])
        if currencyInfo then
            current = currencyInfo.quantity or 0
        end
        local missingCount = math.max(0, required - current)
        missing[crestType] = missingCount
        
        if crestType == "valorstone" then
            totalMissingValor = totalMissingValor + missingCount
        else
            totalMissingCrests = totalMissingCrests + missingCount
        end
    end
    
    -- Calculate dungeons needed based on key level rewards
    local dungeonsForCrests = 0
    local dungeonsForValor = 0

    -- Only estimate dungeons for the crest type that drops at this key level
    local neededCrestType = keyRewards.type
    local neededAmount = missing[neededCrestType] or 0

    if neededAmount > 0 then
        dungeonsForCrests = math.ceil(neededAmount / keyRewards.amount)
    end

    -- Valor calculation (estimate)
    if totalMissingValor > 0 then
        dungeonsForValor = math.ceil(totalMissingValor / 75) -- 75 valorstone per dungeon estimate
    end

    -- Build estimation text with color and formatting
    local estimationText = {}
    local gold = "|cffffd700"
    local green = "|cff00ff00"
    local blue = "|cff3399ff"
    local orange = "|cffff9900"
    local purple = "|cffa335ee"
    local red = "|cffff3333"
    local gray = "|cffbbbbbb"
    local reset = "|r"

    if dungeonsForCrests > 0 then
        table.insert(estimationText, string.format("%sCrests %s(+%d)%s: %s%d%s dungeons", orange, blue, keyLevel, reset, gold, dungeonsForCrests, reset))
        table.insert(estimationText, string.format("  %s(%d %s crests per dungeon)%s", gray, keyRewards.amount, keyRewards.type:gsub("^%l", string.upper), reset))
    elseif neededAmount > 0 then
        -- You need a crest type that this key cannot drop
        table.insert(estimationText, string.format("%sThis key level does not drop the crest type you need (%s).%s", red, neededCrestType:gsub("^%l", string.upper), reset))
    end

    -- Add padding between crest and valor estimations
    if dungeonsForCrests > 0 and dungeonsForValor > 0 then
        table.insert(estimationText, " ")
    end

    if dungeonsForValor > 0 then
        table.insert(estimationText, string.format("%sValor (estimate):%s %s%d%s dungeons", purple, reset, gold, dungeonsForValor, reset))
        table.insert(estimationText, string.format("  %s(~75 valorstone per dungeon)%s", gray, reset))
    end

    if #estimationText == 0 then
        estimationText = {green .. "You have everything you need!" .. reset}
    end

    craftedInputFrame.estimationResults:SetText(table.concat(estimationText, "\n"))
end 