-- SPDX-License-Identifier: MIT
-- Shared tooltip augmentations. Each data type is hooked at most once.
local _, F = ...
local seen = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local installed = {}
local function anyActive(ids)
    for _, id in ipairs(ids) do
        if F:Active(id) then return true end
    end
    return false
end

local function prepare(tooltip)
    if not hooked[tooltip] then
        tooltip:HookScript("OnTooltipCleared", function(self) seen[self] = nil end)
        hooked[tooltip] = true
    end
end

local function recordFor(tooltip, kind, id)
    local record = seen[tooltip]
    if not record or record.kind ~= kind or record.id ~= id then
        record = { kind = kind, id = id }
        seen[tooltip] = record
    end
    return record
end

local function add(tooltip, record, key, text)
    if record[key] then return end
    tooltip:AddLine(text, 0.55, 0.85, 0.85)
    record[key] = true
end

local function itemTooltip(tooltip, data)
    if not anyActive({ "maxStack", "itemLevel", "itemID", "itemCount", "sellPrice" }) then return end
    if not tooltip or not tooltip.GetItem or type(data) ~= "table" or not F:Plain(data) then return end
    local _, link = tooltip:GetItem()
    if not F:Plain(link) or type(link) ~= "string" then return end
    prepare(tooltip)
    local record = recordFor(tooltip, "item", link)
    local info = {}
    if C_Item and C_Item.GetItemInfo then info = { C_Item.GetItemInfo(link) } end
    local id = link:match("item:(%d+)")
    if F:Active("itemID") and id then add(tooltip, record, "itemID", "Item ID: " .. id) end
    local stack = info[8]
    if F:Active("maxStack") and F:Plain(stack) and type(stack) == "number" and stack > 1 then
        add(tooltip, record, "maxStack", "Max Stack: " .. stack)
    end
    local equip = info[9]
    if F:Active("itemLevel") and F:Plain(equip) and type(equip) == "string" and equip ~= "" then
        local level = C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
        if F:Plain(level) and type(level) == "number" and level > 0 then
            add(tooltip, record, "itemLevel", "Item Level (ForeverSuite): " .. level)
        end
    end
    if F:Active("itemCount") then
        local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
        if getCount then
            local includeBank = F:GetOption("itemCount", "includeBank") == true
            local count = getCount(link, includeBank, false, includeBank)
            if F:Plain(count) and type(count) == "number" and count >= 0 then
                add(tooltip, record, "itemCount", "Owned: " .. count
                    .. (includeBank and " (bags and bank)" or " (bags)"))
            end
        end
    end
    if F:Active("sellPrice") then
        local price = info[11]
        if F:Plain(price) and type(price) == "number" and price > 0 then
            local stack = info[8]
            local stacked = F:GetOption("sellPrice", "stackTotal") == true
                and F:Plain(stack) and type(stack) == "number" and stack > 1
            local label = "Sells for: "
            if stacked then
                price = price * stack
                label = "Stack sells for: "
            end
            local money = GetMoneyString and GetMoneyString(price) or (price .. " copper")
            add(tooltip, record, "sellPrice", label .. money)
        end
    end
end

local function spellTooltip(tooltip, data)
    if not F:Active("spellID") or not tooltip or type(data) ~= "table" or not F:Plain(data) then return end
    local id = data.id
    if not F:Plain(id) or type(id) ~= "number" or id <= 0 then return end
    prepare(tooltip)
    local record = recordFor(tooltip, "spell", id)
    add(tooltip, record, "spellID", "Spell ID: " .. id)
end

