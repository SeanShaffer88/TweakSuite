-- SPDX-License-Identifier: MIT
-- Original item-level overlay service for the character and inspect panels.
local _, F = ...
local CHARACTER_SLOTS = {
    { "CharacterHeadSlot", 1 }, { "CharacterNeckSlot", 2 }, { "CharacterShoulderSlot", 3 },
    { "CharacterShirtSlot", 4 }, { "CharacterChestSlot", 5 }, { "CharacterWaistSlot", 6 },
    { "CharacterLegsSlot", 7 }, { "CharacterFeetSlot", 8 }, { "CharacterWristSlot", 9 },
    { "CharacterHandsSlot", 10 }, { "CharacterFinger0Slot", 11 }, { "CharacterFinger1Slot", 12 },
    { "CharacterTrinket0Slot", 13 }, { "CharacterTrinket1Slot", 14 }, { "CharacterBackSlot", 15 },
    { "CharacterMainHandSlot", 16 }, { "CharacterSecondaryHandSlot", 17 },
    { "CharacterRangedSlot", 18 }, { "CharacterTabardSlot", 19 },
}
local INSPECT_SLOTS = {
    { "InspectHeadSlot", 1 }, { "InspectNeckSlot", 2 }, { "InspectShoulderSlot", 3 },
    { "InspectShirtSlot", 4 }, { "InspectChestSlot", 5 }, { "InspectWaistSlot", 6 },
    { "InspectLegsSlot", 7 }, { "InspectFeetSlot", 8 }, { "InspectWristSlot", 9 },
    { "InspectHandsSlot", 10 }, { "InspectFinger0Slot", 11 }, { "InspectFinger1Slot", 12 },
    { "InspectTrinket0Slot", 13 }, { "InspectTrinket1Slot", 14 }, { "InspectBackSlot", 15 },
    { "InspectMainHandSlot", 16 }, { "InspectSecondaryHandSlot", 17 },
    { "InspectRangedSlot", 18 }, { "InspectTabardSlot", 19 },
}
local overlayByButton = {}
local bagOverlayByButton = {}
local hooked = false
local bagHooked = false
local conflicts = { "SimpleItemLevel", "EnhanceQoL", "EnhanceQoLBags", "Leatrix_Plus",
    "Leatrix_Plus_Forever", "TinyInspect", "Pawn" }

local function positionOffset(position)
    if position == "TOPLEFT" then return 3, -3 end
    if position == "CENTER" then return 0, 0 end
    return 2, -2
end

local function hideSlots(slots)
    for _, entry in ipairs(slots) do
        local button = _G[entry[1]]
        local overlay = button and overlayByButton[button]
        if overlay then overlay:Hide() end
    end
end

local function hideBagOverlays()
    for _, overlay in pairs(bagOverlayByButton) do overlay:Hide() end
end

local function containerLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bag, slot)
    end
    if GetContainerItemLink then return GetContainerItemLink(bag, slot) end
end

local function containerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end
    if GetContainerNumSlots then return GetContainerNumSlots(bag) or 0 end
    return 0
end

local function styleBagOverlay(button)
    local overlay = bagOverlayByButton[button]
    if not overlay then
        overlay = button:CreateFontString(nil, "OVERLAY")
        overlay:SetJustifyH("RIGHT")
        overlay:SetJustifyV("BOTTOM")
        overlay:SetTextColor(1, 0.82, 0.22)
        bagOverlayByButton[button] = overlay
    end
    if STANDARD_TEXT_FONT and overlay.SetFont then
        overlay:SetFont(STANDARD_TEXT_FONT, F:GetOption("bagItemLevel", "size"), "OUTLINE")
    elseif GameFontNormalSmall then
        overlay:SetFontObject(GameFontNormalSmall)
    end
    local position = F:GetOption("bagItemLevel", "position")
    local x, y = positionOffset(position)
    overlay:ClearAllPoints()
    overlay:SetPoint(position, button, position, x, y)
    return overlay
end

