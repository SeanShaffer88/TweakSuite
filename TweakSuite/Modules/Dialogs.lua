-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: MIT
-- Original keyboard dialog handling. The reference addon is used as a behavior baseline only.
local _, F = ...
-- Older client functions: the client's own global when present, else a private shim (Compat.lua).
local GetNumGossipOptions = F.Compat("GetNumGossipOptions")
local GetGossipOptions = F.Compat("GetGossipOptions")
local GetQuestLevel = F.Compat("GetQuestLevel")
local GetQuestGreenRange = F.Compat("GetQuestGreenRange")
local conflicts = { "DialogKey_Numy", "DialogKey", "Leatrix_Plus", "Leatrix_Plus_Forever",
    "EnhanceQoL", "TweaksForever" }
-- Accept is the only button that never has a reward-choice side effect. The two complete
-- buttons are used only when the client reports no reward choices to protect a manual pick.
local buttons = { "QuestFrameAcceptButton", "QuestFrameCompleteButton", "QuestFrameCompleteQuestButton" }
local hints = {}
local keyFrame

local function rewardChoices()
    if not GetNumQuestChoices then return nil end
    local choices = GetNumQuestChoices()
    if not F:Plain(choices) or type(choices) ~= "number" then return nil end
    return choices
end

local function visibleButton(name)
    local control = _G[name]
    if not control then return nil end
    if control.IsVisible and not control:IsVisible() then return nil end
    if control.IsEnabled and not control:IsEnabled() then return nil end
    return control
end

local function watchedButtons()
    local list = (F.db and F.db.watch) or {}
    return type(list) == "table" and list or {}
end

local function hintTarget()
    for _, name in ipairs(buttons) do
        local control = visibleButton(name)
        if control then
            if name == "QuestFrameAcceptButton" then return name, control end
            local choices = rewardChoices()
            if choices == 0 then return name, control end
        end
    end
end

local function keyLabel(key)
    if key == "SPACE" then return "Space" end
    if key == "ENTER" then return "Enter" end
    return tostring(key)
end

local function hideHints()
    for _, hint in pairs(hints) do hint:Hide() end
end

local function refreshHints()
    if InCombatLockdown() then return end
    if not F:Active("dialogAccept") or not F:GetOption("dialogAccept", "hint") then
        hideHints(); return
    end
    local targetName, target = hintTarget()
    if not target then
        for _, name in ipairs(watchedButtons()) do
            local control = visibleButton(name)
            if control then
                targetName, target = name, control
                break
            end
        end
    end
    for name, hint in pairs(hints) do
        if name ~= targetName then hint:Hide() end
    end
    if not target then return end
    local hint = hints[targetName]
    if not hint then
        hint = target:CreateFontString(nil, "OVERLAY")
        if GameFontNormalSmall then hint:SetFontObject(GameFontNormalSmall) end
        hint:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", 0, 2)
        hint:SetTextColor(1, 0.82, 0.22)
        hints[targetName] = hint
    end
    hint:SetText("[" .. keyLabel(F:GetOption("dialogAccept", "key")) .. "]")
    hint:Show()
end

local function questExcepted()
    if not F.QuestExcepted then return false end
    local ok, excepted = pcall(F.QuestExcepted, F)
    return ok and excepted == true
end

local function clickContinue()
    if questExcepted() then return false end
    for _, name in ipairs(watchedButtons()) do
        local control = visibleButton(name)
        if control then
            control:Click()
            return true
        end
    end
    for _, name in ipairs(buttons) do
        local control = visibleButton(name)
        if control then
            if name ~= "QuestFrameAcceptButton" then
                local choices = rewardChoices()
                if choices == nil or choices > 0 then return false end
            end
            control:Click()
            return true
        end
    end
    return false
end

local function selectReward(index)
    local choices = rewardChoices()
    if not choices or choices < 1 or index > choices then return false end
    for _, pattern in ipairs({ "QuestInfoItem%d", "QuestRewardItem%d" }) do
        local control = visibleButton(pattern:format(index))
        if control then
            control:Click()
            return true
        end
    end
    return false
end

-- Gossip selection. Money gossip is never chosen, so a number key cannot spend gold.
local function gossipOption(index)
    if not GossipFrame or not GossipFrame:IsShown() then return nil end
    if C_GossipInfo and C_GossipInfo.GetOptions then
        local options = C_GossipInfo.GetOptions()
        local entry = type(options) == "table" and options[index]
        if type(entry) == "table" then
            if type(entry.moneyCost) == "number" and entry.moneyCost > 0 then return nil end
            if type(entry.optionType) == "string" and entry.optionType:lower():find("money") then return nil end
            return index
        end
    end
    if not GetNumGossipOptions or not GetGossipOptions then return nil end
    local count = GetNumGossipOptions()
    if type(count) ~= "number" or index > count then return nil end
    local values = { GetGossipOptions() }
    local optionType = values[(index - 1) * 2 + 2]
    if type(optionType) == "string" and optionType:lower():find("money") then return nil end
    return index
