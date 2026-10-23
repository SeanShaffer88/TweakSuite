-- SPDX-License-Identifier: MIT
-- Chat storage, saved channels, a whisper window, class colours and word filters.
local _, F = ...
local common = { "Prat-3.0", "Chatter", "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL" }
local MAX_LOG = 200
local MAX_FILTERS = 50

local CHAT_STORE_EVENTS = {
    CHAT_MSG_SAY = "Say", CHAT_MSG_YELL = "Yell", CHAT_MSG_WHISPER = "Whisper",
    CHAT_MSG_WHISPER_INFORM = "To", CHAT_MSG_PARTY = "Party", CHAT_MSG_PARTY_LEADER = "Party",
    CHAT_MSG_RAID = "Raid", CHAT_MSG_RAID_LEADER = "Raid", CHAT_MSG_GUILD = "Guild",
    CHAT_MSG_OFFICER = "Officer", CHAT_MSG_SYSTEM = "System",
}
local CHAT_FILTER_EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER" }

local function chatPrefix()
    return date and ("[" .. date("%H:%M") .. "] ") or ""
end

local function chatLog()
    if not F.db then return nil end
    if type(F.db.chatLog) ~= "table" then F.db.chatLog = {} end
    return F.db.chatLog
end

local function storeLine(channel, name, text, extra)
    local log = chatLog()
    if not log or type(text) ~= "string" or text == "" then return end
    local limit = F:GetOption("chatLogStore", "size") or MAX_LOG
    limit = math.max(20, math.min(MAX_LOG, limit))
    log[#log + 1] = { channel = channel, name = type(name) == "string" and name or "",
        text = text:sub(1, 400), time = (type(extra) == "number" and extra) or nil }
    while #log > limit do table.remove(log, 1) end
end

function F:ChatLog()
    local log = (self.db and type(self.db.chatLog) == "table") and self.db.chatLog or {}
    return log
end

