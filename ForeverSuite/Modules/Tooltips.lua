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

local SLOT_FOR_EQUIP = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_SHIRT = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 },
    INVTYPE_HOLDOFFHAND = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
    INVTYPE_RELIC = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_2HWEAPON = { 16, 17 }, INVTYPE_TABARD = { 19 },
}

local ITEM_TOOLTIP_FEATURES = { "maxStack", "itemLevel", "itemID", "itemCount", "sellPrice", "upgradeHint", "bindType",
    "flyoutItemLevel", "missingEnchant", "missingGems", "socketInfo", "repToken", "questItem" }
local UNIT_TOOLTIP_FEATURES = { "npcID", "tooltipClassColor", "unitHealth", "targetCastInfo" }

-- Item link fields: item:id:enchant:gem1:gem2:gem3:gem4:suffix:unique:...
local function linkFields(link)
    if type(link) ~= "string" or link:sub(1, 5) ~= "item:" then return nil end
    local fields = {}
    for value in link:gmatch("[^:]+") do fields[#fields + 1] = value end
    return fields
end

local function equippedLink(slot)
    if not GetInventoryItemLink then return nil end
    local ok, link = pcall(GetInventoryItemLink, "player", slot)
    if ok and type(link) == "string" then return link end
    return nil
end

local ENCHANTABLE = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CLOAK = true, INVTYPE_CHEST = true,
    INVTYPE_ROBE = true, INVTYPE_WRIST = true, INVTYPE_HAND = true, INVTYPE_LEGS = true,
    INVTYPE_FEET = true, INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true, INVTYPE_2HWEAPON = true, INVTYPE_SHIELD = true,
}

-- Socket counts come from the client's item stats table. When the client does not
-- expose that table the helpers stay silent instead of guessing.
local function socketCount(link)
    if type(GetItemStats) ~= "function" then return nil end
    local ok, stats = pcall(GetItemStats, link)
    if not ok or type(stats) ~= "table" then return nil end
    local total, empty = 0, 0
    for key, value in pairs(stats) do
        if type(key) == "string" and key:find("SOCKET") then
            local count = type(value) == "number" and value or 1
            total = total + count
            if key:find("EMPTY") then empty = empty + count end
        end
    end
    if total == 0 then return nil end
    return total, empty
end

local function isEquipped(link, equipLoc)
    local slots = SLOT_FOR_EQUIP[equipLoc]
    if not slots then return false, nil end
    for _, slot in ipairs(slots) do
        if equippedLink(slot) == link then return true, slot end
    end
    return false, nil
end

local function bestEquippedLevel(equipLoc)
    local slots = SLOT_FOR_EQUIP[equipLoc]
    if not slots or not C_Item or not C_Item.GetDetailedItemLevelInfo then return nil end
    local best
    for _, slot in ipairs(slots) do
        local link = equippedLink(slot)
        local level = link and C_Item.GetDetailedItemLevelInfo(link)
        if type(level) == "number" and level > 0 and (not best or level > best) then best = level end
    end
    return best
end

-- Returns the best comparison against the slot(s) the hovered item would occupy.
local function upgradeComparison(link, equipLoc, hoveredLevel)
    local slots = SLOT_FOR_EQUIP[equipLoc]
    if not slots or not GetInventoryItemLink or not C_Item or not C_Item.GetDetailedItemLevelInfo then return nil end
    local best
    for _, slot in ipairs(slots) do
        local worn = GetInventoryItemLink("player", slot)
        if type(worn) == "string" and worn ~= link then
            local wornLevel = C_Item.GetDetailedItemLevelInfo(worn)
            if type(wornLevel) == "number" and wornLevel > 0 then
                local delta = hoveredLevel - wornLevel
                if not best or delta > best then best = delta end
            end
        end
    end
    return best
end


-- The client's own item tooltip text is read through C_TooltipInfo, which is the
-- supported replacement for the removed GetItemInfo description fields. Lines that
-- the client marks secret are skipped instead of being compared.
local lineCache, lineCacheSize = {}, 0

