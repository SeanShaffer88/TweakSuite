-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: MIT
local _, F = ...
local function cvarFeature(id, title, name, desired, description, options)
    if type(desired) ~= "function" then
        local value = desired
        desired = function() return value end
    end
    local function currentValue()
        local value = desired()
        if value == nil then return nil end
        return tostring(value)
    end
    local function apply()
        local want = currentValue()
        if not want or not C_CVar or not C_CVar.GetCVar or not C_CVar.SetCVar then return end
        local current = C_CVar.GetCVar(name)
        local saved = F.db.cvars[id]
        if type(saved) ~= "table" or type(saved.before) ~= "string" then
            F.db.cvars[id] = { before = current, applied = want }
        elseif current ~= saved.applied and current ~= want then
            -- Another tool changed the value after us; remember its value as the new baseline.
            F.db.cvars[id] = { before = current, applied = want }
        else
            saved.applied = want
        end
        C_CVar.SetCVar(name, want)
        assert(C_CVar.GetCVar(name) == want, "Client refused CVar " .. name)
    end
    local function restore()
        local saved = F.db.cvars[id]
        if type(saved) ~= "table" then F.db.cvars[id] = nil; return end
        if type(saved.before) == "string" and C_CVar and C_CVar.GetCVar and C_CVar.SetCVar then
            if C_CVar.GetCVar(name) == saved.applied then
                C_CVar.SetCVar(name, saved.before)
                if C_CVar.GetCVar(name) ~= saved.before then return end
            end
        end
        F.db.cvars[id] = nil
    end
    F:Register(id, { title = title, category = "Interface", description = description .. " Your prior value is restored when switched off, unless another tool changed it.",
        cvar = name, value = desired, options = options or {},
        disableText = "Restores the saved previous value if the client still has TweakSuite's value. If another tool changed it, that later value is preserved. Switching off does not necessarily set the opposite value.",
        conflicts = { "AdvancedInterfaceOptions", "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "TweaksForever" },
        available = function()
            return C_CVar and C_CVar.GetCVar and C_CVar.SetCVar and C_CVar.GetCVar(name) ~= nil
        end,
        enable = apply, refresh = apply, disable = restore })
end
cvarFeature("autoLoot", "Auto-loot by default", "autoLootDefault", "1", "Enables the client's auto-loot setting.")
cvarFeature("keyDown", "Cast on key press", "ActionButtonUseKeyDown", "1", "Activates action buttons on key press instead of release.")
cvarFeature("noGlow", "Disable full-screen glow", "ffxGlow", "0", "Disables the full-screen glow effect when this CVar exists.")
cvarFeature("nameplates", "Always show enemy nameplates", "nameplateShowAll", "1", "Keeps enabled enemy nameplates visible outside combat.")
cvarFeature("noLowHealthFlash", "Disable low-health screen flash", "doNotFlashLowHealthWarning", "1", "Disables the red screen flash at low health.")
cvarFeature("questText", "Instant quest text", "instantQuestText", "1", "Shows quest text immediately when supported by the client.")
cvarFeature("stackPlates", "Stack nameplates vertically", "nameplateMotion", "1", "Uses the client's stacking layout for nameplates.")
cvarFeature("classPlates", "Class colors on enemy nameplates", "ShowClassColorInNameplate", "1", "Uses class colors for supported player nameplates.")
cvarFeature("hideFriendlyPets", "Hide friendly pet nameplates", "nameplateShowFriendlyPets", "0", "Hides pet plates without hiding friendly players.")
cvarFeature("hideFriendlyGuardians", "Hide friendly guardian nameplates", "nameplateShowFriendlyGuardians", "0", "Reduces nameplate clutter from friendly guardians.")
cvarFeature("hideFriendlyTotems", "Hide friendly totem nameplates", "nameplateShowFriendlyTotems", "0", "Hides friendly totem plates.")
cvarFeature("hideEnemyPets", "Hide enemy pet nameplates", "nameplateShowEnemyPets", "0", "Hides enemy pet plates; enemy player plates keep their own setting.")
cvarFeature("enemyTotems", "Show enemy totem nameplates", "nameplateShowEnemyTotems", "1", "Enables nameplates for enemy totems.")
cvarFeature("personalResource", "Always show personal resource bar", "nameplatePersonalShowAlways", "1", "Keeps the enabled personal resource display visible outside combat.")
cvarFeature("targetOfTarget", "Show target of target", "showTargetOfTarget", "1", "Enables the client's target-of-target display.")
cvarFeature("hideOwnName", "Hide your overhead name", "UnitNameOwn", "0", "Removes your character's own overhead name.")
cvarFeature("hideTitles", "Hide player titles", "UnitNamePlayerPVPTitle", "0", "Hides titles in overhead player names.")
cvarFeature("hideGuildNames", "Hide overhead guild names", "UnitNamePlayerGuild", "0", "Hides guild names above player characters.")
cvarFeature("hideGuildRanks", "Hide overhead guild ranks", "UnitNameGuildTitle", "0", "Hides guild ranks above player characters.")
cvarFeature("hideCritterNames", "Hide critter names", "UnitNameNonCombatCreatureName", "0", "Hides overhead names on noncombat creatures.")
cvarFeature("noCameraBobbing", "Disable camera bobbing", "cameraBobbing", "0", "Disables the client camera's bobbing setting.")
cvarFeature("noTerrainTilt", "Disable camera terrain tilt", "cameraTerrainTilt", "0", "Disables automatic terrain tilt when the CVar exists.")
cvarFeature("noWaterCollision", "Disable camera water collision", "cameraWaterCollision", "0", "Allows the camera to cross the water surface.")
cvarFeature("chatWheel", "Enable chat mouse-wheel scrolling", "chatMouseScroll", "1", "Enables chat scrolling with the mouse wheel when supported.")
cvarFeature("noLootHistory", "Do not auto-open loot history", "autoOpenLootHistory", "0", "Keeps loot history from opening automatically.")
cvarFeature("noSpellAlerts", "Hide spell activation overlays", "displaySpellActivationOverlays", "0", "Hides the client's on-screen spell activation artwork.")

cvarFeature("autoQuestWatch", "Track accepted quests automatically", "autoQuestWatch", "1",
    "Adds newly accepted quests to the quest tracker when the client supports automatic tracking.")
cvarFeature("autoQuestProgress", "Automatic quest progress updates", "autoQuestProgress", "1",
    "Updates objective progress in the quest tracker as it happens.")
cvarFeature("mapQuestDifficulty", "Quest difficulty on the world map", "mapQuestDifficulty", "1",
    "Colors quest entries on the world map by their difficulty against your level.")
cvarFeature("questTooltips", "Quest tracking tooltips", "showQuestTrackingTooltips", "1",
    "Shows the detailed quest tooltip when hovering a tracked objective.")
cvarFeature("cooldownCount", "Numeric cooldown countdowns", "countdownForCooldowns", "1",
    "Shows the remaining seconds as numbers on cooldown buttons and auras.")
cvarFeature("targetCastbar", "Target cast bar", "showTargetCastbar", "1",
    "Shows the client's cast bar for your current target.")
cvarFeature("lockActionBars", "Lock action bars", "lockActionBars", "1",
    "Prevents spells and items from being dragged out of action bar slots. Keys and clicks keep working.")
cvarFeature("alwaysShowActionBars", "Always show action bars", "alwaysShowActionBars", "1",
    "Keeps action bars visible instead of fading them out when they are not in use.")
cvarFeature("safeAbilityToggle", "Prevent right-click auto-cast toggling", "secureAbilityToggle", "1",
    "Blocks right-clicking an action button from switching auto-cast on or off, avoiding accidental toggles.")
cvarFeature("allTargetDebuffs", "Show every aura on your target", "noBuffDebuffFilterOnTarget", "1",
    "Removes the client's buff and debuff filtering on the target frame.")
cvarFeature("buffDurations", "Aura durations", "buffDurations", "1",
    "Shows the remaining time on buff and debuff icons.")
cvarFeature("autoSelfCast", "Automatic self-cast", "autoSelfCast", "1",
    "Casts helpful spells on yourself when no valid target is selected.")
cvarFeature("emphasizeSpells", "Emphasize your own spell effects", "emphasizeMySpellEffects", "1",
    "Keeps your own spell effects prominent where the client supports the setting.")
cvarFeature("chatBubbles", "Chat bubbles above players", "chatBubbles", "1",
    "Shows nearby player chat as bubbles above their heads.")
cvarFeature("partyBubbles", "Party chat bubbles", "chatBubblesParty", "1",
    "Shows party member chat as bubbles above their heads.")
cvarFeature("fctDamage", "Hide damage numbers", "floatingCombatTextCombatDamage", "0",
    "Hides the floating damage numbers from your combat log on screen.")
cvarFeature("fctHealing", "Hide healing numbers", "floatingCombatTextCombatHealing", "0",
    "Hides the floating healing numbers from your combat log on screen.")
cvarFeature("rotateMinimap", "Rotate the minimap", "rotateMinimap", "1",
    "Turns the minimap with your character's facing direction instead of keeping north at the top.")
cvarFeature("chatTimestamps", "Timestamps in chat", "showTimestamps", "1",
    "Adds a local time stamp in front of each chat message.")
cvarFeature("thousandsSeparators", "Thousands separators in large numbers", "breakUpLargeNumbers", "1",
    "Groups long numbers such as damage, healing and money with a separator so they are easier to read.")
cvarFeature("autoPushSpells", "New spells go to the action bar", "autoPushSpellToActionBar", "1",
    "Places newly learned spells on the first free action bar slot when the client supports automatic placement.")
cvarFeature("friendlyNameplates", "Always show friendly nameplates", "nameplateShowFriends", "1",
    "Keeps nameplates visible for friendly players outside combat.")
cvarFeature("nameplateScale", "Nameplate scale", "nameplateGlobalScale",
    function() return tostring(F:GetOption("nameplateScale", "scale") / 100) end,
    "Scales nameplates as a percentage of their default size. The client may clamp extreme values.",
    { { key = "scale", type = "number", title = "Nameplate size (percent)", default = 100, min = 50, max = 200, step = 5, unit = "%",
        description = "100 keeps the client size. Larger values make nameplates easier to read but take more screen space." } })
cvarFeature("noDeathEffect", "Disable the death screen effect", "ffxDeath", "0",
    "Removes the desaturated death effect overlay when you die. The release dialog and corpse behavior are unchanged.")
cvarFeature("autoTrackFaction", "Track reputation changes automatically", "autoTrackReputation", "1",
    "Watches the faction whose reputation changes, so its progress bar updates without manual selection.")
cvarFeature("nameplateDistance", "Nameplate maximum distance", "nameplateMaxDistance",
    function() return tostring(F:GetOption("nameplateDistance", "distance")) end,
    "Sets how far away enemy and friendly nameplates remain visible, in yards. The client may clamp the value.",
    { { key = "distance", type = "number", title = "Maximum distance", default = 40, min = 20, max = 60, step = 1, unit = " yd",
        description = "Nameplates beyond this distance fade out. 40 yards matches the usual client default; 60 keeps distant plates visible longer and costs more drawing time." } })
cvarFeature("cameraZoom", "Maximum camera zoom distance", "cameraDistanceMaxZoomFactor",
    function() return tostring(F:GetOption("cameraZoom", "distance")) end,
    "Sets how far the camera may zoom out. Higher values allow a wider view; the client may clamp very large values.",
    { { key = "distance", type = "number", title = "Zoom distance factor", default = 2, min = 1, max = 4, step = 0.1,
        integer = false,
        description = "Camera distance multiplier. 1 is the closest view, 2 is the common default, 4 is the widest this setting allows. Some clients clamp the value." } })

for category, ids in pairs({
    Nameplates = { "nameplates", "stackPlates", "classPlates", "hideFriendlyPets", "hideFriendlyGuardians", "hideFriendlyTotems", "hideEnemyPets", "enemyTotems", "personalResource", "nameplateDistance", "nameplateScale", "friendlyNameplates" },
    ["Overhead names"] = { "hideOwnName", "hideTitles", "hideGuildNames", "hideGuildRanks", "hideCritterNames" },
    Camera = { "noCameraBobbing", "noTerrainTilt", "noWaterCollision" },
    Chat = { "chatWheel", "chatBubbles", "partyBubbles", "chatTimestamps" },
}) do
    for _, id in ipairs(ids) do F.features[id].category = category end
end

local fadeSaved, arrowSaved = {}, {}
local function chatFrames(callback)
    for _, name in ipairs(CHAT_FRAMES or {}) do if _G[name] then callback(_G[name], name) end end
end
F:Register("chatFade", { title = "Keep chat text visible", category = "Chat",
    disableText = "Restores each chat window's previous fading setting if it still has the value applied by TweakSuite.",
    description = "Disables fading on existing chat windows. Restores their previous fading setting when switched off.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "EnhanceQoLChatSocial", "Prat-3.0" },
    available = function() return ChatFrame1 and ChatFrame1.GetFading and ChatFrame1.SetFading end,
    enable = function()
        local function apply()
            chatFrames(function(frame)
                if frame.GetFading and frame.SetFading then
                    if fadeSaved[frame] == nil then fadeSaved[frame] = frame:GetFading() end
                    frame:SetFading(false)
                end
            end)
        end
        apply(); F:Listen("chatFade", "UPDATE_CHAT_WINDOWS", apply)
    end,
    disable = function()
        for frame, value in pairs(fadeSaved) do
            if not frame:GetFading() then frame:SetFading(value) end
            fadeSaved[frame] = nil
        end
    end })
F:Register("chatArrows", { title = "Arrow keys edit chat", category = "Chat",
    disableText = "Restores each chat edit box's previous Alt-arrow behavior if it still has the value applied by TweakSuite.",
    description = "Lets arrow keys move the text cursor without holding Alt. Restores each edit box when switched off.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "EnhanceQoLChatSocial", "Prat-3.0" },
    available = function() return ChatFrame1EditBox and ChatFrame1EditBox.GetAltArrowKeyMode end,
    enable = function()
        local function apply()
            chatFrames(function(_, name)
                local edit = _G[name .. "EditBox"]
                if edit and edit.GetAltArrowKeyMode and edit.SetAltArrowKeyMode then
                    if arrowSaved[edit] == nil then arrowSaved[edit] = edit:GetAltArrowKeyMode() end
                    edit:SetAltArrowKeyMode(false)
                end
            end)
        end
        apply(); F:Listen("chatArrows", "UPDATE_CHAT_WINDOWS", apply)
    end,
    disable = function()
        for edit, value in pairs(arrowSaved) do
            if not edit:GetAltArrowKeyMode() then edit:SetAltArrowKeyMode(value) end
            arrowSaved[edit] = nil
        end
    end })

local trackerHooked, trackerWasShown = false, false
local function hideTracker()
    if not F:Active("hideObjectiveTracker") then return end
    if ObjectiveTrackerFrame and ObjectiveTrackerFrame.Hide then ObjectiveTrackerFrame:Hide() end
end
F:Register("hideObjectiveTracker", { title = "Hide the objective tracker", category = "Interface",
    description = "Hides the quest objective tracker while the feature is on. Quests are still accepted, tracked and completed normally; only the on-screen list is hidden.",
    disableText = "Shows the client's objective tracker again with the quests that are currently tracked.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "Questie" },
    available = function() return ObjectiveTrackerFrame ~= nil and ObjectiveTrackerFrame.Hide ~= nil end,
    enable = function()
        if ObjectiveTrackerFrame then trackerWasShown = ObjectiveTrackerFrame:IsShown() == true end
        if not trackerHooked and ObjectiveTrackerFrame and ObjectiveTrackerFrame.HookScript then
            ObjectiveTrackerFrame:HookScript("OnShow", hideTracker)
            trackerHooked = true
        end
        hideTracker()
        F:Listen("hideObjectiveTracker", "PLAYER_ENTERING_WORLD", hideTracker)
        F:Listen("hideObjectiveTracker", "QUEST_LOG_UPDATE", hideTracker)
        F:Listen("hideObjectiveTracker", "QUEST_ACCEPTED", hideTracker)
        F:Listen("hideObjectiveTracker", "QUEST_TURNED_IN", hideTracker)
    end,
    refresh = hideTracker,
    disable = function()
        if trackerWasShown and ObjectiveTrackerFrame and ObjectiveTrackerFrame.Show then
            ObjectiveTrackerFrame:Show()
        end
        trackerWasShown = false
    end })

local fontSaved = {}
local function applyChatFont()
    if not F:Active("chatFont") then return end
    local size = F:GetOption("chatFont", "size")
    if type(size) ~= "number" then return end
    chatFrames(function(frame)
        if frame.GetFont and frame.SetFont then
            local font, current, flags = frame:GetFont()
            if type(font) == "string" and type(current) == "number" then
                if type(fontSaved[frame]) ~= "table" then
                    fontSaved[frame] = { font = font, size = current, flags = flags }
                end
                frame:SetFont(fontSaved[frame].font, size, fontSaved[frame].flags)
            end
        end
    end)
end
F:Register("chatFont", { title = "Chat font size", category = "Chat",
    description = "Changes the text size of existing chat windows without changing the font itself. Newly created chat windows pick up the size when the window list changes.",
    disableText = "Restores each chat window's previous font size if it still has the size applied by TweakSuite.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "Prat-3.0", "Chatter" },
    options = {
        { key = "size", type = "number", title = "Font size", default = 14, min = 10, max = 24, step = 1, unit = "pt",
          description = "Chat text size in points. 14 matches the usual client default; larger values are easier to read but fit less text per line." },
    },
    available = function()
        return ChatFrame1 ~= nil and ChatFrame1.GetFont ~= nil and ChatFrame1.SetFont ~= nil
    end,
    enable = function()
        applyChatFont()
        F:Listen("chatFont", "UPDATE_CHAT_WINDOWS", applyChatFont)
        F:Listen("chatFont", "PLAYER_ENTERING_WORLD", applyChatFont)
    end,
    refresh = applyChatFont,
    disable = function()
        for frame, saved in pairs(fontSaved) do
            if frame.SetFont and saved then frame:SetFont(saved.font, saved.size, saved.flags) end
            fontSaved[frame] = nil
        end
    end })

local clampSaved = {}
F:Register("chatUnclamp", { title = "Let chat windows leave the screen", category = "Chat",
    description = "Removes the screen-edge clamp from chat windows so they can be dragged partly off screen, for example to hide them beyond the UI edge. Unlock the chat frame to drag them.",
    disableText = "Restores the previous screen clamp on each chat window.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "Prat-3.0", "Chatter" },
    available = function() return ChatFrame1 ~= nil and ChatFrame1.SetClampedToScreen ~= nil end,
    enable = function()
        local function apply()
            chatFrames(function(frame)
                if frame.SetClampedToScreen then
                    if clampSaved[frame] == nil and frame.IsClampedToScreen then
                        clampSaved[frame] = frame:IsClampedToScreen() ~= false
                    end
                    frame:SetClampedToScreen(false)
                end
            end)
        end
        apply(); F:Listen("chatUnclamp", "UPDATE_CHAT_WINDOWS", apply)
    end,
    refresh = function() end,
    disable = function()
        for frame, wasClamped in pairs(clampSaved) do
            if wasClamped and frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
            clampSaved[frame] = nil
        end
    end })

local function tellSound()
    if SOUNDKIT and SOUNDKIT.TELL_MESSAGE ~= nil then return SOUNDKIT.TELL_MESSAGE end
    return "TellMessage"
end
F:Register("whisperSound", { title = "Sound for incoming whispers", category = "Chat",
    description = "Plays the client's tell sound when another player whispers you, so a quiet chat window does not hide the message. It does not play for your own outgoing whispers.",
    disableText = "Stops playing the extra sound. Chat itself is unchanged.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "Prat-3.0" },
    options = {
        { key = "muteInCombat", type = "boolean", title = "Mute during combat", default = false,
          description = "Skips the sound while you are in combat. The whisper still appears in chat either way." },
    },
    available = function() return PlaySound ~= nil or PlaySoundFile ~= nil end,
    enable = function()
        F:Listen("whisperSound", "CHAT_MSG_WHISPER", function()
            if F:GetOption("whisperSound", "muteInCombat") == true and InCombatLockdown() then return end
            if PlaySound then
                PlaySound(tellSound())
            elseif PlaySoundFile and SOUNDKIT and SOUNDKIT.TELL_MESSAGE_FILE then
                PlaySoundFile(SOUNDKIT.TELL_MESSAGE_FILE)
            end
        end)
    end })

local maxLinesSaved = {}
local function applyChatHistory()
    if not F:Active("chatHistory") then return end
    local lines = F:GetOption("chatHistory", "lines")
    if type(lines) ~= "number" then return end
    chatFrames(function(frame)
        if not frame.SetMaxLines then return end
        if maxLinesSaved[frame] == nil then
            maxLinesSaved[frame] = frame.GetMaxLines and frame:GetMaxLines() or 128
        end
        frame:SetMaxLines(lines)
    end)
end
F:Register("chatHistory", { title = "Chat history length", category = "Chat",
    description = "Keeps more lines of chat in memory per window than the client default, so scrolling back reaches further. It changes scrollback only; the visible window size and font are unchanged.",
    disableText = "Restores each chat window's previous scrollback limit if TweakSuite was the one that raised it.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "Prat-3.0", "Chatter" },
    options = {
        { key = "lines", type = "number", title = "Lines kept per window", default = 512, min = 128, max = 2048, step = 128, unit = " lines",
          description = "How many past messages each chat window keeps for scrolling. Higher values use more memory; 128 matches the usual client default." },
    },
    available = function() return ChatFrame1 ~= nil and ChatFrame1.SetMaxLines ~= nil end,
    enable = function()
        applyChatHistory()
        F:Listen("chatHistory", "UPDATE_CHAT_WINDOWS", applyChatHistory)
        F:Listen("chatHistory", "PLAYER_ENTERING_WORLD", applyChatHistory)
    end,
    refresh = applyChatHistory,
    disable = function()
        for frame, saved in pairs(maxLinesSaved) do
            if frame.SetMaxLines and type(saved) == "number" then frame:SetMaxLines(saved) end
            maxLinesSaved[frame] = nil
        end
    end })

-- Recent chat lines, kept for /ts copy. Nothing is written to disk.
local chatLog, CHAT_LOG_MAX = {}, 200
local CHAT_EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT" }
local chatHooked = false
local function recordChat(_, message, author)
    if type(message) ~= "string" then return end
    chatLog[#chatLog + 1] = (type(author) == "string" and author ~= "" and (author .. ": ") or "") .. message
    while #chatLog > CHAT_LOG_MAX do table.remove(chatLog, 1) end
end

function F:CopyChat(count)
    count = tonumber(count) or 20
    if count < 1 then count = 1 end
    if count > CHAT_LOG_MAX then count = CHAT_LOG_MAX end
    if #chatLog == 0 then
        self:Print("No chat lines recorded yet. Lines are recorded while TweakSuite is loaded.")
        return 0
    end
    local first = math.max(1, #chatLog - count + 1)
    local lines = {}
    for index = first, #chatLog do lines[#lines + 1] = chatLog[index] end
    self:ShowReport(table.concat(lines, "\n"))
    return #lines
end

F:Register("copyChat", { title = "Copy recent chat", category = "Chat",
    description = "Keeps the last 200 chat lines in memory and opens them in a selectable box with /ts copy. Nothing is written to disk and nothing is sent to other players.",
    disableText = "Stops copying. /ts copy then reports that the feature is off.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "Prat-3.0", "Chatter" },
    available = function() return 1 == 1 end,
    enable = function()
        if not chatHooked then
            for _, event in ipairs(CHAT_EVENTS) do F:Listen("copyChat", event, recordChat) end
            chatHooked = true
        else
            for _, event in ipairs(CHAT_EVENTS) do F:Listen("copyChat", event, recordChat) end
        end
    end,
    disable = function() end })

local stickyHooked = false
local function stickyButtons()
    if not F:Active("stickyChatButtons") then return end
    local frame = _G.ChatFrame1ButtonFrame
    if frame and frame.SetAlpha then frame:SetAlpha(1) end
    if frame and frame.Show then frame:Show() end
end
F:Register("stickyChatButtons", { title = "Keep chat buttons visible", category = "Chat",
    description = "Stops the chat menu and scroll buttons from fading away when the mouse is not over the chat, so they are always clickable.",
    disableText = "Stops forcing the buttons visible; the client fades them again on its own.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "Prat-3.0", "Chatter" },
    available = function() return _G.ChatFrame1ButtonFrame ~= nil end,
    enable = function()
        local frame = _G.ChatFrame1ButtonFrame
        if frame and not stickyHooked and frame.HookScript then
            frame:HookScript("OnShow", stickyButtons)
            stickyHooked = true
        end
        stickyButtons()
        F:Listen("stickyChatButtons", "UPDATE_CHAT_WINDOWS", stickyButtons)
    end,
    refresh = stickyButtons,
    disable = function() end })

local editPoints = {}
local function placeEditBox()
    local edit = _G.ChatFrame1EditBox
    local frame = _G.ChatFrame1
    if not edit or not frame or not edit.SetPoint then return end
    if F:GetOption("chatEditPosition", "where") == "top" then
        if editPoints[edit] == nil then editPoints[edit] = true end
        edit:ClearAllPoints()
        edit:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
        edit:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 2)
    elseif editPoints[edit] then
        edit:ClearAllPoints()
        edit:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        edit:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        editPoints[edit] = nil
    end
end
F:Register("chatEditPosition", { title = "Chat edit box position", category = "Chat",
    description = "Places the chat input line above the chat frame instead of at the bottom of it, so typing does not cover the newest messages.",
    disableText = "Puts the input line back at the bottom of the chat frame.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "Prat-3.0" },
    options = {
        { key = "where", type = "choice", title = "Input line position", default = "bottom",
          choices = { { value = "bottom", label = "Bottom (client default)" }, { value = "top", label = "Above the chat frame" } },
          description = "Where the typing line sits. Above the frame keeps the newest messages visible while typing." },
    },
    available = function() return _G.ChatFrame1EditBox ~= nil and _G.ChatFrame1 ~= nil end,
    enable = function()
        placeEditBox()
        F:Listen("chatEditPosition", "UPDATE_CHAT_WINDOWS", placeEditBox)
    end,
    refresh = placeEditBox,
    disable = function()
        for edit in pairs(editPoints) do
            edit:ClearAllPoints()
            edit:SetPoint("BOTTOMLEFT", _G.ChatFrame1, "BOTTOMLEFT", 0, 0)
            edit:SetPoint("BOTTOMRIGHT", _G.ChatFrame1, "BOTTOMRIGHT", 0, 0)
        end
        editPoints = {}
    end })

local xpStart, xpStartTime = nil, nil
local function xpSnapshot()
    if not F:Active("xpTracker") then return end
    if type(UnitXP) ~= "function" or type(GetTime) ~= "function" then return end
    local xp, maxXP = UnitXP("player"), UnitXPMax("player")
    if type(xp) ~= "number" or type(maxXP) ~= "number" or maxXP <= 0 then return end
    if xpStart == nil then
        xpStart, xpStartTime = xp, GetTime()
        return
    end
    local elapsed = GetTime() - (xpStartTime or GetTime())
    if elapsed < 60 then return end
end
function F:XPRate()
    if not xpStart then return nil end
    local elapsed = (GetTime and GetTime() or 0) - (xpStartTime or 0)
    if elapsed < 1 then return nil end
    local gained = (UnitXP("player") or 0) - xpStart
    return gained, elapsed, gained / elapsed * 3600
end
F:Register("xpTracker", { title = "Experience per hour", category = "Interface",
    description = "Records experience gained since the feature was switched on and reports the rate with /ts xp. It reads experience only and never changes quests, rests or bonuses.",
    disableText = "Stops recording. The last recorded rate stays available until the feature is enabled again.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "TitanPanel" },
    available = function() return UnitXP ~= nil and UnitXPMax ~= nil and GetTime ~= nil end,
    enable = function()
        xpStart, xpStartTime = nil, nil
        xpSnapshot()
        F:Listen("xpTracker", "PLAYER_XP_UPDATE", xpSnapshot)
        F:Listen("xpTracker", "PLAYER_ENTERING_WORLD", xpSnapshot)
    end,
    refresh = function() end,
    disable = function() xpStart, xpStartTime = nil, nil end })
