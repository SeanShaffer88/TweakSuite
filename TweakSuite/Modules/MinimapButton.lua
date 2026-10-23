-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Minimap button for opening TweakSuite. Part of TweakSuite's own interface rather than a
-- tweak, so it is shown by default; hide it in Options > AddOns > TweakSuite or with
-- /ts button. (/ts minimap belongs to the minimap button collection feature.) Drag it around the minimap edge; the position is saved with TweakSuite settings.
local _, F = ...

local DEFAULT_ANGLE = 225
local button

local function settings()
    local db = F.db
    if not db then return { hide = false, angle = DEFAULT_ANGLE } end
    if F.readOnly then return db.minimap or { hide = false, angle = DEFAULT_ANGLE } end
    local m = db.minimap
    if type(m) ~= "table" then m = {}; db.minimap = m end
    if type(m.hide) ~= "boolean" then m.hide = false end
    if type(m.angle) ~= "number" or m.angle ~= m.angle or m.angle < 0 or m.angle >= 360 then m.angle = DEFAULT_ANGLE end
    return m
end
F.MinimapSettings = settings

local function isSquare()
    return type(GetMinimapShape) == "function" and GetMinimapShape() == "SQUARE"
end

-- Place the button on the minimap edge at `angle` degrees (0 = right, counter-clockwise).
local function place(angle)
    if not button or not Minimap then return end
    local rad = math.rad(angle)
    local x, y = math.cos(rad), math.sin(rad)
    local w, h = (Minimap:GetWidth() or 140) / 2 + 5, (Minimap:GetHeight() or 140) / 2 + 5
    if isSquare() then
        -- Project onto the square edge instead of the circle.
        local scale = 1 / math.max(math.abs(x), math.abs(y))
        x, y = x * scale, y * scale
        x, y = math.max(-1, math.min(1, x)) * w, math.max(-1, math.min(1, y)) * h
    else
        x, y = x * w, y * h
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
F.PlaceMinimapButton = place

local function angleFromCursor()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    local angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
    return angle
end

local function create()
    if button or not Minimap then return button end
    button = CreateFrame("Button", "TweakSuiteMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53); overlay:SetPoint("TOPLEFT")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20); background:SetPoint("CENTER")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18); icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\AddOns\\TweakSuite\\Media\\Icon")
    button.icon = icon

    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            F:OpenAddonOptions()
        elseif F.window and F.window:IsShown() then
            F.window:Hide()
        else
            F:OpenSettings()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", function() place(angleFromCursor()) end)
    end)
    button:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
        local angle = angleFromCursor()
        if not F.readOnly then settings().angle = angle end
        place(angle)
    end)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("TweakSuite", 1, 0.82, 0.22)
        GameTooltip:AddLine("Left-click: open or close TweakSuite", 1, 1, 1)
        GameTooltip:AddLine("Right-click: TweakSuite in Options", 1, 1, 1)
        GameTooltip:AddLine("Drag: move around the minimap", 1, 1, 1)
        GameTooltip:AddLine("Hide in Options > AddOns > TweakSuite or with /ts button", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return button
end

function F:UpdateMinimapButton()
    local m = settings()
    if m.hide then
        if button then button:Hide() end
        return
    end
    if not create() then return end
    place(m.angle)
    button:Show()
end

function F:SetMinimapButtonShown(shown)
    if self.readOnly or type(shown) ~= "boolean" then return false end
    settings().hide = not shown
    self:UpdateMinimapButton()
    if self.addonPanel and self.addonPanel.minimapCheck then self.addonPanel.minimapCheck:SetChecked(shown) end
    return true
end

F:Command("button", function()
    local shown = settings().hide
    if F:SetMinimapButtonShown(shown) then
        F:Print(shown and "Minimap button shown." or "Minimap button hidden. /ts button or Options > AddOns > TweakSuite shows it again.")
    end
end, "/ts button - show or hide the TweakSuite minimap button")

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    F:Initialize()
    local ok, err = pcall(F.UpdateMinimapButton, F)
    if not ok then F.errors[#F.errors + 1] = "minimap button: " .. tostring(err):sub(1, 300) end
end)