local function showBagLevel(button, link)
    local level = C_Item.GetDetailedItemLevelInfo(link)
    if not F:Plain(level) or type(level) ~= "number" or level <= 0 then
        local overlay = bagOverlayByButton[button]
        if overlay then overlay:Hide() end
        return
    end
    local overlay = styleBagOverlay(button)
    overlay:SetText(tostring(level))
    overlay:Show()
end

local function clearBagButton(button)
    local overlay = bagOverlayByButton[button]
    if overlay then overlay:Hide() end
end

local function applyContainer(index, bank)
    if not F:Active("bagItemLevel") or InCombatLockdown() then return end
    local frame = _G["ContainerFrame" .. index]
    if not frame then return end
    local bag = index - 1
    if frame.GetID then
        local id = frame:GetID()
        if type(id) == "number" then bag = id end
    end
    local includeBank = F:GetOption("bagItemLevel", "includeBank") == true
    local slots = containerSlots(bag)
    for slot = 1, slots do
        local button = _G["ContainerFrame" .. index .. "Item" .. slot]
        if button then
            if bank and not includeBank then
                clearBagButton(button)
            else
                local link = containerLink(bag, slot)
                if F:Plain(link) and type(link) == "string" then
                    showBagLevel(button, link)
                else
                    clearBagButton(button)
                end
            end
        end
    end
end

local function applyBankMain()
    if not F:Active("bagItemLevel") or InCombatLockdown() then return end
    local slots = NUM_BANKGENERIC_SLOTS or 0
    local includeBank = F:GetOption("bagItemLevel", "includeBank") == true
    for slot = 1, slots do
        local button = _G["BankFrameItem" .. slot]
        if button then
            if not includeBank then
                clearBagButton(button)
            else
                local link = containerLink(-1, slot)
                if F:Plain(link) and type(link) == "string" then
                    showBagLevel(button, link)
                else
                    clearBagButton(button)
                end
            end
        end
    end
end

local function applyBags()
    if not F:Active("bagItemLevel") then return end
    -- Container frames are Blizzard UI; keep every visual change out of combat.
    if InCombatLockdown() then return end
    local bagFrames = NUM_BAG_SLOTS or 0
    local bankFrames = NUM_BANKBAGSLOTS or 0
    for index = 1, bagFrames + bankFrames do
        applyContainer(index, index > bagFrames)
    end
    applyBankMain()
end

local function applySlot(featureId, buttonName, unit, slot)
    local button = _G[buttonName]
    if not button then return end
    local overlay = overlayByButton[button]
    if not F:Active(featureId) then
        if overlay then overlay:Hide() end
        return
    end
    -- Slot buttons belong to Blizzard's protected character UI. Defer visual changes in combat.
    if InCombatLockdown() then return end
    local link = GetInventoryItemLink(unit, slot)
    if not F:Plain(link) or type(link) ~= "string" then
        if overlay then overlay:Hide() end
        return
    end
    local level = C_Item.GetDetailedItemLevelInfo(link)
    if not F:Plain(level) or type(level) ~= "number" or level <= 0 then
        if overlay then overlay:Hide() end
        return
    end
    if not overlay then
        overlay = button:CreateFontString(nil, "OVERLAY")
        overlay:SetJustifyH("RIGHT")
        overlay:SetJustifyV("BOTTOM")
        overlay:SetTextColor(1, 0.82, 0.22)
        overlayByButton[button] = overlay
    end
    if STANDARD_TEXT_FONT and overlay.SetFont then
        overlay:SetFont(STANDARD_TEXT_FONT, F:GetOption(featureId, "size"), "OUTLINE")
    elseif GameFontNormalSmall then
        overlay:SetFontObject(GameFontNormalSmall)
    end
    local position = F:GetOption(featureId, "position")
    local x, y = positionOffset(position)
    overlay:ClearAllPoints()
    overlay:SetPoint(position, button, position, x, y)
    overlay:SetText(tostring(level))
    overlay:Show()
end

