-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Map coordinates, waypoints, taxi shortcuts and travel helpers.
local _, F = ...
-- Older client functions: the client's own global when present, else a private shim (Compat.lua).
local GetTaxiNodeName = F.Compat("GetTaxiNodeName")
local NumTaxiNodes = F.Compat("NumTaxiNodes")
local common = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "TomTom", "Questie", "Atlas" }

local WAYPOINT_SET = "waypoints"
local function setWaypoint(x, y, mapID)
    if C_Map and C_Map.SetUserWaypoint and C_Map.GetUserWaypoint then
        local existing = C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
        local point = { uiMapID = mapID, position = { x = x / 100, y = y / 100 } }
        if type(existing) == "table" then
            local ok = pcall(C_Map.SetUserWaypoint, point)
            if ok then return true end
        end
        local ok = pcall(C_Map.SetUserWaypoint, point)
        if ok then return true end
    end
    if SetMapToCurrentZone then pcall(SetMapToCurrentZone) end
    if SetUserWaypoint then
        local ok = pcall(SetUserWaypoint, { x = x / 100, y = y / 100 })
        if ok then return true end
    end
    return false
end

local function clearWaypoint()
    if C_Map and C_Map.ClearUserWaypoint then
        local ok = pcall(C_Map.ClearUserWaypoint)
        if ok then return true end
    end
    if ClearUserWaypoint then
        local ok = pcall(ClearUserWaypoint)
        if ok then return true end
    end
    return false
end

function F:SetWaypoint(x, y, mapID)
    x, y = tonumber(x), tonumber(y)
    if not x or not y or x < 0 or x > 100 or y < 0 or y > 100 then
        return false, "coordinates must be numbers between 0 and 100"
    end
    local map = mapID
    if map == nil and C_Map and C_Map.GetBestMapForUnit then
        map = C_Map.GetBestMapForUnit("player")
    end
    if map == nil then return false, "the client did not report a map for this zone" end
    if not setWaypoint(x, y, map) then return false, "this client has no user waypoint API" end
    return true, map
end

function F:ClearWaypoint()
    return clearWaypoint()
end

function F:CursorMapPosition()
    local frame = _G.WorldMapFrame
    if not frame then return nil end
    if frame.GetNormalizedCursorPosition then
        local ok, x, y = pcall(frame.GetNormalizedCursorPosition, frame)
        if ok and type(x) == "number" and type(y) == "number" then
            return math.floor(x * 100 + 0.5), math.floor(y * 100 + 0.5)
        end
    end
    if GetCursorPosition and frame.GetLeft and frame.GetTop and frame.GetWidth and frame.GetHeight then
        local cx, cy = GetCursorPosition()
        if type(cx) ~= "number" or type(cy) ~= "number" then return nil end
        local scale = 1
        if frame.GetEffectiveScale then scale = frame:GetEffectiveScale() or 1 end
        cx, cy = cx / scale, cy / scale
        local left, top = frame:GetLeft(), frame:GetTop()
        local width, height = frame:GetWidth(), frame:GetHeight()
        if not left or not top or not width or not height or width == 0 or height == 0 then return nil end
        local x = (cx - left) / width * 100
        local y = (top - cy) / height * 100
        if x < 0 or x > 100 or y < 0 or y > 100 then return nil end
        return math.floor(x + 0.5), math.floor(y + 0.5)
    end
    return nil
end

local function mapCoordFrame()
    if F.mapCoordFrame then return F.mapCoordFrame end
    local frame = _G.WorldMapFrame
    if not frame or not frame.CreateFontString then return nil end
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("BOTTOMLEFT", 10, 10)
    label:SetText("")
    F.mapCoordFrame = label
    if frame.HookScript then
        frame:HookScript("OnUpdate", function()
            if not F:Active("cursorCoords") then
                if label:GetText() ~= "" then label:SetText("") end
                return
            end
            local x, y = F:CursorMapPosition()
            local text = x and string.format("%d, %d", x, y) or ""
            if label:GetText() ~= text then label:SetText(text) end
        end)
    end
    return label
end

F:Register("worldMapCoords", {
    title = "World map cursor coordinates",
    category = "Maps",
    description = "Shows and prints the map coordinates under the mouse, so a location can be shared in chat. /ts where prints the coordinate once. It only reads the cursor position over the world map and changes nothing else.",
    disableText = "Removes the coordinate readout and stops /ts where from reading the map.",
    conflicts = common,
    available = function() return WorldMapFrame ~= nil end,
    enable = function()
        F:Listen("worldMapCoords", "WORLD_MAP_UPDATE", function() end)
    end,
})

