-- SPDX-License-Identifier: MIT
local _, F = ...
local common = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "TweaksForever" }
local function define(id, title, description, event, available, action, conflicts, options)
    F:Register(id, { title = title, category = "Automation", description = description,
        conflicts = conflicts or common, available = available, options = options or {},
        enable = function() F:Listen(id, event, function(_, ...)
            if F:CanAutomate() then action(...) end
        end) end })
end

local function repairAction()
    if not CanMerchantRepair() then return end
    local cost, needed = GetRepairAllCost()
    if not (F:Plain(cost) and F:Plain(needed) and needed and type(cost) == "number") then return end
    if cost <= 0 or cost > F.db.repairCap then return end
    local funding = F:GetOption("repair", "funding")
    local guildOK = funding ~= "personal" and CanGuildBankRepair and CanGuildBankRepair()
    if funding == "guild" then
        if guildOK then RepairAllItems(true) end
        return
    end
    local money = GetMoney and GetMoney() or 0
    if cost <= money then
        RepairAllItems(false)
    elseif funding == "both" and guildOK then
        RepairAllItems(true)
    end
end

define("repair", "Repair with personal gold",
    "Repairs at merchants using your gold, guild funds or both, up to the cap (default 10g). /fs cap 25 changes it. Hold Shift to skip.",
    "MERCHANT_SHOW", function() return CanMerchantRepair and GetRepairAllCost and RepairAllItems and GetMoney end,
    repairAction, nil, {
        { key = "funding", type = "choice", title = "Repair funding", default = "personal",
          choices = { { value = "personal", label = "Personal gold" },
              { value = "guild", label = "Guild bank only" },
              { value = "both", label = "Personal, then guild" } },
          description = "Guild funding is used only when the client says you may withdraw guild repair money. Personal funding still checks that you can pay. The /fs cap limit applies to every choice." },
    })

define("sellJunk", "Sell junk at merchants",
    "Uses the game's Sell All Junk operation, including items YOU marked as junk. Hold Shift to skip. No custom selling rules yet.",
    "MERCHANT_SHOW", function() return C_MerchantFrame and C_MerchantFrame.SellAllJunkItems
        and C_MerchantFrame.IsSellAllJunkEnabled end,
    function()
        if C_MerchantFrame.IsSellAllJunkEnabled() then C_MerchantFrame.SellAllJunkItems() end
    end, { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "EnhanceQoLVendor", "TweaksForever", "Scrap", "Peddler" })

define("fastLoot", "Faster automatic looting",
    "Loots slots when the client opens loot in auto-loot mode. Holds off in combat or while Shift is held. Keeps confirmations intact.",
    "LOOT_OPENED", function() return GetNumLootItems and LootSlot end,
    function(autoLoot)
        if not F:Plain(autoLoot) or not autoLoot then return end
        local count = GetNumLootItems()
        if not F:Plain(count) or type(count) ~= "number" then return end
        for slot = count, 1, -1 do LootSlot(slot) end
    end, { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "TweaksForever", "Plumber", "Leatrix_Faster_Loot" })

define("acceptQuests", "Accept offered quests",
    "Accepts a quest when its details open. Hold Shift to read normally. Quest exceptions and filters are planned for a later stage.",
    "QUEST_DETAIL", function() return AcceptQuest end, function() AcceptQuest() end)

define("turnInQuests", "Turn in quests without reward choices",
    "Completes quests with zero reward choices and no money requirement. Multiple or single choice rewards remain manual. Hold Shift to skip.",
    "QUEST_COMPLETE", function() return GetNumQuestChoices and GetQuestReward and GetQuestRequiredMoney end,
    function()
        local choices, cost = GetNumQuestChoices(), GetQuestRequiredMoney()
        if F:Plain(choices) and F:Plain(cost) and choices == 0 and cost == 0 then GetQuestReward(0) end
    end)