function F:ItemTooltipLines(link)
    if type(link) ~= "string" then return nil end
    if lineCache[link] then return lineCache[link] end
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local lines = {}
    for _, line in ipairs(data.lines) do
        local text
        if type(line) == "table" then text = F:Plain(line.leftText) and line.leftText or nil end
        if type(text) == "string" and text ~= "" then lines[#lines + 1] = text end
    end
    if lineCacheSize > 400 then lineCache, lineCacheSize = {}, 0 end
    lineCache[link] = lines
    lineCacheSize = lineCacheSize + 1
    return lines
end

-- Pure parser so the rules can be tested without a client frame. It recognises the
-- two patterns the client uses for reputation tokens and quest starting items.
function F:ScanTooltipExtras(lines)
    local extras = {}
    if type(lines) ~= "table" then return extras end
    for _, raw in ipairs(lines) do
        if type(raw) == "string" then
            local faction, amount = raw:match("[Ii]ncreases your reputation with ([%w%s'%-]+) by (%d+)")
            if faction then
                extras.reputation = { faction = (faction:gsub("%s+$", "")), amount = tonumber(amount) }
            end
            local quest = raw:match('[Bb]egins a quest:?%s*"(.-)"') or raw:match("[Bb]egins a quest:?%s*(.+)$")
            if quest and quest ~= "" then extras.quest = { name = (quest:gsub("%.$", "")) } end
            if not extras.quest then
                local quoted = raw:match('quest "([^"]+)"')
                if quoted then extras.quest = { name = quoted } end
            end
        end
    end
    return extras
end

local function tooltipExtras(tooltip, record, link)
    if not (F:Active("repToken") or F:Active("questItem")) then return end
    local extras = F:ScanTooltipExtras(F:ItemTooltipLines(link))
    if F:Active("repToken") and extras.reputation then
        local text = "Reputation token: " .. extras.reputation.faction
        if F:GetOption("repToken", "showAmount") ~= false and extras.reputation.amount then
            text = text .. " (+" .. extras.reputation.amount .. ")"
        end
        add(tooltip, record, "repToken", text)
    end
    if F:Active("questItem") and extras.quest then
        local text = "Starts a quest"
        if F:GetOption("questItem", "showName") ~= false and extras.quest.name then
            text = text .. ": " .. extras.quest.name
        end
        add(tooltip, record, "questItem", text)
    end
end


local function itemTooltip(tooltip, data)
    if not anyActive(ITEM_TOOLTIP_FEATURES) then return end
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
    if F:Active("bindType") then
        local BIND = { [1] = "Binds when picked up", [2] = "Binds when equipped",
            [3] = "Binds when used", [4] = "Quest item", [5] = "Binds to account" }
        local bind = info[14]
        if F:Plain(bind) and type(bind) == "number" and BIND[bind] then
            add(tooltip, record, "bindType", "Binding: " .. BIND[bind])
        end
    end
    if F:Active("upgradeHint") and type(equip) == "string" then
        local hoveredLevel = C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
        if type(hoveredLevel) == "number" and hoveredLevel > 0 then
            local delta = upgradeComparison(link, equip, hoveredLevel)
            if delta ~= nil then
                if delta > 0 then
                    add(tooltip, record, "upgradeHint", "Upgrade: +" .. delta .. " item levels")
                elseif delta < 0 then
                    if F:GetOption("upgradeHint", "showDowngrades") ~= false then
                        add(tooltip, record, "upgradeHint", "Downgrade: " .. delta .. " item levels")
                    end
                else
                    add(tooltip, record, "upgradeHint", "Same item level as equipped")
                end
            end
        end
    end
    local name = tooltip.GetName and tooltip:GetName() or ""
    local detailLevel = C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
    if F:Active("flyoutItemLevel") and name ~= "GameTooltip" then
        if F:Plain(detailLevel) and type(detailLevel) == "number" and detailLevel > 0 then
            local equipped = type(equip) == "string" and bestEquippedLevel(equip)
            local text = "Item Level: " .. detailLevel
            if equipped then
                local delta = detailLevel - equipped
                text = text .. " (equipped " .. equipped .. (delta == 0 and "" or
                    (delta > 0 and ", +" .. delta or ", " .. delta)) .. ")"
            end
            add(tooltip, record, "flyout", text)
        end
    end
    tooltipExtras(tooltip, record, link)
    tooltipExtras(tooltip, record, link)
    if F:Active("missingEnchant") and type(equip) == "string" and ENCHANTABLE[equip] then
        local onCharacter = isEquipped(link, equip)
        local fields = linkFields(link)
        if onCharacter and fields then
            local enchant = tonumber(fields[3] or "0") or 0
            if enchant == 0 then add(tooltip, record, "missingEnchant", "Missing enchant") end
        end
    end
    if F:Active("missingGems") or F:Active("socketInfo") then
        local fields = linkFields(link)
        local total, empty = socketCount(link)
        local onCharacter = isEquipped(link, equip)
        local filled = 0
        if fields then
            for index = 4, 7 do
                local gem = tonumber(fields[index] or "0") or 0
                if gem ~= 0 then filled = filled + 1 end
            end
        end
        if total and total > 0 then
            if onCharacter and F:Active("missingGems") and filled < total then
                add(tooltip, record, "missingGems", "Empty socket: " .. (total - filled) .. " of " .. total)
            end
            if F:Active("socketInfo") then
                add(tooltip, record, "socketInfo", "Sockets: " .. filled .. " of " .. total .. " filled")
            end
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

local classBorderSaved = {}

local function restoreClassBorder(tooltip)
    local saved = classBorderSaved[tooltip]
    if not saved or not tooltip.SetBackdropBorderColor then return end
    tooltip:SetBackdropBorderColor(saved[1] or 0, saved[2] or 0, saved[3] or 0, saved[4] or 1)
    classBorderSaved[tooltip] = nil
end


-- Target cast information comes from the client's own cast APIs. Secrets are checked
-- first so a hidden cast simply produces no line instead of an error.
function F:TargetCastLine(unit)
    if type(unit) ~= "string" then return nil end
    if C_Secrets and C_Secrets.ShouldUnitSpellCastBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldUnitSpellCastBeSecret, unit)
        if ok and secret == true then return nil end
    end
    local name, _, _, startTime, endTime, _, _, notInterruptible
    if UnitCastingInfo then
        local ok, a, b, c, d, e, f, g, h = pcall(UnitCastingInfo, unit)
        if ok then name, _, _, startTime, endTime, _, _, notInterruptible = a, b, c, d, e, f, g, h end
    end
    if not name and UnitChannelInfo then
        local ok, a, b, c, d, e = pcall(UnitChannelInfo, unit)
        if ok then name, _, _, startTime, endTime = a, b, c, d, e end
    end
    if type(name) ~= "string" or name == "" then return nil end
    local text = "Casting: " .. name
    if F:GetOption("targetCastInfo", "showRemaining") ~= false
        and type(startTime) == "number" and type(endTime) == "number" then
        local now = GetTime and GetTime() or 0
        local remaining = (endTime - now) / 1000
        if remaining > 0 and remaining < 60 then text = text .. string.format(" (%.1f s left)", remaining) end
    end
    if notInterruptible == true then text = text .. ", cannot be interrupted" end
    return text
