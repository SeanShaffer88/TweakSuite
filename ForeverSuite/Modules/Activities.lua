-- SPDX-License-Identifier: MIT
-- Quest log helpers, rested experience, rare alerts and non-blocking trade and craft warnings.
local _, F = ...
local common = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "Questie", "RareScanner" }
local rareSeen = {}
local lastTradeSignature, lastCraftName

local function questDifficulty(level)
    if GetQuestDifficultyColor then
        local color = GetQuestDifficultyColor(level)
        if type(color) == "table" then
            local name = "yellow"
            if color.red and color.green and color.blue then
                if color.red > 0.9 and color.green < 0.4 then name = "red"
                elseif color.red > 0.9 and color.green > 0.6 then name = "yellow"
                elseif color.green > 0.6 and color.red < 0.5 then name = "green"
                elseif color.blue > 0.6 then name = "grey" end
            end
            return name, color
        end
    end
    local player = UnitLevel and UnitLevel("player") or 0
    local green = GetQuestGreenRange and GetQuestGreenRange() or 5
    if type(player) ~= "number" or type(level) ~= "number" then return "unknown", nil end
    local delta = player - level
    if delta <= -5 then return "red", nil end
    if delta <= 2 then return "yellow", nil end
    if delta < green then return "green", nil end
    return "grey", nil
end

function F:QuestRows()
    local rows = {}
    if not (GetNumQuestLogEntries and GetQuestLogTitle) then return rows end
    local count = GetNumQuestLogEntries()
    if type(count) ~= "number" then return rows end
    for index = 1, count do
        local title, level, tag, group, header, collapsed, complete, frequency, questID = GetQuestLogTitle(index)
        if type(title) == "string" and title ~= "" and not header then
            local distance
            if C_QuestLog and C_QuestLog.GetDistanceSqToQuest and type(questID) == "number" then
                local ok, value = pcall(C_QuestLog.GetDistanceSqToQuest, questID)
                if ok and type(value) == "number" then distance = value end
            elseif GetDistanceSqToQuest and type(questID) == "number" then
                local ok, value = pcall(GetDistanceSqToQuest, questID)
                if ok and type(value) == "number" then distance = value end
            end
            local difficulty, color = questDifficulty(level)
            rows[#rows + 1] = { index = index, title = title, level = level, tag = tag,
                complete = complete, difficulty = difficulty, color = color, distance = distance,
                questID = questID }
        end
    end
    return rows
end

local function sortedRows(byDistance)
    local rows = F:QuestRows()
    if not byDistance then return rows end
    table.sort(rows, function(a, b)
        if a.distance and b.distance then return a.distance < b.distance end
        if a.distance then return true end
        if b.distance then return false end
        return (a.level or 0) < (b.level or 0)
    end)
    return rows
end

function F:PrintQuestList(byDistance)
    local rows = sortedRows(byDistance)
    if #rows == 0 then F:Print("The quest log is empty or the client does not report entries."); return 0 end
    local missingDistance = false
    for _, row in ipairs(rows) do
        local text = "[" .. tostring(row.level or "?") .. "] " .. row.title
        if row.complete then text = text .. " (complete)" end
        if row.tag and row.tag ~= "" then text = text .. " [" .. row.tag .. "]" end
        text = text .. " - " .. row.difficulty
        if row.distance then
            text = text .. string.format(" - %.0f m", math.sqrt(row.distance))
        elseif byDistance then
            missingDistance = true
        end
        F:Print(text)
    end
    if byDistance and missingDistance then
        F:Print("This client does not report quest distances, so quests without a distance follow the sorted ones.")
    end
    return #rows
end

F:Register("questList", {
    title = "Quest list with levels",
    category = "Quests",
    description = "Prints every quest in your log with its level and difficulty colour using /fs quests. It is a read-only listing: no quest is accepted, abandoned or turned in.",
    disableText = "Stops the /fs quests listing. The quest log itself is unchanged.",
    conflicts = common,
    available = function() return GetNumQuestLogEntries ~= nil and GetQuestLogTitle ~= nil end,
    enable = function() end,
})

