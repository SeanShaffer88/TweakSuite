-- SPDX-License-Identifier: MIT
-- Original UI. Leatrix Plus's published gallery informs the visual direction only.
local _, F = ...
local categories = { "Home", "All tweaks", "Automation", "Dialogs", "Tooltips", "Inventory",
    "Interface", "Nameplates", "Overhead names", "Camera", "Chat" }
F.categories = categories
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
    if feature.category == "Dialogs" then lines[#lines + 1] = "Key handling pauses in combat or while Shift is held." end
    if feature.category == "Tooltips" then lines[#lines + 1] = "This preview adds tooltip lines only outside combat." end
    if #feature.options > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Options"
        for _, option in ipairs(feature.options) do
            lines[#lines + 1] = option.title .. ": " .. self:OptionValueText(id, option.key)
                .. "  (default " .. self:OptionDefaultText(option) .. ")"
            lines[#lines + 1] = "  " .. option.description
            if option.type == "number" then
                lines[#lines + 1] = "  Range " .. option.min .. " to " .. option.max .. "; step " .. option.step .. "."
            elseif option.type == "choice" then
                local labels = {}
                for _, choice in ipairs(option.choices) do labels[#labels + 1] = choice.label end
                lines[#lines + 1] = "  Choices: " .. table.concat(labels, ", ") .. "."
            end
        end
        lines[#lines + 1] = "Change with /fs set " .. id .. " <option> <value>, or use the Options button on the setting."
    end
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

function F:RefreshOptionControls()
    local frame = self.optionsWindow
    if not frame or not frame.cache or frame.updating then return end
    frame.updating = true
    for featureId, cached in pairs(frame.cache) do
        for _, control in ipairs(cached.controls) do
            local ok, err = pcall(control.update)
            if not ok then self:RecordError(featureId, err) end
        end
    end
    frame.updating = false
end

function F:ShowOptions(id)
    local feature = self.features[id]
    if not feature or #feature.options == 0 then return end
    if not self.optionsWindow then
        local frame = window("ForeverSuiteFeatureOptions", "Feature options", 620, 540)
        frame.featureTitle = label(frame, "", "GameFontNormalLarge")
        frame.featureTitle:SetPoint("TOPLEFT", 22, -52)
        frame.featureDescription = label(frame, "", "GameFontHighlightSmall")
        frame.featureDescription:SetPoint("TOPLEFT", 22, -78)
        frame.featureDescription:SetWidth(566)
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 18, -128); scroll:SetPoint("BOTTOMRIGHT", -34, 58)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetWidth(548); scroll:SetScrollChild(content)
        frame.scroll, frame.content, frame.cache = scroll, content, {}
        frame.reset = button(frame, "Reset options", 130, function()
            if not frame.featureId then return end
            F:ResetOptions(frame.featureId)
        end)
        frame.reset:SetPoint("BOTTOMLEFT", 22, 20)
        local close = button(frame, "Close", 100, function() frame:Hide() end)
        close:SetPoint("BOTTOMRIGHT", -24, 20)
        self.optionsWindow = frame
    end
    local frame = self.optionsWindow
    frame.featureId = id
    frame.featureTitle:SetText(feature.title)
    frame.featureDescription:SetText(feature.description)
    local cached = frame.cache[id]
    if not cached then
        cached = { controls = {} }
        local holder = CreateFrame("Frame", nil, frame.content)
        holder:SetPoint("TOPLEFT"); holder:SetWidth(548)
        cached.holder = holder
        local y = -4
        for _, option in ipairs(feature.options) do
            local title = label(holder, option.title, "GameFontNormal")
            title:SetPoint("TOPLEFT", 4, y)
            local description = label(holder, option.description, "GameFontHighlightSmall")
            description:SetPoint("TOPLEFT", 4, y - 20); description:SetWidth(330)
            local meta = "Default: " .. self:OptionDefaultText(option) .. "."
            if option.type == "number" then
                meta = meta .. "  Range " .. option.min .. " to " .. option.max .. "; step " .. option.step .. "."
            elseif option.type == "choice" then
                meta = meta .. "  Click the button to cycle choices."
            end
            local note = label(holder, meta, "GameFontDisableSmall")
            note:SetPoint("TOPLEFT", 4, y - 58); note:SetWidth(330)
            if option.type == "boolean" then
                local check = CreateFrame("CheckButton", nil, holder, "UICheckButtonTemplate")
                check:SetSize(26, 26); check:SetPoint("TOPLEFT", 386, y - 4)
                if self.readOnly then check:SetEnabled(false) end
                check:SetScript("OnClick", function(control)
                    F:SetOption(id, option.key, control:GetChecked() == true)
                    F:RefreshOptionControls(); F:RefreshSettings()
                end)
                cached.controls[#cached.controls + 1] = { widget = check,
                    update = function() check:SetChecked(F:GetOption(id, option.key) == true) end }
            elseif option.type == "number" then
                local minus = button(holder, "-", 24, function()
                    F:SetOption(id, option.key, F:GetOption(id, option.key) - option.step)
                    F:RefreshOptionControls(); F:RefreshSettings()
                end)
                minus:SetPoint("TOPLEFT", 348, y - 4)
                if self.readOnly then minus:SetEnabled(false) end
                local value = label(holder, "", "GameFontHighlight")
                value:SetPoint("LEFT", minus, "RIGHT", 6, 0); value:SetWidth(76); value:SetJustifyH("CENTER")
                local plus = button(holder, "+", 24, function()
                    F:SetOption(id, option.key, F:GetOption(id, option.key) + option.step)
                    F:RefreshOptionControls(); F:RefreshSettings()
                end)
                plus:SetPoint("LEFT", value, "RIGHT", 6, 0)
                if self.readOnly then plus:SetEnabled(false) end
                cached.controls[#cached.controls + 1] = { widget = plus, update = function()
                    local current = F:GetOption(id, option.key)
                    value:SetText(F:OptionValueText(id, option.key))
                    minus:SetEnabled(not F.readOnly and current > option.min)
                    plus:SetEnabled(not F.readOnly and current < option.max)
                end }
            else
                local cycle = button(holder, "", 160, function()
                    local current = F:GetOption(id, option.key)
                    local index = 1
                    for position, choice in ipairs(option.choices) do
                        if choice.value == current then index = position end
                    end
                    local nextChoice = option.choices[(index % #option.choices) + 1]
                    F:SetOption(id, option.key, nextChoice.value)
                    F:RefreshOptionControls(); F:RefreshSettings()
                end)
                cycle:SetPoint("TOPLEFT", 368, y - 4)
                if self.readOnly then cycle:SetEnabled(false) end
                cached.controls[#cached.controls + 1] = { widget = cycle,
                    update = function() cycle:SetText(F:OptionValueText(id, option.key) .. "   >") end }
            end
            y = y - 96
        end
        holder:SetHeight(math.max(1, -y))
        cached.height = math.max(1, -y)
        frame.cache[id] = cached
    end
    for otherId, other in pairs(frame.cache) do
        other.holder:SetShown(otherId == id)
    end
    frame.content:SetHeight(cached.height)
    frame.scroll:SetVerticalScroll(0); frame.scroll:UpdateScrollChildRect()
    self:RefreshOptionControls()
    frame:Show()
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
                    local text = feature.title .. " " .. feature.category .. " " .. feature.description .. " " .. id
                    for _, option in ipairs(feature.options) do
                        text = text .. " " .. option.title .. " " .. option.description
                    end
                    text = text:lower()
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
    self:RefreshOptionControls()
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
    local note = label(frame, "Every setting starts off.\n\nHover for an explanation.\nDetails covers defaults,\nrestoration and conflicts.\nOptions covers variants.", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 22, -452); note:SetWidth(134)
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
        local title = label(row, feature.title); title:SetPoint("TOPLEFT", 28, -4); title:SetWidth(190)
        row.status = label(row, "", "GameFontHighlightSmall"); row.status:SetPoint("TOPLEFT", 28, -37); row.status:SetWidth(278)
        local summary = feature.description:match("^(.-%.)") or feature.description
        local description = label(row, summary, "GameFontHighlightSmall")
        description:SetPoint("TOPLEFT", 28, -61); description:SetWidth(278)
        local details = button(row, "?", 24, function() F:ShowDetails(id) end)
        details:SetPoint("TOPRIGHT", -3, 1); hoverDetails(details, id)
        if #feature.options > 0 then
            local options = button(row, "Opt", 38, function() F:ShowOptions(id) end)
            options:SetPoint("TOPRIGHT", -32, 1)
            options:SetScript("OnEnter", function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(feature.title, 1, 0.82, 0.22)
                GameTooltip:AddLine("Options change this feature's variants, such as key, position or size.", 0.95, 0.91, 0.82, true)
                GameTooltip:Show()
            end)
            options:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        end
        self.rows[id] = row
    end
    frame.home = CreateFrame("Frame", nil, frame)
    frame.home:SetPoint("TOPLEFT", 184, -90); frame.home:SetSize(620, 430)
    local welcome = label(frame.home, "Welcome to ForeverSuite", "GameFontNormalLarge"); welcome:SetPoint("TOPLEFT", 0, 0)
    local intro = label(frame.home, "A growing collection of optional tweaks for WoW Forever.\n\nChoose a category on the left, or search for a setting above.\nEach checkbox controls one feature. Its status tells you whether it is active.\n\nHover over a checkbox or its ? button for a quick explanation.\nClick ? for the full effect, default, restore behavior and conflicts.\nUse Opt to change a feature's key, position or size.", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", 0, -40); intro:SetWidth(590)
    frame.homeStats = label(frame.home, "", "GameFontNormal"); frame.homeStats:SetPoint("TOPLEFT", 0, -218)
    local preview = label(frame.home, "Development preview - Stage 2 in progress\n\nThe complete addon collection is being consolidated in stages.\nStage 1 added 36 settings; this build adds keyboard dialogs,\nitem-level overlays and more tooltip lines.\n\nKeep your existing addons available while individual replacements are tested.\nAn overlapping loaded addon blocks the matching ForeverSuite feature.\n\nHold Shift to skip automation. Use /fs cap 10 to set the repair limit.", "GameFontHighlightSmall")
    preview:SetPoint("TOPLEFT", 0, -286); preview:SetWidth(590)
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
