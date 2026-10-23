-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Conservative merchant selling rules and junk marking. Original implementation.
local _, F = ...
-- Older client functions: the client's own global when present, else a private shim (Compat.lua).
local GetContainerNumSlots = F.Compat("GetContainerNumSlots")
local GetContainerItemLink = F.Compat("GetContainerItemLink")
local UseContainerItem = F.Compat("UseContainerItem")
local common = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "EnhanceQoLVendor",
    "TweaksForever", "Scrap", "Peddler", "Dejunk" }
local QUALITY = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3 }
local BAG_SLOTS = 4
local previewFrame

local function containerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end
    if GetContainerNumSlots then return GetContainerNumSlots(bag) or 0 end
    return 0
end

local function containerLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bag, slot)
    end
    if GetContainerItemLink then return GetContainerItemLink(bag, slot) end
end

local function useContainerItem(bag, slot)
    if C_Container and C_Container.UseContainerItem then
        return C_Container.UseContainerItem(bag, slot)
    end
    if UseContainerItem then return UseContainerItem(bag, slot) end
end

local function itemInfo(link)
    if not C_Item or not C_Item.GetItemInfo then return nil end
    local values = { C_Item.GetItemInfo(link) }
    if values[1] == nil then return nil end
    return { name = values[1], quality = values[3], itemLevel = values[4], equipLoc = values[9],
        sellPrice = values[11], classID = values[12], bindType = values[14] }
end

local function listed(list, value)
    if type(list) ~= "table" or value == nil then return false end
    for _, entry in ipairs(list) do
        if entry == value then return true end
    end
    return false
end

local function itemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    local id = link:match("item:(%d+)")
    return id and tonumber(id) or nil
end

function F:NeverSellList()
    if not self.db then return {} end
    if type(self.db.neverSell) ~= "table" then self.db.neverSell = {} end
    return self.db.neverSell
end