F:Register("questDistance", {
    title = "Quest distance sorting",
    category = "Quests",
    description = "Adds the distance to each quest in the /fs quests listing and sorts the list by distance. When the client does not expose quest distances, the list keeps working without them.",
    disableText = "Stops adding distance and sorting. The quest listing itself stays available.",
    conflicts = common,
    available = function()
        return (C_QuestLog and C_QuestLog.GetDistanceSqToQuest) or GetDistanceSqToQuest ~= nil
    end,
    enable = function() end,
})

local function questItemMatches(link, wanted)
    if type(link) ~= "string" or wanted == "" then return false end
    local id = link:match("item:(%d+)")
    if id and id == wanted then return true end
    local info = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(link)
    local name = type(info) == "string" and info
    if type(name) ~= "string" then return false end
    return name:lower():find(wanted:lower(), 1, true) ~= nil
end

function F:UseQuestItem(wanted)
    wanted = tostring(wanted or ""):match("^%s*(.-)%s*$")
    if wanted == "" then return false, "name or item ID required" end
    if InCombatLockdown() then return false, "cannot use items during combat" end
    for bag = 0, 4 do
        local slots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)
            or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
        for slot = 1, slots do
            local link = C_Container and C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)
                or (GetContainerItemLink and GetContainerItemLink(bag, slot))
            if questItemMatches(link, wanted) then
                local info = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(link)
                local classID = select(12, C_Item.GetItemInfo and C_Item.GetItemInfo(link) or nil)
                if type(info) == "string" then
                    if C_Container and C_Container.UseContainerItem then
                        C_Container.UseContainerItem(bag, slot)
                    elseif UseContainerItem then
                        UseContainerItem(bag, slot)
                    end
                    return true, info
                end
            end
        end
    end
    return false, "no matching item found in your bags"
end

F:Register("questItemUse", {
    title = "Use quest items by name",
    category = "Quests",
    description = "Finds a quest item in your bags by name or item ID and uses it with /fs useq <name>. It only right-clicks one of your own items outside combat and never uses an item that is not in your bags.",
    disableText = "Stops the /fs useq command. Bags and items are untouched.",
    conflicts = common,
    available = function() return (C_Container and C_Container.UseContainerItem) or UseContainerItem ~= nil end,
    enable = function() end,
})

F:Register("questTarget", {
    title = "Target a quest mob by name",
    category = "Quests",
    description = "Targets a creature by name with /fs qtarget <name>, which is handy for quest objectives whose name is written in the log. It only chooses a target; it never attacks, pulls or interacts.",
    disableText = "Stops the /fs qtarget command. Your current target is unchanged.",
    conflicts = common,
    available = function() return TargetByName ~= nil or TargetUnit ~= nil end,
    enable = function() end,
})

function F:RestedSnapshot()
    local exhaustion = GetXPExhaustion and GetXPExhaustion() or nil
    if type(exhaustion) ~= "number" then return nil end
    local maxXP = UnitXPMax and UnitXPMax("player") or nil
    local level = UnitLevel and UnitLevel("player") or nil
    local percent
    if type(maxXP) == "number" and maxXP > 0 then percent = exhaustion / maxXP * 100 end
    return { rested = exhaustion, maxPerLevel = maxXP, level = level, percent = percent,
        cap = type(maxXP) == "number" and math.floor(maxXP * 1.5) or nil }
end

function F:PrintRested()
    local snapshot = self:RestedSnapshot()
    if not snapshot then self:Print("This client does not report rested experience."); return end
    local text = "Rested XP: " .. snapshot.rested
    if snapshot.percent then
        text = text .. string.format(" (%.1f%% of a level)", snapshot.percent)
    end
    if snapshot.cap and snapshot.rested >= snapshot.cap then text = text .. " - full" end
    self:Print(text)
