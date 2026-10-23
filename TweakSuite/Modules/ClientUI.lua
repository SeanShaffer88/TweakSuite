-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: MIT
-- Client UI surfaces that TweakSuite only lightly touches: talking heads, event
-- toasts, sound channels and the minimap mask. Each feature restores what it changed.
local _, F = ...

-- ---------------------------------------------------------------------------
-- Talking heads

local talkHooked = false

local function talkingHeadFrame()
    return _G.TalkingHeadFrame
end

-- The client exposes the current line through C_TalkingHead. String fields are read
-- defensively because the structure differs between builds.
function F:TalkingHeadLine()
    if not (C_TalkingHead and C_TalkingHead.GetCurrentLineInfo) then return nil end
    local ok, info = pcall(C_TalkingHead.GetCurrentLineInfo)
    if not ok or type(info) ~= "table" then return nil end
    local speaker, text
    for key, value in pairs(info) do
        if type(value) == "string" and value ~= "" then
            if type(key) == "string" and key:lower():find("speaker") then speaker = value
            elseif type(key) == "string" and key:lower():find("text") then text = value
            elseif not text and #value > 8 then text = value end
        end
    end
    if not text then return nil end
    return { speaker = speaker, text = text }
end

local function applyTalkingHead()
    local frame = talkingHeadFrame()
    if not frame then return end
    if not F:Active("talkingHeads") then return end
    if F:GetOption("talkingHeads", "replace") ~= false then
        if frame.Hide then frame:Hide() end
    end
    local line = F:TalkingHeadLine()
    if line then
        F:Print((line.speaker or "Talking head") .. ": " .. line.text)
    end
    if not talkHooked and frame.HookScript then
        talkHooked = true
        frame:HookScript("OnShow", function()
            if F:Active("talkingHeads") and F:GetOption("talkingHeads", "replace") ~= false then
                if frame.Hide then frame:Hide() end
                local shown = F:TalkingHeadLine()
                if shown then F:Print((shown.speaker or "Talking head") .. ": " .. shown.text) end
            end
        end)
    end
end

F:Register("talkingHeads", {
    title = "Talking head replacement",
    category = "Interface",
    description = "Replaces the 3D talking head popup with a single chat line containing the speaker and text. The frame is only hidden, never modified, and turn it off to get the popup back.",
    disableText = "Stops hiding the popup. The next talking head appears normally.",
    conflicts = { "Leatrix_Plus", "Narcissus" },
    options = {
        { key = "replace", type = "boolean", title = "Hide the popup", default = true,
          description = "Hides the talking head frame while the line is printed to chat. Turn it off to keep the popup and only print the text." },
    },
    available = function() return C_TalkingHead ~= nil or _G.TalkingHeadFrame ~= nil end,
    enable = applyTalkingHead,
    refresh = applyTalkingHead,
    disable = function() end,
})

-- ---------------------------------------------------------------------------
-- Event toasts

local toastFrame

local function toastTick()
    if not F:Active("toastControl") then return end
    if F:GetOption("toastControl", "autoRemove") ~= true then return end
    if not (C_EventToastManager and C_EventToastManager.GetNextToastToDisplay) then return end
    local ok, toast = pcall(C_EventToastManager.GetNextToastToDisplay)
    if ok and toast ~= nil and C_EventToastManager.RemoveCurrentToast then
        pcall(C_EventToastManager.RemoveCurrentToast)
    end
end

F:Register("toastControl", {
    title = "Event toast controls",
    category = "Interface",
    description = "Removes the current client event toast with /ts toast, and can clear toasts automatically as they appear. Toasts are the small banners the client shows for events; nothing else is changed.",
    disableText = "Stops clearing toasts. Toasts already dismissed stay dismissed.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "autoRemove", type = "boolean", title = "Clear toasts automatically", default = false,
          description = "Removes each event toast as soon as the client queues it. Off by default so you can read them." },
    },
    available = function() return C_EventToastManager ~= nil end,
    enable = function()
        if not toastFrame then
            toastFrame = CreateFrame("Frame", "TweakSuiteToastWatch", UIParent)
            toastFrame:SetSize(1, 1)
            toastFrame.elapsed = 0
            toastFrame:SetScript("OnUpdate", function(self, delta)
                self.elapsed = (self.elapsed or 0) + (delta or 0)
                if self.elapsed < 1 then return end
                self.elapsed = 0
                toastTick()
            end)
        end
        toastFrame:Show()
    end,
    disable = function()
        if toastFrame then toastFrame:Hide() end
    end,
})

