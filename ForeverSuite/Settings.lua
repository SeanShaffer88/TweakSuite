-- SPDX-License-Identifier: MIT
-- Original UI. Leatrix Plus's published gallery informs the visual direction only.
local _, F = ...
local categories = { "Home", "All tweaks", "Automation", "Tooltips", "Interface", "Nameplates", "Overhead names", "Camera", "Chat" }
local function label(parent, text, size)
    local font = parent:CreateFontString(nil, "OVERLAY", size or "GameFontNormal")
    font:SetText(text); font:SetJustifyH("LEFT"); font:SetJustifyV("TOP")
    return font
end
local function button(parent, text, width, callback)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(width, 24); control:SetText(text); control:SetScript("OnClick", callback)
    return control
end
local function window(name, title, width, height)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(width, height); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true); frame:EnableMouse(true); frame:SetMovable(true)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    frame:SetBackdropColor(0.095, 0.08, 0.06, 0.98)
    frame:SetBackdropBorderColor(0.28, 0.23, 0.12, 0.9)
    frame.heading = label(frame, title, "GameFontNormalLarge")
    frame.heading:SetPoint("TOPLEFT", 20, -18); frame.heading:SetTextColor(1, 0.82, 0.22)
    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT", 12, -8); drag:SetPoint("TOPRIGHT", -40, -8); drag:SetHeight(34)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() frame:StartMoving() end)
    drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3); close:SetScript("OnClick", function() frame:Hide() end)
    UISpecialFrames[#UISpecialFrames + 1] = name
    frame:Hide()
    return frame
end

function F:DetailText(id)
    local feature = self.features[id]
    local lines = { feature.title, "", "What it does", feature.description,
        "", "Default", feature.defaultText, "", "When switched off", feature.disableText,
        "", "During combat", feature.combatText, "", "Current status: " .. feature.state }
    if feature.category == "Automation" then lines[#lines + 1] = "Actions also pause in combat or while Shift is held." end
    if feature.category == "Tooltips" then lines[#lines + 1] = "This preview adds tooltip lines only outside combat." end
    local conflicts = table.concat(feature.conflicts or {}, ", ")
    if conflicts ~= "" then
        lines[#lines + 1] = ""; lines[#lines + 1] = "Overlapping addons: " .. conflicts
        lines[#lines + 1] = "A loaded overlap blocks this feature even if its internal option is off. Disable that addon and reload for a controlled test."
    end
    if feature.cvar then lines[#lines + 1] = "\nClient setting: " .. feature.cvar .. " = " .. feature.value end
    lines[#lines + 1] = "\nCommand: /fs on " .. id .. "  or  /fs off " .. id
    return table.concat(lines, "\n")
end

function F:ShowDetails(id)
    if not self.detailsWindow then
        local frame = window("ForeverSuiteDetails", "Setting details", 620, 540)
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 22, -54); scroll:SetPoint("BOTTOMRIGHT", -36, 20)
        local content = CreateFrame("Frame", nil, scroll); content:SetWidth(552)
        frame.body = label(content, "", "GameFontHighlight")
        frame.body:SetPoint("TOPLEFT"); frame.body:SetWidth(548)
        scroll:SetScrollChild(content); frame.content = content; frame.scroll = scroll
        self.detailsWindow = frame
    end
    local frame = self.detailsWindow
    frame.body:SetText(self:DetailText(id))
    frame.content:SetHeight(frame.body:GetStringHeight() + 20)
    frame.scroll:SetVerticalScroll(0); frame.scroll:UpdateScrollChildRect(); frame:Show()
end

function F:ShowReport(text)
    if not self.reportWindow then
        local frame = window("ForeverSuiteReport", "ForeverSuite diagnostic report", 700, 510)
        local hint = label(frame, "Ctrl+A, Ctrl+C to copy feature status and recent errors.", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 20, -48)
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 20, -78); scroll:SetPoint("BOTTOMRIGHT", -38, 20)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetWidth(630); edit:SetHeight(390); edit:SetMultiLine(true); edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal); edit:SetMaxLetters(20000)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        edit:SetScript("OnTextChanged", function() scroll:UpdateScrollChildRect() end)
        scroll:SetScrollChild(edit); frame.edit = edit; self.reportWindow = frame
    end
    self.reportWindow.edit:SetText(text)
    self.reportWindow:Show(); self.reportWindow.edit:SetFocus(); self.reportWindow.edit:HighlightText()
end

local function hoverDetails(control, id)
    control:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        local feature = F.features[id]
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(feature.title, 1, 0.82, 0.22)
        GameTooltip:AddLine(feature.description, 0.95, 0.91, 0.82, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Default: Off. " .. feature.disableText, 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Status: " .. feature.state, 1, 0.82, 0.22, true)
        GameTooltip:AddLine("Details shows conflicts, combat behavior and commands.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function F:RefreshSettings()
    if not self.window then return end
    local frame, query = self.window, self.window.search:GetText():lower()
    local selected = self.selectedCategory or "Home"
    local home = selected == "Home" and query == ""
    frame.home:SetShown(home); frame.scroll:SetShown(not home)
    local visible, active, enabled = 0, 0, 0
    for _, id in ipairs(self.order) do
        self.rows[id]:Hide()
        if self:Active(id) then active = active + 1 end
        if self.db.enabled[id] then enabled = enabled + 1 end
    end
    for _, heading in pairs(self.groupHeadings) do heading:Hide() end
    local y = -4
    if not home then
        for _, category in ipairs(categories) do
            if category ~= "Home" and category ~= "All tweaks" then
                local matches = {}
                for _, id in ipairs(self.order) do
                    local feature = self.features[id]
                    local text = (feature.title .. " " .. feature.category .. " " .. feature.description .. " " .. id):lower()
                    if feature.category == category and ((query ~= "" and text:find(query, 1, true))
                        or (query == "" and (selected == "All tweaks" or selected == category))) then
                        matches[#matches + 1] = id
                    end
                end
                if #matches > 0 then
                    local heading = self.groupHeadings[category]
                    heading:ClearAllPoints(); heading:SetPoint("TOPLEFT", 4, y); heading:Show(); y = y - 26
                    for index, id in ipairs(matches) do
                        local feature, row = self.features[id], self.rows[id]
                        local column = (index - 1) % 2
                        row:ClearAllPoints(); row:SetPoint("TOPLEFT", column * 320, y - math.floor((index - 1) / 2) * 114)
                        row:Show(); row.check:SetChecked(self.db.enabled[id] == true); row.check:SetEnabled(not self.readOnly)
                        row.status:SetText(feature.state); row.status:SetTextColor(feature.state == "active" and 0.45 or 0.85, feature.state == "active" and 0.9 or 0.74, 0.5)
                        visible = visible + 1
                    end
                    y = y - math.ceil(#matches / 2) * 114 - 12
                end
            end
        end
    end
    frame.content:SetHeight(math.max(1, -y)); frame.scroll:UpdateScrollChildRect()
    frame.pageTitle:SetText(query ~= "" and "Search results" or selected)
    frame.summary:SetText(active .. " active / " .. #self.order .. " settings"
        .. (self.paused and "  |  Paused" or "") .. (self.pending and "  |  Waiting for combat to end" or ""))
    frame.homeStats:SetText(#self.order .. " settings available in this preview\n" .. active .. " active; " .. enabled .. " requested\nClient " .. (self.build or "unknown"))
    for category, control in pairs(self.categoryButtons) do
        control.selected:SetShown(selected == category)
    end
    frame.empty:SetShown(not home and visible == 0)
end

function F:OpenSettings()
    self:Initialize()
    if not self.window then self:SetupSettings() end
    self:RefreshSettings(); self.window:Show()
end

function F:SetupSettings()
    if self.window then return end
    self.rows, self.categoryButtons, self.groupHeadings = {}, {}, {}
    local frame = window("ForeverSuiteOptions", "ForeverSuite", 850, 610)
    self.window = frame
    local version = label(frame, self.version, "GameFontHighlightSmall"); version:SetPoint("TOPLEFT", 20, -42)
    local side = frame:CreateTexture(nil, "BACKGROUND")
    side:SetPoint("TOPLEFT", 5, -60); side:SetPoint("BOTTOMLEFT", 5, 6); side:SetWidth(159)
    side:SetColorTexture(0.04, 0.03, 0.02, 0.35)
    frame.pageTitle = label(frame, "Home", "GameFontNormalLarge"); frame.pageTitle:SetPoint("TOPLEFT", 180, -20)
    frame.search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.search:SetSize(270, 24); frame.search:SetPoint("TOPRIGHT", -45, -18)
    frame.search:SetAutoFocus(false); frame.search:SetMaxLetters(100)
    frame.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame.search:SetScript("OnTextChanged", function()
        if frame.scroll then frame.scroll:SetVerticalScroll(0) end
        F:RefreshSettings()
    end)
    local searchHint = label(frame, "Search all settings", "GameFontDisableSmall")
    searchHint:SetPoint("TOPRIGHT", -48, -46)
    frame.summary = label(frame, "", "GameFontHighlightSmall"); frame.summary:SetPoint("TOPLEFT", 180, -48)
    for index, category in ipairs(categories) do
        local control = CreateFrame("Button", nil, frame)
        control:SetSize(144, 26); control:SetPoint("TOPLEFT", 13, -78 - (index - 1) * 32)
        control.selected = control:CreateTexture(nil, "BACKGROUND"); control.selected:SetAllPoints()
        control.selected:SetColorTexture(0.42, 0.34, 0.02, 0.5)
        local text = label(control, category); text:SetPoint("LEFT", 10, 0); text:SetTextColor(1, 0.82, 0.22)
        control:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        control:SetScript("OnClick", function()
            F.selectedCategory = category; frame.search:SetText(""); frame.scroll:SetVerticalScroll(0); F:RefreshSettings()
        end)
        self.categoryButtons[category] = control
    end
    local note = label(frame, "Every setting starts off.\n\nHover for an explanation.\nDetails covers defaults,\nrestoration and conflicts.", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 22, -405); note:SetWidth(134)
    frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 178, -82); frame.scroll:SetPoint("BOTTOMRIGHT", -30, 61)
    frame.content = CreateFrame("Frame", nil, frame.scroll); frame.content:SetSize(634, 1); frame.scroll:SetScrollChild(frame.content)
    frame.empty = label(frame, "No matching settings. Try a shorter search.", "GameFontHighlight")
    frame.empty:SetPoint("TOPLEFT", 192, -100); frame.empty:Hide()
    for _, category in ipairs(categories) do
        self.groupHeadings[category] = label(frame.content, category, "GameFontNormalLarge")
    end
    for _, id in ipairs(self.order) do
        local feature = self.features[id]
        local row = CreateFrame("Frame", nil, frame.content); row:SetSize(310, 108)
        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetPoint("TOPLEFT", 0, 0); row.check:SetSize(26, 26)
        row.check:SetScript("OnClick", function(self) F:SetEnabled(id, self:GetChecked() == true); F:RefreshSettings() end)
        hoverDetails(row.check, id)
        local title = label(row, feature.title); title:SetPoint("TOPLEFT", 28, -4); title:SetWidth(222)
        row.status = label(row, "", "GameFontHighlightSmall"); row.status:SetPoint("TOPLEFT", 28, -37); row.status:SetWidth(278)
        local summary = feature.description:match("^(.-%.)") or feature.description
        local description = label(row, summary, "GameFontHighlightSmall")
        description:SetPoint("TOPLEFT", 28, -61); description:SetWidth(278)
        local details = button(row, "?", 24, function() F:ShowDetails(id) end)
        details:SetPoint("TOPRIGHT", -3, 1); hoverDetails(details, id)
        self.rows[id] = row
    end
    frame.home = CreateFrame("Frame", nil, frame)
    frame.home:SetPoint("TOPLEFT", 184, -90); frame.home:SetSize(620, 430)
    local welcome = label(frame.home, "Welcome to ForeverSuite", "GameFontNormalLarge"); welcome:SetPoint("TOPLEFT", 0, 0)
    local intro = label(frame.home, "A growing collection of optional tweaks for WoW Forever.\n\nChoose a category on the left, or search for a setting above.\nEach checkbox controls one feature. Its status tells you whether it is active.\n\nHover over a checkbox or its ? button for a quick explanation.\nClick ? for the full effect, default, restore behavior and conflicts.", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", 0, -40); intro:SetWidth(590)
    frame.homeStats = label(frame.home, "", "GameFontNormal"); frame.homeStats:SetPoint("TOPLEFT", 0, -202)
    local preview = label(frame.home, "Development preview\n\nThe complete addon collection is being consolidated in stages.\nKeep your existing addons available while individual replacements are tested.\nAn overlapping loaded addon blocks the matching ForeverSuite feature.\n\nHold Shift to skip automation. Use /fs cap 10 to set the repair limit.", "GameFontHighlightSmall")
    preview:SetPoint("TOPLEFT", 0, -270); preview:SetWidth(590)
    local pause = button(frame, "Pause / resume", 120, function() F.paused = not F.paused; F:Refresh(); F:RefreshSettings() end)
    pause:SetPoint("BOTTOMLEFT", 180, 18)
    local allOff = button(frame, "Switch all off", 120, function()
        if F.readOnly then return end
        for _, id in ipairs(F.order) do F.db.enabled[id] = false end
        F:Refresh(); F:RefreshSettings()
    end)
    allOff:SetPoint("LEFT", pause, "RIGHT", 8, 0)
    local report = button(frame, "Diagnostic report", 145, function() F:ShowReport(F:Report()) end)
    report:SetPoint("BOTTOMRIGHT", -24, 18)
    frame:SetScript("OnShow", function() F:RefreshSettings() end)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local panel = CreateFrame("Frame")
        local title = label(panel, "ForeverSuite", "GameFontNormalLarge"); title:SetPoint("TOPLEFT", 16, -16)
        local open = button(panel, "Open ForeverSuite", 180, function() F:OpenSettings() end); open:SetPoint("TOPLEFT", 16, -55)
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, "ForeverSuite"))
    end
end