end

F:Register("restedInfo", {
    title = "Rested experience report",
    category = "Quests",
    description = "Prints how much rested experience you have and what part of a level that is with /fs rested. It only reads the client value and never changes your rest state.",
    disableText = "Stops the /fs rested report.",
    conflicts = common,
    available = function() return GetXPExhaustion ~= nil end,
    enable = function() end,
})

local restedWasFull = false
local function checkRested()
    if not F:Active("restedFull") then return end
    local snapshot = F:RestedSnapshot()
    if not snapshot or not snapshot.cap or snapshot.cap <= 0 then return end
    local full = snapshot.rested >= snapshot.cap
    if full and not restedWasFull then
        F:Print("Rested experience is full. Log out at an inn or in a city to keep it there.")
    end
    restedWasFull = full
end

function F:RefreshRestedForTest()
    checkRested()
end

F:Register("restedFull", {
    title = "Notify when rested XP is full",
    category = "Quests",
    description = "Prints one chat line when your rested experience reaches the cap, so you know it is time to log out at an inn rather than keep questing. It checks once a minute and never changes your rest.",
    disableText = "Stops the check. Nothing else is restored.",
    conflicts = common,
    options = {
        { key = "interval", type = "number", title = "Check every", default = 60, min = 15, max = 300, step = 15, unit = " s",
          description = "How often the rested value is read. Longer intervals cost less and only delay the notice." },
    },
    available = function() return GetXPExhaustion ~= nil and UnitXPMax ~= nil end,
    enable = function()
        checkRested()
        if type(C_Timer) == "table" and C_Timer.NewTicker then
            F:Listen("restedFull", "PLAYER_ENTERING_WORLD", checkRested)
            F.restedTicker = C_Timer.NewTicker(F:GetOption("restedFull", "interval") or 60, checkRested)
        else
            F:Listen("restedFull", "PLAYER_ENTERING_WORLD", checkRested)
            F:Listen("restedFull", "ZONE_CHANGED_NEW_AREA", checkRested)
        end
    end,
    disable = function()
        if F.restedTicker and F.restedTicker.Cancel then F.restedTicker:Cancel() end
        F.restedTicker = nil
        restedWasFull = false
    end,
})

F:Register("rareAlerts", {
    title = "Rare mob alert",
    category = "Quests",
    description = "Announces a rare or rare-elite creature when you target it, with a chat line, the NPC ID and an optional sound. It only reacts to your own target and never attacks, pulls or marks anything.",
    disableText = "Stops announcing rares. Your target is unchanged.",
    conflicts = { "RareScanner", "NPCScan", "SilverDragon" },
    options = {
        { key = "sound", type = "boolean", title = "Play a sound", default = true,
          description = "Plays the client tell sound when a rare is targeted. Turn this off for a chat-only alert." },
        { key = "once", type = "boolean", title = "Announce each rare once per session", default = true,
          description = "Keeps the alert from repeating every time you re-target the same creature. The NPC ID is always shown." },
    },
    available = function() return UnitGUID ~= nil and UnitClassification ~= nil end,
    enable = function()
        F:Listen("rareAlerts", "PLAYER_TARGET_CHANGED", function()
            if InCombatLockdown() and F:GetOption("rareAlerts", "sound") then return end
            local classification = UnitClassification("target")
            if classification ~= "rare" and classification ~= "rareelite" then return end
            local guid = UnitGUID("target")
            local npcID = type(guid) == "string" and guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)") or nil
            local key = npcID or guid
            if F:GetOption("rareAlerts", "once") and key and rareSeen[key] then return end
            if key then rareSeen[key] = true end
            local name = UnitName and UnitName("target") or "A rare"
            F:Print("Rare: " .. name .. (npcID and (" (NPC " .. npcID .. ")") or "") .. ".")
            if F:GetOption("rareAlerts", "sound") and PlaySound and SOUNDKIT and SOUNDKIT.TELL_MESSAGE then
                PlaySound(SOUNDKIT.TELL_MESSAGE)
            end
        end)
    end,
})