end

local function unitTooltip(tooltip, data)
    if not anyActive(UNIT_TOOLTIP_FEATURES) or InCombatLockdown() then return end
    if not tooltip or not tooltip.GetUnit or type(data) ~= "table" or not F:Plain(data) then return end
    local _, unit = tooltip:GetUnit()
    if not F:Plain(unit) or type(unit) ~= "string" then return end
    prepare(tooltip)
    local record = recordFor(tooltip, "unit", unit)
    if F:Active("npcID") and UnitGUID then
        local guid = UnitGUID(unit)
        if F:Plain(guid) and type(guid) == "string" then
            -- Creature-0-<server>-<instance>-<zone>-<npcID>-<spawn>
            local npcID = guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")
                or guid:match("^Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)")
            if npcID then add(tooltip, record, "npcID", "NPC ID: " .. npcID) end
        end
    end
    if F:Active("unitHealth") and UnitHealth and UnitHealthMax then
        local health, maximum = UnitHealth(unit), UnitHealthMax(unit)
        if F:Plain(health) and F:Plain(maximum) and type(health) == "number" and type(maximum) == "number"
            and maximum > 0 and health >= 0 then
            local percent = math.floor(health / maximum * 100 + 0.5)
            add(tooltip, record, "unitHealth", "Health: " .. health .. " / " .. maximum .. " (" .. percent .. "%)")
        end
    end
    if F:Active("targetCastInfo") then
        local castText = F:TargetCastLine(unit)
        if castText then add(tooltip, record, "targetCastInfo", castText) end
    end
    if F:Active("tooltipClassColor") and UnitClass and tooltip.SetBackdropBorderColor then
        local _, classFile = UnitClass(unit)
        local color = type(classFile) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        if type(color) == "table" then
            if classBorderSaved[tooltip] and tooltip.fsClassUnit ~= classFile then restoreClassBorder(tooltip) end
            tooltip.fsClassUnit = classFile
            if not classBorderSaved[tooltip] and tooltip.GetBackdropBorderColor then
                local r, g, b, a = tooltip:GetBackdropBorderColor()
                classBorderSaved[tooltip] = { r, g, b, a }
            end
            tooltip:SetBackdropBorderColor(color.r or 1, color.g or 1, color.b or 1, 1)
        end
    end
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