F:Register("cursorCoords", {
    title = "Cursor map coordinates",
    category = "Maps",
    description = "Draws a small coordinate label in the corner of the world map that follows the mouse position while the map is open. It is a plain text label and does not replace any map element.",
    disableText = "Clears and stops updating the coordinate label.",
    conflicts = common,
    available = function() return WorldMapFrame ~= nil and WorldMapFrame.CreateFontString ~= nil end,
    enable = function() mapCoordFrame() end,
    disable = function()
        if F.mapCoordFrame then F.mapCoordFrame:SetText("") end
    end,
})

-- Zone level ranges for the classic world. Values are the levels the client uses for
-- quest difficulty colours; unknown zones report no range instead of guessing.
local ZONE_LEVELS = {
    ["Elwynn Forest"] = "1-10", ["Westfall"] = "10-20", ["Redridge Mountains"] = "15-25",
    ["Duskwood"] = "18-30", ["Stranglethorn Vale"] = "30-45", ["Northern Stranglethorn"] = "25-30",
    ["Cape of Stranglethorn"] = "30-40", ["Wetlands"] = "20-30", ["Arathi Highlands"] = "25-35",
    ["The Hinterlands"] = "40-50", ["Western Plaguelands"] = "51-58", ["Eastern Plaguelands"] = "53-60",
    ["Tirisfal Glades"] = "1-10", ["Silverpine Forest"] = "10-20", ["Hillsbrad Foothills"] = "20-30",
    ["Alterac Mountains"] = "30-40", ["Badlands"] = "35-45", ["Searing Gorge"] = "43-50",
    ["Burning Steppes"] = "50-58", ["Swamp of Sorrows"] = "35-45", ["Blasted Lands"] = "45-55",
    ["Deadwind Pass"] = "55-60", ["Dun Morogh"] = "1-10", ["Loch Modan"] = "10-20",
    ["Darkshore"] = "10-20", ["Ashenvale"] = "18-30", ["Stonetalon Mountains"] = "15-27",
    ["Desolace"] = "30-40", ["Mulgore"] = "1-10", ["The Barrens"] = "10-25",
    ["Thousand Needles"] = "25-35", ["Tanaris"] = "40-50", ["Un'Goro Crater"] = "48-55",
    ["Silithus"] = "55-60", ["Feralas"] = "40-50", ["Dustwallow Marsh"] = "35-45",
    ["Felwood"] = "48-55", ["Winterspring"] = "53-60", ["Moonglade"] = "50-60",
    ["Azshara"] = "45-55", ["Teldrassil"] = "1-10", ["Durotar"] = "1-10",
    ["Eversong Woods"] = "1-10", ["Ghostlands"] = "10-20", ["Hellfire Peninsula"] = "58-63",
    ["Zangarmarsh"] = "60-64", ["Nagrand"] = "64-67", ["Terokkar Forest"] = "62-65",
}

function F:ZoneLevelRange(zone)
    return ZONE_LEVELS[zone or ""]
end

local function zoneNotice()
    if not F:Active("zoneLevels") or InCombatLockdown() then return end
    local zone = GetRealZoneText and GetRealZoneText() or GetZoneText()
    if type(zone) ~= "string" or zone == "" then return end
    local range = F:ZoneLevelRange(zone)
    if not range then return end
    local sub = GetSubZoneText and GetSubZoneText() or ""
    F:Print("Zone: " .. zone .. (sub ~= "" and (" (" .. sub .. ")") or "") .. ", levels " .. range .. ".")
end

F:Register("zoneLevels", {
    title = "Zone level ranges",
    category = "Maps",
    description = "Prints the level range of each zone once when you enter it, using a built-in table of the classic world. /ts zone prints the range for the zone you are in. Unknown zones stay silent instead of guessing.",
    disableText = "Stops printing zone ranges. No map element is changed.",
    conflicts = common,
    available = function() return GetRealZoneText ~= nil or GetZoneText ~= nil end,
    enable = function()
        F:Listen("zoneLevels", "ZONE_CHANGED_NEW_AREA", zoneNotice)
        zoneNotice()
    end,
})

