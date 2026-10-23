-- SPDX-License-Identifier: MIT
-- Loot notices, a tracked item bar and merchant cost details.
local _, F = ...

local QUALITY_LABEL = { [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic", [5] = "Legendary" }

-- Loot notifications read the client's own loot event, which carries the item link
-- and quantity; no loot frame is replaced.
function F:LootMessage(link, quantity)
    if type(link) ~= "string" or not F:Plain(link) then return nil end
    local name = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(link) or link
    if type(name) ~= "string" or not F:Plain(name) then name = link end
    local count = tonumber(quantity) or 1
    local quality = C_Item and C_Item.GetItemQuality and C_Item.GetItemQuality(link) or 0
    if type(quality) ~= "number" then quality = 0 end
    if quality < (tonumber(F:GetOption("lootNotice", "minQuality")) or 0) then return nil end
    return name .. (count > 1 and (" x" .. count) or "") .. " (" .. (QUALITY_LABEL[quality] or "Unknown") .. ")"
end

F:Register("lootNotice", {
    title = "Loot notifications",
    category = "Inventory",
    description = "Prints one short line for each item you loot, with the quantity and quality, and optionally plays a soft sound. It reads the client's loot event and leaves the loot window untouched.",
    disableText = "Stops the loot lines and sounds.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "LootAlert" },
    options = {
        { key = "minQuality", type = "choice", title = "Lowest quality shown", default = "0",
          choices = { { value = "0", label = "Everything" }, { value = "1", label = "Common and better" },
              { value = "2", label = "Uncommon and better" }, { value = "3", label = "Rare and better" } },
          description = "Loot below the chosen quality is not announced. The default announces everything so a quest item is never missed." },
        { key = "sound", type = "boolean", title = "Play a sound", default = false,
          description = "Plays a quiet chime for each announced item. Off by default to keep looting quiet." },
    },
    available = function() return C_Item ~= nil and C_Item.GetItemInfo ~= nil end,
    enable = function()
        F:Listen("lootNotice", "LOOT_ITEM", function(_, link, quantity)
            local text = F:LootMessage(link, quantity)
            if not text then return end
            F:Print("Looted: " .. text)
            if F:GetOption("lootNotice", "sound") and PlaySound then pcall(PlaySound, 3157, "Master") end
        end)
    end,
})

-- ---------------------------------------------------------------------------
-- Tracked item bar

local trackBar, trackText

local function trackedItems()
    local list = F.db and F.db.trackedItems
    return type(list) == "table" and list or {}
end

function F:TrackItem(itemID, label)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 or itemID > 10000000 then return false, "item ID must be between 1 and 10000000" end
    for _, entry in ipairs(trackedItems()) do
        if entry.id == itemID then return false, "that item is already tracked" end
    end
    if #trackedItems() >= 30 then return false, "at most 30 items can be tracked" end
    if type(F.db) ~= "table" then return false, "settings are read only" end
    if type(F.db.trackedItems) ~= "table" then F.db.trackedItems = {} end
    if type(label) == "string" and #label > 40 then label = label:sub(1, 40) end
    F.db.trackedItems[#F.db.trackedItems + 1] = { id = itemID, label = (label ~= "" and label or nil) }
    F:UpdateTrackedBar()
    return true
end

function F:UntrackItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then return false, "an item ID is required" end
    local list = trackedItems()
    for index, entry in ipairs(list) do
        if entry.id == itemID then
            table.remove(F.db.trackedItems, index)
            if next(F.db.trackedItems) == nil then F.db.trackedItems = nil end
            F:UpdateTrackedBar()
            return true
        end
    end
    return false, "that item is not tracked"
end

function F:TrackedItemCounts()
    local rows = {}
    for _, entry in ipairs(trackedItems()) do
        local count = 0
        if C_Item and C_Item.GetItemCount then
            local ok, value = pcall(C_Item.GetItemCount, entry.id, false, false, false)
            if ok and type(value) == "number" then count = value end
        end
        rows[#rows + 1] = { id = entry.id, label = entry.label, count = count }
    end
    return rows
end

function F:UpdateTrackedBar()
    if not F:Active("trackedBar") then return end
    local rows = F:TrackedItemCounts()
    if not trackBar then return end
    if #rows == 0 then trackBar:Hide(); return end
    local lines = {}
    for _, row in ipairs(rows) do
        lines[#lines + 1] = (row.label or ("Item " .. row.id)) .. ": " .. row.count
    end
    if trackText and trackText.SetText then trackText:SetText(table.concat(lines, "\n")) end
    trackBar:Show()
end

local function ensureTrackBar()
    if trackBar then return trackBar end
    trackBar = CreateFrame("Frame", "ForeverSuiteTrackedBar", UIParent)
    trackBar:SetSize(160, 24)
    trackBar:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -140)
    trackBar:SetFrameStrata("LOW")
    trackText = trackBar:CreateFontString(nil, "OVERLAY")
    if GameFontNormalSmall then trackText:SetFontObject(GameFontNormalSmall) end
    trackText:SetPoint("TOPLEFT", trackBar, "TOPLEFT", 0, 0)
    trackText:SetJustifyH("LEFT")
    trackBar:SetScript("OnSizeChanged", function(self)
        local height = 16 + 14 * #trackedItems()
        self:SetSize(160, math.max(16, height))
    end)
    trackBar:Hide()
    return trackBar
end

F:Register("trackedBar", {
    title = "Tracked item bar",
    category = "Inventory",
    description = "Shows a small text panel with the number of each tracked item in your bags. /fs track add <itemID> [label], remove and list manage the list, and the panel updates on every bag change.",
    disableText = "Hides the panel. The tracked list is kept for the next time the feature is enabled.",
    conflicts = {},
    available = function() return UIParent ~= nil and C_Item ~= nil end,
    enable = function()
        ensureTrackBar()
        F:UpdateTrackedBar()
        F:Listen("trackedBar", "BAG_UPDATE", function() F:UpdateTrackedBar() end)
        F:Listen("trackedBar", "PLAYER_ENTERING_WORLD", function() F:UpdateTrackedBar() end)
    end,
    refresh = function() F:UpdateTrackedBar() end,
    disable = function()
        if trackBar then trackBar:Hide() end
    end,
})

-- ---------------------------------------------------------------------------
-- Merchant multi-currency costs

function F:MerchantCost(index)
    index = tonumber(index)
    if not index or index < 1 then return nil, "a merchant item index is required" end
    local name, _, price
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local ok, itemName, _, itemPrice = pcall(C_MerchantFrame.GetItemInfo, index)
        if ok then name, price = itemName, itemPrice end
    end
    if not name and GetMerchantItemLink then
        local link = GetMerchantItemLink(index)
        if type(link) == "string" and C_Item and C_Item.GetItemInfo then name = C_Item.GetItemInfo(link) end
    end
    if type(name) ~= "string" or name == "" then return nil, "the client does not report that merchant slot" end
    local costs = {}
    if GetMerchantItemCostInfo and GetMerchantItemCostItem then
        local ok, count = pcall(GetMerchantItemCostInfo, index)
        if ok and type(count) == "number" then
            for costIndex = 1, math.min(count, 6) do
                local costOk, texture, amount, link, costName = pcall(GetMerchantItemCostItem, index, costIndex)
                if costOk and (amount or costName or link) then
                    costs[#costs + 1] = { amount = tonumber(amount), link = link, name = costName, texture = texture }
                end
            end
        end
    end
    return { index = index, name = name, money = tonumber(price), costs = costs }
end

F:Register("merchantCurrency", {
    title = "Merchant cost details",
    category = "Inventory",
    description = "Prints every alternative cost of a merchant item with /fs cost <index>, including currency costs the gold price does not show. It only reads the merchant window and never buys anything.",
    disableText = "Stops the cost command. The merchant window is unchanged.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function() return GetMerchantItemCostInfo ~= nil end,
    enable = function() end,
})

-- ---------------------------------------------------------------------------
-- Custom loot window

local lootFrame

function F:LootEntries()
    local rows = {}
    if not (GetNumLootItems and GetLootSlotInfo) then return rows end
    local ok, count = pcall(GetNumLootItems)
    if not ok or type(count) ~= "number" then return rows end
    for slot = 1, count do
        local entryOK, icon, name, quantity, currencyID, quality = pcall(GetLootSlotInfo, slot)
        if entryOK and type(name) == "string" and name ~= "" then
            rows[#rows + 1] = {
                slot = slot, icon = icon, name = name,
                quantity = tonumber(quantity) or 1,
                currencyID = currencyID,
                quality = tonumber(quality) or 1,
            }
        end
    end
    return rows
end

local QUALITY_COLOR = {
    [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 },
    [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 },
    [6] = { 0.9, 0.8, 0.5 }, [7] = { 0, 0.8, 1 },
}

function F:LootQualityColor(quality)
    local color = QUALITY_COLOR[tonumber(quality) or 1] or QUALITY_COLOR[1]
    return color[1], color[2], color[3]
end

function F:RefreshLootWindow()
    if not F:Active("lootWindow") then return false end
    local entries = F:LootEntries()
    if not lootFrame then
        lootFrame = CreateFrame("Frame", "ForeverSuiteLootList", UIParent)
        lootFrame:SetSize(240, 24)
        lootFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        lootFrame.rows = {}
    end
    for _, row in ipairs(lootFrame.rows) do row:Hide() end
    if #entries == 0 then
        lootFrame:Hide()
        return false
    end
    for index, entry in ipairs(entries) do
        local row = lootFrame.rows[index]
        if not row then
            row = CreateFrame("Button", nil, lootFrame)
            row:SetSize(240, 18)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.text:SetPoint("LEFT", 4, 0)
            row.text:SetPoint("RIGHT", -4, 0)
            row.text:SetJustifyH("LEFT")
            row.slot = index
            row:SetScript("OnClick", function(self)
                if F:Active("lootWindow") and LootSlot then pcall(LootSlot, self.slot) end
            end)
            lootFrame.rows[index] = row
        end
        row.slot = entry.slot
        row.text:SetText(entry.name .. (entry.quantity > 1 and (" x" .. entry.quantity) or ""))
        row.text:SetTextColor(F:LootQualityColor(entry.quality))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(index - 1) * 18)
        row:Show()
    end
    lootFrame:SetHeight(#entries * 18)
    lootFrame:Show()
    return true
end

F:Register("lootWindow", {
    title = "Compact loot list",
    category = "Inventory",
    description = "Lists the items currently on the loot window in a small list, with quality colours and stack counts, and lets you click a line to loot it. The client's own loot window stays available; nothing is looted automatically.",
    disableText = "Hides the list and leaves the current loot on the client's window.",
    conflicts = { "XLoot", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "hideDefault", type = "boolean", title = "Hide the client loot window", default = false,
          description = "Hides Blizzard's loot frame while the list is open. Off by default so the roll buttons and the loot log stay where you know them." },
    },
    available = function() return GetNumLootItems ~= nil and GetLootSlotInfo ~= nil end,
    enable = function()
        F:Listen("lootWindow", "LOOT_OPENED", function()
            F:RefreshLootWindow()
            if F:GetOption("lootWindow", "hideDefault") == true and LootFrame and LootFrame.Hide then
                LootFrame:Hide()
            end
        end)
        F:Listen("lootWindow", "LOOT_CLOSED", function()
            if lootFrame then lootFrame:Hide() end
            if F:GetOption("lootWindow", "hideDefault") == true and LootFrame and LootFrame.Show then
                LootFrame:Show()
            end
        end)
        F:Listen("lootWindow", "LOOT_SLOT_CLEARED", function() F:RefreshLootWindow() end)
    end,
    refresh = function() F:RefreshLootWindow() end,
    disable = function()
        if lootFrame then lootFrame:Hide() end
        if LootFrame and LootFrame.Show then LootFrame:Show() end
    end,
})
