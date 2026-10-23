-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Quiet client popups: beta surveys, feedback prompts and the beta reporting button.
-- Everything is name based and guarded so a missing frame on either client is harmless.
local _, F = ...

local SURVEY_FRAMES = {
    "BetaSurveyFrame", "SurveyFrame", "BetaFeedbackFrame", "FeedbackFrame",
    "BetaSurveyPopup", "BetaFeedbackPopup", "SurveyPopup", "BetaPollFrame",
}
local REPORT_BUTTONS = {
    "BetaReportButton", "BugReportButton", "ReportBugButton", "ReporterButton",
    "BetaReporterButton", "MainMenuReportButton", "ReportFrameButton",
}
local REPORT_FRAMES = {
    "BugReportFrame", "ReportBugFrame", "BetaReportFrame", "BugReporterFrame", "ReportFrame",
}
local hooked = {}

local function firstFrame(names)
    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame then return frame, name end
    end
end

local function hideFrame(frame)
    if frame and frame.Hide then pcall(frame.Hide, frame) end
end

local function showFrame(frame)
    if frame and frame.Show then pcall(frame.Show, frame) end
end

local function hookHidden(frame, key)
    if not frame or hooked[key] then return end
    hooked[key] = true
    if frame.HookScript then
        frame:HookScript("OnShow", function(self)
            if F:Active("betaPopups") or F:Active("betaReporter") then hideFrame(self) end
        end)
    end
end

local function applySurveys()
    if not F:Active("betaPopups") then return end
    for _, name in ipairs(SURVEY_FRAMES) do
        local frame = _G[name]
        if frame then
            if frame:IsShown() then hideFrame(frame) end
            hookHidden(frame, "survey:" .. name)
        end
    end
end

local function applyReporter()
    local button = firstFrame(REPORT_BUTTONS)
    local hide = F:Active("betaReporter") and F:GetOption("betaReporter", "hideButton")
    for _, name in ipairs(REPORT_BUTTONS) do
        local frame = _G[name]
        if frame then
            if hide then
                if frame:IsShown() then hideFrame(frame) end
                hookHidden(frame, "button:" .. name)
            else
                showFrame(frame)
            end
        end
    end
    return button
end

function F:OpenBugReporter()
    local button = firstFrame(REPORT_BUTTONS)
    if button then
        if button.Show then showFrame(button) end
        if button.Click then
            local ok = pcall(button.Click, button)
            if ok then return true end
        end
        return true
    end
    local frame = firstFrame(REPORT_FRAMES)
    if frame then
        showFrame(frame)
        return true
    end
    return false
end

function F:BetaFrames(kind)
    local names = kind == "surveys" and SURVEY_FRAMES or (kind == "buttons" and REPORT_BUTTONS or REPORT_FRAMES)
    local present = {}
    for _, name in ipairs(names) do
        if _G[name] then present[#present + 1] = name end
    end
    return present
end

F:Register("betaPopups", {
    title = "Hide beta survey popups",
    category = "Interface",
    description = "Closes the beta survey and feedback prompts that the test client can show after a session. It only touches frames with a known survey name and never hides a quest, loot or error dialog.",
    disableText = "Stops closing survey frames. A survey that is open right now stays open until you close it.",
    conflicts = { "NoBugReportPopups", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "hideSurveys", type = "boolean", title = "Close survey prompts", default = true,
          description = "Hides every detected survey or feedback prompt as soon as it appears. Turning this off leaves the feature enabled but lets prompts show." },
    },
    available = function() return UIParent ~= nil end,
    enable = function()
        if F:GetOption("betaPopups", "hideSurveys") == false then return end
        applySurveys()
        F:Listen("betaPopups", "PLAYER_LOGIN", applySurveys)
        F:Listen("betaPopups", "ADDON_LOADED", applySurveys)
    end,
    refresh = function()
        if F:GetOption("betaPopups", "hideSurveys") == false then return end
        applySurveys()
    end,
    disable = function() end,
})

F:Register("betaReporter", {
    title = "Hide the beta reporter button",
    category = "Interface",
    description = "Removes the beta reporting button from the screen while keeping reporting available on demand. Use /ts bugreport to open the reporter at any time, which is how manual bug reports keep working after the button is hidden.",
    disableText = "Shows the reporter button again if the client has one, so reporting is back on the normal interface.",
    conflicts = { "NoBugReportPopups", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "hideButton", type = "boolean", title = "Hide the report button", default = true,
          description = "Hides the detected reporting button. Turn it off to keep the button visible while the feature, and the /ts bugreport command, stay available." },
    },
    available = function() return UIParent ~= nil end,
    enable = function()
        applyReporter()
        F:Listen("betaReporter", "PLAYER_LOGIN", function() applyReporter() end)
        F:Listen("betaReporter", "ADDON_LOADED", function() applyReporter() end)
    end,
    refresh = function() applyReporter() end,
    disable = function()
        for _, name in ipairs(REPORT_BUTTONS) do
            local frame = _G[name]
            if frame then showFrame(frame) end
        end
    end,
})