local function unitTooltip(tooltip, data)
    if not F:Active("npcID") or not tooltip or not tooltip.GetUnit or type(data) ~= "table" or not F:Plain(data) then return end
    local _, unit = tooltip:GetUnit()
    if not F:Plain(unit) or type(unit) ~= "string" or not UnitGUID then return end
    local guid = UnitGUID(unit)
    if not F:Plain(guid) or type(guid) ~= "string" then return end
    -- Creature-0-<server>-<instance>-<zone>-<npcID>-<spawn>
    local npcID = guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")
        or guid:match("^Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if not npcID then return end
    prepare(tooltip)
    local record = recordFor(tooltip, "unit", guid)
    add(tooltip, record, "npcID", "NPC ID: " .. npcID)
end

local function questTooltip(tooltip, data)
    if not F:Active("questID") or not tooltip or type(data) ~= "table" or not F:Plain(data) then return end
    local id = data.id or data.questID
    if not F:Plain(id) or type(id) ~= "number" or id <= 0 then return end
    prepare(tooltip)
    local record = recordFor(tooltip, "quest", id)
    add(tooltip, record, "questID", "Quest ID: " .. id)
end

local function currencyTooltip(tooltip, data)
    if not F:Active("currencyID") or not tooltip or type(data) ~= "table" or not F:Plain(data) then return end
    local id = data.id or data.currencyID
    if not F:Plain(id) or type(id) ~= "number" or id <= 0 then return end
    prepare(tooltip)
    local record = recordFor(tooltip, "currency", id)
    add(tooltip, record, "currencyID", "Currency ID: " .. id)
end

local function safe(handler, tooltip, data, ids)
    if not F.db or InCombatLockdown() then return end
    local ok, err = pcall(handler, tooltip, data)
    if not ok then
        for _, id in ipairs(ids) do
            if F:Active(id) then F:RecordError(id, err) end
        end
    end
end

local function install(dataType, handler, ids)
    if installed[dataType] then return end
    TooltipDataProcessor.AddTooltipPostCall(dataType, function(tooltip, data)
        safe(handler, tooltip, data, ids)
    end)
    installed[dataType] = true
end

local function tooltipAvailable()
    return TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum
        and Enum.TooltipDataType
end

local function itemAvailable()
    return tooltipAvailable() and Enum.TooltipDataType.Item and C_Item
        and C_Item.GetItemInfo and C_Item.GetDetailedItemLevelInfo
end

local function itemEnable() install(Enum.TooltipDataType.Item, itemTooltip, { "maxStack", "itemLevel", "itemID", "itemCount", "sellPrice" }) end
local common = { "EnhanceQoL", "EnhanceQoLTooltip", "Leatrix_Plus", "Leatrix_Plus_Forever", "TweaksForever" }

F:Register("maxStack", {
    title = "Maximum stack size",
    category = "Tooltips",
    description = "Adds maximum stack size to stackable item tooltips outside combat.",
    conflicts = { "MaxStackTooltip", "EnhanceQoL", "EnhanceQoLTooltip" },
    disableText = "Stops adding this line to new tooltips. Move your mouse away and hover again to rebuild the current tooltip.",
    enable = itemEnable,
    available = itemAvailable,
})
F:Register("itemLevel", {
    title = "Item level in tooltips",
    category = "Tooltips",
    description = "Adds the actual item level for equipment outside combat. Character and inspect overlays have their own settings; bag and bank overlays are planned.",
    conflicts = { "SimpleItemLevel", "EnhanceQoL", "EnhanceQoLTooltip", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    disableText = "Stops adding this line to new tooltips. Move your mouse away and hover again to rebuild the current tooltip.",
    enable = itemEnable,
    available = itemAvailable,
})
F:Register("itemID", {
    title = "Item ID in tooltips",
    category = "Tooltips",
    description = "Adds the item ID outside combat. Re-hover after changing tooltip options.",
    conflicts = common,
    disableText = "Stops adding this line to new tooltips. Move your mouse away and hover again to rebuild the current tooltip.",
    enable = itemEnable,
    available = itemAvailable,
})
F:Register("itemCount", {
    title = "Item count in tooltips",
    category = "Tooltips",
    description = "Adds how many of the hovered item you own. The option chooses whether bank contents are included; it does not count other characters or other accounts.",
    conflicts = { "EnhanceQoL", "EnhanceQoLBags", "BagSync", "Plumber" },
    disableText = "Stops adding the count to new tooltips. Move your mouse away and hover again to rebuild the current tooltip.",
    options = {
        { key = "includeBank", type = "boolean", title = "Include bank", default = false,
          description = "Counts items in bank storage as well as in bags, including the reagent bank when the client has one. The client only knows bank contents after the bank has been opened this session." },
    },
    enable = itemEnable,
    available = function()
        return tooltipAvailable() and Enum.TooltipDataType.Item
            and ((C_Item and C_Item.GetItemCount) or GetItemCount)
    end,
})
F:Register("spellID", {
    title = "Spell ID in tooltips",
    category = "Tooltips",
    description = "Adds the spell ID to spell tooltips outside combat. Hidden when the client does not label a tooltip as a spell.",
    conflicts = common,
    disableText = "Stops adding the spell ID to new tooltips. Re-hover to rebuild the current tooltip.",
    enable = function() install(Enum.TooltipDataType.Spell, spellTooltip, { "spellID" }) end,
    available = function()
        return TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum
            and Enum.TooltipDataType and Enum.TooltipDataType.Spell
    end,
})
F:Register("npcID", {
    title = "NPC ID in tooltips",
    category = "Tooltips",
    description = "Adds the NPC ID for creature and vehicle unit tooltips outside combat. Player characters, pets and game objects are left alone.",
    conflicts = { "EnhanceQoL", "Plumber" },
    disableText = "Stops adding the NPC ID to new tooltips. Re-hover to rebuild the current tooltip.",
    enable = function() install(Enum.TooltipDataType.Unit, unitTooltip, { "npcID" }) end,
    available = function()
        return TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum
            and Enum.TooltipDataType and Enum.TooltipDataType.Unit and UnitGUID ~= nil
    end,
})
F:Register("currencyID", {
    title = "Currency ID in tooltips",
    category = "Tooltips",
    description = "Adds the currency ID to currency tooltips outside combat. It does not add currency totals or alternative currencies.",
    conflicts = { "EnhanceQoL", "Plumber" },
    disableText = "Stops adding the currency ID to new tooltips. Re-hover to rebuild the current tooltip.",
    enable = function() install(Enum.TooltipDataType.Currency, currencyTooltip, { "currencyID" }) end,
    available = function()
        return TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum
            and Enum.TooltipDataType and Enum.TooltipDataType.Currency
    end,
})

F:Register("sellPrice", {
    title = "Vendor sell price in tooltips",
    category = "Tooltips",
    description = "Adds the price a vendor pays for the hovered item, outside combat. Items the client reports as unsellable get no line.",
    conflicts = common,
    options = {
        { key = "stackTotal", type = "boolean", title = "Show stack total", default = false,
          description = "Multiplies the unit sell price by the stack size, so a full stack shows what the whole stack is worth. Uses the item's maximum stack size, not how many you carry." },
    },
    disableText = "Stops adding the price line to new tooltips. Move your mouse away and hover again to rebuild the current tooltip.",
    enable = function() install(Enum.TooltipDataType.Item, itemTooltip, { "sellPrice" }) end,
    available = function()
        return tooltipAvailable() and Enum.TooltipDataType.Item and C_Item and C_Item.GetItemInfo
    end,
})

local TOOLTIP_FRAMES = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "FriendsTooltip" }
local scaleSaved, scaleHooked = {}, {}
local function applyTooltipScale()
    if not F:Active("tooltipScale") then return end
    -- Tooltip frames belong to the client's UI; keep scale changes out of combat.
    if InCombatLockdown() then return end
    local scale = F:GetOption("tooltipScale", "scale") / 100
    if type(scale) ~= "number" then return end
    for _, name in ipairs(TOOLTIP_FRAMES) do
        local frame = _G[name]
        if frame and frame.SetScale then
            if type(scaleSaved[frame]) ~= "table" and frame.GetScale then
                scaleSaved[frame] = { before = frame:GetScale() }
            end
            frame:SetScale(scale)
            if type(scaleSaved[frame]) == "table" then scaleSaved[frame].applied = scale end
        end
    end
end
F:Register("tooltipScale", {
    title = "Tooltip scale",
    category = "Tooltips",
    description = "Scales the game, item, shopping and friend tooltips. The number applies to new and currently open tooltips outside combat. It does not resize the settings windows.",
    disableText = "Restores the scale each tooltip had before ForeverSuite changed it, unless another addon has changed it since.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "TinyTooltip", "TipTac" },
    options = {
        { key = "scale", type = "number", title = "Tooltip scale (percent)", default = 100, min = 80, max = 200, step = 5, unit = "%",
          description = "Percent of the client's tooltip size. 100 keeps the default; 150 makes tooltips half again as large." },
    },
    available = function() return GameTooltip ~= nil and GameTooltip.SetScale ~= nil end,
    enable = function()
        for _, name in ipairs(TOOLTIP_FRAMES) do
            local frame = _G[name]
            if frame and frame.HookScript and not scaleHooked[frame] then
                frame:HookScript("OnShow", applyTooltipScale)
                scaleHooked[frame] = true
            end
        end
        applyTooltipScale()
        F:Listen("tooltipScale", "PLAYER_REGEN_ENABLED", applyTooltipScale)
    end,
    refresh = applyTooltipScale,
    disable = function()
        if InCombatLockdown() then return end
        for frame, stored in pairs(scaleSaved) do
            if frame.GetScale and frame:GetScale() == stored.applied and type(stored.before) == "number" then
                frame:SetScale(stored.before)
            end
            scaleSaved[frame] = nil
        end
    end,
})

F:Register("questID", {
    title = "Quest ID in tooltips",
    category = "Tooltips",
    description = "Adds the quest ID to quest tooltips outside combat. Hidden when the client does not label a tooltip as a quest.",
    conflicts = common,
    disableText = "Stops adding the quest ID to new tooltips. Re-hover to rebuild the current tooltip.",
    enable = function() install(Enum.TooltipDataType.Quest, questTooltip, { "questID" }) end,
    available = function()
        return TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum
            and Enum.TooltipDataType and Enum.TooltipDataType.Quest
    end,
})