local function installUnit()
    if installed[Enum.TooltipDataType.Unit] then return end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
        safe(unitTooltip, tooltip, data, UNIT_TOOLTIP_FEATURES)
    end)
    installed[Enum.TooltipDataType.Unit] = true
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

local function itemEnable() install(Enum.TooltipDataType.Item, itemTooltip, ITEM_TOOLTIP_FEATURES) end
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

F:Register("targetCastInfo", {
    title = "Target cast information",
    category = "Tooltips",
    description = "Adds the spell a unit is casting, the time left and whether it can be interrupted to that unit's tooltip. The client's cast APIs are used and a cast the client hides produces no line.",
    disableText = "Removes the cast line from unit tooltips.",
    conflicts = { "TinyTooltip", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "showRemaining", type = "boolean", title = "Show the time left", default = true,
          description = "Adds the remaining cast time in seconds when the client reports the cast timestamps." },
    },
    available = function() return UnitCastingInfo ~= nil end,
    enable = installUnit,
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

F:Register("upgradeHint", {
    title = "Item level comparison in tooltips",
    category = "Tooltips",
    description = "Compares a hovered equippable item with what you are wearing in that slot and states the difference in item levels. It only reads equipment; nothing is equipped, swapped or sold. Rings, trinkets and two-hand weapons compare against the best matching slot.",
    conflicts = { "Pawn", "SimpleItemLevel", "EnhanceQoL", "TinyInspect", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    disableText = "Stops adding the comparison line to new tooltips. Re-hover to rebuild the current tooltip.",
    options = {
        { key = "showDowngrades", type = "boolean", title = "Show downgrades", default = true,
          description = "Also states when the hovered item is worse than the equipped one. Turn this off to see only upgrades and equal item levels." },
    },
    enable = itemEnable,
    available = function()
        return tooltipAvailable() and Enum.TooltipDataType.Item and C_Item
            and C_Item.GetItemInfo and C_Item.GetDetailedItemLevelInfo and GetInventoryItemLink ~= nil
    end,
})

F:Register("repToken", {
    title = "Reputation token details",
    category = "Tooltips",
    description = "Adds the faction and amount to reputation token tooltips, read from the client's own item tooltip text through C_TooltipInfo. Tokens whose text the client hides are left alone.",
    disableText = "Removes the reputation line from item tooltips.",
    conflicts = { "TinyTooltip", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "showAmount", type = "boolean", title = "Show the reputation amount", default = true,
          description = "Adds the numeric amount the client reports, for example (+350). Turn off to show only the faction name." },
    },
    available = function() return C_TooltipInfo ~= nil and C_TooltipInfo.GetHyperlink ~= nil end,
    enable = itemEnable,
})

F:Register("questItem", {
    title = "Quest-starting item details",
    category = "Tooltips",
    description = "Marks items that begin a quest and shows the quest name when the client's tooltip text includes it. Useful to spot quest starters before selling a bag.",
    disableText = "Removes the quest line from item tooltips.",
    conflicts = { "TinyTooltip", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "showName", type = "boolean", title = "Show the quest name", default = true,
          description = "Adds the quest name when the client's tooltip text contains it. Only the text the client already renders is used." },
    },
    available = function() return C_TooltipInfo ~= nil and C_TooltipInfo.GetHyperlink ~= nil end,
    enable = itemEnable,
})

F:Register("bindType", {
    title = "Binding type in tooltips",
    category = "Tooltips",
    description = "Adds how an item binds, such as binds when equipped or binds when picked up, outside combat. It reads the client's item data and never changes the item.",
    conflicts = common,
    disableText = "Stops adding the binding line to new tooltips. Re-hover to rebuild the current tooltip.",
    enable = itemEnable,
    available = itemAvailable,
})

local BORDER_COLORS = {
    gold = { 1, 0.82, 0.22 }, blue = { 0.3, 0.6, 1 }, green = { 0.35, 0.85, 0.4 }, red = { 0.9, 0.3, 0.25 },
}
local borderSaved, borderHooked = {}, {}
local function applyTooltipBorderOn(tooltip)
    if not F:Active("tooltipBorder") or InCombatLockdown() then return end
    if not tooltip or not tooltip.SetBackdropBorderColor then return end
    local choice = F:GetOption("tooltipBorder", "color") or "gold"
    local color = BORDER_COLORS[choice] or BORDER_COLORS.gold
    if type(borderSaved[tooltip]) ~= "table" then
        borderSaved[tooltip] = {
            r = tooltip.GetBackdropBorderColor and select(1, tooltip:GetBackdropBorderColor()) or nil,
        }
    end
    tooltip:SetBackdropBorderColor(color[1], color[2], color[3], 1)
