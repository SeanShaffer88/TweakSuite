-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Small utilities that do not belong to a gameplay module: a macro drawer, a sound
-- browser and keyboard/gamepad navigation for the settings list.
local _, F = ...

-- ---------------------------------------------------------------------------
-- Macro drawer

local drawer
local MAX_DRAWER = 8

local function drawerStore()
    if type(F.db) ~= "table" then return nil end
    if type(F.db.drawer) ~= "table" then F.db.drawer = {} end
    return F.db.drawer
end

function F:DrawerNames()
    local names = {}
    local store = F.db and F.db.drawer
    if type(store) ~= "table" then return names end
    for index, name in ipairs(store) do
        if type(name) == "string" and name ~= "" then names[index] = name end
    end
    return names
end

function F:DrawerAdd(name)
    if type(name) ~= "string" or name == "" then return false, "a macro name is needed" end
    local store = drawerStore()
    if not store then return false, "settings are read only" end
    local names = F:DrawerNames()
    if #names >= MAX_DRAWER then return false, "the drawer holds at most " .. MAX_DRAWER .. " macros" end
    for _, existing in ipairs(names) do
        if existing == name then return false, "that macro is already in the drawer" end
    end
    if GetMacroIndexByName then
        local ok, index = pcall(GetMacroIndexByName, name)
        if ok and (type(index) ~= "number" or index <= 0) then return false, "no macro with that name exists" end
    end
    store[#store + 1] = name
    F:RefreshDrawer()
    return true
end

function F:DrawerRemove(name)
    local store = drawerStore()
    if not store then return false, "settings are read only" end
    for index, existing in ipairs(store) do
        if existing == name then
            table.remove(store, index)
            if #store == 0 then F.db.drawer = nil end
            F:RefreshDrawer()
            return true
        end
    end
    return false, "that macro is not in the drawer"
end

function F:RunDrawerMacro(name)
    if not GetMacroIndexByName or not RunMacro then return false, "this client cannot run macros" end
    local ok, index = pcall(GetMacroIndexByName, name)
    if not ok or type(index) ~= "number" or index <= 0 then return false, "no macro with that name exists" end
    pcall(RunMacro, index)
    return true
end

function F:RefreshDrawer()
    if not drawer then return false end
    if not F:Active("drawerMacros") then drawer:Hide(); return false end
    local names = F:DrawerNames()
    for _, button in ipairs(drawer.buttons) do button:Hide() end
    if #names == 0 then drawer:Hide(); return false end
    for index, name in ipairs(names) do
        local button = drawer.buttons[index]
        if not button then
            button = CreateFrame("Button", nil, drawer)
            button:SetSize(120, 20)
            button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            button.label:SetAllPoints()
            button:SetScript("OnClick", function(self)
                local ok, reason = F:RunDrawerMacro(self.macroName)
                if not ok then F:Print("Drawer: " .. tostring(reason)) end
            end)
            drawer.buttons[index] = button
        end
        button.macroName = name
        button.label:SetText(name)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 0, -(index - 1) * 22)
        button:Show()
    end
    drawer:SetHeight(#names * 22)
    drawer:Show()
    return true
end

F:Register("drawerMacros", {
    title = "Macro drawer",
    category = "Interface",
    description = "Keeps up to eight named macros in one small movable drawer. /ts drawer add <name> stores a macro by name, /ts drawer toggles the drawer and clicking a button runs that macro exactly as its action button would.",
    disableText = "Hides the drawer. The saved macro names are kept.",
    conflicts = { "OPie", "ElvUI" },
    available = function() return GetMacroIndexByName ~= nil and RunMacro ~= nil end,
    enable = function()
        if not drawer then
            drawer = CreateFrame("Frame", "TweakSuiteDrawer", UIParent)
            drawer:SetSize(120, 22)
            drawer:SetPoint("RIGHT", UIParent, "RIGHT", -40, 0)
            drawer.buttons = {}
            drawer:SetMovable(true)
            drawer:EnableMouse(true)
            drawer:RegisterForDrag("LeftButton")
            drawer:SetScript("OnDragStart", function(self) self:StartMoving() end)
            drawer:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        end
        F:RefreshDrawer()
    end,
    refresh = function() F:RefreshDrawer() end,
    disable = function() if drawer then drawer:Hide() end end,
})

-- ---------------------------------------------------------------------------
-- Music and sound browser

function F:MediaFavorites()
    local favorites = {}
    local store = F.db and F.db.media
    if type(store) ~= "table" then return favorites end
    for _, entry in ipairs(store) do
        if type(entry) == "table" and type(entry.name) == "string" and type(entry.id) == "number" then
            favorites[#favorites + 1] = entry
        end
    end
    return favorites
end

function F:PlayMedia(id)
    if type(id) ~= "number" or id <= 0 then return false, "a positive sound ID is needed" end
    if PlaySoundFile then
        local ok = pcall(PlaySoundFile, id)
        if ok then return true end
    end
    if PlaySound then
        local ok = pcall(PlaySound, id)
        if ok then return true end
    end
    return false, "this client cannot play that sound"
end

function F:SaveMedia(name, id)
    local store = F.db and F.db.media
    if type(store) ~= "table" then
        if type(F.db) ~= "table" then return false, "settings are read only" end
        F.db.media = {}
        store = F.db.media
    end
    if type(name) ~= "string" or name == "" then return false, "a name is needed" end
    for _, entry in ipairs(store) do
        if entry.name == name then
            entry.id = tonumber(id) or entry.id
            return true
        end
    end
    if #store >= 20 then return false, "the list holds at most 20 sounds" end
    store[#store + 1] = { name = name:sub(1, 30), id = tonumber(id) or 0 }
    return true
end

function F:RemoveMedia(name)
    local store = F.db and F.db.media
    if type(store) ~= "table" then return false, "the list is empty" end
    for index, entry in ipairs(store) do
        if entry.name == name then
            table.remove(store, index)
            if #store == 0 then F.db.media = nil end
            return true
        end
    end
    return false, "no saved sound with that name"
end

F:Register("mediaBrowser", {
    title = "Music and sound browser",
    category = "Interface",
    description = "Plays a sound or music file by ID with /ts music <id>, saves favourites with /ts music add <name> <id> and stops playback with /ts music stop. The beta client exposes no movie playback function, so this row covers sounds only.",
    disableText = "Stops the music commands. Saved favourites are kept.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function() return PlaySoundFile ~= nil or PlaySound ~= nil end,
    enable = function() end,
})

-- ---------------------------------------------------------------------------
-- Settings navigation

local navIndex = 0

function F:NavRows()
    local rows = {}
    for _, id in ipairs(self.order) do
        local row = self.rows and self.rows[id]
        if row and row.IsShown and row:IsShown() then rows[#rows + 1] = id end
    end
    return rows
end

function F:NavMove(delta)
    local rows = F:NavRows()
    if #rows == 0 then return nil end
    navIndex = math.max(1, math.min(#rows, (navIndex or 0) + delta))
    local id = rows[navIndex]
    local row = F.rows[id]
    if row and row.check and row.check.SetFocus then pcall(row.check.SetFocus, row.check) end
    if row and row.status and row.status.GetText then
        F.navFocus = id
        return id, row.status:GetText()
    end
    return id
end

function F:NavActivate()
    local rows = F:NavRows()
    local id = rows[navIndex]
    if not id then return false, "nothing is selected" end
    local ok, enabled = F:SetEnabled(id, not F.db.enabled[id])
    if not ok then return false, "settings are read only" end
    return true, id, enabled
end

F:Register("gamepadNav", {
    title = "Settings navigation",
    category = "Interface",
    description = "Moves through the settings list with the arrow keys and toggles the highlighted feature with Enter or Space, so a controller that sends key presses can drive the window. With a gamepad present the same keys are reachable through the client's own binding.",
    disableText = "Stops intercepting the arrow keys in the settings window.",
    conflicts = {},
    available = function() return UIParent ~= nil end,
    enable = function()
        if F.window and F.window.EnableKeyboard then
            F.window:EnableKeyboard(true)
            if not F.window.navHooked then
                F.window.navHooked = true
                F.window:HookScript("OnKeyDown", function(_, key)
                    if not F:Active("gamepadNav") then return end
                    if key == "UP" then F:NavMove(-1)
                    elseif key == "DOWN" then F:NavMove(1)
                    elseif key == "ENTER" or key == "SPACE" then
                        local ok, id, enabled = F:NavActivate()
                        if ok then F:Print((enabled and "Enabled " or "Disabled ") .. id .. ".") end
                    end
                end)
            end
        end
    end,
    disable = function() end,
})

F:Command("nav", function(rest)
    if not F:Active("gamepadNav") then F:Print("Enable Settings navigation first."); return end
    local action = (rest or ""):lower()
    if action == "next" then F:NavMove(1)
    elseif action == "back" then F:NavMove(-1)
    elseif action == "toggle" then
        local ok, id, enabled = F:NavActivate()
        F:Print(ok and ((enabled and "Enabled " or "Disabled ") .. id .. ".") or "Nothing is selected.")
        return
    end
    local id, status = F:NavMove(0)
    F:Print(id and ("Highlighted " .. id .. " (" .. tostring(status) .. ").") or "No rows are visible. Open /ts and pick a category.")
end, "/ts nav [next|back|toggle] moves the settings highlight")

F:Command("drawer", function(rest)
    if not F:Active("drawerMacros") then F:Print("Enable Macro drawer first."); return end
    local action, name = (rest or ""):match("^(%S*)%s*(.-)$")
    action = (action or ""):lower()
    if action == "" or action == "toggle" then
        F:RefreshDrawer()
        if drawer then
            if drawer:IsShown() then drawer:Hide(); F:Print("Drawer hidden.") else drawer:Show(); F:Print("Drawer shown.") end
        end
    elseif action == "add" then
        local ok, reason = F:DrawerAdd(name)
        F:Print(ok and ("Added " .. name .. " to the drawer.") or ("Not added: " .. tostring(reason)))
    elseif action == "remove" then
        local ok, reason = F:DrawerRemove(name)
        F:Print(ok and ("Removed " .. name .. " from the drawer.") or ("Not removed: " .. tostring(reason)))
    elseif action == "list" then
        local names = F:DrawerNames()
        F:Print(#names > 0 and ("Drawer: " .. table.concat(names, ", ")) or "The drawer is empty.")
    else
        F:Print("Use /ts drawer [add <name>|remove <name>|list].")
    end
end, "/ts drawer [add <name>|remove <name>|list] manages the macro drawer")

F:Command("music", function(rest)
    if not F:Active("mediaBrowser") then F:Print("Enable Music and sound browser first."); return end
    local action, name, id = (rest or ""):match("^(%S*)%s*(%S*)%s*(%S*)$")
    action = (action or ""):lower()
    if action == "" then
        local favorites = F:MediaFavorites()
        F:Print(#favorites > 0 and ("Saved sounds: " .. #favorites .. ". Use /ts music <name> or /ts music <id>.")
            or "Use /ts music <id> to play a sound, or /ts music add <name> <id> to save one.")
    elseif action == "stop" then
        if StopMusic then pcall(StopMusic) end
        F:Print("Playback stopped.")
    elseif action == "add" then
        local ok, reason = F:SaveMedia(name, tonumber(id))
        F:Print(ok and ("Saved " .. name .. " (" .. tostring(id) .. ").") or ("Not saved: " .. tostring(reason)))
    elseif action == "remove" then
        local ok, reason = F:RemoveMedia(name)
        F:Print(ok and ("Removed " .. name .. ".") or ("Not removed: " .. tostring(reason)))
    elseif action == "list" then
        local favorites = F:MediaFavorites()
        if #favorites == 0 then F:Print("No saved sounds."); return end
        for _, entry in ipairs(favorites) do F:Print("  " .. entry.name .. " -> " .. entry.id) end
    else
        local wanted = tonumber(action)
        if not wanted then
            for _, entry in ipairs(F:MediaFavorites()) do
                if entry.name:lower() == action then wanted = entry.id break end
            end
        end
        if not wanted then F:Print("No saved sound named " .. action .. "."); return end
        local ok, reason = F:PlayMedia(wanted)
        F:Print(ok and ("Playing " .. wanted .. ".") or ("Not played: " .. tostring(reason)))
    end
end, "/ts music [<id>|add <name> <id>|remove <name>|list|stop] plays or saves sounds")

F:Command("meter", function(rest)
    if not F:Active("damageMeter") then F:Print("Enable Native damage meter data first."); return end
    local action = (rest or ""):lower()
    if action == "reset" then
        if F:GetOption("damageMeter", "allowReset") ~= true then
            F:Print("Resetting is off. Turn on Allow resetting sessions in the feature options.")
            return
        end
        if not (C_DamageMeter and C_DamageMeter.ResetAllCombatSessions) then
            F:Print("This client cannot reset combat sessions.")
            return
        end
        local ok = pcall(C_DamageMeter.ResetAllCombatSessions)
        F:Print(ok and "Combat sessions reset." or "The client refused to reset the sessions.")
        return
    end
    for _, line in ipairs(F:MeterLines()) do F:Print("  " .. line) end
end, "/ts meter [reset] lists the client's combat sessions")