local function applyCharacter()
    for _, entry in ipairs(CHARACTER_SLOTS) do
        applySlot("charItemLevel", entry[1], "player", entry[2])
    end
end

local function inspectUnit()
    if InspectFrame and InspectFrame.unit then return InspectFrame.unit end
    return "target"
end

local function applyInspect()
    local unit = inspectUnit()
    for _, entry in ipairs(INSPECT_SLOTS) do
        applySlot("inspectItemLevel", entry[1], unit, entry[2])
    end
end

local function installHooks()
    if hooked then return end
    local installed = false
    if CharacterFrame and CharacterFrame.HookScript then
        CharacterFrame:HookScript("OnShow", applyCharacter)
        installed = true
    end
    if InspectFrame and InspectFrame.HookScript then
        InspectFrame:HookScript("OnShow", applyInspect)
        installed = true
    end
    hooked = installed
end

local function installBagHooks()
    if bagHooked then return end
    local installed = false
    local bagFrames = NUM_BAG_SLOTS or 0
    local bankFrames = NUM_BANKBAGSLOTS or 0
    for index = 1, bagFrames + bankFrames do
        local frame = _G["ContainerFrame" .. index]
        if frame and frame.HookScript then
            frame:HookScript("OnShow", function() applyContainer(index, index > bagFrames) end)
            installed = true
        end
    end
    if BankFrame and BankFrame.HookScript then
        BankFrame:HookScript("OnShow", applyBankMain)
        installed = true
    end
    bagHooked = installed
end

local function onBagUpdate(_, bag)
    if not F:Active("bagItemLevel") then return end
    if InCombatLockdown() then return end
    local bagFrames = NUM_BAG_SLOTS or 0
    local bankFrames = NUM_BANKBAGSLOTS or 0
    for index = 1, bagFrames + bankFrames do
        local frame = _G["ContainerFrame" .. index]
        local id = frame and frame.GetID and frame:GetID()
        if index - 1 == bag or id == bag then applyContainer(index, index > bagFrames) end
    end
end

local function onInventoryChanged(_, unit)
    if unit == "player" then applyCharacter() end
end

local function onInspectReady(_, guid)
    if guid and UnitGUID and UnitGUID(inspectUnit()) ~= guid then return end
    applyInspect()
end

local function levelOptions()
    return {
        { key = "position", type = "choice", title = "Text position", default = "BOTTOMRIGHT",
          choices = { { value = "BOTTOMRIGHT", label = "Bottom right" },
              { value = "TOPLEFT", label = "Top left" }, { value = "CENTER", label = "Center" } },
          description = "Corner of each equipment slot used for the number. Center can cover the item icon." },
        { key = "size", type = "number", title = "Text size", default = 11, min = 6, max = 24, step = 1,
          description = "Font size in points. The number uses the client's standard font with an outline." },
    }
end

F:Register("charItemLevel", {
    title = "Item levels on the character panel",
    category = "Inventory",
    description = "Shows the actual item level in the corner of each equipped slot on the character panel. Updates when equipment changes and when the panel opens. It does not inspect other players and does not change the item tooltip.",
    disableText = "Hides the slot numbers immediately. It does not alter any equipment or Blizzard text.",
    conflicts = conflicts,
    options = levelOptions(),
    available = function()
        return GetInventoryItemLink and C_Item and C_Item.GetDetailedItemLevelInfo
            and CharacterFrame ~= nil
    end,
    enable = function()
        installHooks()
        F:Listen("charItemLevel", "PLAYER_ENTERING_WORLD", function() installHooks(); applyCharacter() end)
        F:Listen("charItemLevel", "PLAYER_EQUIPMENT_CHANGED", applyCharacter)
        F:Listen("charItemLevel", "UNIT_INVENTORY_CHANGED", onInventoryChanged)
        F:Listen("charItemLevel", "PLAYER_REGEN_ENABLED", applyCharacter)
        applyCharacter()
    end,
    refresh = applyCharacter,
    disable = function() hideSlots(CHARACTER_SLOTS) end,
})