end
local function applyTooltipBorder()
    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }) do
        local frame = _G[name]
        if frame then
            if not borderHooked[frame] and frame.HookScript then
                frame:HookScript("OnShow", applyTooltipBorderOn)
                borderHooked[frame] = true
            end
            applyTooltipBorderOn(frame)
        end
    end
end
F:Register("tooltipBorder", {
    title = "Tooltip border colour",
    category = "Tooltips",
    description = "Colours the border of the game, item and shopping tooltips so they stand out against the background. It does not change tooltip text, content or size.",
    disableText = "Restores the border colour each tooltip had before ForeverSuite changed it.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "TinyTooltip", "TipTac", "EnhanceQoL" },
    options = {
        { key = "color", type = "choice", title = "Border colour", default = "gold",
          choices = { { value = "gold", label = "Gold" }, { value = "blue", label = "Blue" },
              { value = "green", label = "Green" }, { value = "red", label = "Red" } },
          description = "Border colour used while the feature is on. Gold matches the ForeverSuite palette." },
    },
    available = function() return GameTooltip ~= nil and GameTooltip.SetBackdropBorderColor ~= nil end,
    enable = applyTooltipBorder,
    refresh = applyTooltipBorder,
    disable = function()
        for frame, saved in pairs(borderSaved) do
            if frame.SetBackdropBorderColor and type(saved.r) == "number" then
                frame:SetBackdropBorderColor(saved.r, saved.g or 0, saved.b or 0, 1)
            end
            borderSaved[frame] = nil
        end
    end,
})

local function hideCombatTooltips()
    if not F:Active("tooltipHideCombat") then return end
    if not InCombatLockdown() then return end
    for _, frame in ipairs(_G.GameTooltip and { GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 } or {}) do
        if frame and frame.Hide then frame:Hide() end
    end
end
F:Register("tooltipHideCombat", {
    title = "Hide tooltips in combat",
    category = "Tooltips",
    description = "Hides any open game tooltip when combat starts and keeps tooltips from staying on screen during a fight. It does not block your own hover after combat ends.",
    disableText = "Stops hiding tooltips. Nothing else is restored because no tooltip setting is changed.",
    conflicts = common,
    available = function() return GameTooltip ~= nil and GameTooltip.Hide ~= nil end,
    enable = function()
        F:Listen("tooltipHideCombat", "PLAYER_REGEN_DISABLED", hideCombatTooltips)
    end,
})