end

local function selectGossip(index)
    if not (F:Active("gossipKeys") or F:Active("gossipPreferences")) or not SelectGossipOption then return false end
    local visible = gossipOption(index)
    if not visible then return false end
    SelectGossipOption(visible)
    return true
end

local function gossipCount()
    if C_GossipInfo and C_GossipInfo.GetOptions then
        local options = C_GossipInfo.GetOptions()
        if type(options) == "table" then return #options end
    end
    if GetNumGossipOptions then
        local count = GetNumGossipOptions()
        if type(count) == "number" then return count end
    end
end

-- Selects the only gossip option when it is free and the option is enabled. Never runs on money.
local function autoSingleGossip()
    if not F:Active("gossipKeys") or not F:GetOption("gossipKeys", "autoSingle") then return end
    if F:GetOption("gossipKeys", "autoSingle") ~= true then return end
    if InCombatLockdown() or not F:CanAutomate() then return end
    if gossipCount() ~= 1 then return end
    if gossipOption(1) then selectGossip(1) end
end

local function pressButton(name)
    local control = visibleButton(name)
    if control then control:Click(); return true end
    return false
end

-- Turn-in only runs when the client reports no reward choices, so a bound key can
-- never choose a reward for the player.
local function turnIn()
    if questExcepted() then return false end
    local choices = rewardChoices()
    if choices ~= nil and choices > 0 then return false end
    return pressButton("QuestFrameCompleteQuestButton")
end

local function syncKeyboard()
    if not keyFrame then return end
    local wanted = F:Active("dialogAccept") or F:Active("rewardKeys") or F:Active("gossipKeys")
        or F:Active("dialogKeys")
    if InCombatLockdown() then
        -- SetPropagateKeyboardInput is restricted in combat. Hide the catcher so it cannot
        -- hold on to keys; it is shown and reset after combat.
        if keyFrame:IsShown() then keyFrame:Hide() end
        return
    end
    if wanted then
        if not keyFrame:IsShown() then keyFrame:Show() end
        keyFrame:SetPropagateKeyboardInput(true)
    elseif keyFrame:IsShown() then
        keyFrame:Hide()
    end
end

local function onKeyDown(self, key)
    local consume = false
    if not InCombatLockdown() and F:CanAutomate() and type(key) == "string" then
        if F:Active("dialogAccept") and key == F:GetOption("dialogAccept", "key") then
            consume = clickContinue()
        elseif F:Active("dialogKeys") and key == F:GetOption("dialogKeys", "turnInKey") then
            consume = turnIn()
        elseif F:Active("dialogKeys") and key == F:GetOption("dialogKeys", "declineKey") then
            consume = pressButton("QuestFrameDeclineButton")
        elseif F:Active("rewardKeys") or F:Active("gossipKeys") then
            local digit = key:match("^([1-9])$") or key:match("^NUMPAD([1-9])$")
            if digit then
                local index = tonumber(digit)
                if F:Active("rewardKeys") then consume = selectReward(index) end
                if not consume then consume = selectGossip(index) end
            end
        end
    end
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(not consume) end
end

local function ensureKeyFrame()
    if keyFrame then return keyFrame end
    keyFrame = CreateFrame("Frame", "TweakSuiteKeyCatcher", UIParent)
    keyFrame:SetSize(1, 1)
    keyFrame:SetPoint("CENTER")
    keyFrame:SetFrameStrata("DIALOG")
    keyFrame:SetAlpha(0)
    keyFrame:EnableMouse(false)
    keyFrame:EnableKeyboard(true)
    keyFrame:SetPropagateKeyboardInput(true)
    keyFrame:SetScript("OnKeyDown", onKeyDown)
    keyFrame:Hide()
    return keyFrame
end

local function onDialogEvent()
    refreshHints()
    syncKeyboard()
end