local function tradeSummary()
    if not F:Active("tradeWarning") then return end
    if not GetTradePlayerItemLink then return end
    local parts = {}
    for index = 1, 6 do
        local link = GetTradePlayerItemLink(index)
        if type(link) == "string" then
            local info = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(link)
            local name = type(info) == "string" and info or link
            local level = C_Item and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link)
            local text = name
            if type(level) == "number" and level > 0 then text = text .. " (ilvl " .. level .. ")" end
            parts[#parts + 1] = text
        end
    end
    local signature = table.concat(parts, "|")
    if signature == "" or signature == lastTradeSignature then return end
    lastTradeSignature = signature
    F:Print("Trade window contains: " .. table.concat(parts, ", ") .. ". Check the offer before you accept.")
end

F:Register("tradeWarning", {
    title = "Trade window summary",
    category = "Quests",
    description = "Lists the items in your side of a trade with their item levels when the trade window changes, so a wrong item is visible before you accept. It never accepts, cancels or alters a trade.",
    disableText = "Stops summarising trades. An open trade is unchanged.",
    conflicts = common,
    available = function() return GetTradePlayerItemLink ~= nil end,
    enable = function()
        F:Listen("tradeWarning", "TRADE_SHOW", tradeSummary)
        F:Listen("tradeWarning", "TRADE_UPDATE", tradeSummary)
        F:Listen("tradeWarning", "TRADE_CLOSED", function() lastTradeSignature = nil end)
    end,
})

local function craftSummary()
    if not F:Active("craftWarning") then return end
    if not (GetTradeSkillInfo and GetTradeSkillSelectionIndex) then return end
    local selected = GetTradeSkillSelectionIndex()
    if type(selected) ~= "number" or selected <= 0 then return end
    local name = GetTradeSkillInfo(selected)
    if type(name) ~= "string" or name == lastCraftName then return end
    lastCraftName = name
    local reagents = {}
    if GetTradeSkillNumReagents and GetTradeSkillReagentInfo then
        local count = GetTradeSkillNumReagents(selected)
        for index = 1, (type(count) == "number" and count or 0) do
            local reagentName, _, needed = GetTradeSkillReagentInfo(selected, index)
            if type(reagentName) == "string" then
                reagents[#reagents + 1] = reagentName .. (type(needed) == "number" and (" x" .. needed) or "")
            end
        end
    end
    F:Print("Crafting " .. name .. (#reagents > 0 and (" with " .. table.concat(reagents, ", ")) or "") .. ".")
end

F:Register("craftWarning", {
    title = "Crafting confirmation text",
    category = "Quests",
    description = "Prints the selected recipe and its reagents when you change the recipe or press create, so an expensive craft is never started by accident. It is text only and never blocks or repeats a craft.",
    disableText = "Stops printing the craft summary.",
    conflicts = common,
    available = function() return GetTradeSkillInfo ~= nil and GetTradeSkillSelectionIndex ~= nil end,
    enable = function()
        F:Listen("craftWarning", "TRADE_SKILL_UPDATE", craftSummary)
        local button = _G.TradeSkillCreateButton or _G.CraftCreateButton
        if button and button.HookScript then
            button:HookScript("OnClick", craftSummary)
        end
    end,
})

F:Register("typedConfirm", {
    title = "Typed confirmation for settings resets",
    category = "Interface",
    description = "Requires the word confirm at the end of destructive ForeverSuite commands such as /fs reset, /fs profile delete and /fs chatlog clear. It protects your saved settings only; no item, quest or character action is affected.",
    disableText = "Stops requiring the extra word. Nothing is reset by turning the feature off.",
    conflicts = {},
    available = function() return true end,
    enable = function() end,
})