F:Register("flyoutItemLevel", {
    title = "Item levels in flyout tooltips",
    category = "Tooltips",
    description = "Shows the item level and the comparison with what you are wearing in the smaller shopping and comparison tooltips, not only the main game tooltip. It only reads equipment data.",
    disableText = "Stops adding item levels to flyout tooltips. Re-hover to rebuild the tooltip.",
    conflicts = { "SimpleItemLevel", "TinyInspect", "EnhanceQoL", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    enable = itemEnable,
    available = itemAvailable,
})

F:Register("missingEnchant", {
    title = "Missing enchant indicator",
    category = "Tooltips",
    description = "Marks an equipped item in a slot that can be enchanted when it carries no enchant, so a forgotten enchant is easy to spot. It reads the item link; nothing is bought, applied or changed.",
    disableText = "Stops marking items without enchants. Re-hover to rebuild the tooltip.",
    conflicts = { "Pawn", "TinyInspect", "EnhanceQoL" },
    enable = itemEnable,
    available = itemAvailable,
})

F:Register("missingGems", {
    title = "Missing gem indicator",
    category = "Tooltips",
    description = "Marks an equipped item that has an empty socket, for example because a gem was never added or was replaced. Socket counts come from the client's own item stats; if the client does not report them the line is skipped.",
    disableText = "Stops marking empty sockets. Re-hover to rebuild the tooltip.",
    conflicts = { "Pawn", "TinyInspect", "EnhanceQoL" },
    enable = itemEnable,
    available = itemAvailable,
})

F:Register("socketInfo", {
    title = "Socket inspection",
    category = "Tooltips",
    description = "Adds a socket summary to item tooltips and provides /fs sockets, which checks every equipped item and lists the ones with empty sockets. Inspection only: no gems are inserted, removed or bought.",
    disableText = "Stops adding socket summaries and disables /fs sockets.",
    conflicts = { "TinyInspect", "EnhanceQoL" },
    enable = itemEnable,
    available = itemAvailable,
})

F:Register("tooltipClassColor", {
    title = "Class-coloured unit tooltips",
    category = "Tooltips",
    description = "Colours the border of a unit tooltip with that unit's class colour, so a player's class is readable at a glance. Only the border is coloured; text and content are untouched.",
    disableText = "Restores the border colour each tooltip had before the feature coloured it.",
    conflicts = { "TipTac", "TinyTooltip", "EnhanceQoL", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function()
        return tooltipAvailable() and Enum.TooltipDataType.Unit ~= nil and UnitClass ~= nil
    end,
    enable = installUnit,
    disable = function()
        for tooltip in pairs(classBorderSaved) do restoreClassBorder(tooltip) end
    end,
})

F:Register("unitHealth", {
    title = "Health in unit tooltips",
    category = "Tooltips",
    description = "Adds current health, maximum health and the percentage to unit tooltips. It only reads the values the client already tracks; no unit frame is replaced.",
    disableText = "Stops adding health lines. Re-hover to rebuild the tooltip.",
    conflicts = { "TipTac", "TinyTooltip", "EnhanceQoL" },
    available = function()
        return tooltipAvailable() and Enum.TooltipDataType.Unit ~= nil and UnitHealth ~= nil and UnitHealthMax ~= nil
    end,
    enable = installUnit,
})

local ANCHORS = {
    default = nil,
    topleft = { "TOPLEFT", "TOPLEFT", 12, -12 },
    topright = { "TOPRIGHT", "TOPRIGHT", -12, -12 },
    bottomleft = { "BOTTOMLEFT", "BOTTOMLEFT", 12, 12 },
    bottomright = { "BOTTOMRIGHT", "BOTTOMRIGHT", -12, 12 },
}

local function applyTooltipAnchor()
    if InCombatLockdown() then return end
    local frame = _G.GameTooltip
    if not frame then return end
    if not frame.fsAnchorHooked and frame.HookScript then
        frame.fsAnchorHooked = true
        frame:HookScript("OnShow", function(self)
            if not F:Active("tooltipAnchor") then return end
            local entry = ANCHORS[F:GetOption("tooltipAnchor", "position") or "default"]
            if not entry then return end
            self:ClearAllPoints()
            self:SetPoint(entry[1], UIParent, entry[2], entry[3], entry[4])
        end)
    end
    if not F:Active("tooltipAnchor") then return end
    local entry = ANCHORS[F:GetOption("tooltipAnchor", "position") or "default"]
    if entry and frame:IsShown() then
        frame:ClearAllPoints()
        frame:SetPoint(entry[1], UIParent, entry[2], entry[3], entry[4])
    elseif not entry and frame.ClearAllPoints then
        frame:ClearAllPoints()
    end
end

F:Register("tooltipAnchor", {
    title = "Tooltip anchor position",
    category = "Tooltips",
    description = "Places the game tooltip in a fixed screen corner instead of following the mouse, which keeps a long item tooltip from covering the fight. Item and shopping tooltips keep their normal place.",
    disableText = "Stops forcing a corner. The tooltip returns to the client's own mouse position the next time it is shown.",
    conflicts = { "TipTac", "TinyTooltip", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "position", type = "choice", title = "Tooltip corner", default = "default",
          choices = { { value = "default", label = "Follow the mouse (client default)" },
              { value = "topleft", label = "Top left" }, { value = "topright", label = "Top right" },
              { value = "bottomleft", label = "Bottom left" }, { value = "bottomright", label = "Bottom right" } },
          description = "Corner used for the main game tooltip. The client still chooses the anchor it uses for its own layout when this is set to the default." },
    },
    available = function() return GameTooltip ~= nil and GameTooltip.HookScript ~= nil end,
    enable = applyTooltipAnchor,
    refresh = applyTooltipAnchor,
    disable = applyTooltipAnchor,
})

function F:InspectSockets()
    local rows = {}
    if type(GetItemStats) ~= "function" then return rows end
    for slot = 1, 19 do
        local link = equippedLink(slot)
        if link then
            local total, empty = socketCount(link)
            if total and empty > 0 then
                rows[#rows + 1] = { slot = slot, link = link, total = total, empty = empty }
            end
        end
    end
    return rows
end