F:Register("inspectItemLevel", {
    title = "Item levels on the inspect panel",
    category = "Inventory",
    description = "Shows each equipped item's actual item level on the inspect panel after the client finishes loading inspect data. It does not request extra inspect data and shows nothing until that data arrives.",
    disableText = "Hides the inspect slot numbers. The inspect panel itself is unchanged.",
    conflicts = conflicts,
    options = levelOptions(),
    available = function()
        return GetInventoryItemLink and C_Item and C_Item.GetDetailedItemLevelInfo
            and InspectFrame ~= nil and UnitGUID ~= nil
    end,
    enable = function()
        installHooks()
        F:Listen("inspectItemLevel", "PLAYER_ENTERING_WORLD", function() installHooks(); applyInspect() end)
        F:Listen("inspectItemLevel", "INSPECT_READY", onInspectReady)
        F:Listen("inspectItemLevel", "PLAYER_TARGET_CHANGED", applyInspect)
        F:Listen("inspectItemLevel", "PLAYER_REGEN_ENABLED", applyInspect)
        applyInspect()
    end,
    refresh = applyInspect,
    disable = function() hideSlots(INSPECT_SLOTS) end,
})

local function bagOptions()
    local options = levelOptions()
    -- Bag slots already use their bottom-right corner for the stack count.
    options[1].default = "TOPLEFT"
    options[1].description = "Corner of each bag slot used for the number. Top left avoids the stack count in the bottom-right corner; Center can cover the item icon."
    options[#options + 1] = { key = "includeBank", type = "boolean", title = "Include bank",
        default = false,
        description = "Also numbers the main bank slots and bank bags. Bank contents are only known after the bank has been opened in this session." }
    return options
end

F:Register("bagItemLevel", {
    title = "Item levels in bags and bank",
    category = "Inventory",
    description = "Shows the actual item level in the corner of each bag slot, and of bank slots when Include bank is enabled. Updates as items move and when a bag opens. It only marks existing items; it never moves, sells or sorts them.",
    disableText = "Hides the bag and bank numbers. No item is moved, sold or changed.",
    conflicts = conflicts,
    options = bagOptions(),
    available = function()
        local link = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
        return link and C_Item and C_Item.GetDetailedItemLevelInfo and ContainerFrame1 ~= nil
    end,
    enable = function()
        installBagHooks()
        F:Listen("bagItemLevel", "PLAYER_ENTERING_WORLD", function() installBagHooks(); applyBags() end)
        F:Listen("bagItemLevel", "BAG_UPDATE", onBagUpdate)
        F:Listen("bagItemLevel", "BAG_UPDATE_DELAYED", applyBags)
        F:Listen("bagItemLevel", "BANKFRAME_OPENED", applyBags)
        F:Listen("bagItemLevel", "PLAYERBANKSLOTS_CHANGED", applyBags)
        F:Listen("bagItemLevel", "PLAYER_REGEN_ENABLED", applyBags)
        applyBags()
    end,
    refresh = applyBags,
    disable = hideBagOverlays,
})

local averageLabel
local function averageValues()
    if not GetAverageItemLevel then return nil end
    local overall, equipped = GetAverageItemLevel()
    if type(equipped) ~= "number" then equipped = overall end
    if type(equipped) ~= "number" or equipped <= 0 then return nil end
    if type(overall) ~= "number" or overall <= 0 then overall = equipped end
    return equipped, overall
end