F:Register("dialogAccept", {
    title = "Keyboard accept and continue",
    category = "Dialogs",
    description = "Press a chosen key to click the visible Accept or Continue button on quest dialogs. It never completes a quest that offers reward choices, never clicks Decline or Goodbye, never touches popup confirmations, and pauses in combat or while Shift is held.",
    disableText = "Stops listening for the dialog key immediately and removes the key hints. It does not close the current dialog.",
    conflicts = conflicts,
    options = {
        { key = "key", type = "choice", title = "Dialog key", default = "SPACE",
          choices = { { value = "SPACE", label = "Space" }, { value = "ENTER", label = "Enter" },
              { value = "E", label = "E" }, { value = "Q", label = "Q" }, { value = "F", label = "F" },
              { value = "R", label = "R" }, { value = "T", label = "T" }, { value = "G", label = "G" },
              { value = "V", label = "V" }, { value = "C", label = "C" }, { value = "X", label = "X" },
              { value = "Z", label = "Z" } },
          description = "Key pressed while a dialog button is available. The key passes through to the game when no matching dialog button is shown." },
        { key = "hint", type = "boolean", title = "Show key hint", default = true,
          description = "Shows the key in brackets beside the one dialog button it would press." },
    },
    available = function() return _G.QuestFrameAcceptButton and QuestFrameAcceptButton.Click and GetNumQuestChoices end,
    enable = function()
        ensureKeyFrame()
        F:Listen("dialogAccept", "PLAYER_REGEN_DISABLED", syncKeyboard)
        F:Listen("dialogAccept", "PLAYER_REGEN_ENABLED", syncKeyboard)
        F:Listen("dialogAccept", "QUEST_DETAIL", onDialogEvent)
        F:Listen("dialogAccept", "QUEST_PROGRESS", onDialogEvent)
        F:Listen("dialogAccept", "QUEST_COMPLETE", onDialogEvent)
        F:Listen("dialogAccept", "QUEST_ACCEPTED", refreshHints)
        F:Listen("dialogAccept", "QUEST_TURNED_IN", refreshHints)
        F:Listen("dialogAccept", "GOSSIP_SHOW", onDialogEvent)
        F:Listen("dialogAccept", "GOSSIP_CLOSED", refreshHints)
        refreshHints()
        syncKeyboard()
    end,
    refresh = function() refreshHints(); syncKeyboard() end,
    disable = function() hideHints(); syncKeyboard() end,
})

F:Register("rewardKeys", {
    title = "Number keys select quest rewards",
    category = "Dialogs",
    description = "While a quest reward choice is open, press 1 to 6 to select the matching reward. Selection never turns the quest in; you still confirm the final hand-in with the client's own button. Pauses in combat or while Shift is held.",
    disableText = "Stops number-key selection. An already selected reward stays selected.",
    conflicts = conflicts,
    available = function() return GetNumQuestChoices and (_G.QuestInfoItem1 or _G.QuestRewardItem1) end,
    enable = function()
        ensureKeyFrame()
        F:Listen("rewardKeys", "PLAYER_REGEN_DISABLED", syncKeyboard)
        F:Listen("rewardKeys", "PLAYER_REGEN_ENABLED", syncKeyboard)
        syncKeyboard()
    end,
    refresh = syncKeyboard,
    disable = syncKeyboard,
})

F:Register("gossipKeys", {
    title = "Number keys select gossip options",
    category = "Dialogs",
    description = "While a gossip dialog is open, press 1 to 9 to choose the matching option. Options that cost money are never chosen, so a number key cannot buy anything. It does not accept quests, turn in quests or touch popup confirmations, and it pauses in combat or while Shift is held.",
    disableText = "Stops number-key gossip selection immediately. The open gossip window is unchanged.",
    conflicts = conflicts,
    available = function()
        return _G.GossipFrame ~= nil and SelectGossipOption ~= nil
            and (GetNumGossipOptions ~= nil or (C_GossipInfo and C_GossipInfo.GetOptions ~= nil))
    end,
    options = {
        { key = "autoSingle", type = "boolean", title = "Choose a lone gossip option", default = false,
          description = "When a gossip window offers exactly one option and it does not cost money, choose it automatically. "
              .. "Dialogs with several options, money costs, quests or popups are never touched." },
    },
    enable = function()
        ensureKeyFrame()
        -- One listener per event: Listen replaces any earlier handler with the same id.
        F:Listen("gossipKeys", "PLAYER_REGEN_DISABLED", syncKeyboard)
        F:Listen("gossipKeys", "PLAYER_REGEN_ENABLED", syncKeyboard)
        F:Listen("gossipKeys", "GOSSIP_SHOW", function()
            syncKeyboard()
            autoSingleGossip()
        end)
        F:Listen("gossipKeys", "GOSSIP_CLOSED", syncKeyboard)
        syncKeyboard()
    end,
    refresh = syncKeyboard,
    disable = syncKeyboard,
})