-- ---------------------------------------------------------------------------
-- Sound channel muting

local SOUND_CVARS = {
    master = "Sound_MasterVolume",
    music = "Sound_MusicVolume",
    ambience = "Sound_AmbienceVolume",
    dialog = "Sound_DialogVolume",
    sfx = "Sound_SFXVolume",
}

function F:SoundChannelNames()
    local names = {}
    for name in pairs(SOUND_CVARS) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function F:MuteSoundChannel(channel, mute)
    local cvar = SOUND_CVARS[channel]
    if not cvar then return false, "unknown sound channel" end
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return false, "this client cannot change sound volume" end
    if type(F.db) ~= "table" then return false, "settings are read only" end
    if type(F.db.mutedChannels) ~= "table" then F.db.mutedChannels = {} end
    local saved = F.db.mutedChannels
    if mute then
        if saved[channel] == nil then
            local ok, current = pcall(C_CVar.GetCVar, cvar)
            saved[channel] = ok and tonumber(current) or 1
        end
        pcall(C_CVar.SetCVar, cvar, "0")
    else
        local previous = saved[channel]
        if previous == nil then return false, "that channel was not muted by TweakSuite" end
        pcall(C_CVar.SetCVar, cvar, tostring(previous))
        saved[channel] = nil
        if next(saved) == nil then F.db.mutedChannels = nil end
    end
    return true
end

F:Register("soundMute", {
    title = "Sound channel muting",
    category = "Interface",
    description = "Silences one sound channel with /ts mute music|ambience|dialog|sfx|master and restores the exact previous volume with /ts mute <channel> off. It stores the old value, so nothing is guessed when restoring.",
    disableText = "Restores every channel TweakSuite muted and forgets the saved volumes.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function() return C_CVar ~= nil and C_CVar.SetCVar ~= nil end,
    enable = function() end,
    disable = function()
        local saved = F.db and F.db.mutedChannels
        if type(saved) ~= "table" then return end
        for channel, value in pairs(saved) do
            local cvar = SOUND_CVARS[channel]
            if cvar and C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, cvar, tostring(value)) end
        end
        F.db.mutedChannels = nil
    end,
})

-- ---------------------------------------------------------------------------
-- Minimap shape

local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"
local originalMask

function F:MinimapShape()
    return F:GetOption("minimapShape", "shape") or "round"
end

function F:ApplyMinimapShape()
    if not (Minimap and Minimap.SetMaskTexture) then return false end
    if originalMask == nil and Minimap.GetMaskTexture then
        local ok, mask = pcall(Minimap.GetMaskTexture, Minimap)
        if ok then originalMask = mask end
    end
    if not F:Active("minimapShape") or F:MinimapShape() ~= "square" then
        if originalMask then
            pcall(Minimap.SetMaskTexture, Minimap, originalMask)
        else
            pcall(Minimap.SetMaskTexture, Minimap, "Interface\\Minimap\\UI-Minimap-Background")
        end
        return true
    end
    pcall(Minimap.SetMaskTexture, Minimap, SQUARE_MASK)
    return true
end

F:Register("minimapShape", {
    title = "Minimap shape",
    category = "Interface",
    description = "Switches the minimap between the round mask and a square mask. Only the mask texture changes, so the map data and buttons are untouched. Use the Minimap scale feature for size.",
    disableText = "Puts the original minimap mask back.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "SexyMap" },
    options = {
        { key = "shape", type = "choice", title = "Minimap shape", default = "round",
          choices = { { value = "round", label = "Round" }, { value = "square", label = "Square" } },
          description = "Square uses the client's plain white mask, which some clients show as a rounded square. Round restores the original mask." },
    },
    available = function() return Minimap ~= nil and Minimap.SetMaskTexture ~= nil end,
    enable = F.ApplyMinimapShape,
    refresh = function() F:ApplyMinimapShape() end,
    disable = function() F:ApplyMinimapShape() end,
})
