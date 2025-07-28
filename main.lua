local ADDON_NAME, NemUpgradeTracker = ...
NemUpgradeTracker = NemUpgradeTracker or {}
_G["NemUpgradeTracker"] = NemUpgradeTracker

-- SavedVariables
NemUpgradeTrackerDB = NemUpgradeTrackerDB or { 
    trackedItems = {},
    selectedItems = {},
    craftedItems = {
        carved = 0,
        weathered = 0,
        runed = 0,
        gilded = 0
    }
}

-- Slash command handler
SLASH_NEMUPGRADETRACKER1 = "/nut"
SlashCmdList["NEMUPGRADETRACKER"] = function(msg)
    local cmd = string.lower(msg or "")
    if cmd == "scan" then
        print("[NemUpgradeTracker] Scanning for upgradeable items...")
        NemUpgradeTracker:ScanItems()
    elseif cmd == "show" then
       -- print("[NemUpgradeTracker] Showing item selection UI...")
        NemUpgradeTracker:ShowSelectionUI()
    elseif cmd == "summary" then
        print("[NemUpgradeTracker] Showing crest summary...")
        -- Placeholder: show summary UI
    elseif cmd == "clear" then
        print("[NemUpgradeTracker] Clearing saved data...")
        NemUpgradeTrackerDB = { 
            trackedItems = {},
            selectedItems = {},
            craftedItems = {
                carved = 0,
                weathered = 0,
                runed = 0,
                gilded = 0
            }
        }
        NemUpgradeTracker.selectedItems = {}
        NemUpgradeTracker.craftedItems = {
            carved = 0,
            weathered = 0,
            runed = 0,
            gilded = 0
        }
        print("[NemUpgradeTracker] Saved data cleared. Use /nut show to restart.")
    elseif cmd == "debug" then
        print("[NemUpgradeTracker] Debugging saved data...")
        NemUpgradeTracker:DebugSavedData()
    else
        print("NemUpgradeTracker commands:")
        print("/nut scan     - Scan and refresh tracked items")
        print("/nut show     - Open item selection UI")
        print("/nut summary  - Open crest requirement summary")
        print("/nut clear    - Clear saved data for testing")
        print("/nut debug    - Debug saved data state")
    end
end

SLASH_NEMUPGRADETRACKERTEST1 = "/nutcrest"
SlashCmdList["NEMUPGRADETRACKERTEST"] = function(msg)
    local idx = tonumber(msg) or 1
    local items = NemUpgradeTracker.upgradeableItems or {}
    local item = items[idx]
    if item then
        NemUpgradeTracker:CalculateCrestNeeds(item)
    else
        print("[NemUpgradeTracker] No upgradeable item at index " .. idx)
    end
end

-- Run scan on PLAYER_LOGIN
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Delay scan to ensure all data is loaded
        C_Timer.After(1, function()
            NemUpgradeTracker:ScanItems()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Also scan when entering world (for zone changes, etc.)
        C_Timer.After(0.5, function()
            NemUpgradeTracker:ScanItems()
        end)
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        -- Check for crest/valorstone gains
        NemUpgradeTracker:CheckCurrencyGains()
    end
end) 