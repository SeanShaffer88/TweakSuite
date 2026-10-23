-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Small visual frame tweaks for the client's own UI. Original implementation.
local _, F = ...
local common = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "TweaksForever" }

local function hideFrame(frame)
    if frame and frame.Hide then frame:Hide() end
end

local function showFrame(frame)
    if frame and frame.Show then frame:Show() end
end

local function simpleHide(id, title, description, disableText, frameNames, conflicts, category, restoreVisibility)
    local shownBefore = {}
    F:Register(id, {
        title = title,
        category = category or "Interface",
        description = description,
        disableText = disableText,
        conflicts = conflicts or common,
        available = function()
            for _, name in ipairs(frameNames) do
                if _G[name] ~= nil then return true end
            end
            return false
        end,
        enable = function()
            local function apply()
                for _, name in ipairs(frameNames) do
                    local frame = _G[name]
                    if frame then
                        if shownBefore[frame] == nil then shownBefore[frame] = frame:IsShown() == true end
                        hideFrame(frame)
                    end
                end
            end
            apply()
            F:Listen(id, "PLAYER_ENTERING_WORLD", apply)
            F:Listen(id, "PLAYER_REGEN_ENABLED", apply)
        end,
        refresh = function()
            for _, name in ipairs(frameNames) do hideFrame(_G[name]) end
        end,
        disable = function()
            -- Frames the client shows on demand stay hidden after the feature is off;
            -- forcing them visible would leave empty banner or zone text on screen.
            for _, name in ipairs(frameNames) do
                local frame = _G[name]
                if frame and restoreVisibility ~= false and shownBefore[frame] == true then
                    showFrame(frame)
                end
                if frame then shownBefore[frame] = nil end
            end
        end,
    })
end

simpleHide("hideGryphons", "Hide action bar gryphons",
    "Hides the two decorative gryphon end caps beside the main action bar. Bar buttons, bindings and paging are unchanged.",
    "Shows the client's gryphon end caps again.",
    { "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap" },
    { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "TweaksForever", "Bartender4" })

simpleHide("hideBossBanner", "Hide boss banner",
    "Hides the large boss encounter banner that covers the top of the screen. Encounter mechanics and warnings are not changed.",
    "Stops hiding the banner. The client shows it again for future encounters when it needs to; nothing is forced on screen.",
    { "BossBanner" },
    { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "DBM-Core", "BigWigs" },
    "Interface", false)

simpleHide("hideZoneText", "Hide zone name text",
    "Hides the large zone name that appears after loading or crossing a zone boundary. The minimap zone label and chat messages are unchanged.",
    "Stops hiding the zone name. The client shows it again at the next zone change; nothing is forced on screen.",
    { "ZoneTextFrame", "SubZoneTextFrame" },
    { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL" },
    "Interface", false)

simpleHide("hideChatButtons", "Hide chat window buttons",
    "Hides the chat menu and scroll buttons beside the chat windows. Chat, scrolling with the mouse wheel and typing are unchanged.",
    "Shows the client's chat buttons again.",
    { "ChatFrame1ButtonFrame", "ChatFrameMenuButton", "ChatFrame1UpButton", "ChatFrame1DownButton", "ChatFrame1BottomButton" },
    { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "Prat-3.0", "Chatter" },
    "Chat")

simpleHide("hideMinimapClock", "Hide the minimap clock",
    "Hides the clock button beside the minimap. The in-game time itself and chat timestamps are unchanged.",
    "Shows the client's clock button again.",
    { "TimeManagerClockButton", "GameTimeFrame" },
    { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL" })

simpleHide("hideMinimapZone", "Hide the minimap zone label",
    "Hides the zone name text on the minimap while keeping the minimap, tracking dots and the zone text shown at zone changes untouched.",
    "Shows the minimap zone label again.",
    { "MinimapZoneText", "MinimapZoneTextButton" },
    { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "SexyMap" })

simpleHide("hideMicroMenu", "Hide the micro menu",
    "Hides the row of small buttons that opens the spellbook, talents, quest log and the rest. The keyboard shortcuts and slash commands still open those windows.",
    "Shows the micro menu again.",
    { "MicroMenuContainer" },
    { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "Bartender4", "Dominos" })

local barHooked = false
local function barAlpha()
    local bar = _G.MainMenuBar
    if not bar or not bar.SetAlpha then return end
    if not F:Active("actionBarFade") then
        bar:SetAlpha(1); return
    end
    local alpha = F:GetOption("actionBarFade", "alpha") / 100
    local hovered = false
    if bar.IsMouseOver then hovered = bar:IsMouseOver() == true end
    if hovered then bar:SetAlpha(1) else bar:SetAlpha(alpha) end
end
F:Register("actionBarFade", { title = "Dim action bars until the mouse is over them", category = "Interface",
    description = "Lowers the opacity of the main action bar and restores full opacity while the mouse is over it. Buttons keep working and bindings are unchanged.",
    disableText = "Restores full opacity on the action bar.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "Bartender4", "Dominos", "ElvUI" },
    options = {
        { key = "alpha", type = "number", title = "Opacity when idle", default = 25, min = 0, max = 90, step = 5, unit = "%",
          description = "Opacity of the bar while the mouse is elsewhere. 0 makes the bar invisible until hovered. "
              .. "Not recommended for new players, because the bar looks missing." },
    },
    available = function() return _G.MainMenuBar ~= nil and MainMenuBar.SetAlpha ~= nil end,
    enable = function()
        local bar = _G.MainMenuBar
        if bar and not barHooked and bar.HookScript then
            bar:HookScript("OnEnter", barAlpha)
            bar:HookScript("OnLeave", barAlpha)
            bar:HookScript("OnShow", barAlpha)
            barHooked = true
        end
        barAlpha()
        F:Listen("actionBarFade", "PLAYER_ENTERING_WORLD", barAlpha)
    end,
    refresh = barAlpha,
    disable = function()
        local bar = _G.MainMenuBar
        if bar and bar.SetAlpha then bar:SetAlpha(1) end
    end })

local minimapSaved
F:Register("minimapScale", { title = "Minimap scale", category = "Interface",
    description = "Scales the minimap cluster by a percentage so it takes less or more screen space. Tracking dots, the zone label and the clock keep their relative position.",
    disableText = "Restores the minimap scale that was in use before TweakSuite changed it.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "SexyMap", "ElvUI" },
    options = {
        { key = "scale", type = "number", title = "Minimap size", default = 100, min = 60, max = 140, step = 5, unit = "%",
          description = "Percentage of the client's minimap size. 100 keeps the default. Very small values can hide the zone label." },
    },
    available = function()
        return _G.MinimapCluster ~= nil and MinimapCluster.SetScale ~= nil and MinimapCluster.GetScale ~= nil
    end,
    enable = function()
        local cluster = _G.MinimapCluster
        if minimapSaved == nil and cluster and cluster.GetScale then minimapSaved = cluster:GetScale() end
        if cluster then cluster:SetScale(F:GetOption("minimapScale", "scale") / 100) end
        F:Listen("minimapScale", "PLAYER_ENTERING_WORLD", function()
            if cluster then cluster:SetScale(F:GetOption("minimapScale", "scale") / 100) end
        end)
    end,
    refresh = function()
        local cluster = _G.MinimapCluster
        if cluster then cluster:SetScale(F:GetOption("minimapScale", "scale") / 100) end
    end,
    disable = function()
        local cluster = _G.MinimapCluster
        if cluster and type(minimapSaved) == "number" then cluster:SetScale(minimapSaved) end
        minimapSaved = nil
    end })
