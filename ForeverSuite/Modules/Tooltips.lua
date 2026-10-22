-- SPDX-License-Identifier: MIT
local _, F = ...
local seen = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local installed = false
local function process(tooltip, data)
    if not F.db or InCombatLockdown() then return end
    if not (F:Active("maxStack") or F:Active("itemLevel") or F:Active("itemID")) then return end
    if not tooltip or not tooltip.GetItem or not F:Plain(data) then return end
    local _, link = tooltip:GetItem()
    if not F:Plain(link) or type(link) ~= "string" then return end
    if not hooked[tooltip] then
        tooltip:HookScript("OnTooltipCleared", function(self) seen[self] = nil end)
        hooked[tooltip] = true
    end
    local record = seen[tooltip]
    if not record or record.link ~= link then record = { link = link }; seen[tooltip] = record end
    local info = { C_Item.GetItemInfo(link) }
    local id = link:match("item:(%d+)")
    if F:Active("itemID") and not record.itemID and id then
        tooltip:AddLine("Item ID: " .. id, 0.55, 0.85, 0.85); record.itemID = true
    end
    local stack = info[8]
    if F:Active("maxStack") and not record.maxStack and F:Plain(stack) and type(stack) == "number" and stack > 1 then
        tooltip:AddLine("Max Stack: " .. stack, 0.55, 0.85, 0.85); record.maxStack = true
    end
    local equip = info[9]
    if F:Active("itemLevel") and not record.itemLevel and F:Plain(equip) and type(equip) == "string" and equip ~= "" then
        local level = C_Item.GetDetailedItemLevelInfo(link)
        if F:Plain(level) and type(level) == "number" and level > 0 then
            tooltip:AddLine("Item Level (ForeverSuite): " .. level, 0.55, 0.85, 0.85); record.itemLevel = true
        end
    end
end
local function safeProcess(tooltip, data)
    local ok, err = pcall(process, tooltip, data)
    if not ok then
        for _, id in ipairs({ "maxStack", "itemLevel", "itemID" }) do
            if F:Active(id) then F:RecordError(id, err) end
        end
    end
end
local function install()
    if installed then return end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, safeProcess)
    -- Blizzard rebuilds item tooltips when their asynchronous data is ready.
    installed = true
end
local entries = {
    { "maxStack", "Maximum stack size", "Adds maximum stack size to stackable item tooltips outside combat.", { "MaxStackTooltip", "EnhanceQoL", "EnhanceQoLTooltip" } },
    { "itemLevel", "Item level in tooltips", "Adds the actual item level for equipment outside combat. Bag and character overlays are a later stage.", { "SimpleItemLevel", "EnhanceQoL", "EnhanceQoLTooltip", "Leatrix_Plus", "Leatrix_Plus_Forever" } },
    { "itemID", "Item ID in tooltips", "Adds the item ID outside combat. Re-hover after changing tooltip options.", { "EnhanceQoL", "EnhanceQoLTooltip", "Leatrix_Plus", "Leatrix_Plus_Forever" } },
}
for _, entry in ipairs(entries) do
    F:Register(entry[1], { title = entry[2], category = "Tooltips", description = entry[3], conflicts = entry[4],
        disableText = "Stops adding this line to new tooltips. Move your mouse away and hover again to rebuild the current tooltip.",
        enable = install, available = function()
            return TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
                and C_Item and C_Item.GetItemInfo and C_Item.GetDetailedItemLevelInfo
        end })
end
