-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: GPL-3.0-or-later
local _, F = ...
-- Older client functions: the client's own global when present, else a private shim (Compat.lua).
local GetQuestRequiredMoney = F.Compat("GetQuestRequiredMoney")
local common = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "TweaksForever" }
local function define(id, title, description, event, available, action, conflicts, options)
    F:Register(id, { title = title, category = "Automation", description = description,
        conflicts = conflicts or common, available = available, options = options or {},
        enable = function() F:Listen(id, event, function(_, ...)
            if F:CanAutomate() then action(...) end
        end) end })
end

local function moneyText(copper)
    if GetMoneyString then
        local ok, text = pcall(GetMoneyString, copper)
        if ok and type(text) == "string" then return text end
    end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local remaining = copper % 100
    return gold .. "g " .. silver .. "s " .. remaining .. "c"
end

local function repaired(cost)
    if F:GetOption("repair", "report") == false then return end
    F:Print("Repaired for " .. moneyText(cost) .. ".")
end

local function repairAction()
    if not CanMerchantRepair() then return end
    local cost, needed = GetRepairAllCost()
    if not (F:Plain(cost) and F:Plain(needed) and needed and type(cost) == "number") then return end
    if cost <= 0 or cost > F.db.repairCap then return end
    local funding = F:GetOption("repair", "funding")
    local guildOK = funding ~= "personal" and CanGuildBankRepair and CanGuildBankRepair()
    if funding == "guild" then
        if guildOK then
            RepairAllItems(true)
            repaired(cost)
        end
        return
    end
    local money = GetMoney and GetMoney() or 0
    if cost <= money then
        RepairAllItems(false)
        repaired(cost)
    elseif funding == "both" and guildOK then
        RepairAllItems(true)
        repaired(cost)
    end
end