local keyChoices = { { value = "NONE", label = "Not bound" } }
for _, entry in ipairs({ { "SPACE", "Space" }, { "ENTER", "Enter" }, { "BACKSPACE", "Backspace" },
    { "DELETE", "Delete" }, { "F", "F" }, { "G", "G" }, { "R", "R" }, { "T", "T" } }) do
    keyChoices[#keyChoices + 1] = { value = entry[1], label = entry[2] }
end

F:Register("dialogKeys", {
    title = "Custom dialog key bindings",
    category = "Dialogs",
    description = "Binds extra keys to the turn-in and decline buttons of quest dialogs, separately from the accept key. Turn-in waits until the client reports no reward choice, so a bound key cannot pick a reward for you. Decline only clicks the visible decline button.",
    disableText = "Removes the extra bindings immediately. The open dialog is unchanged and no button is pressed after the feature is off.",
    conflicts = conflicts,
    options = {
        { key = "turnInKey", type = "choice", title = "Turn-in key", default = "NONE", choices = keyChoices,
          description = "Presses the final turn-in button only when the quest shows no reward choices. Leave it unbound if you prefer to click turn-in yourself." },
        { key = "declineKey", type = "choice", title = "Decline key", default = "NONE", choices = keyChoices,
          description = "Clicks the visible decline button. Declining only closes the dialog; the quest stays in your log and can be accepted later." },
    },
    available = function() return _G.QuestFrameAcceptButton and _G.QuestFrameAcceptButton.Click end,
    enable = function()
        ensureKeyFrame()
        F:Listen("dialogKeys", "PLAYER_REGEN_DISABLED", syncKeyboard)
        F:Listen("dialogKeys", "PLAYER_REGEN_ENABLED", syncKeyboard)
        F:Listen("dialogKeys", "QUEST_COMPLETE", syncKeyboard)
        F:Listen("dialogKeys", "QUEST_DETAIL", syncKeyboard)
        syncKeyboard()
    end,
    refresh = syncKeyboard,
    disable = syncKeyboard,
})

local function questTitle()
    if GetTitleText then
        local ok, title = pcall(GetTitleText)
        if ok and type(title) == "string" then return title end
    end
    return nil
end

function F:QuestExceptionList()
    if not self.db then return { ids = {}, titles = {} } end
    if type(self.db.questExceptions) ~= "table" then self.db.questExceptions = { ids = {}, titles = {} } end
    local store = self.db.questExceptions
    if type(store.ids) ~= "table" then store.ids = {} end
    if type(store.titles) ~= "table" then store.titles = {} end
    return store
end

function F:QuestExcepted()
    if not self:Active("questExceptions") then return false end
    local store = self:QuestExceptionList()
    local id = GetQuestID and GetQuestID() or nil
    if type(id) == "number" then
        for _, entry in ipairs(store.ids) do if entry == id then return true end end
    end
    local title = questTitle()
    if title then
        local lower = title:lower()
        for _, entry in ipairs(store.titles) do
            if entry:lower() == lower then return true end
        end
    end
    return false
end

function F:AddQuestException(value)
    local text = tostring(value or ""):match("^%s*(.-)%s*$")
    if text == "" or #text > 120 then return false end
    local store = self:QuestExceptionList()
    local id = tonumber(text)
    if id then
        for _, entry in ipairs(store.ids) do if entry == id then return true end end
        store.ids[#store.ids + 1] = id
        return true, "id " .. id
    end
    local lower = text:lower()
    for _, entry in ipairs(store.titles) do if entry:lower() == lower then return true end end
    store.titles[#store.titles + 1] = text
    return true, "title \"" .. text .. "\""
end

function F:RemoveQuestException(value)
    local text = tostring(value or ""):match("^%s*(.-)%s*$")
    local store = self:QuestExceptionList()
    local id = tonumber(text)
    if id then
        for index = #store.ids, 1, -1 do
            if store.ids[index] == id then table.remove(store.ids, index); return true end
        end
        return false
    end
    local lower = text:lower()
    for index = #store.titles, 1, -1 do
        if store.titles[index]:lower() == lower then table.remove(store.titles, index); return true end
    end
    return false
end

function F:QuestExceptionCount()
    local store = self:QuestExceptionList()
    return #store.ids + #store.titles
end

F:Register("questExceptions", {
    title = "Quest acceptance exceptions",
    category = "Dialogs",
    description = "Keeps the keyboard accept and turn-in keys from pressing buttons for quests you list by ID or exact title, for example a quest whose reward you want to pick by hand. /ts quest except <id|title> adds one and /ts quest allow removes it. It never declines or abandons a quest.",
    disableText = "Stops honouring the exception list; the list itself is kept and applies again when the feature is turned back on.",
    conflicts = { "DialogKey", "DialogKey_Numy", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function() return GetQuestID ~= nil end,
    enable = function() end,
    disable = function() end,
})

local function trivialCheck()
    if not F:Active("trivialQuests") then return end
    if InCombatLockdown() or not F:CanAutomate() then return end
    if not (GetQuestLevel and UnitLevel and GetQuestGreenRange) then return end
    local level = GetQuestLevel()
    local player = UnitLevel("player")
    local green = GetQuestGreenRange()
    if type(level) ~= "number" or type(player) ~= "number" or type(green) ~= "number" then return end
    if level <= 0 or player <= 0 then return end
    if player - level < green then return end
    local title = questTitle() or "This quest"
    F:Print(title .. " is trivial for you (quest level " .. level .. ", you are " .. player .. ").")
end

F:Register("trivialQuests", {
    title = "Trivial quest notice",
    category = "Dialogs",
    description = "Prints one chat line when a quest dialog opens for a quest that is trivial for your level, using the client's own quest level and green range. It is only a notice: no quest is accepted, declined or hidden.",
    disableText = "Stops printing the notice. Quest dialogs themselves are unchanged.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL" },
    available = function() return GetQuestLevel ~= nil and GetQuestGreenRange ~= nil and UnitLevel ~= nil end,
    enable = function()
        F:Listen("trivialQuests", "QUEST_DETAIL", trivialCheck)
        F:Listen("trivialQuests", "QUEST_PROGRESS", trivialCheck)
    end,
})

function F:NpcKey()
    if not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, "npc")
    if not ok or type(guid) ~= "string" then return nil end
    local id = guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    return id
end

function F:GossipPreferences()
    if not self.db then return {} end
    if type(self.db.gossipPrefs) ~= "table" then self.db.gossipPrefs = {} end
    return self.db.gossipPrefs
end

function F:SetGossipPreference(index, npcKey)
    index = tonumber(index)
    if not index or index < 1 or index > 9 then return false, "option must be 1 to 9" end
    local key = npcKey or self:NpcKey()
    if not key then return false, "no gossip NPC in range" end
    self:GossipPreferences()[key] = math.floor(index)
    return true, key, math.floor(index)
end

function F:ClearGossipPreference(npcKey)
    local key = npcKey or self:NpcKey()
    if not key then return false, "no gossip NPC in range" end
    if self:GossipPreferences()[key] == nil then return false, "no preference for this NPC" end
    self:GossipPreferences()[key] = nil
    return true, key
end

function F:GossipPreferenceList()
    local rows = {}
    for key, index in pairs(self:GossipPreferences()) do
        rows[#rows + 1] = { npc = key, index = index }
    end
    table.sort(rows, function(a, b) return tostring(a.npc) < tostring(b.npc) end)
    return rows
end

local function applyGossipPreference()
    if not F:Active("gossipPreferences") then return end
    if InCombatLockdown() or not F:CanAutomate() then return end
    local key = F:NpcKey()
    if not key then return end
    local index = F:GossipPreferences()[key]
    if type(index) ~= "number" then return end
    if gossipOption(index) and selectGossip(index) then
        if F:GetOption("gossipPreferences", "announce") ~= false then
            F:Print("Chose gossip option " .. index .. " for this NPC.")
        end
    end
end

F:Register("gossipPreferences", {
    title = "Per-NPC gossip preferences",
    category = "Dialogs",
    description = "Remembers that you always choose a certain gossip option at a certain NPC and chooses it again the next time that NPC's gossip window opens. Options that cost money are never chosen, and the rule pauses in combat or while Shift is held. /ts gossip prefer <1-9> sets it for the NPC you are talking to.",
    disableText = "Stops choosing remembered gossip options. Everyone stays a normal gossip window, and saved preferences are kept.",
    conflicts = conflicts,
    options = {
        { key = "announce", type = "boolean", title = "Say when a preference was used", default = true,
          description = "Prints which gossip option was chosen automatically, so a dialog never advances silently." },
    },
    available = function()
        return SelectGossipOption ~= nil and UnitGUID ~= nil
            and (GetNumGossipOptions ~= nil or (C_GossipInfo and C_GossipInfo.GetOptions ~= nil))
    end,
    enable = function()
        F:Listen("gossipPreferences", "GOSSIP_SHOW", applyGossipPreference)
        applyGossipPreference()
    end,
})
