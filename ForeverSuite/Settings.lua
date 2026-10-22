-- SPDX-License-Identifier: MIT
local _, F = ...
local function label(parent, text, size)
    local font = parent:CreateFontString(nil, "OVERLAY", size or "GameFontNormal")
    font:SetText(text); font:SetJustifyH("LEFT")
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
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    local heading = label(frame, title, "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 20, -18)
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

function F:ShowReport(text)
    if not self.reportWindow then
        local frame = window("ForeverSuiteReport", "ForeverSuite diagnostic report", 700, 510)
        local hint = label(frame, "Ctrl+A, Ctrl+C to copy. This report contains feature status and recent errors.", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", 20, -48)
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 20, -78); scroll:SetPoint("BOTTOMRIGHT", -38, 20)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetWidth(630); edit:SetHeight(390); edit:SetMultiLine(true); edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal); edit:SetMaxLetters(20000)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        edit:SetScript("OnTextChanged", function() scroll:UpdateScrollChildRect() end)
        scroll:SetScrollChild(edit)
        frame.edit = edit; self.reportWindow = frame
    end
    self.reportWindow.edit:SetText(text)
    self.reportWindow:Show(); self.reportWindow.edit:SetFocus(); self.reportWindow.edit:HighlightText()
end

function F:RefreshSettings()
    if not self.window then return end
    local query = self.window.search:GetText():lower()
    local y, visible = -8, 0
    for _, id in ipairs(self.order) do
        local feature, row = self.features[id], self.rows[id]
        local haystack = (feature.title .. " " .. feature.category .. " " .. feature.description .. " " .. id):lower()
        local selected = self.selectedCategory or "All tweaks"
        local matchesCategory = selected == "All tweaks" or selected == feature.category
        -- Search is global so a setting cannot be hidden by the selected category.
        if (query ~= "" and haystack:find(query, 1, true)) or (query == "" and matchesCategory) then
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, y); row:Show()
            row.check:SetChecked(self.db.enabled[id] == true)
            row.check:SetEnabled(not self.readOnly)
            row.status:SetText(feature.state)
            row.status:SetTextColor(feature.state == "active" and 0.4 or 0.95, feature.state == "active" and 0.9 or 0.7, 0.6)
            y = y - 100; visible = visible + 1
        else row:Hide() end
    end
    self.window.content:SetHeight(math.max(1, -y))
    self.window.scroll:UpdateScrollChildRect()
    self.window.summary:SetText((query ~= "" and "Search results" or (self.selectedCategory or "All tweaks")) .. ": " .. visible .. " of " .. #self.order .. " settings | " .. (self.paused and "Paused" or "Ready")
        .. (self.pending and " | Changes waiting for combat to end" or ""))
    for category, control in pairs(self.categoryButtons or {}) do
        local count = 0
        for _, id in ipairs(self.order) do if category == "All tweaks" or self.features[id].category == category then count = count + 1 end end
        control:SetText(((self.selectedCategory or "All tweaks") == category and "> " or "") .. category .. " (" .. count .. ")")
    end
    self.window.empty:SetShown(visible == 0)
end