define("repair", "Repair with personal gold",
    "Repairs at merchants using your gold, guild funds or both, up to the cap (default 10g). /ts cap 25 changes it. Hold Shift to skip.",
    "MERCHANT_SHOW", function() return CanMerchantRepair and GetRepairAllCost and RepairAllItems and GetMoney end,
    repairAction, nil, {
        { key = "report", type = "boolean", title = "Report repair cost in chat", default = true,
          description = "Prints the amount paid when a repair happens, so the cap and your remaining gold stay visible. Turn this off if your chat is already busy." },
        { key = "funding", type = "choice", title = "Repair funding", default = "personal",
          choices = { { value = "personal", label = "Personal gold" },
              { value = "guild", label = "Guild bank only" },
              { value = "both", label = "Personal, then guild" } },
          description = "Guild funding is used only when the client says you may withdraw guild repair money. Personal funding still checks that you can pay. The /ts cap limit applies to every choice." },
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

local function excepted(kind)
    local list = (F.db and F.db.except and F.db.except[kind]) or {}
    if #list == 0 or type(GetTitleText) ~= "function" then return false end
    local ok, title = pcall(GetTitleText)
    if not ok or type(title) ~= "string" then return false end
    for _, entry in ipairs(list) do
        if entry == title then return true end
    end
    return false
end

local function alreadyCompleted()
    if F:GetOption("acceptQuests", "skipCompleted") ~= true then return false end
    if type(GetQuestID) ~= "function" or not C_QuestLog or not C_QuestLog.IsQuestFlaggedCompleted then
        return false
    end
    local ok, questID = pcall(GetQuestID)
    if not ok or type(questID) ~= "number" or questID <= 0 then return false end
    local done, completed = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
    return done and completed == true
end

local function skipBecauseDaily()
    if F:GetOption("acceptQuests", "skipDailies") ~= true then return false end
    if type(IsDailyQuest) ~= "function" then return false end
    local ok, daily = pcall(IsDailyQuest)
    return ok and daily == true
end

local function skipBecauseRepeatable()
    if F:GetOption("acceptQuests", "skipRepeatable") ~= true then return false end
    if type(IsRepeatableQuest) ~= "function" then return false end
    local ok, repeatable = pcall(IsRepeatableQuest)
    return ok and repeatable == true
end

define("acceptQuests", "Accept offered quests",
    "Accepts a quest when its details open. Hold Shift to read normally. Optional filters skip daily and repeatable quests. Named quest exceptions are still planned.",
    "QUEST_DETAIL", function() return AcceptQuest end,
    function()
        if excepted("accept") then return end
        if alreadyCompleted() then return end
        if excepted("accept") then return end
        if alreadyCompleted() then return end
        if skipBecauseDaily() then return end
        if skipBecauseRepeatable() then return end
        AcceptQuest()
    end, nil, {
        { key = "skipCompleted", type = "boolean", title = "Skip quests already completed", default = false,
          description = "Leaves a quest open when the client reports you have finished it before. "
              .. "Requires the client's quest-history API; without it every quest is accepted as normal." },
        { key = "skipDailies", type = "boolean", title = "Skip daily quests", default = false,
          description = "Leaves daily quests open for you to read and accept yourself. Requires the client's daily-quest API; if it is missing, the quest is accepted as normal." },
        { key = "skipRepeatable", type = "boolean", title = "Skip repeatable quests", default = false,
          description = "Leaves repeatable quests open, including profession and turn-in repeatables. Daily quests are usually also repeatable, so enable both filters only if you want the stricter result." },
    })

define("turnInQuests", "Turn in quests without reward choices",
    "Completes quests with zero reward choices and no money requirement. Multiple or single choice rewards remain manual. "
        .. "Quests named on the never-turn-in list are always left open. Hold Shift to skip.",
    "QUEST_COMPLETE", function() return GetNumQuestChoices and GetQuestReward and GetQuestRequiredMoney end,
    function()
        if excepted("turnin") then return end
        local choices, cost = GetNumQuestChoices(), GetQuestRequiredMoney()
        if F:Plain(choices) and F:Plain(cost) and choices == 0 and cost == 0 then GetQuestReward(0) end
    end)

local function declineInvite()
    if C_PartyInfo and C_PartyInfo.DeclineInvite then
        C_PartyInfo.DeclineInvite()
    elseif DeclineGroup then
        DeclineGroup()
    elseif DeclineInvite then
        DeclineInvite()
    end
end

local function inviteAllowed(name)
    if type(name) ~= "string" or name == "" then return true end
    if F:GetOption("blockStrangerInvites", "allowFriends") ~= false and UnitIsFriend
        and UnitIsFriend("player", name) then return true end
    if F:GetOption("blockStrangerInvites", "allowGuild") ~= false and UnitIsInMyGuild
        and UnitIsInMyGuild(name) then return true end
    return false
end

F:Register("blockStrangerInvites", {
    title = "Decline group invites from strangers",
    category = "Automation",
    description = "Declines incoming group invitations from players who are neither your friends nor guild members. Friends and guild members still reach you by default. Hold Shift or leave combat to let an invite through. Nothing is reported to the other player beyond the normal decline.",
    disableText = "Stops declining invites immediately. Any invite already declined stays declined.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "BadBoy", "GlobalIgnore" },
    options = {
        { key = "allowFriends", type = "boolean", title = "Allow friends", default = true,
          description = "Friend-listed players can still invite you. Turn this off to treat friends like strangers." },
        { key = "allowGuild", type = "boolean", title = "Allow guild members", default = true,
          description = "Players in your guild can still invite you. Turn this off to treat guild members like strangers." },
        { key = "announce", type = "boolean", title = "Say when an invite was declined", default = true,
          description = "Prints the declined player's name in chat, so an invitation is never silently dropped." },
    },
    available = function()
        return (C_PartyInfo and C_PartyInfo.DeclineInvite) or DeclineGroup ~= nil or DeclineInvite ~= nil
    end,
    enable = function()
        F:Listen("blockStrangerInvites", "PARTY_INVITE_REQUEST", function(_, name)
            if not F:CanAutomate() then return end
            if type(name) ~= "string" or inviteAllowed(name) then return end
            declineInvite()
            if F:GetOption("blockStrangerInvites", "announce") ~= false then
                F:Print("Declined a group invite from " .. name .. ".")
            end
        end)
    end,
})
