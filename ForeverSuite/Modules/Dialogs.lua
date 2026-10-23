-- SPDX-License-Identifier: MIT
-- Original keyboard dialog handling. The reference addon is used as a behavior baseline only.
local _, F = ...
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

local function clickContinue()
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

local function syncKeyboard()
    if not keyFrame then return end
    local wanted = F:Active("dialogAccept") or F:Active("rewardKeys")
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
        elseif F:Active("rewardKeys") then
            local digit = key:match("^([1-9])$") or key:match("^NUMPAD([1-9])$")
            if digit then consume = selectReward(tonumber(digit)) end
        end
    end
    if not InCombatLockdown() then self:SetPropagateKeyboardInput(not consume) end
end

local function ensureKeyFrame()
    if keyFrame then return keyFrame end
    keyFrame = CreateFrame("Frame", "ForeverSuiteKeyCatcher", UIParent)
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
