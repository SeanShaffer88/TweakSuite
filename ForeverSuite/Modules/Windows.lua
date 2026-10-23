-- SPDX-License-Identifier: MIT
-- Movable Blizzard windows with saved positions. Original implementation.
local _, F = ...
local WINDOWS = {
    "CharacterFrame", "SpellBookFrame", "MerchantFrame", "QuestFrame", "GossipFrame",
    "MailFrame", "BankFrame", "TradeFrame", "TabardFrame", "TrainerFrame",
    "PetStableFrame", "FriendsFrame", "AuctionHouseFrame", "WorldMapFrame",
}
local installed = setmetatable({}, { __mode = "k" })
local originals, dragging, defaults = {}, {}, {}

local function requireShift()
    return F:GetOption("moveWindows", "requireShift") ~= false
end

local function remember()
    return F:GetOption("moveWindows", "remember") ~= false
end

local function frameName(frame)
    return frame.GetName and frame:GetName() or nil
end

local function capture(frame)
    if not frame.GetPoint then return nil end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if type(point) ~= "string" then return nil end
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    return { point = point, relativePoint = relativePoint or point, x = x, y = y }
end

local function applyStored(frame, stored)
    if type(stored) ~= "table" or type(stored.point) ~= "string" then return end
    if type(stored.x) ~= "number" or type(stored.y) ~= "number" then return end
    frame:ClearAllPoints()
    frame:SetPoint(stored.point, stored.relativePoint or stored.point, stored.x, stored.y)
end

local function save(frame)
    local name = frameName(frame)
    if not name or not remember() or not F.db then return end
    local stored = capture(frame)
    if not stored then return end
    if type(F.db.layouts) ~= "table" then F.db.layouts = {} end
    F.db.layouts[name] = stored
end

local function restore(frame)
    local name = frameName(frame)
    local stored = name and F.db and F.db.layouts and F.db.layouts[name]
    if stored then applyStored(frame, stored) end
end

local function onDragStart(frame)
    if not F:Active("moveWindows") or InCombatLockdown() then return end
    if F.WindowExcluded and F:WindowExcluded(frameName(frame)) then return end
    if requireShift() and not (IsShiftKeyDown and IsShiftKeyDown()) then return end
    originals[frame] = originals[frame] or capture(frame)
    dragging[frame] = true
    frame:StartMoving()
end

local function onDragStop(frame)
    if not dragging[frame] then return end
    dragging[frame] = nil
    frame:StopMovingOrSizing()
    save(frame)
end

local function onShow(frame)
    if not F:Active("moveWindows") or InCombatLockdown() then return end
    if F.WindowExcluded and F:WindowExcluded(frameName(frame)) then return end
    restore(frame)
end

local function install(frame)
    if not frame or installed[frame] then return end
    if not (frame.SetMovable and frame.RegisterForDrag and frame.StartMoving and frame.StopMovingOrSizing) then return end
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    if frame.HookScript then
        frame:HookScript("OnDragStart", onDragStart)
        frame:HookScript("OnDragStop", onDragStop)
        frame:HookScript("OnShow", onShow)
    end
    defaults[frame] = capture(frame)
    installed[frame] = true
    restore(frame)
end

local function installAll()
    for _, name in ipairs(WINDOWS) do install(_G[name]) end
end

local function restoreOriginals()
    for frame, stored in pairs(originals) do
        if stored then applyStored(frame, stored) end
        originals[frame] = nil
        dragging[frame] = nil
    end
end

