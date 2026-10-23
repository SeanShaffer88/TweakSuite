-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Gear groups, fishing helpers, consumable shortcuts, reagent bag protection and minimap buttons.
local _, F = ...
-- Older client functions: the client's own global when present, else a private shim (Compat.lua).
local GetContainerNumSlots = F.Compat("GetContainerNumSlots")
local GetContainerItemLink = F.Compat("GetContainerItemLink")
local UseContainerItem = F.Compat("UseContainerItem")
local UnitAura = F.Compat("UnitAura")
local common = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "AdiBags", "Bagnon" }
local QUALITY_NAME = { [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic" }

local function itemInfo(link)
    if not (C_Item and C_Item.GetItemInfo) or type(link) ~= "string" then return nil end
    local values = { C_Item.GetItemInfo(link) }
    if values[1] == nil then return nil end
    return { name = values[1], quality = values[3], itemLevel = values[4], subType = values[7],
        equipLoc = values[9], classID = values[12] }
end

local function equipped(slot)
    if not GetInventoryItemLink then return nil end
    local ok, link = pcall(GetInventoryItemLink, "player", slot)
    if ok and type(link) == "string" then return link end
    return nil
end

local function itemID(link)
    if type(link) ~= "string" then return nil end
    local id = link:match("item:(%d+)")
    return id and tonumber(id) or nil
end

local function bagLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then return C_Container.GetContainerItemLink(bag, slot) end
    if GetContainerItemLink then return GetContainerItemLink(bag, slot) end
end

local function bagSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
    if GetContainerNumSlots then return GetContainerNumSlots(bag) or 0 end
    return 0
end

local function useBagItem(bag, slot)
    if C_Container and C_Container.UseContainerItem then return C_Container.UseContainerItem(bag, slot) end
    if UseContainerItem then return UseContainerItem(bag, slot) end
end

-- ---------------------------------------------------------------------------
-- Gear groups

function F:GearGroups()
    if not self.db then return {} end
    if type(self.db.gearGroups) ~= "table" then self.db.gearGroups = {} end
    return self.db.gearGroups
end

function F:GearGroupNames()
    local names = {}
    for name in pairs(self:GearGroups()) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function F:GearAdd(group, item)
    group = tostring(group or ""):match("^%s*(.-)%s*$")
    if group == "" or #group > 20 then return false, "group name must be 1-20 characters" end
    local id = tonumber(tostring(item or ""):match("item:(%d+)") or item)
    if not id or id <= 0 then return false, "item ID must be a positive number" end
    local groups = self:GearGroups()
    local list = groups[group]
    if type(list) ~= "table" then
        if #self:GearGroupNames() >= 10 then return false, "at most 10 gear groups" end
        list = {}
        groups[group] = list
    end
    for _, existing in ipairs(list) do
        if existing == id then return false, "that item is already in the group" end
    end
    if #list >= 40 then return false, "at most 40 items per group" end
    list[#list + 1] = id
    return true, id
end

function F:GearRemove(group, item)
    local list = self:GearGroups()[group]
    if type(list) ~= "table" then return false, "unknown group" end
    local id = tonumber(tostring(item or ""):match("item:(%d+)") or item)
    if not id then return false, "item ID required" end
    for index = #list, 1, -1 do
        if list[index] == id then table.remove(list, index); return true end
    end
    return false, "that item is not in the group"
end

function F:GearGroupContains(group, link)
    local list = self:GearGroups()[group]
    local id = itemID(link)
    if type(list) ~= "table" or not id then return false end
    for _, existing in ipairs(list) do
        if existing == id then return true end
    end
    return false
end

function F:GearGroupReport(group)
    local groups = self:GearGroups()
    local names = group and { group } or self:GearGroupNames()
    local lines = {}
    for _, name in ipairs(names) do
        local list = groups[name]
        if type(list) == "table" then
            local parts = {}
            for _, id in ipairs(list) do
                local link = "item:" .. id
                local info = itemInfo(link)
                parts[#parts + 1] = info and info.name or tostring(id)
            end
            lines[#lines + 1] = name .. ": " .. (#parts > 0 and table.concat(parts, ", ") or "empty")
        end
    end
    return lines
end

F:Register("gearGroups", {
    title = "Gear groups",
    category = "Inventory",
    description = "Keeps named lists of item IDs such as a tanking set or a resistance set, and marks those items wherever they are in your bags. /ts gear add <group> <itemID>, remove, list and show manage the lists. It never equips, sells or moves an item.",
    disableText = "Stops the gear group commands and removes the bag marks. Saved groups are kept.",
    conflicts = common,
    available = function() return C_Item ~= nil and C_Item.GetItemInfo ~= nil end,
    enable = function() end,
})

local gearMarks = {}
local function clearGearMarks()
    for button in pairs(gearMarks) do
        if button.SetBackdropBorderColor then pcall(button.SetBackdropBorderColor, button, 0, 0, 0, 1) end
    end
    gearMarks = {}
end

function F:MarkGearInBags(group)
    clearGearMarks()
    if not self:Active("gearBagMarks") then return 0 end
    local count = 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = bagSlots(bag)
        for slot = 1, slots do
            local link = bagLink(bag, slot)
            if type(link) == "string" and self:GearGroupContains(group, link) then
                local button = _G["ContainerFrame" .. (bag + 1) .. "Item" .. slot]
                if button and button.SetBackdropBorderColor then
                    button:SetBackdropBorderColor(1, 0.82, 0.22, 1)
                    gearMarks[button] = true
                    count = count + 1
                end
            end
        end
    end
    return count
end

F:Register("gearBagMarks", {
    title = "Gear group bag markers",
    category = "Inventory",
    description = "Draws a gold border on bag slots whose item belongs to the selected gear group, so a set piece is easy to find. /ts gear show <group> marks the bags and /ts gear show clear removes the marks.",
    disableText = "Removes every gear group mark from the bags. Items themselves are untouched.",
    conflicts = common,
    available = function() return C_Item ~= nil and C_Item.GetItemInfo ~= nil end,
    options = {
        { key = "autoRefresh", type = "boolean", title = "Refresh when bags change", default = true,
          description = "Re-applies the marks after items move, so a marked item stays marked without running the command again." },
    },
    enable = function()
        if F:GetOption("gearBagMarks", "autoRefresh") then
            F:Listen("gearBagMarks", "BAG_UPDATE_DELAYED", function()
                if F.markedGearGroup then F:MarkGearInBags(F.markedGearGroup) end
            end)
        end
    end,
    disable = clearGearMarks,
})

-- ---------------------------------------------------------------------------
-- Fishing

local FISHING_POLE = { INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPON = true,
    INVTYPE_WEAPONOFFHAND = true, INVTYPE_RANGEDRIGHT = true }
local savedWeapons, lastCast = {}, 0

local function isFishingPole(link)
    local info = itemInfo(link)
    if not info then return false end
    if type(info.subType) == "string" and info.subType:lower():find("fishing", 1, true) then return true end
    if type(info.name) == "string" and info.name:lower():find("fishing pole", 1, true) then return true end
    return false
end

function F:SaveFishingSet()
    local main, off = equipped(16), equipped(17)
    if not main and not off then return false, "no weapons equipped to remember" end
    savedWeapons = { main = main, off = off }
    return true
end

function F:RestoreFishingSet()
    if not savedWeapons.main and not savedWeapons.off then return false, "no saved weapons" end
    if not EquipItemByName then return false, "the client cannot equip by name" end
    local restored = 0
    for _, link in ipairs({ savedWeapons.main, savedWeapons.off }) do
        if type(link) == "string" then
            local ok = pcall(EquipItemByName, link)
            if ok then restored = restored + 1 end
        end
    end
    return restored > 0, restored
end

local function trackFishing()
    if not F:Active("fishingSet") then return end
    local main = equipped(16)
    if main and isFishingPole(main) then F:SaveFishingSet() end
end

F:Register("fishingSet", {
    title = "Fishing gear restoration",
    category = "Inventory",
    description = "Remembers the weapons you were wearing before you equipped a fishing pole and puts them back with /ts fish restore. The set is remembered automatically when a pole is equipped, and nothing is equipped unless you ask for it.",
    disableText = "Stops remembering the previous weapons. Weapons already restored stay equipped.",
    conflicts = { "FishingBuddy", "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL" },
    available = function() return EquipItemByName ~= nil and GetInventoryItemLink ~= nil end,
    enable = function()
        F:Listen("fishingSet", "PLAYER_EQUIPMENT_CHANGED", trackFishing)
        trackFishing()
    end,
})

local function castFishing()
    if not F:Active("fishingSet") and not F:Active("fishingLure") then return false end
    if InCombatLockdown() then return false, "cannot fish during combat" end
    local now = GetTime and GetTime() or 0
    if F:GetOption("fishingSet", "doubleClickGuard") ~= false and now - lastCast < 1 then
        return false, "ignored a second cast within one second"
    end
    lastCast = now
    if CastSpellByName then
        local ok = pcall(CastSpellByName, "Fishing")
        if ok then return true end
    end
    return false, "this client cannot cast Fishing by name"
end

function F:Fish()
    return castFishing()
end

F:Register("fishingCast", {
    title = "Fishing cast shortcut",
    category = "Inventory",
    description = "Casts Fishing with /ts fish. A second cast within one second is ignored, so double-clicking the command cannot cancel the cast it just started. It never moves or sells anything.",
    disableText = "Stops the /ts fish shortcut. Fishing itself is unchanged.",
    conflicts = { "FishingBuddy", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "doubleClickGuard", type = "boolean", title = "Ignore a double click", default = true,
          description = "Ignores a second /ts fish within one second, which is what a double click produces. Turn it off if you really want two casts back to back." },
    },
    available = function() return CastSpellByName ~= nil end,
    enable = function() end,
})

function F:LureList()
    if not self.db then return {} end
    if type(self.db.lures) ~= "table" then self.db.lures = {} end
    return self.db.lures
end

function F:SetLure(name, item)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    local id = tonumber(tostring(item or ""):match("item:(%d+)") or item)
    if name == "" or #name > 30 then return false, "lure name must be 1-30 characters" end
    if not id or id <= 0 then return false, "item ID must be a positive number" end
    local list = self:LureList()
    if #list >= 10 then return false, "at most 10 saved lures" end
    for index = #list, 1, -1 do
        if list[index].name:lower() == name:lower() then table.remove(list, index) end
    end
    list[#list + 1] = { name = name, id = id }
    return true, name, id
end

function F:ApplyLure(name)
    local chosen
    for _, entry in ipairs(self:LureList()) do
        if not name or entry.name:lower() == tostring(name):lower() then chosen = entry; break end
    end
    if not chosen then return false, "no saved lure with that name" end
    local main = equipped(16)
    if main and not isFishingPole(main) then return false, "equip a fishing pole first" end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = bagSlots(bag)
        for slot = 1, slots do
            local link = bagLink(bag, slot)
            if itemID(link) == chosen.id then
                useBagItem(bag, slot)
                return true, chosen.name
            end
        end
    end
    return false, "that lure is not in your bags"
end

F:Register("fishingLure", {
    title = "Fishing lure selection",
    category = "Inventory",
    description = "Saves lure item IDs under a name and applies one with /ts lure <name> (or /ts lure to use the first saved lure). /ts lure add <name> <itemID>, remove and list manage the list. It uses one lure from your bags and never buys or creates one.",
    disableText = "Stops the lure commands. Saved lures are kept.",
    conflicts = { "FishingBuddy", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "remind", type = "boolean", title = "Remind me when no lure is active", default = true,
          description = "Prints a reminder with /ts fish when no aura with Lure in its name is active. The check is a name match and can miss localized or unusual lures." },
    },
    available = function() return UseContainerItem ~= nil or (C_Container and C_Container.UseContainerItem) end,
    enable = function() end,
})

function F:HasLure()
    if not UnitAura then return nil end
    for index = 1, 40 do
        local name = UnitAura("player", index)
        if type(name) ~= "string" then break end
        if name:lower():find("lure", 1, true) then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Consumables

local function findConsumable(wantedSpell, wantedWords)
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = bagSlots(bag)
        for slot = 1, slots do
            local link = bagLink(bag, slot)
            local info = itemInfo(link)
            if info and info.classID == 0 then
                local spellName
                if C_Item and C_Item.GetItemSpell then
                    local ok, name = pcall(C_Item.GetItemSpell, link)
                    if ok and type(name) == "string" then spellName = name end
                end
                if spellName and spellName:lower() == wantedSpell then return bag, slot, info.name end
                if type(info.name) == "string" then
                    local lower = info.name:lower()
                    for _, word in ipairs(wantedWords) do
                        if lower:find(word, 1, true) then return bag, slot, info.name end
                    end
                end
            end
        end
    end
end

function F:UseFoodOrDrink(kind)
    if InCombatLockdown() then return false, "cannot eat or drink during combat" end
    local words = kind == "drink" and { "water", "juice", "milk", "tea", "coffee", "drink" }
        or { "bread", "meat", "fish", "food", "cheese", "fruit" }
    local bag, slot, name = findConsumable(kind, words)
    if not bag then return false, "no " .. kind .. " found in your bags" end
    useBagItem(bag, slot)
    return true, name
end

F:Register("foodDrink", {
    title = "Eat and drink shortcuts",
    category = "Inventory",
    description = "Uses the first food or drink in your bags with /ts eat and /ts drink. It prefers items the client labels as food or drink and falls back to common English item words, so a localized client may not find every item. Nothing is bought.",
    disableText = "Stops the eat and drink shortcuts. Bags are unchanged.",
    conflicts = common,
    available = function() return UseContainerItem ~= nil or (C_Container and C_Container.UseContainerItem) end,
    enable = function() end,
})

F:Register("petFood", {
    title = "Pet food highlights",
    category = "Inventory",
    description = "Lists bag items that look like pet food with /ts petfood, using the client consumable type and common English food words. It is a listing only: no item is fed, moved or sold.",
    disableText = "Stops the pet food listing.",
    conflicts = common,
    available = function() return C_Item ~= nil and C_Item.GetItemInfo ~= nil end,
    enable = function() end,
})

function F:PetFoodList()
    local words = { "meat", "fish", "fruit", "fungus", "bread", "cheese" }
    local rows = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = bagSlots(bag)
        for slot = 1, slots do
            local link = bagLink(bag, slot)
            local info = itemInfo(link)
            if info and info.classID == 0 and type(info.name) == "string" then
                local lower = info.name:lower()
                for _, word in ipairs(words) do
                    if lower:find(word, 1, true) then
                        rows[#rows + 1] = { name = info.name, bag = bag, slot = slot }
                        break
                    end
                end
            end
        end
    end
    return rows
end

-- ---------------------------------------------------------------------------
-- Reagent bag and bag filters

F:Register("reagentBag", {
    title = "Protect the reagent bag",
    category = "Automation",
    description = "Excludes one bag from the automatic selling rules, so reagents stored in a dedicated bag are never vendored even when they match a quality rule. /ts reagentbag <0-4> chooses the bag and /ts reagentbag off disables the exclusion.",
    disableText = "Stops excluding the reagent bag. The bag choice is kept and applies again when the feature is turned back on.",
    conflicts = common,
    options = {
        { key = "bag", type = "number", title = "Reagent bag number", default = 4, min = 0, max = 4, step = 1,
          description = "Bag number 0 to 4 as the client counts them. Bag 0 is the backpack; 4 is the last purchased bag slot on most clients." },
    },
    available = function() return C_Item ~= nil and C_Item.GetItemInfo ~= nil end,
    enable = function() end,
})

F:Register("bagFilters", {
    title = "Bag search filters",
    category = "Inventory",
    description = "Adds filters to the bag search: #quest, #gear, #reagent, #consumable, #junk and #rare, for example /ts bag #quest. Filters can be combined with text, so /ts bag #gear helm lists only helms from your gear groups. It still only reads containers.",
    disableText = "Stops the filter keywords. Plain text search keeps working.",
    conflicts = common,
    available = function()
        return ((C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink) ~= nil
    end,
    enable = function() end,
})

function F:BagFilterMatch(link, info, filters)
    for _, filter in ipairs(filters) do
        if filter == "quest" then
            if not info or info.classID ~= 12 then return false end
        elseif filter == "reagent" then
            if not info or info.classID ~= 7 then return false end
        elseif filter == "consumable" then
            if not info or info.classID ~= 0 then return false end
        elseif filter == "junk" then
            if not info or (info.quality or 0) > 0 then return false end
        elseif filter == "rare" then
            if not info or (info.quality or 0) < 3 then return false end
        elseif filter == "gear" then
            local matched = false
            for _, group in ipairs(F:GearGroupNames()) do
                if F:GearGroupContains(group, link) then matched = true; break end
            end
            if not matched then return false end
        else
            return false
        end
    end
    return true
end

function F:ParseBagSearch(text)
    local filters, words = {}, {}
    for token in tostring(text or ""):gmatch("%S+") do
        local filter = token:match("^#(%a+)$")
        if filter then filters[#filters + 1] = filter:lower() else words[#words + 1] = token:lower() end
    end
    return filters, table.concat(words, " ")
end

-- ---------------------------------------------------------------------------
-- Minimap buttons

local collected = {}
function F:MinimapButtons()
    local rows = {}
    local minimap = _G.Minimap
    if not minimap or not minimap.GetChildren then return rows end
    local children = { minimap:GetChildren() }
    for _, button in ipairs(children) do
        -- TweakSuite's own button has its own show/hide setting, so the collection leaves it alone.
        if button and button ~= _G.MiniMapTracking and button ~= _G.MiniMapWorldMapButton
            and button ~= _G.TweakSuiteMinimapButton then
            local kind = button.GetObjectType and button:GetObjectType() or nil
            local name = button.GetName and button:GetName() or nil
            if kind == "Button" or (not kind and name) then
                rows[#rows + 1] = button
            end
        end
    end
    return rows
end

function F:CollectMinimapButtons()
    local rows = self:MinimapButtons()
    local count = 0
    for _, button in ipairs(rows) do
        if button.Hide then pcall(button.Hide, button); collected[#collected + 1] = button; count = count + 1 end
    end
    return count
end

function F:RestoreMinimapButtons()
    local count = 0
    for _, button in ipairs(collected) do
        if button.Show then pcall(button.Show, button); count = count + 1 end
    end
    collected = {}
    return count
end

F:Register("minimapButtons", {
    title = "Minimap button collection",
    category = "Interface",
    description = "Hides the addon buttons that sit around the minimap with /ts minimap collect and brings them back with /ts minimap restore. Buttons are only hidden; their addons keep running and nothing is unloaded.",
    disableText = "Shows every button that was collected again, so the minimap looks as it did before.",
    conflicts = { "MinimapButtonBag", "MBF", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function() return _G.Minimap ~= nil and _G.Minimap.GetChildren ~= nil end,
    enable = function() end,
    disable = function() F:RestoreMinimapButtons() end,
})

-- ---------------------------------------------------------------------------
-- Trainer helper: listings, rank upgrades and capped bulk learning.

local function trainerService(index)
    if not GetTrainerServiceInfo then return nil end
    local name, rank, category, expanded = GetTrainerServiceInfo(index)
    if type(name) ~= "string" or name == "" then return nil end
    local cost = GetTrainerServiceCost and GetTrainerServiceCost(index) or nil
    return { index = index, name = name, rank = rank, category = category,
        expanded = expanded, cost = type(cost) == "number" and cost or nil }
end

function F:TrainerServices()
    local rows = {}
    if not GetNumTrainerServices then return rows end
    local count = GetNumTrainerServices()
    if type(count) ~= "number" then return rows end
    for index = 1, count do
        local service = trainerService(index)
        if service then rows[#rows + 1] = service end
    end
    return rows
end

function F:TrainerReport(mode)
    local rows = self:TrainerServices()
    if #rows == 0 then self:Print("No trainer window is open (or the client reports no services)."); return 0 end
    local shown = 0
    for _, service in ipairs(rows) do
        local available = service.category == "available"
        local upgrade = type(service.rank) == "string" and service.rank ~= "" and service.rank ~= "Rank 1"
        local include = true
        if mode == "missing" then include = available
        elseif mode == "ranks" then include = available and upgrade end
        if include then
            local text = service.name .. (type(service.rank) == "string" and (" " .. service.rank) or "")
            text = text .. (available and " - available" or (" - " .. tostring(service.category or "unknown")))
            if service.cost then text = text .. " - " .. (GetMoneyString and GetMoneyString(service.cost) or (service.cost .. "c")) end
            self:Print(text)
            shown = shown + 1
        end
    end
    if shown == 0 then self:Print("Nothing matches that trainer filter.") end
    return shown
end

function F:TrainAll(cap)
    if InCombatLockdown() then return false, "cannot train during combat" end
    if not BuyTrainerService then return false, "this client cannot buy trainer services" end
    local budget = tonumber(cap) or (self.db and self.db.repairCap) or 100000
    if budget <= 0 then return false, "the cap must be positive" end
    local spent, learned = 0, 0
    for _, service in ipairs(self:TrainerServices()) do
        if service.category == "available" and service.cost and spent + service.cost <= budget then
            local ok = pcall(BuyTrainerService, service.index)
            if ok then
                spent = spent + service.cost
                learned = learned + 1
            end
        end
    end
    return true, learned, spent
end

F:Register("trainerHelper", {
    title = "Trainer list and rank upgrades",
    category = "Character",
    description = "Lists every trainer service with its cost and marks rank upgrades, using /ts trainer, /ts trainer missing and /ts trainer ranks. It only reads the open trainer window; nothing is learned until you use /ts train.",
    disableText = "Stops the trainer listings. The trainer window itself is unchanged.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL" },
    available = function() return GetNumTrainerServices ~= nil and GetTrainerServiceInfo ~= nil end,
    enable = function() end,
})

F:Register("trainerBulk", {
    title = "Bulk trainer purchases",
    category = "Character",
    description = "Learns every available trainer service that fits inside a gold cap with /ts train [cap] and prints what was learned. It never trains during combat, never spends past the cap and never buys a service the client marks unavailable.",
    disableText = "Stops the bulk purchase command. Spells already learned stay learned.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL" },
    options = {
        { key = "cap", type = "number", title = "Spend cap", default = 10, min = 1, max = 500, step = 1, unit = " g",
          description = "Maximum gold spent by one /ts train run. The default keeps an accidental run inexpensive." },
    },
    available = function() return BuyTrainerService ~= nil and GetNumTrainerServices ~= nil end,
    enable = function() end,
})

-- ---------------------------------------------------------------------------
-- Mana regeneration timing

local lastManaSpend, lastManaValue
local function watchMana()
    if not F:Active("manaRegen") then return end
    local mana = UnitPower and UnitPower("player") or nil
    if type(mana) ~= "number" then return end
    if lastManaValue and mana < lastManaValue then lastManaSpend = GetTime and GetTime() or nil end
    lastManaValue = mana
end

function F:ManaReport()
    local mana, maximum = UnitPower and UnitPower("player") or nil, UnitPowerMax and UnitPowerMax("player") or nil
    if type(mana) ~= "number" or type(maximum) ~= "number" then return nil end
    local now = GetTime and GetTime() or 0
    local since = lastManaSpend and (now - lastManaSpend) or nil
    return { mana = mana, max = maximum, percent = maximum > 0 and mana / maximum * 100 or 0,
        sinceSpend = since, ruleActive = since ~= nil and since < 5 }
end

F:Register("manaRegen", {
    title = "Mana regeneration timing",
    category = "Character",
    description = "Tracks when you last spent mana and prints your mana, its percentage and whether the five-second regeneration rule is still running with /ts regen. It only reads power values.",
    disableText = "Stops tracking mana spending and the /ts regen report.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL" },
    available = function() return UnitPower ~= nil and UnitPowerMax ~= nil end,
    enable = function()
        F:Listen("manaRegen", "UNIT_POWER_FREQUENT", function(_, unit)
            if unit == "player" then watchMana() end
        end)
        F:Listen("manaRegen", "PLAYER_ENTERING_WORLD", function() lastManaValue = nil; watchMana() end)
        watchMana()
    end,
})