function F:ChatLogText(count, name)
    local log = self:ChatLog()
    local lines = {}
    local start = #log - (tonumber(count) or 40) + 1
    if start < 1 then start = 1 end
    local wanted = type(name) == "string" and name:lower() or nil
    for index = start, #log do
        local entry = log[index]
        if type(entry) == "table" then
            if not wanted or (entry.name or ""):lower() == wanted then
                lines[#lines + 1] = (entry.channel and ("[" .. entry.channel .. "] ") or "")
                    .. (entry.name ~= "" and (entry.name .. ": ") or "") .. tostring(entry.text)
            end
        end
    end
    return table.concat(lines, "\n")
end

function F:ChannelList()
    local db = self.db
    if not db then return {} end
    if type(db.channels) ~= "table" then db.channels = {} end
    return db.channels
end

function F:AddChannel(name)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name == "" or #name > 40 then return false, "channel name must be 1-40 characters" end
    local list = self:ChannelList()
    if #list >= 10 then return false, "at most 10 saved channels" end
    for _, entry in ipairs(list) do
        if entry:lower() == name:lower() then return false, "that channel is already saved" end
    end
    list[#list + 1] = name
    return true
end

function F:RemoveChannel(name)
    local list = self:ChannelList()
    local lower = tostring(name or ""):lower()
    for index = #list, 1, -1 do
        if list[index]:lower() == lower then
            table.remove(list, index)
            if LeaveChannelByName then pcall(LeaveChannelByName, name) end
            if next(list) == nil then self.db.channels = nil end
            return true
        end
    end
    return false
end

function F:JoinSavedChannels()
    if not self:Active("chatChannels") then return end
    for _, name in ipairs(self:ChannelList()) do
        if JoinChannelByName then pcall(JoinChannelByName, name) end
    end
end

function F:ChatFilterList()
    if not self.db then return {} end
    if type(self.db.chatFilters) ~= "table" then self.db.chatFilters = {} end
    return self.db.chatFilters
end

function F:AddChatFilter(word)
    word = tostring(word or ""):match("^%s*(.-)%s*$")
    if word == "" or #word > 40 then return false, "use a word or phrase of 1-40 characters" end
    local list = self:ChatFilterList()
    if #list >= MAX_FILTERS then return false, "at most " .. MAX_FILTERS .. " filters" end
    for _, entry in ipairs(list) do
        if entry:lower() == word:lower() then return false, "that filter already exists" end
    end
    list[#list + 1] = word
    return true
end

function F:RemoveChatFilter(word)
    local list = self:ChatFilterList()
    local lower = tostring(word or ""):lower()
    for index = #list, 1, -1 do
        if list[index]:lower() == lower then table.remove(list, index); return true end
    end
    return false
end

local function matchesFilter(text)
    if type(text) ~= "string" then return false end
    local lower = text:lower()
    for _, word in ipairs(F:ChatFilterList()) do
        if lower:find(word:lower(), 1, true) then return true end
    end
    return false
end

-- Message filters must be registered once and decide from the live feature state.
local filterInstalled = {}
local function installMessageFilters()
    if not ChatFrame_AddMessageEventFilter then return end
    for _, event in ipairs(CHAT_FILTER_EVENTS) do
        if not filterInstalled[event] then
            filterInstalled[event] = true
            pcall(ChatFrame_AddMessageEventFilter, event, function(_, _, ...)
                local values = { ... }          -- 1 text, 2 player name, 12 guid
                local text, name = values[1], values[2]
                if F:Active("chatFilters") and matchesFilter(text) then return true end
                if not F:Active("chatClassColors") or type(name) ~= "string" then return end
                local guid = values[12]
                if type(guid) ~= "string" or not GetPlayerInfoByGUID then return end
                local _, classFile = GetPlayerInfoByGUID(guid)
                local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
                if type(color) ~= "table" then return end
                values[2] = string.format("|cff%02x%02x%02x%s|r",
                    math.floor((color.r or 1) * 255), math.floor((color.g or 1) * 255),
                    math.floor((color.b or 1) * 255), name)
                return false, unpack(values)
            end)
        end
    end
end

local whisperWindow
local function createWhisperWindow()
    local frame = CreateFrame("Frame", "ForeverSuiteWhisperWindow", UIParent)
    frame:SetSize(420, 300)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    end
    if frame.SetBackdropColor then frame:SetBackdropColor(0.12, 0.09, 0.06, 0.95) end
    if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(0.85, 0.65, 0.25, 1) end
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("Whisper log")
    frame.title = title
    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", 10, -30)
    body:SetPoint("BOTTOMRIGHT", -10, 40)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetText("")
    frame.body = body
    local edit = CreateFrame("EditBox", nil, frame)
    edit:SetPoint("BOTTOMLEFT", 10, 10)
    edit:SetPoint("BOTTOMRIGHT", -80, 10)
    edit:SetHeight(22)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(255)
    frame.edit = edit
    local send = CreateFrame("Button", nil, frame)
    send:SetSize(60, 22)
    send:SetPoint("BOTTOMRIGHT", -10, 10)
    local sendText = send:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sendText:SetPoint("CENTER")
    sendText:SetText("Send")
    frame.send = send
    frame.partner = nil
    frame:SetScript("OnShow", function(self)
        if self.partner then self.title:SetText("Whisper log: " .. self.partner) end
    end)
    send:SetScript("OnClick", function() F:SendWhisperFromWindow() end)
    if edit.SetScript then
        edit:SetScript("OnEnterPressed", function() F:SendWhisperFromWindow() end)
    end
    frame:Hide()
    return frame
end

function F:ShowWhisper(name)
    if not self:Active("whisperWindow") then return false, "enable the whisper window first" end
    if type(name) ~= "string" or name == "" then return false, "no player name" end
    if not whisperWindow then whisperWindow = createWhisperWindow() end
    whisperWindow.partner = name
    whisperWindow.title:SetText("Whisper log: " .. name)
    whisperWindow.body:SetText(self:ChatLogText(60, name))
    whisperWindow:Show()
    return true
end

function F:HideWhisper()
    if whisperWindow then whisperWindow:Hide() end
end

function F:RefreshWhisperWindow(name)
    if not whisperWindow or not whisperWindow:IsShown() then return end
    if name and whisperWindow.partner and name:lower() ~= whisperWindow.partner:lower() then return end
    whisperWindow.body:SetText(self:ChatLogText(60, whisperWindow.partner))
end

function F:SendWhisperFromWindow()
    if not whisperWindow or not whisperWindow.partner then return false, "no conversation open" end
    local text = whisperWindow.edit.GetText and whisperWindow.edit:GetText() or ""
    if type(text) ~= "string" or text == "" then return false, "nothing to send" end
    if InCombatLockdown() then return false, "cannot send during combat" end
    if SendChatMessage then pcall(SendChatMessage, text, "WHISPER", nil, whisperWindow.partner) end
    whisperWindow.edit:SetText("")
    return true
end

F:Register("chatLogStore", {
    title = "Persistent chat history",
    category = "Chat",
    description = "Keeps the last 200 chat lines, whispers and system messages in saved settings so a conversation survives a reload. /fs chatlog prints the stored lines into the copy window. It stores text only, never item or player data beyond the line itself.",
    disableText = "Stops recording new lines. Lines already stored stay saved until you clear them with /fs chatlog clear.",
    conflicts = { "Prat-3.0", "Chatter", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "whispersOnly", type = "boolean", title = "Only store whispers", default = false,
          description = "Keeps the saved history to whispers and replies, which is smaller and more private. Turn it off to store every channel." },
        { key = "size", type = "number", title = "Stored lines", default = 200, min = 20, max = 200, step = 20,
          description = "How many lines stay in saved settings. Older lines are dropped first." },
    },
    available = function() return ChatFrame1 ~= nil end,
    enable = function()
        for event, channel in pairs(CHAT_STORE_EVENTS) do
            F:Listen("chatLogStore", event, function(_, text, name, ...)
                local chosen = channel
                if (chosen == "Say" or chosen == "Yell" or chosen == "System") and F:GetOption("chatLogStore", "whispersOnly") then
                    return
                end
                if chosen == "Whisper" and F.db and type(name) == "string" then F.db.lastWhisper = name end
                storeLine(chosen, name, text, ...)
                F:RefreshWhisperWindow(name)
            end)
        end
    end,
})

F:Register("chatChannels", {
    title = "Saved chat channels",
    category = "Chat",
    description = "Remembers custom chat channels and joins them again after a reload or login, so a guild or server channel is never quietly missing. /fs channels add <name>, remove <name> and list manage the set.",
    disableText = "Stops joining saved channels automatically. Channels you have already joined stay joined until you leave them.",
    conflicts = common,
    available = function() return JoinChannelByName ~= nil end,
    enable = function()
        F:Listen("chatChannels", "PLAYER_LOGIN", function() F:JoinSavedChannels() end)
        F:JoinSavedChannels()
    end,
})

F:Register("chatClassColors", {
    title = "Class-coloured chat names",
    category = "Chat",
    description = "Colours the sender name of say, yell, party, raid, guild and whisper lines with that player's class colour. It only changes the displayed name and leaves the message text and links untouched.",
    disableText = "Stops colouring new lines. Lines already in the window keep the colour they were shown with.",
    conflicts = { "Prat-3.0", "Chatter", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function() return ChatFrame_AddMessageEventFilter ~= nil and GetPlayerInfoByGUID ~= nil end,
    enable = installMessageFilters,
})

F:Register("chatFilters", {
    title = "Chat word filter",
    category = "Chat",
    description = "Hides chat lines that contain a word or phrase you list, across say, yell, party, raid, guild and whisper. /fs filter add <word>, remove and list manage the list. It hides only matching lines and never blocks or alters what other players send.",
    disableText = "Shows every line again from now on. Filtered lines that were already hidden are not restored.",
    conflicts = { "Prat-3.0", "Chatter", "GlobalIgnore", "BadBoy" },
    available = function() return ChatFrame_AddMessageEventFilter ~= nil end,
    enable = installMessageFilters,
})

F:Register("whisperWindow", {
    title = "Whisper conversation window",
    category = "Chat",
    description = "Opens a small window with the stored conversation with one player and a reply box that sends a whisper. /fs whisper <name> opens it, /fs reply <text> sends a whisper to the same player, and /fs whisper close hides it.",
    disableText = "Closes the window and stops the whisper commands. Stored chat history is untouched.",
    conflicts = { "Prat-3.0", "Chatter", "WIM", "WhisperWindow" },
    available = function() return ChatFrame1 ~= nil and SendChatMessage ~= nil end,
    enable = function() end,
    disable = function() F:HideWhisper() end,
})

-- Whispers can arrive while the window is in the background, so this is a small,
-- separate feature: a sound and, optionally, the client's own tab flash.
local WHISPER_SOUNDS = {
    tell = { kit = 3081, file = "Sound\\Interface\\iTellMessage.wav" },
    bell = { kit = 3157, file = "Sound\\DingSmall.wav" },
}
local flashing = false

F:Register("whisperAlert", {
    title = "Whisper notification sound",
    category = "Chat",
    description = "Plays a quiet sound and, optionally, flashes the chat tab when a whisper arrives. The sound is chosen from two built-in client sounds and the tab flash uses the client's own alert, so nothing is drawn by ForeverSuite.",
    disableText = "Stops the sound and asks the client to stop flashing the chat tab.",
    conflicts = { "Prat-3.0", "Chatter", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "sound", type = "choice", title = "Whisper sound", default = "tell",
          choices = { { value = "tell", label = "Tell message" }, { value = "bell", label = "Small bell" }, { value = "none", label = "No sound" } },
          description = "Which built-in sound to play for an incoming whisper. No sound keeps the feature silent but still leaves the tab flash available." },
        { key = "flash", type = "boolean", title = "Flash the chat tab", default = true,
          description = "Uses the client's chat tab alert for a whisper that arrives while the chat window is not focused." },
    },
    available = function() return PlaySound ~= nil or PlaySoundFile ~= nil end,
    enable = function()
        F:Listen("whisperAlert", "CHAT_MSG_WHISPER", function()
            local choice = F:GetOption("whisperAlert", "sound") or "tell"
            local kit = WHISPER_SOUNDS[choice]
            if kit then
                local played = false
                if PlaySoundFile then played = pcall(PlaySoundFile, kit.file, "Master") end
                if not played and PlaySound then pcall(PlaySound, kit.kit, "Master") end
            end
            if F:GetOption("whisperAlert", "flash") ~= false and FCF_StartAlertFlash and ChatFrame1 then
                pcall(FCF_StartAlertFlash, ChatFrame1)
                flashing = true
            end
        end)
        F:Listen("whisperAlert", "CHAT_MSG_WHISPER_INFORM", function()
            if flashing and FCF_StopAlertFlash and ChatFrame1 then
                pcall(FCF_StopAlertFlash, ChatFrame1)
                flashing = false
            end
        end)
    end,
    disable = function()
        if flashing and FCF_StopAlertFlash and ChatFrame1 then pcall(FCF_StopAlertFlash, ChatFrame1) end
        flashing = false
    end,
})