local function applyAverage()
    if not F:Active("averageItemLevel") or InCombatLockdown() then return end
    local equipped, overall = averageValues()
    if not equipped or not CharacterFrame then
        if averageLabel then averageLabel:Hide() end
        return
    end
    if not averageLabel then
        averageLabel = CharacterFrame:CreateFontString(nil, "OVERLAY")
        averageLabel:SetPoint("TOPLEFT", 14, -70)
        averageLabel:SetJustifyH("LEFT")
        averageLabel:SetTextColor(1, 0.82, 0.22)
        if STANDARD_TEXT_FONT and averageLabel.SetFont then
            averageLabel:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
        elseif GameFontNormalSmall then
            averageLabel:SetFontObject(GameFontNormalSmall)
        end
    end
    local text = "Item level " .. math.floor(equipped + 0.5)
    if F:GetOption("averageItemLevel", "showOverall") == true and overall ~= equipped then
        text = text .. " (overall " .. math.floor(overall + 0.5) .. ")"
    end
    averageLabel:SetText(text)
    averageLabel:Show()
end

F:Register("averageItemLevel", {
    title = "Average item level on the character panel",
    category = "Inventory",
    description = "Shows the client's average equipped item level at the top left of the character panel. The number comes from the client; ForeverSuite does not estimate or change equipment. Its fixed position is a preview detail.",
    disableText = "Hides the text. Equipment and Blizzard's own stats are unchanged.",
    conflicts = { "SimpleItemLevel", "EnhanceQoL", "TinyInspect", "Pawn" },
    options = {
        { key = "showOverall", type = "boolean", title = "Also show overall average", default = false,
          description = "Adds the client's average across every equipped and inventory slot when it differs from the equipped average. Includes items you are not wearing." },
    },
    available = function()
        return GetAverageItemLevel ~= nil and CharacterFrame ~= nil
    end,
    enable = function()
        if CharacterFrame and CharacterFrame.HookScript then CharacterFrame:HookScript("OnShow", applyAverage) end
        F:Listen("averageItemLevel", "PLAYER_ENTERING_WORLD", applyAverage)
        F:Listen("averageItemLevel", "PLAYER_EQUIPMENT_CHANGED", applyAverage)
        F:Listen("averageItemLevel", "PLAYER_REGEN_ENABLED", applyAverage)
        applyAverage()
    end,
    refresh = applyAverage,
    disable = function()
        if averageLabel then averageLabel:Hide() end
    end,
})

local durabilityLabels = {}
local function durabilityColor(percent)
    if percent <= 20 then return 1, 0.3, 0.25 end
    if percent <= 50 then return 1, 0.82, 0.22 end
    return 0.6, 1, 0.6
end

local function applyDurability()
    if not F:Active("slotDurability") or InCombatLockdown() then return end
    if not GetInventoryItemDurability then return end
    for _, entry in ipairs(CHARACTER_SLOTS) do
        local button = _G[entry[1]]
        if button then
            local label = durabilityLabels[button]
            local current, maximum = GetInventoryItemDurability(entry[2])
            if type(current) == "number" and type(maximum) == "number" and maximum > 0 then
                if not label then
                    label = button:CreateFontString(nil, "OVERLAY")
                    label:SetPoint("BOTTOMLEFT", 2, 2)
                    label:SetJustifyH("LEFT")
                    if STANDARD_TEXT_FONT and label.SetFont then
                        label:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
                    elseif GameFontNormalSmall then
                        label:SetFontObject(GameFontNormalSmall)
                    end
                    durabilityLabels[button] = label
                end
                local percent = math.floor(current / maximum * 100 + 0.5)
                label:SetText(percent .. "%")
                label:SetTextColor(durabilityColor(percent))
                label:Show()
            elseif label then
                label:Hide()
            end
        end
    end
end

F:Register("slotDurability", {
    title = "Durability percentages on equipment slots",
    category = "Inventory",
    description = "Shows each equipped item's remaining durability as a percentage in the lower-left corner of its character-panel slot, colored green, yellow or red. Items without durability show nothing.",
    disableText = "Hides the durability percentages. Equipment and repair state are unchanged.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "SimpleItemLevel", "TinyInspect" },
    available = function()
        return GetInventoryItemDurability ~= nil and CharacterFrame ~= nil
    end,
    enable = function()
        if CharacterFrame and CharacterFrame.HookScript then CharacterFrame:HookScript("OnShow", applyDurability) end
        F:Listen("slotDurability", "PLAYER_ENTERING_WORLD", applyDurability)
        F:Listen("slotDurability", "PLAYER_EQUIPMENT_CHANGED", applyDurability)
        F:Listen("slotDurability", "UPDATE_INVENTORY_DURABILITY", applyDurability)
        F:Listen("slotDurability", "PLAYER_REGEN_ENABLED", applyDurability)
        applyDurability()
    end,
    refresh = applyDurability,
    disable = function()
        for _, label in pairs(durabilityLabels) do label:Hide() end
    end,
})

