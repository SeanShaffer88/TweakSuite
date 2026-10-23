-- SPDX-License-Identifier: MIT
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
