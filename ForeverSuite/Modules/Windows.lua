-- SPDX-License-Identifier: MIT
-- Movable Blizzard windows with saved positions. Original implementation.
local _, F = ...
local WINDOWS = {
    "CharacterFrame", "SpellBookFrame", "MerchantFrame", "QuestFrame", "GossipFrame",
    "MailFrame", "BankFrame", "TradeFrame", "TabardFrame", "TrainerFrame",
    "PetStableFrame", "FriendsFrame", "AuctionHouseFrame", "WorldMapFrame",
}
local installed = setmetatable({}, { __mode = "k" })
local originals, dragging = {}, {}

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