local bagSpaceLabel
local function freeBagSlots()
    if GetNumFreeBagSlots then
        local free = GetNumFreeBagSlots()
        if type(free) == "number" then return free end
    end
    if C_Container and C_Container.GetContainerNumFreeSlots then
        local total = 0
        for bag = 0, NUM_BAG_SLOTS or 4 do
            local free = C_Container.GetContainerNumFreeSlots(bag)
            if type(free) == "number" then total = total + free end
        end
        return total
    end
end

local function applyBagSpace()
    local button = _G.MainMenuBarBackpackButton
    if not F:Active("bagSpace") or InCombatLockdown() or not button then
        if bagSpaceLabel then bagSpaceLabel:Hide() end
        return
    end
    local free = freeBagSlots()
    if type(free) ~= "number" then
        if bagSpaceLabel then bagSpaceLabel:Hide() end
        return
    end
    if not bagSpaceLabel then
        bagSpaceLabel = button:CreateFontString(nil, "OVERLAY")
        bagSpaceLabel:SetPoint("TOPLEFT", 2, -2)
        bagSpaceLabel:SetJustifyH("LEFT")
        bagSpaceLabel:SetTextColor(1, 0.82, 0.22)
        if STANDARD_TEXT_FONT and bagSpaceLabel.SetFont then
            bagSpaceLabel:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        elseif GameFontNormalSmall then
            bagSpaceLabel:SetFontObject(GameFontNormalSmall)
        end
    end
    bagSpaceLabel:SetText(tostring(free))
    bagSpaceLabel:Show()
end

F:Register("bagSpace", {
    title = "Free bag slots on the backpack",
    category = "Inventory",
    description = "Shows the number of empty bag slots on the backpack button, updated when bags change. It counts carried bags only, not the bank or reagent bank.",
    disableText = "Hides the number. No item or bag is moved.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "Bagnon", "AdiBags" },
    available = function()
        return _G.MainMenuBarBackpackButton ~= nil
            and (GetNumFreeBagSlots ~= nil or (C_Container and C_Container.GetContainerNumFreeSlots ~= nil))
    end,
    enable = function()
        F:Listen("bagSpace", "PLAYER_ENTERING_WORLD", applyBagSpace)
        F:Listen("bagSpace", "BAG_UPDATE", applyBagSpace)
        F:Listen("bagSpace", "BAG_UPDATE_DELAYED", applyBagSpace)
        F:Listen("bagSpace", "PLAYER_REGEN_ENABLED", applyBagSpace)
        applyBagSpace()
    end,
    refresh = applyBagSpace,
    disable = function()
        if bagSpaceLabel then bagSpaceLabel:Hide() end
    end,
})

local lootLabels = {}
local function applyLootLevels()
    if not F:Active("lootItemLevel") or InCombatLockdown() then return end
    if not _G.LootFrame or not GetLootSlotLink then return end
    local count = GetNumLootItems and GetNumLootItems() or 0
    if type(count) ~= "number" then count = 0 end
    for index = 1, 4 do
        local button = _G["LootButton" .. index]
        if button then
            local label = lootLabels[button]
            local link = index <= count and GetLootSlotLink(index) or nil
            local level
            if type(link) == "string" and C_Item and C_Item.GetDetailedItemLevelInfo then
                level = C_Item.GetDetailedItemLevelInfo(link)
            end
            if type(level) == "number" and level > 0 then
                if not label then
                    label = button:CreateFontString(nil, "OVERLAY")
                    label:SetPoint("TOPLEFT", 3, -3)
                    label:SetJustifyH("LEFT")
                    label:SetTextColor(1, 0.82, 0.22)
                    if STANDARD_TEXT_FONT and label.SetFont then
                        label:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
                    elseif GameFontNormalSmall then
                        label:SetFontObject(GameFontNormalSmall)
                    end
                    lootLabels[button] = label
                end
                label:SetText(tostring(level))
                label:Show()
            elseif label then
                label:Hide()
            end
        end
    end