F:Register("moveWindows", {
    title = "Move Blizzard windows",
    category = "Windows",
    description = "Lets you drag common client windows to a new place and keeps that position. Requires Shift by default to avoid accidental drags. Window contents, tabs and buttons are not changed.",
    disableText = "Stops tracking drags and puts each window back where it was before the first move in this session. Sizes are unchanged.",
    conflicts = { "BlizzMove", "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "MoveAny" },
    options = {
        { key = "requireShift", type = "boolean", title = "Require Shift to drag", default = true,
          description = "Only starts a window drag while Shift is held. Turning this off makes every left-button drag on a window move it, which can interfere with clicking tabs." },
        { key = "remember", type = "boolean", title = "Remember positions", default = true,
          description = "Stores each window position in saved settings and restores it when the window opens again, including after a reload." },
    },
    available = function()
        return UIParent ~= nil and CharacterFrame ~= nil and CharacterFrame.SetMovable ~= nil
    end,
    enable = function()
        installAll()
        F:Listen("moveWindows", "PLAYER_ENTERING_WORLD", function()
            installAll()
            for _, name in ipairs(WINDOWS) do
                local frame = _G[name]
                if frame and frame:IsShown() then onShow(frame) end
            end
        end)
        F:Listen("moveWindows", "PLAYER_REGEN_ENABLED", installAll)
    end,
    refresh = function()
        for _, name in ipairs(WINDOWS) do
            local frame = _G[name]
            if frame and frame:IsShown() then restore(frame) end
        end
    end,
    disable = function()
        restoreOriginals()
    end,
})

function F:ResetWindowLayout(name)
    if type(name) ~= "string" or name == "" then return false, "no window name" end
    local known = false
    for _, candidate in ipairs(WINDOWS) do
        if candidate == name then known = true end
    end
    local frame = _G[name]
    if not known or not frame then return false, "unknown window" end
    if self.db and type(self.db.layouts) == "table" then self.db.layouts[name] = nil end
    local original = defaults[frame]
    if original then
        applyStored(frame, original)
    elseif frame.ClearAllPoints and frame.SetPoint then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER")
    end
    return true
end

function F:WindowNames()
    local names = {}
    for _, name in ipairs(WINDOWS) do
        if _G[name] then names[#names + 1] = name end
    end
    return names
end

-- ---------------------------------------------------------------------------
-- Window sizing, snapping, anchoring and layout sets.
-- Every helper below is defensive: frames and APIs differ between the beta and
-- launch clients, so a missing method never stops the addon or another window.

local extras = {}

local function known(name)
    for _, candidate in ipairs(WINDOWS) do
        if candidate == name then return true end
    end
    return false
end

local function screenSize()
    local width, height
    if UIParent and UIParent.GetWidth then
        local ok, value = pcall(UIParent.GetWidth, UIParent)
        if ok and type(value) == "number" and value > 0 then width = value end
    end
    if not width and GetScreenWidth then
        local ok, value = pcall(GetScreenWidth)
        if ok and type(value) == "number" and value > 0 then width = value end
    end
    if UIParent and UIParent.GetHeight then
        local ok, value = pcall(UIParent.GetHeight, UIParent)
        if ok and type(value) == "number" and value > 0 then height = value end
    end
    if not height and GetScreenHeight then
        local ok, value = pcall(GetScreenHeight)
        if ok and type(value) == "number" and value > 0 then height = value end
    end
    return width, height
end

local function measure(frame)
    local width, height
    if frame.GetWidth then
        local ok, value = pcall(frame.GetWidth, frame)
        if ok and type(value) == "number" and value > 0 then width = value end
    end
    if frame.GetHeight then
        local ok, value = pcall(frame.GetHeight, frame)
        if ok and type(value) == "number" and value > 0 then height = value end
    end
    return width, height
end

function F:WindowFrame(name)
    if type(name) ~= "string" or not known(name) then return nil end
    return _G[name]
end

function F:WindowExcluded(name)
    if type(name) ~= "string" then return true end
    if not self:Active("windowExceptions") then return false end
    if name == "AuctionHouseFrame" and self:GetOption("windowExceptions", "auctionHouse") then return true end
    if name == "WorldMapFrame" and self:GetOption("windowExceptions", "worldMap") then return true end
    local frame = _G[name]
    if frame and frame.IsProtected and self:GetOption("windowExceptions", "protectedFrames") then
        local ok, protected = pcall(frame.IsProtected, frame)
        if ok and protected then return true end
    end
    return false
end

function F:WindowNamesForUI()
    local names = {}
    for _, name in ipairs(WINDOWS) do
        if _G[name] then names[#names + 1] = name end
    end
    return names
end

local function layoutStore()
    if not F.db then return nil end
    if type(F.db.layouts) ~= "table" then F.db.layouts = {} end
    return F.db.layouts
end

local function storePlacement(frame)
    local name = frameName(frame)
    local layouts = layoutStore()
    if not name or not layouts then return end
    if not frame.GetPoint then return end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return end
    local entry = layouts[name] or {}
    entry.point, entry.relativePoint, entry.x, entry.y = point, relativePoint or point, x, y
    local width, height = measure(frame)
    if width then entry.width = width end
    if height then entry.height = height end
    layouts[name] = entry
end

local function applyPlacement(frame, entry)
    if type(entry) ~= "table" then return end
    if type(entry.point) == "string" and type(entry.x) == "number" and type(entry.y) == "number" then
        frame:ClearAllPoints()
        frame:SetPoint(entry.point, entry.relativePoint or entry.point, entry.x, entry.y)
    end
    if type(entry.width) == "number" and type(entry.height) == "number" and frame.SetSize then
        pcall(frame.SetSize, frame, entry.width, entry.height)
    end
end

function F:SetWindowSize(name, width, height)
    local frame = self:WindowFrame(name)
    if not frame then return false, "unknown window" end
    if type(width) ~= "number" or type(height) ~= "number" then return false, "size must be numbers" end
    if width < 200 or width > 2400 or height < 150 or height > 1600 then
        return false, "size outside 200-2400 by 150-1600"
    end
    if not frame.SetSize then return false, "the client does not allow resizing this window" end
    pcall(frame.SetSize, frame, math.floor(width), math.floor(height))
    if self:Active("resizeWindows") then storePlacement(frame) end
    return true
end

function F:SetWindowAnchor(name, target, x, y)
    local frame = self:WindowFrame(name)
    if not frame then return false, "unknown window" end
    if type(self.db) ~= "table" then return false, "settings are read only" end
    if type(self.db.anchors) ~= "table" then self.db.anchors = {} end
    if target == nil or target == "" or target == "clear" then
        self.db.anchors[name] = nil
        if next(self.db.anchors) == nil then self.db.anchors = nil end
        return true
    end
    if not self:WindowFrame(target) or target == name then return false, "anchor target must be another tracked window" end
    x, y = tonumber(x) or 0, tonumber(y) or 0
    if x < -2000 or x > 2000 or y < -2000 or y > 2000 then return false, "offset outside -2000 to 2000" end
    self.db.anchors[name] = { target = target, x = math.floor(x), y = math.floor(y) }
    return true
end

function F:ApplyWindowAnchor(name)
    local frame = self:WindowFrame(name)
    if not frame then return false end
    local entry = self.db and type(self.db.anchors) == "table" and self.db.anchors[name]
    if not entry then return false end
    local target = self:WindowFrame(entry.target)
    if not target then return false end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", target, "TOPLEFT", entry.x or 0, entry.y or 0)
    return true
end

function F:WindowAnchorNames()
    local names = {}
    for name in pairs(self.db and self.db.anchors or {}) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function F:SaveWindowLayout(name)
    if type(name) ~= "string" or name == "" then return false, "name required" end
    if #name > 24 then return false, "name must be 24 characters or fewer" end
    if type(self.db) ~= "table" then return false, "settings are read only" end
    if type(self.db.windowLayouts) ~= "table" then self.db.windowLayouts = {} end
    local snapshot = {}
    for _, windowName in ipairs(WINDOWS) do
        local frame = _G[windowName]
        if frame and frame.GetPoint then
            local copied = capture(frame)
            if copied then
                local width, height = measure(frame)
                copied.width, copied.height = width, height
                snapshot[windowName] = copied
            end
        end
    end
    self.db.windowLayouts[name] = snapshot
    return true, snapshot
end

function F:WindowLayoutNames()
    local names = {}
    for name in pairs(self.db and self.db.windowLayouts or {}) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function F:ApplyWindowLayout(name)
    local layouts = self.db and self.db.windowLayouts
    local snapshot = type(layouts) == "table" and layouts[name]
    if type(snapshot) ~= "table" then return false, "unknown window layout" end
    if InCombatLockdown() then return false, "after combat" end
    local applied = 0
    for windowName, entry in pairs(snapshot) do
        local frame = _G[windowName]
        if frame and known(windowName) and not self:WindowExcluded(windowName) then
            applyPlacement(frame, entry)
            applied = applied + 1
        end
    end
    return true, applied
end

function F:DeleteWindowLayout(name)
    if type(self.db) ~= "table" or type(self.db.windowLayouts) ~= "table" then return false, "unknown layout" end
    if self.db.windowLayouts[name] == nil then return false, "unknown layout" end
    self.db.windowLayouts[name] = nil
    if next(self.db.windowLayouts) == nil then self.db.windowLayouts = nil end
    return true
end

local function clampToScreen(frame)
    if not frame or not frame.GetPoint then return false end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return false end
    if relativeTo and relativeTo ~= UIParent then return false end
    local left, top
    local width, height = measure(frame)
    width, height = width or 0, height or 0
    local _, screenHeight = screenSize()
    if point:find("LEFT") then left = x
    elseif point:find("RIGHT") then left = -x
    else left = x - width / 2 end
    if point:find("TOP") then top = -y
    elseif point:find("BOTTOM") then top = -y - height
    else top = -y - height / 2 end
    local screenWidth = screenSize()
    local margin = F:GetOption("snapWindows", "margin") or 0
    local maxLeft = math.max(margin, (screenWidth or left + width) - width - margin)
    local maxTop = math.max(margin, (screenHeight or top + height) - height - margin)
    local newLeft = math.min(math.max(left, margin), maxLeft)
    local newTop = math.min(math.max(top, margin), maxTop)
    if newLeft == left and newTop == top then return false end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", math.floor(newLeft), math.floor(-newTop))
    return true
end

local function enforceWindows()
    if not F:Active("windowKeepOpen") then return end
    local pinned = F.pinnedWindows
    if type(pinned) ~= "table" then return end
    for name in pairs(pinned) do
        local frame = _G[name]
        if frame and not frame:IsShown() and not F:WindowExcluded(name) and not InCombatLockdown() then
            frame:Show()
        end
    end
end

local function deferredEnforce()
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(0, enforceWindows)
    else
        enforceWindows()
    end
end

F:Register("resizeWindows", {
    title = "Resize windows",
    category = "Windows",
    description = "Adds a resize grip to the corner of each movable client window and restores the size you last used, separately from the position. Only the window frame is resized; text and buttons keep their own scale.",
    disableText = "Removes the resize grips and stops saving sizes. Windows keep the size they currently have.",
    conflicts = { "BlizzMove", "MoveAny", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "grip", type = "boolean", title = "Show a resize grip", default = true,
          description = "Draws a small grip in the lower-right corner of each supported window. Dragging it resizes the window." },
        { key = "remember", type = "boolean", title = "Remember sizes", default = true,
          description = "Stores the size with the window position and restores it the next time the window opens." },
    },
    available = function() return UIParent ~= nil and CharacterFrame ~= nil end,
    enable = function()
        for _, name in ipairs(WINDOWS) do
            local frame = _G[name]
            if frame and not F:WindowExcluded(name) then
                if frame.SetResizable then pcall(frame.SetResizable, frame, true) end
                if frame.SetMinResize then pcall(frame.SetMinResize, frame, 200, 150) end
                if frame.SetClampedToScreen then pcall(frame.SetClampedToScreen, frame, true) end
                if frame.SetScript and not frame.fsSizeHooked then
                    frame.fsSizeHooked = true
                    frame:HookScript("OnSizeChanged", function(self)
                        if F:Active("resizeWindows") and F:GetOption("resizeWindows", "remember") then
                            storePlacement(self)
                        end
                    end)
                end
                if frame.SetScript and not frame.fsGripHooked then
                    frame.fsGripHooked = true
                    frame:HookScript("OnShow", function(self)
                        if not F:Active("resizeWindows") then return end
                        local layouts = F.db and F.db.layouts
                        local entry = layouts and layouts[frameName(self)]
                        if entry and entry.width and entry.height and self.SetSize then
                            pcall(self.SetSize, self, entry.width, entry.height)
                        end
                    end)
                end
                if F:GetOption("resizeWindows", "grip") and not extras[name .. "grip"] then
                    local grip = CreateFrame("Button", nil, frame)
                    grip:SetSize(16, 16)
                    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
                    if grip.SetNormalTexture then grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up") end
                    grip:RegisterForDrag("LeftButton")
                    grip:SetScript("OnDragStart", function()
                        if F:Active("resizeWindows") and not InCombatLockdown() and frame.StartSizing then
                            frame:StartSizing("BOTTOMRIGHT")
                        end
                    end)
                    grip:SetScript("OnDragStop", function()
                        if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
                        if F:Active("resizeWindows") then storePlacement(frame) end
                    end)
                    extras[name .. "grip"] = grip
                elseif not F:GetOption("resizeWindows", "grip") and extras[name .. "grip"] then
                    extras[name .. "grip"]:Hide()
                    extras[name .. "grip"] = nil
                end
            end
        end
    end,
    refresh = function()
        for _, name in ipairs(WINDOWS) do
            local frame = _G[name]
            local grip = extras[name .. "grip"]
            if grip then
                if F:GetOption("resizeWindows", "grip") then grip:Show() else grip:Hide() end
            end
            if frame and F:WindowExcluded(name) and grip then grip:Hide() end
        end
    end,
    disable = function()
        for key, grip in pairs(extras) do
            if type(grip) == "table" and grip.Hide then grip:Hide(); grip:SetScript("OnDragStart", nil); grip:SetScript("OnDragStop", nil) end
            extras[key] = nil
        end
    end,
})

F:Register("snapWindows", {
    title = "Keep windows on screen",
    category = "Windows",
    description = "Pushes a window back inside the screen after you drag it, so a title bar can never end up off screen and unreachable. Uses the screen size reported by the client and the margin you choose.",
    disableText = "Stops clamping positions. Windows stay where they are now.",
    conflicts = { "BlizzMove", "MoveAny" },
    options = {
        { key = "margin", type = "number", title = "Screen margin", default = 8, min = 0, max = 200, step = 4, unit = " px",
          description = "Space kept between a window edge and the screen edge. Zero lets a window touch the edge exactly." },
    },
    available = function() return UIParent ~= nil end,
    enable = function()
        for _, name in ipairs(WINDOWS) do
            local frame = _G[name]
            if frame and frame.HookScript and not extras[name .. "snap"] then
                extras[name .. "snap"] = true
                frame:HookScript("OnDragStop", function(self)
                    if F:Active("snapWindows") and not F:WindowExcluded(name) then clampToScreen(self) end
                end)
                frame:HookScript("OnShow", function(self)
                    if F:Active("snapWindows") and not F:WindowExcluded(name) then clampToScreen(self) end
                end)
            end
        end
    end,
    refresh = function()
        for _, name in ipairs(WINDOWS) do
            local frame = _G[name]
            if frame and frame:IsShown() and not F:WindowExcluded(name) then clampToScreen(frame) end
        end
    end,
    disable = function()
        for key in pairs(extras) do
            if type(key) == "string" and key:sub(-4) == "snap" then extras[key] = nil end
        end
    end,
})

F:Register("windowAnchors", {
    title = "Anchor windows to each other",
    category = "Windows",
    description = "Pins a window to another one so it follows along instead of drifting. Use /fs anchor <window> <target> [x] [y] to attach, and /fs anchor <window> clear to release. Only ForeverSuite's tracked windows can be anchored.",
    disableText = "Releases every anchor. Each window keeps its current position and can be dragged freely again.",
    conflicts = { "BlizzMove", "MoveAny" },
    available = function() return UIParent ~= nil end,
    enable = function()
        for _, name in ipairs(WINDOWS) do
            local frame = _G[name]
            if frame and frame.HookScript and not extras[name .. "anchor"] then
                extras[name .. "anchor"] = true
                frame:HookScript("OnShow", function()
                    if F:Active("windowAnchors") and not F:WindowExcluded(name) then F:ApplyWindowAnchor(name) end
                end)
            end
            F:ApplyWindowAnchor(name)
        end
    end,
    refresh = function()
        for _, name in ipairs(WINDOWS) do F:ApplyWindowAnchor(name) end
    end,
    disable = function()
        for key in pairs(extras) do
            if type(key) == "string" and key:sub(-6) == "anchor" then extras[key] = nil end
        end
    end,
})

F:Register("windowLayouts", {
    title = "Window layout sets",
    category = "Windows",
    description = "Saves the position and size of every tracked window under a name and restores that set later, for example one layout for raiding and one for questing. Use /fs layout save|use|delete|list.",
    disableText = "Stops applying layouts. Saved layouts stay stored and can be used again when the feature is enabled.",
    conflicts = { "BlizzMove", "MoveAny" },
    available = function() return UIParent ~= nil end,
    enable = function() end,
    disable = function() end,
})

F:Register("windowKeepOpen", {
    title = "Keep panels open together",
    category = "Windows",
    description = "When one tracked window opens, reopens the other tracked windows that were already open instead of letting the client close them. Closing a window with its own close button removes it from the set, so your close still wins.",
    disableText = "Forgets the open set. Nothing is closed or reopened after the feature is turned off.",
    conflicts = { "BlizzMove", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "respectCloseButton", type = "boolean", title = "Close button wins", default = true,
          description = "Clicking a window's own close button removes it from the reopened set. Turn this off only if a window has no close button and should always be restored." },
    },
    available = function() return UIParent ~= nil and CharacterFrame ~= nil end,
    enable = function()
        F.pinnedWindows = F.pinnedWindows or {}
        for _, name in ipairs(WINDOWS) do
            local frame = _G[name]
            if frame and frame.HookScript and not extras[name .. "keep"] then
                extras[name .. "keep"] = true
                frame:HookScript("OnShow", function()
                    if not F:Active("windowKeepOpen") or F:WindowExcluded(name) then return end
                    F.pinnedWindows[name] = true
                    deferredEnforce()
                end)
                local close = _G[name .. "CloseButton"] or (frame.CloseButton)
                if close and close.HookScript and not extras[name .. "keepClose"] then
                    extras[name .. "keepClose"] = true
                    close:HookScript("OnClick", function()
                        if F:GetOption("windowKeepOpen", "respectCloseButton") then F.pinnedWindows[name] = nil end
                    end)
                end
            end
        end
    end,
    disable = function()
        F.pinnedWindows = {}
        for key in pairs(extras) do
            if type(key) == "string" then
                local suffix = key:sub(-4)
                if suffix == "keep" or key:sub(-9) == "keepClose" then extras[key] = nil end
            end
        end
    end,
})

F:Register("windowExceptions", {
    title = "Panel exceptions",
    category = "Windows",
    description = "Excludes fragile or secure panels from ForeverSuite window handling. Move, resize, snap, anchor and keep-open all skip excluded panels, so a protected client window is never moved or reopened by mistake.",
    disableText = "Clears the exclusions. Every tracked window is handled again, at its current position.",
    conflicts = { "BlizzMove", "MoveAny" },
    options = {
        { key = "auctionHouse", type = "boolean", title = "Skip the auction house", default = true,
          description = "The auction house window has its own secure layout and is left alone by every window feature." },
        { key = "worldMap", type = "boolean", title = "Skip the world map", default = true,
          description = "The world map is managed by the client's map system. Skipping it prevents conflicts with map addons and waypoints." },
        { key = "protectedFrames", type = "boolean", title = "Skip protected frames", default = true,
          description = "Any tracked window that reports itself as protected is skipped, which keeps secure frames safe in and out of combat." },
    },
    available = function() return UIParent ~= nil end,
    enable = function()
        for _, name in ipairs(WINDOWS) do
            local frame = _G[name]
            if frame and F:WindowExcluded(name) and frame.Hide and F:Active("windowKeepOpen") then
                F.pinnedWindows = F.pinnedWindows or {}
                F.pinnedWindows[name] = nil
            end
        end
    end,
    refresh = function() end,
    disable = function() end,
})