function F:AddNeverSell(value)
    local id = tonumber(tostring(value or ""):match("item:(%d+)") or value)
    if not id or id <= 0 then return false end
    local list = self:NeverSellList()
    if not listed(list, id) then list[#list + 1] = id end
    return true, id
end

function F:RemoveNeverSell(value)
    local id = tonumber(value)
    local list = self:NeverSellList()
    for index = #list, 1, -1 do
        if list[index] == id then table.remove(list, index); return true end
    end
    return false
end

function F:SellWhitelist()
    if not self.db then return {} end
    if type(self.db.sellWhitelist) ~= "table" then self.db.sellWhitelist = {} end
    return self.db.sellWhitelist
end

function F:AddSellWhitelist(value)
    local id = tonumber(tostring(value or ""):match("item:(%d+)") or value)
    if not id or id <= 0 then return false end
    local list = self:SellWhitelist()
    if not listed(list, id) then list[#list + 1] = id end
    return true, id
end

function F:RemoveSellWhitelist(value)
    local id = tonumber(value)
    local list = self:SellWhitelist()
    for index = #list, 1, -1 do
        if list[index] == id then table.remove(list, index); return true end
    end
    return false
end

function F:IsSellWhitelisted(link)
    local id = itemIDFromLink(link)
    return id ~= nil and listed(self:SellWhitelist(), id)
end

function F:IsProtectedFromSale(link)
    local id = itemIDFromLink(link)
    return id ~= nil and listed(self:NeverSellList(), id)
end

-- Candidates that the current rules would sell. Every rule is checked here so the
-- preview, the chat report and the actual sale can never disagree.
function F:SaleCandidates()
    local rows = {}
    local qualityLimit = QUALITY[F:GetOption("merchantRules", "quality")] or 0
    local maxLevel = F:GetOption("merchantRules", "maxItemLevel") or 0
    local bindMode = F:GetOption("merchantRules", "bindMode")
    local protectedBag
    if F:Active("reagentBag") then protectedBag = F:GetOption("reagentBag", "bag") end
    for bag = 0, BAG_SLOTS do
        local skipBag = protectedBag ~= nil and bag == protectedBag
        local slots = containerSlots(bag)
        for slot = 1, slots do
            local link
            if not skipBag then link = containerLink(bag, slot) end
            if type(link) == "string" then
                local info = itemInfo(link)
                if info and info.sellPrice and info.sellPrice > 0 then
                    local skip = false
                    if info.classID == 12 then skip = true end                     -- quest items
                    if info.classID == 9 then skip = true end                      -- recipes are usually kept
                    local whitelisted = F.IsSellWhitelisted and F:IsSellWhitelisted(link)
                    if not whitelisted then
                        if (info.quality or 0) > qualityLimit then skip = true end
                        if maxLevel > 0 and (info.itemLevel or 0) > maxLevel then skip = true end
                        if bindMode == "boe" and info.bindType ~= 2 then skip = true end
                    end
                    if F:IsProtectedFromSale(link) then skip = true end
                    if not skip then
                        rows[#rows + 1] = { bag = bag, slot = slot, link = link, name = info.name,
                            quality = info.quality or 0, itemLevel = info.itemLevel or 0,
                            price = info.sellPrice }
                    end
                end
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.quality ~= b.quality then return a.quality < b.quality end
        if a.itemLevel ~= b.itemLevel then return a.itemLevel < b.itemLevel end
        return a.slot < b.slot
    end)
    return rows
end

local function sell(rows)
    local sold = 0
    for _, row in ipairs(rows) do
        -- Re-check the slot immediately before selling: the bag may have moved since the scan.
        local link = containerLink(row.bag, row.slot)
        if link == row.link then
            useContainerItem(row.bag, row.slot)
            sold = sold + 1
        end
    end
    return sold
end

local function describe(rows)
    local counts = {}
    for _, row in ipairs(rows) do counts[row.name or "item"] = (counts[row.name or "item"] or 0) + 1 end
    local parts = {}
    for name, count in pairs(counts) do
        parts[#parts + 1] = (count > 1 and count .. "x " or "") .. name
    end
    table.sort(parts)
    return table.concat(parts, ", ")
end

local function hidePreview()
    if previewFrame then previewFrame:Hide() end
end

local function showPreview(rows)
    if not previewFrame then
        local frame = CreateFrame("Frame", "TweakSuiteSellPreview", UIParent, "BackdropTemplate")
        frame:SetSize(460, 300); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        frame:SetBackdropColor(0.095, 0.08, 0.06, 0.98)
        frame:SetBackdropBorderColor(0.28, 0.23, 0.12, 0.9)
        frame:SetMovable(true); frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        frame.heading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        frame.heading:SetPoint("TOPLEFT", 18, -14); frame.heading:SetText("Sell preview")
        frame.heading:SetTextColor(1, 0.82, 0.22)
        frame.body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.body:SetPoint("TOPLEFT", 18, -44); frame.body:SetWidth(410); frame.body:SetJustifyH("LEFT")
        local sellButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        sellButton:SetSize(150, 24); sellButton:SetPoint("BOTTOMLEFT", 18, 16)
        sellButton:SetText("Sell listed items")
        sellButton:SetScript("OnClick", function()
            local pending = F.previewRows or {}
            F.previewRows = nil
            hidePreview()
            local count = sell(pending)
            F:Print("Sold " .. count .. " item(s). Buy back from the merchant if that was a mistake.")
        end)
        local cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        cancel:SetSize(110, 24); cancel:SetPoint("BOTTOMRIGHT", -18, 16)
        cancel:SetText("Cancel")
        cancel:SetScript("OnClick", function()
            F.previewRows = nil
            hidePreview()
            F:Print("Sale cancelled. Nothing was sold.")
        end)
        frame:SetScript("OnHide", function() F.previewRows = nil end)
        UISpecialFrames[#UISpecialFrames + 1] = "TweakSuiteSellPreview"
        previewFrame = frame
    end
    previewFrame.body:SetText(describe(rows) .. "\n\n"
        .. "Quest items, recipes, protected items and anything above the configured quality "
        .. "or item level are excluded. Review the list, then confirm.")
    previewFrame:Show()
end

local function offerSale()
    if not F:Active("merchantRules") or not F:CanAutomate() then return end
    local rows = F:SaleCandidates()
    if #rows == 0 then return end
    local batch = F:GetOption("merchantRules", "batchSize") or 10
    if #rows > batch then
        local trimmed = {}
        for index = 1, batch do trimmed[index] = rows[index] end
        rows = trimmed
    end
    if F:GetOption("merchantRules", "preview") ~= false then
        F.previewRows = rows
        showPreview(rows)
        return
    end
    local count = sell(rows)
    if count > 0 then F:Print("Sold " .. count .. " item(s) under the merchant rules.") end
end

F:Register("merchantRules", {
    title = "Sell by merchant rules",
    category = "Automation",
    description = "Sells bag items that match your quality, item level and bind rules. Quest items, recipes, items on the never-sell list and anything above the thresholds are always kept. A preview lists the exact items before any sale unless you turn it off.",
    disableText = "Stops selling immediately. Items already sold stay sold; use the merchant's buyback slots if needed.",
    conflicts = common,
    options = {
        { key = "quality", type = "choice", title = "Sell at or below quality", default = "Poor",
          choices = { { value = "Poor", label = "Poor (gray)" }, { value = "Common", label = "Common (white)" },
              { value = "Uncommon", label = "Uncommon (green)" }, { value = "Rare", label = "Rare (blue)" } },
          description = "Highest quality the rules may sell. Poor is the safest default; higher values can sell useful gear." },
        { key = "maxItemLevel", type = "number", title = "Maximum item level", default = 0,
          min = 0, max = 400, step = 1, unit = " ilvl",
          description = "Also require the item level to be at or below this value. 0 disables the limit. "
              .. "Only items the client reports a level for are affected." },
        { key = "bindMode", type = "choice", title = "Bind filter", default = "any",
          choices = { { value = "any", label = "Any binding" }, { value = "boe", label = "Only bind-on-equip" } },
          description = "Restrict sales to items that bind when equipped, which are the ones usually safe to sell. "
              .. "Any binding sells items whose bind type the client reports, including already-bound gear." },
        { key = "batchSize", type = "number", title = "Items per visit", default = 10, min = 1, max = 12, step = 1,
          description = "Maximum sales per merchant visit. Capped at the client's buyback slots so a mistake can always be reversed." },
        { key = "preview", type = "boolean", title = "Preview before selling", default = true,
          description = "Shows the exact list and waits for confirmation. Turning this off sells immediately when the merchant opens." },
    },
    available = function()
        return _G.MerchantFrame ~= nil and ((C_Container and C_Container.UseContainerItem) or UseContainerItem)
            and ((C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink)
            and C_Item and C_Item.GetItemInfo
    end,
    enable = function()
        F:Listen("merchantRules", "MERCHANT_SHOW", offerSale)
        F:Listen("merchantRules", "MERCHANT_CLOSED", hidePreview)
    end,
    disable = hidePreview,
})

F:Register("sellWhitelist", {
    title = "Sell whitelist",
    category = "Automation",
    description = "Items you list by item ID are always sold, even when they are above your quality or item-level limit. Quest items, recipes and never-sell items are still protected, and the preview shows exactly what will go. Use /ts whitelist add <itemID>, remove and list.",
    disableText = "Stops the whitelist from adding items. The list is kept and applies again when the feature is turned back on.",
    conflicts = common,
    available = function() return C_Item ~= nil and C_Item.GetItemInfo ~= nil end,
    enable = function() end,
    disable = function() end,
})

F:Register("junkMarking", {
    title = "Mark items as junk by hand",
    category = "Automation",
    description = "Lets you mark any bag item as junk with /ts junk and unmark it with /ts unjunk, so the client's own Sell All Junk includes it. Marks are stored by item ID. It never sells by itself.",
    disableText = "Stops adding the junk mark to items. Existing marks stay until you remove them or clear saved data.",
    conflicts = common,
    options = {
        { key = "clearOnSale", type = "boolean", title = "Clear a mark after it is sold", default = true,
          description = "Removes the junk mark once the marked item is no longer in your bags, so the list does not grow forever." },
    },
    available = function() return C_Item and C_Item.GetItemInfo and C_Item.GetItemSellPrice ~= nil end,
    enable = function()
        F:Listen("junkMarking", "MERCHANT_SHOW", function()
            if F:GetOption("junkMarking", "clearOnSale") == false then return end
            local marks = F.db and F.db.junk
            if type(marks) ~= "table" then return end
            for id in pairs(marks) do
                local count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id) or 0
                if type(count) == "number" and count <= 0 then marks[id] = nil end
            end
        end)
    end,
})
