-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Action button helpers and cursor effects.
local _, F = ...
local common = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "Bartender4", "Dominos" }

local ACTION_BUTTONS = {}
for _, prefix in ipairs({ "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }) do
    for index = 1, 12 do ACTION_BUTTONS[#ACTION_BUTTONS + 1] = prefix .. index end
end

local function actionButtons()
    local rows = {}
    for _, name in ipairs(ACTION_BUTTONS) do
        local button = _G[name]
        if button then rows[#rows + 1] = button end
    end
    return rows
end

local function actionSlot(button)
    local name = button.GetName and button:GetName() or nil
    local slot = type(name) == "string" and tonumber(name:match("(%d+)$")) or nil
    return slot
end

-- Range state is computed once per button so the colouring and the tests use the same rule.
function F:ActionRangeState(slot)
    if type(slot) ~= "number" then return "unknown" end
    if IsUsableAction and IsUsableAction(slot) == false then return "unusable" end
    if not IsActionInRange then return "unknown" end
    local ok, inRange = pcall(IsActionInRange, slot)
    if not ok then return "unknown" end
    if inRange == false then return "outOfRange" end
    return "inRange"
end

local rangeOverlays = {}
local function applyRangeColour()
    if not F:Active("actionRange") or InCombatLockdown() then return end
    local outColor = { 0.9, 0.2, 0.2, 0.35 }
    local useColor = { 0.2, 0.4, 0.9, 0.35 }
    for _, button in ipairs(actionButtons()) do
        local overlay = rangeOverlays[button]
        if not overlay then
            overlay = button:CreateTexture(nil, "OVERLAY")
            overlay:SetAllPoints()
            rangeOverlays[button] = overlay
        end
        local state = F:ActionRangeState(actionSlot(button))
        if state == "outOfRange" then
            overlay:SetColorTexture(outColor[1], outColor[2], outColor[3], outColor[4])
            overlay:Show()
        elseif state == "unusable" and F:GetOption("actionRange", "showUnusable") then
            overlay:SetColorTexture(useColor[1], useColor[2], useColor[3], useColor[4])
            overlay:Show()
        else
            overlay:Hide()
        end
    end
end

F:Register("actionRange", {
    title = "Action button range colouring",
    category = "Interface",
    description = "Tints action buttons while their target is out of range and, optionally, while the action cannot be used. /ts range prints the state of the buttons. It only draws a translucent overlay and never changes a button's action.",
    disableText = "Hides every range overlay. Action buttons keep their normal appearance.",
    conflicts = { "Bartender4", "Dominos", "ElvUI", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "showUnusable", type = "boolean", title = "Also tint unusable actions", default = false,
          description = "Adds a blue tint when the client reports the action as unusable, for example without a target. Off by default so only range stands out." },
        { key = "interval", type = "number", title = "Refresh every", default = 1, min = 1, max = 5, step = 1, unit = " s",
          description = "How often the button states are read. Longer intervals cost less performance and update more slowly." },
    },
    available = function() return IsActionInRange ~= nil and _G.ActionButton1 ~= nil end,
    enable = function()
        applyRangeColour()
        F:Listen("actionRange", "PLAYER_TARGET_CHANGED", applyRangeColour)
        F:Listen("actionRange", "ACTIONBAR_UPDATE_STATE", applyRangeColour)
        F:Listen("actionRange", "PLAYER_REGEN_ENABLED", applyRangeColour)
        F.rangeTicker = C_Timer and C_Timer.NewTicker and C_Timer.NewTicker(F:GetOption("actionRange", "interval") or 1, applyRangeColour)
    end,
    refresh = applyRangeColour,
    disable = function()
        if F.rangeTicker and F.rangeTicker.Cancel then F.rangeTicker:Cancel() end
        F.rangeTicker = nil
        for button, overlay in pairs(rangeOverlays) do
            overlay:Hide()
            rangeOverlays[button] = nil
        end
    end,
})

local barTextSaved = {}
local function applyBarText()
    if InCombatLockdown() then return end
    for _, button in ipairs(actionButtons()) do
        for _, child in ipairs({ "HotKey", "Name" }) do
            local region = button[child]
            local key = button.GetName and button:GetName() or nil
            if region and key then
                local id = key .. ":" .. child
                if barTextSaved[id] == nil then
                    barTextSaved[id] = region.GetAlpha and region:GetAlpha() or 1
                end
                local hide = F:Active("actionBarText") and
                    ((child == "HotKey" and F:GetOption("actionBarText", "hideHotkeys")) or
                     (child == "Name" and F:GetOption("actionBarText", "hideMacroNames")))
                if hide then region:SetAlpha(0) else region:SetAlpha(barTextSaved[id]) end
            end
        end
    end
end

F:Register("actionBarText", {
    title = "Action bar text",
    category = "Interface",
    description = "Hides the keybind letters or the macro names on action buttons so the icons stay readable, using /ts bartext hotkeys|macros|show. Display only: the buttons keep working exactly as before.",
    disableText = "Restores the keybind letters and macro names each button had before the feature changed them.",
    conflicts = { "Bartender4", "Dominos", "ElvUI", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "hideHotkeys", type = "boolean", title = "Hide keybind letters", default = false,
          description = "Hides the keybinding text in the corner of each button. Turn on if you know your keys and want cleaner icons." },
        { key = "hideMacroNames", type = "boolean", title = "Hide macro names", default = false,
          description = "Hides the macro name shown on macro buttons, leaving only the icon." },
    },
    available = function() return _G.ActionButton1 ~= nil end,
    enable = applyBarText,
    refresh = applyBarText,
    disable = applyBarText,
})

-- ---------------------------------------------------------------------------
-- Cursor ring and trail

local ring, ringTexture
local function ensureRing()
    if ring then return ring end
    ring = CreateFrame("Frame", "TweakSuiteCursorRing", UIParent)
    ring:SetSize(48, 48)
    ring:SetFrameStrata("TOOLTIP")
    ring:EnableMouse(false)
    ringTexture = ring:CreateTexture(nil, "OVERLAY")
    ringTexture:SetAllPoints()
    ring:SetScript("OnUpdate", function(self)
        if not F:Active("cursorRing") then self:Hide(); return end
        local x, y = GetCursorPosition()
        if type(x) ~= "number" or type(y) ~= "number" then return end
        local scale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        self:Show()
    end)
    return ring
end

local RING_COLORS = { gold = { 1, 0.82, 0.22 }, white = { 1, 1, 1 }, red = { 0.95, 0.3, 0.25 }, green = { 0.4, 0.9, 0.4 } }

F:Register("cursorRing", {
    title = "Cursor ring",
    category = "Interface",
    description = "Draws a ring around the mouse pointer so it is easy to find during a busy fight. Size and colour are configurable, and the ring is a plain texture that never blocks clicks on the world.",
    disableText = "Removes the ring immediately. The mouse pointer itself is unchanged.",
    conflicts = { "Cursor", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "size", type = "number", title = "Ring size", default = 48, min = 16, max = 120, step = 4, unit = " px",
          description = "Diameter of the ring in screen pixels at 100 percent UI scale." },
        { key = "color", type = "choice", title = "Ring colour", default = "gold",
          choices = { { value = "gold", label = "Gold" }, { value = "white", label = "White" },
              { value = "red", label = "Red" }, { value = "green", label = "Green" } },
          description = "Colour of the ring. Gold matches the TweakSuite palette and stays visible on most terrain." },
    },
    available = function() return UIParent ~= nil and GetCursorPosition ~= nil end,
    enable = function()
        local frame = ensureRing()
        local size = F:GetOption("cursorRing", "size") or 48
        frame:SetSize(size, size)
        local color = RING_COLORS[F:GetOption("cursorRing", "color") or "gold"] or RING_COLORS.gold
        ringTexture:SetColorTexture(color[1], color[2], color[3], 0.8)
        frame:Show()
    end,
    refresh = function()
        if not ring then return end
        local size = F:GetOption("cursorRing", "size") or 48
        ring:SetSize(size, size)
        local color = RING_COLORS[F:GetOption("cursorRing", "color") or "gold"] or RING_COLORS.gold
        ringTexture:SetColorTexture(color[1], color[2], color[3], 0.8)
    end,
    disable = function()
        if ring then ring:Hide() end
    end,
})

local trail, trailDots, trailIndex = nil, {}, 0
local function ensureTrail()
    if trail then return trail end
    trail = CreateFrame("Frame", "TweakSuiteCursorTrail", UIParent)
    trail:SetAllPoints(UIParent)
    trail:SetFrameStrata("TOOLTIP")
    trail:EnableMouse(false)
    trail:SetScript("OnUpdate", function(self, delta)
        if not F:Active("cursorTrail") then self:Hide(); return end
        local count = F:GetOption("cursorTrail", "dots") or 8
        local x, y = GetCursorPosition()
        if type(x) ~= "number" or type(y) ~= "number" then return end
        local scale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
        trailIndex = trailIndex % count + 1
        local dot = trailDots[trailIndex]
        if not dot then
            dot = self:CreateTexture(nil, "OVERLAY")
            dot:SetSize(10, 10)
            trailDots[trailIndex] = dot
        end
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        dot:SetAlpha(0.55)
        dot:Show()
        for index, other in pairs(trailDots) do
            if index ~= trailIndex and other.GetAlpha then
                local alpha = (other:GetAlpha() or 0) - (delta or 0.1) * 1.4
                if alpha <= 0 then other:Hide(); other:SetAlpha(0) else other:SetAlpha(alpha) end
            end
        end
    end)
    return trail
end

F:Register("cursorTrail", {
    title = "Cursor trail",
    category = "Interface",
    description = "Leaves a short fading trail of dots behind the mouse pointer so its path stays visible during fast movement. The trail is decorative, never blocks clicks and disappears as soon as the feature is turned off.",
    disableText = "Removes the trail and every dot immediately.",
    conflicts = { "Cursor", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "dots", type = "number", title = "Trail dots", default = 8, min = 3, max = 20, step = 1,
          description = "How many dots the trail keeps before the oldest fades out. More dots make a longer trail." },
    },
    available = function() return UIParent ~= nil and GetCursorPosition ~= nil end,
    enable = function() ensureTrail():Show() end,
    disable = function()
        if trail then trail:Hide() end
        for index, dot in pairs(trailDots) do dot:Hide(); trailDots[index] = nil end
        trailIndex = 0
    end,
})