local DUNGEONS = {
    ["Ragefire Chasm"] = { zone = "Orgrimmar", x = 52, y = 49, level = "13-18" },
    ["The Deadmines"] = { zone = "Westfall", x = 42, y = 72, level = "17-26" },
    ["Wailing Caverns"] = { zone = "The Barrens", x = 46, y = 36, level = "17-24" },
    ["Shadowfang Keep"] = { zone = "Silverpine Forest", x = 45, y = 68, level = "22-30" },
    ["Blackfathom Deeps"] = { zone = "Ashenvale", x = 14, y = 15, level = "24-32" },
    ["The Stockade"] = { zone = "Stormwind City", x = 51, y = 66, level = "24-32" },
    ["Gnomeregan"] = { zone = "Dun Morogh", x = 30, y = 37, level = "29-38" },
    ["Razorfen Kraul"] = { zone = "The Barrens", x = 42, y = 90, level = "30-40" },
    ["Scarlet Monastery"] = { zone = "Tirisfal Glades", x = 80, y = 30, level = "34-45" },
    ["Uldaman"] = { zone = "Badlands", x = 65, y = 46, level = "41-51" },
    ["Zul'Farrak"] = { zone = "Tanaris", x = 39, y = 21, level = "44-54" },
    ["Maraudon"] = { zone = "Desolace", x = 29, y = 62, level = "46-55" },
    ["The Sunken Temple"] = { zone = "Swamp of Sorrows", x = 70, y = 55, level = "50-60" },
    ["Blackrock Depths"] = { zone = "Blackrock Mountain", x = 35, y = 60, level = "52-60" },
    ["Dire Maul"] = { zone = "Feralas", x = 60, y = 37, level = "55-60" },
    ["Lower Blackrock Spire"] = { zone = "Blackrock Mountain", x = 26, y = 45, level = "55-60" },
    ["Stratholme"] = { zone = "Eastern Plaguelands", x = 43, y = 21, level = "58-60" },
    ["Scholomance"] = { zone = "Western Plaguelands", x = 69, y = 73, level = "58-60" },
}

function F:DungeonEntrance(name)
    if name and name ~= "" then return DUNGEONS[name] end
    return DUNGEONS
end