function F:ShowDetails(id)
    local feature = self.features[id]
    if not self.detailsWindow then
        local frame = window("ForeverSuiteDetails", "Setting details", 620, 500)
        frame.body = label(frame, "", "GameFontHighlight")
        frame.body:SetPoint("TOPLEFT", 24, -58); frame.body:SetWidth(570)
        self.detailsWindow = frame
    end
    local conflicts = table.concat(feature.conflicts or {}, ", ")
    local lines = {
        feature.title .. "  [" .. feature.category .. "]",
        "", "What it does", feature.description,
        "", "Default", feature.defaultText,
        "", "When switched off", feature.disableText,
        "", "During combat", feature.combatText,
        "", "Current status: " .. feature.state,
    }
    if feature.category == "Automation" then lines[#lines + 1] = "Actions also pause in combat or while Shift is held." end
    if feature.category == "Tooltips" then lines[#lines + 1] = "This preview adds tooltip lines only outside combat." end
    if conflicts ~= "" then
        lines[#lines + 1] = ""; lines[#lines + 1] = "Overlapping addons: " .. conflicts
        lines[#lines + 1] = "A loaded overlap blocks this feature even if its internal option is off. Disable that addon and reload for a controlled test."
    end
    if feature.cvar then
        lines[#lines + 1] = ""; lines[#lines + 1] = "Client setting: " .. feature.cvar .. " = " .. feature.value
    end
    self.detailsWindow.body:SetText(table.concat(lines, "\n")); self.detailsWindow:Show()
end

function F:OpenSettings()
    self:Initialize()
    if not self.window then self:SetupSettings() end
    self:RefreshSettings(); self.window:Show()
end

function F:SetupSettings()
    if self.window then return end
    self.rows = {}
    local frame = window("ForeverSuiteOptions", "ForeverSuite  |  " .. self.version, 960, 650)
    self.window = frame
    local intro = label(frame, "Stage 1 preview for Forever beta and launch clients. Every feature starts off.\nConflicts mean another loaded addon may do the same job. Disable that addon and reload to test this feature.", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", 20, -50); intro:SetWidth(910)
    frame.search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.search:SetSize(340, 26); frame.search:SetPoint("TOPLEFT", 26, -94)
    frame.search:SetAutoFocus(false); frame.search:SetMaxLetters(100)
    frame.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame.search:SetScript("OnTextChanged", function()
        if frame.scroll then frame.scroll:SetVerticalScroll(0) end
        F:RefreshSettings()
    end)
    local searchLabel = label(frame, "Search features", "GameFontHighlightSmall")
    searchLabel:SetPoint("LEFT", frame.search, "RIGHT", 14, 0)
    local report = button(frame, "Diagnostic report", 145, function() F:ShowReport(F:Report()) end)
    report:SetPoint("TOPRIGHT", -24, -94)
    frame.summary = label(frame, "", "GameFontHighlightSmall")
    frame.summary:SetPoint("TOPLEFT", 202, -134)
    self.categoryButtons = {}
    local categories = { "All tweaks", "Automation", "Tooltips", "Interface", "Nameplates", "Overhead names", "Camera", "Chat" }
    for index, category in ipairs(categories) do
        local control = button(frame, category, 166, function()
            F.selectedCategory = category; frame.search:SetText(""); frame.scroll:SetVerticalScroll(0); F:RefreshSettings()
        end)
        control:SetPoint("TOPLEFT", 20, -158 - (index - 1) * 34)
        self.categoryButtons[category] = control
    end
    local defaults = label(frame, "Every setting starts off.\n\nDetails explains defaults,\nrestore behavior and\naddon conflicts.", "GameFontHighlightSmall")
    defaults:SetPoint("TOPLEFT", 24, -450); defaults:SetWidth(158)
    frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 200, -158); frame.scroll:SetPoint("BOTTOMRIGHT", -40, 58)
    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetSize(708, 1); frame.scroll:SetScrollChild(frame.content)
    frame.empty = label(frame, "No matching settings. Try a shorter search.", "GameFontHighlight")
    frame.empty:SetPoint("TOPLEFT", 222, -180); frame.empty:Hide()
    for _, id in ipairs(self.order) do
        local feature = self.features[id]
        local row = CreateFrame("Frame", nil, frame.content); row:SetSize(708, 94)
        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetPoint("TOPLEFT", 0, -1); row.check:SetSize(26, 26)
        row.check:SetScript("OnClick", function(self) F:SetEnabled(id, self:GetChecked() == true); F:RefreshSettings() end)
        local title = label(row, feature.title); title:SetPoint("TOPLEFT", 32, -4)
        row.status = label(row, "", "GameFontHighlightSmall"); row.status:SetPoint("TOPRIGHT", -8, -6)
        local description = label(row, feature.description, "GameFontHighlightSmall")
        description:SetPoint("TOPLEFT", 32, -29); description:SetWidth(655)
        local meta = label(row, feature.category .. " | /fs on " .. id .. " | /fs off " .. id, "GameFontDisableSmall")
        meta:SetPoint("BOTTOMLEFT", 32, 7)
        local details = button(row, "Details", 62, function() F:ShowDetails(id) end)
        details:SetPoint("BOTTOMRIGHT", -8, 1)
        self.rows[id] = row
    end
    local pause = button(frame, "Pause / resume", 130, function() F.paused = not F.paused; F:Refresh(); F:RefreshSettings() end)
    pause:SetPoint("BOTTOMLEFT", 20, 19)
    local allOff = button(frame, "Switch all off", 130, function()
        if F.readOnly then return end
        for _, id in ipairs(F.order) do F.db.enabled[id] = false end
        F:Refresh(); F:RefreshSettings()
    end)
    allOff:SetPoint("LEFT", pause, "RIGHT", 10, 0)
    local footer = label(frame, "Hold Shift to skip automation. /fs cap 10 sets repair limit.", "GameFontHighlightSmall")
    footer:SetPoint("BOTTOMRIGHT", -22, 25)
    frame:SetScript("OnShow", function() F:RefreshSettings() end)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local panel = CreateFrame("Frame")
        local title = label(panel, "ForeverSuite", "GameFontNormalLarge"); title:SetPoint("TOPLEFT", 16, -16)
        local open = button(panel, "Open ForeverSuite", 180, function() F:OpenSettings() end)
        open:SetPoint("TOPLEFT", 16, -55)
        local category = Settings.RegisterCanvasLayoutCategory(panel, "ForeverSuite")
        Settings.RegisterAddOnCategory(category)
    end
end
