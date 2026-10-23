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
local hooked = false
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