function F:DungeonNames()
    local names = {}
    for name in pairs(DUNGEONS) do names[#names + 1] = name end
    table.sort(names)
    return names
end

F:Register("dungeonMarkers", {
    title = "Dungeon entrance notes",
    category = "Maps",
    description = "Lists the entrance coordinates and level range of every classic dungeon with /ts dungeon [name], and can place the client's own user waypoint at the entrance. Coordinates are approximate and only a note; no markers are drawn over the map.",
    disableText = "Stops the dungeon command and the waypoint shortcut. Nothing on the map is changed.",
    conflicts = { "Atlas", "AtlasLoot", "Questie", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function() return true end,
    enable = function() end,
})

F:Register("waypoints", {
    title = "Waypoint commands",
    category = "Maps",
    description = "Sets the client's user waypoint with /ts way <x> <y> [mapID] and removes it with /ts way clear. It uses the client map API only, so a waypoint disappears when the client clears it.",
    disableText = "Stops the waypoint command. A waypoint already placed stays until the client clears it.",
    conflicts = common,
    available = function()
        return (C_Map and C_Map.SetUserWaypoint) or SetUserWaypoint ~= nil
    end,
    enable = function() end,
})

local function teleportNames()
    local names = {}
    for _, entry in ipairs(F:TeleportList()) do names[#names + 1] = entry.name end
    return names
end

function F:TeleportList()
    local db = self.db
    if not db then return {} end
    if type(db.teleports) ~= "table" then db.teleports = {} end
    return db.teleports
end

function F:AddTeleport(name, spellID)
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    spellID = tonumber(spellID)
    if name == "" or #name > 30 then return false, "name must be 1-30 characters" end
    if not spellID or spellID <= 0 or spellID % 1 ~= 0 then return false, "spell ID must be a positive whole number" end
    local list = self:TeleportList()
    if #list >= 20 then return false, "at most 20 favorites" end
    for index = #list, 1, -1 do
        if list[index].name:lower() == name:lower() then table.remove(list, index) end
    end
    list[#list + 1] = { name = name, id = spellID }
    return true, name, spellID
end

function F:RemoveTeleport(name)
    local list = self:TeleportList()
    local lower = tostring(name or ""):lower()
    for index = #list, 1, -1 do
        if list[index].name:lower() == lower then
            table.remove(list, index)
            if next(list) == nil then self.db.teleports = nil end
            return true
        end
    end
    return false
end

function F:CastTeleport(name)
    local lower = tostring(name or ""):lower()
    for _, entry in ipairs(self:TeleportList()) do
        if entry.name:lower() == lower or tostring(entry.id) == lower then
            if InCombatLockdown() then return false, "cannot cast during combat" end
            if CastSpellByID then
                local ok = pcall(CastSpellByID, entry.id)
                if ok then return true, entry.name end
                return false, "the client refused the cast"
            end
            return false, "this client cannot cast by spell ID"
        end
    end
    return false, "no favorite with that name"
end

F:Register("teleportFavorites", {
    title = "Teleport favorites",
    category = "Maps",
    description = "Saves spell IDs you use for travel under a short name and casts them with /ts tele <name>. /ts tele add <name> <spellID>, remove and list manage the list. It only casts spells your character knows; nothing is bought or learned.",
    disableText = "Stops the teleport commands. Saved favorites are kept.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL" },
    options = {
        { key = "confirm", type = "boolean", title = "Say which spell is cast", default = true,
          description = "Prints the favorite name before the cast so a mistyped name cannot trigger the wrong travel spell silently." },
    },
    available = function() return CastSpellByID ~= nil end,
    enable = function() end,
})

local menu
function F:ToggleTeleportMenu()
    if not self:Active("teleportMenu") then return false, "enable the teleport menu first" end
    if not menu then
        menu = CreateFrame("Frame", "TweakSuiteTeleportMenu", UIParent)
        menu:SetSize(220, 120)
        menu:SetPoint("CENTER")
        menu:SetFrameStrata("DIALOG")
        if menu.SetBackdrop then
            menu:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        end
        if menu.SetBackdropColor then menu:SetBackdropColor(0.12, 0.09, 0.06, 0.95) end
        if menu.SetBackdropBorderColor then menu:SetBackdropBorderColor(0.85, 0.65, 0.25, 1) end
        menu.buttons = {}
        menu:Hide()
    end
    for _, button in ipairs(menu.buttons) do button:Hide() end
    local index = 0
    for _, entry in ipairs(self:TeleportList()) do
        local button = menu.buttons[index + 1]
        if not button then
            button = CreateFrame("Button", nil, menu)
            button:SetSize(190, 20)
            local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT")
            button.text = text
            button:SetScript("OnClick", function(self2)
                local name = self2.favorite
                F:CastTeleport(name)
                if menu then menu:Hide() end
            end)
            menu.buttons[index + 1] = button
        end
        button.favorite = entry.name
        button.text:SetText(entry.name)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 12, -12 - index * 22)
        button:Show()
        index = index + 1
    end
    menu:SetSize(220, math.max(60, 34 + index * 22))
    if menu:IsShown() then menu:Hide() else menu:Show() end
    return true
end

F:Register("teleportMenu", {
    title = "Teleport menu",
    category = "Maps",
    description = "Puts every saved teleport favorite on one small clickable panel, opened with /ts tele menu. Clicking a name casts that favorite. The panel only contains your own saved names and never lists spells you have not added.",
    disableText = "Closes and removes the panel. Saved teleport favorites are untouched.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function() return CastSpellByID ~= nil and UIParent ~= nil end,
    enable = function() end,
    disable = function()
        if menu then menu:Hide(); menu = nil end
    end,
})

local flightStart
function F:TaxiNodes()
    local rows = {}
    if not NumTaxiNodes or not GetTaxiNodeName then return rows end
    local count = NumTaxiNodes()
    if type(count) ~= "number" then return rows end
    for index = 1, count do
        local name = GetTaxiNodeName(index)
        if type(name) == "string" and name ~= "" then rows[#rows + 1] = { index = index, name = name } end
    end
    return rows
end

function F:FlightElapsed()
    if not flightStart then return 0 end
    local now = GetTime and GetTime() or 0
    return math.max(0, now - flightStart)
end

F:Register("flightShortcuts", {
    title = "Flight map shortcuts",
    category = "Maps",
    description = "Lists the flight points on the open taxi map and takes one by number with /ts taxi <n>. /ts taxi list shows the numbered names. It only clicks a node you could click yourself and never chooses a destination automatically.",
    disableText = "Stops the taxi command. An open taxi map still works as usual.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL" },
    available = function() return NumTaxiNodes ~= nil and GetTaxiNodeName ~= nil and TakeTaxiNode ~= nil end,
    enable = function()
        F:Listen("flightShortcuts", "TAXIMAP_OPENED", function() F:Print("Taxi map open. Use /ts taxi list to see the numbered flight points.") end)
    end,
})

F:Register("flightTimer", {
    title = "Flight time display",
    category = "Maps",
    description = "Shows how long the current taxi flight has been running, with /ts flight printing the elapsed time. It starts counting when the client says the taxi map closed and stops when you land.",
    disableText = "Stops the flight timer and clears the current count.",
    conflicts = common,
    available = function() return UnitOnTaxi ~= nil and GetTime ~= nil end,
    enable = function()
        F:Listen("flightTimer", "TAXIMAP_CLOSED", function()
            if UnitOnTaxi and UnitOnTaxi("player") then
                flightStart = GetTime and GetTime() or nil
            end
        end)
        F:Listen("flightTimer", "PLAYER_CONTROL_GAINED", function() flightStart = nil end)
    end,
    disable = function() flightStart = nil end,
})