end

F:Register("lootItemLevel", {
    title = "Item levels on the loot window",
    category = "Inventory",
    description = "Shows the actual item level beside each item in the client's loot window. It marks existing loot only; it never picks up or rolls on an item.",
    disableText = "Hides the numbers on the loot window. Loot itself is unchanged.",
    conflicts = { "SimpleItemLevel", "EnhanceQoL", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function()
        return _G.LootFrame ~= nil and GetLootSlotLink ~= nil
            and C_Item and C_Item.GetDetailedItemLevelInfo ~= nil
    end,
    enable = function()
        F:Listen("lootItemLevel", "LOOT_OPENED", applyLootLevels)
        F:Listen("lootItemLevel", "LOOT_SLOT_CLEARED", applyLootLevels)
        F:Listen("lootItemLevel", "PLAYER_ENTERING_WORLD", applyLootLevels)
        F:Listen("lootItemLevel", "PLAYER_REGEN_ENABLED", applyLootLevels)
        applyLootLevels()
    end,
    refresh = applyLootLevels,
    disable = function()
        for _, label in pairs(lootLabels) do label:Hide() end
    end,
})

local rollLabels = {}
local function applyRollLevels()
    if not F:Active("rollItemLevel") or InCombatLockdown() then return end
    if not GetLootRollItemLink then return end
    for index = 1, 4 do
        local button = _G["GroupLootFrame" .. index]
        if button then
            local label = rollLabels[button]
            local link = GetLootRollItemLink(index)
            local level
            if type(link) == "string" and C_Item and C_Item.GetDetailedItemLevelInfo then
                level = C_Item.GetDetailedItemLevelInfo(link)
            end
            if type(level) == "number" and level > 0 then
                if not label then
                    label = button:CreateFontString(nil, "OVERLAY")
                    label:SetPoint("TOPLEFT", 3, -3)
                    label:SetJustifyH("LEFT")
                    label:SetTextColor(1, 0.82, 0.22)
                    if STANDARD_TEXT_FONT and label.SetFont then
                        label:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
                    elseif GameFontNormalSmall then
                        label:SetFontObject(GameFontNormalSmall)
                    end
                    rollLabels[button] = label
                end
                label:SetText(tostring(level))
                label:Show()
            elseif label then
                label:Hide()
            end
        end
    end
end

F:Register("rollItemLevel", {
    title = "Item levels on loot rolls",
    category = "Inventory",
    description = "Shows the actual item level beside each need/greed roll so you can decide before the timer runs out. It never rolls for you.",
    disableText = "Hides the numbers on loot roll frames. Rolling itself is unchanged.",
    conflicts = { "SimpleItemLevel", "EnhanceQoL", "Leatrix_Plus", "Leatrix_Plus_Forever", "TinyInspect" },
    available = function()
        return _G.GroupLootFrame1 ~= nil and GetLootRollItemLink ~= nil
            and C_Item and C_Item.GetDetailedItemLevelInfo ~= nil
    end,
    enable = function()
        F:Listen("rollItemLevel", "START_LOOT_ROLL", applyRollLevels)
        F:Listen("rollItemLevel", "PLAYER_ENTERING_WORLD", applyRollLevels)
        F:Listen("rollItemLevel", "PLAYER_REGEN_ENABLED", applyRollLevels)
        applyRollLevels()
    end,
    refresh = applyRollLevels,
    disable = function()
        for _, label in pairs(rollLabels) do label:Hide() end
    end,
})
