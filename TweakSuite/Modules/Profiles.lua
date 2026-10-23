-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Named profiles, import/export and a small CVar browser. Original implementation.
local _, F = ...
local MAX_PROFILE_NAME = 24
local MAX_PROFILES = 30

local function trim(text)
    return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function copyTable(source)
    local target = {}
    for key, value in pairs(source or {}) do target[key] = value end
    return target
end

local function characterKey()
    local name = UnitName and UnitName("player") or nil
    if type(name) ~= "string" or name == "" then return "Unknown" end
    local realm = GetRealmName and GetRealmName() or nil
    if type(realm) ~= "string" or realm == "" then realm = "Unknown" end
    return realm .. " - " .. name
end

local function profileStore()
    if type(F.db.profiles) ~= "table" then
        F.db.profiles = { data = {}, order = {} }
    end
    local store = F.db.profiles
    if type(store.data) ~= "table" then store.data = {} end
    if type(store.order) ~= "table" then store.order = {} end
    if type(store.scopes) ~= "table" then store.scopes = {} end
    return store
end

function F:ProfileNames()
    local store = profileStore()
    local names = {}
    for _, name in ipairs(store.order) do
        if store.data[name] then names[#names + 1] = name end
    end
    return names
end

function F:ProfileSnapshot()
    local data = { enabled = {}, options = {} }
    for _, id in ipairs(self.order) do
        data.enabled[id] = self.db.enabled[id] == true
    end
    for id, stored in pairs(self.db.options or {}) do
        if self.features[id] and type(stored) == "table" then
            local kept = {}
            for key, value in pairs(stored) do
                local option = self.features[id].optionByKey[key]
                if option and self:ValidateOption(option, value) ~= nil then kept[key] = value end
            end
            if next(kept) ~= nil then data.options[id] = kept end
        end
    end
    return data
end

function F:ProfileApply(data)
    if self.readOnly or type(data) ~= "table" then return false end
    local enabled = {}
    for _, id in ipairs(self.order) do
        enabled[id] = type(data.enabled) == "table" and data.enabled[id] == true or false
    end
    local options = {}
    for id, stored in pairs(type(data.options) == "table" and data.options or {}) do
        local feature = self.features[id]
        if feature and type(stored) == "table" then
            local kept = {}
            for key, value in pairs(stored) do
                local option = feature.optionByKey[key]
                local normalized = option and self:ValidateOption(option, value)
                if normalized ~= nil then kept[key] = normalized end
            end
            if next(kept) ~= nil then options[id] = kept end
        end
    end
    self.db.enabled, self.db.options = enabled, options
    self:Refresh()
    if self.RefreshSettings then self:RefreshSettings() end
    return true
end

function F:ActiveProfile()
    local store = profileStore()
    if store.scope == "character" then
        local key = characterKey()
        local name = store.perCharacter and store.perCharacter[key]
        if name and store.data[name] then return name end
    end
    if type(store.active) == "string" and store.data[store.active] then return store.active end
    return nil
end

function F:SaveProfile(name)
    if not name or name == "" then return false end
    local store = profileStore()
    store.data[name] = self:ProfileSnapshot()
    local found = false
    for _, existing in ipairs(store.order) do
        if existing == name then found = true end
    end
    if not found then store.order[#store.order + 1] = name end
    store.active = name
    if store.scope == "character" then
        store.perCharacter = store.perCharacter or {}
        store.perCharacter[characterKey()] = name
    end
    return true
end

function F:UseProfile(name)
    local store = profileStore()
    if not store.data[name] then return false, "unknown profile" end
    local current = self:ActiveProfile()
    if current and current ~= name then self:SaveProfile(current) end
    if not self:ProfileApply(store.data[name]) then return false, "read only" end
    store.active = name
    if store.scope == "character" then
        store.perCharacter = store.perCharacter or {}
        store.perCharacter[characterKey()] = name
    end
    return true
end

function F:NewProfile(name)
    name = trim(name)
    if name == "" or #name > MAX_PROFILE_NAME then return false, "name must be 1-" .. MAX_PROFILE_NAME .. " characters" end
    local store = profileStore()
    if store.data[name] then return false, "a profile with that name exists" end
    if #self:ProfileNames() >= MAX_PROFILES then return false, "too many profiles" end
    self:SaveProfile(name)
    return true
end

function F:DeleteProfile(name)
    local store = profileStore()
    if not store.data[name] then return false, "unknown profile" end
    if #self:ProfileNames() <= 1 then return false, "the last profile cannot be deleted" end
    store.data[name] = nil
    for index = #store.order, 1, -1 do
        if store.order[index] == name then table.remove(store.order, index) end
    end
    if store.active == name then
        local names = self:ProfileNames()
        if names[1] then self:UseProfile(names[1]) end
    end
    return true
end

function F:SetProfileScope(scope)
    if scope ~= "global" and scope ~= "character" then return false end
    local store = profileStore()
    store.scope = scope
    if scope == "character" then
        store.perCharacter = store.perCharacter or {}
        local current = self:ActiveProfile()
        if current then store.perCharacter[characterKey()] = current end
    end
    return true
end

local function encodeValue(value)
    if type(value) == "boolean" then return value and "true" or "false" end
    if type(value) == "number" then return string.format("%.6g", value) end
    return tostring(value):gsub("[,=;]", "_")
end

local function decodeValue(raw, option)
    if option.type == "boolean" then
        if raw == "true" then return true end
        if raw == "false" then return false end
        return nil
    elseif option.type == "number" then
        local number = tonumber(raw)
        if not number or number ~= number or number == math.huge or number == -math.huge then return nil end
        return number
    end
    return raw
end

function F:ExportProfile(name)
    local store = profileStore()
    name = name or self:ActiveProfile()
    local data = name and store.data[name]
    if not data then return nil, "no profile to export" end
    local parts = {}
    local enabled = {}
    for _, id in ipairs(self.order) do
        if data.enabled and data.enabled[id] then enabled[#enabled + 1] = id end
    end
    parts[#parts + 1] = "E=" .. table.concat(enabled, ",")
    for id, stored in pairs(data.options or {}) do
        for key, value in pairs(stored) do
            parts[#parts + 1] = "O=" .. id .. "." .. key .. "=" .. encodeValue(value)
        end
    end
    table.sort(parts)
    return "FS1|" .. table.concat(parts, ";")
end

function F:ImportProfile(text, name)
    if self.readOnly then return false, "settings are read only" end
    text = trim(text)
    if text:sub(1, 4) ~= "FS1|" then return false, "not a TweakSuite profile string" end
    local data = { enabled = {}, options = {} }
    for chunk in text:sub(5):gmatch("[^;]+") do
        local kind = chunk:sub(1, 2)
        if kind == "E=" then
            for id in chunk:sub(3):gmatch("[^,]+") do
                if self.features[id] then data.enabled[id] = true end
            end
        elseif kind == "O=" then
            local body = chunk:sub(3)
            local id, key, raw = body:match("^(%w+)%.([%w_]+)=(.*)$")
            local feature = id and self.features[id]
            local option = feature and feature.optionByKey[key]
            if option then
                local value = decodeValue(raw, option)
                if value ~= nil and self:ValidateOption(option, value) ~= nil then
                    data.options[id] = data.options[id] or {}
                    data.options[id][key] = value
                end
            end
        end
    end
    local target = trim(name or "")
    if target == "" then
        local index = 1
        repeat
            target = "Imported " .. index
            index = index + 1
        until not profileStore().data[target]
    elseif #target > MAX_PROFILE_NAME then
        return false, "name must be 1-" .. MAX_PROFILE_NAME .. " characters"
    end
    local existingNames = self:ProfileNames()
    if not profileStore().data[target] and #existingNames >= MAX_PROFILES then
        return false, "too many profiles (" .. MAX_PROFILES .. " maximum)"
    end
    profileStore().data[target] = data
    local found = false
    for _, existing in ipairs(profileStore().order) do
        if existing == target then found = true end
    end
    if not found then profileStore().order[#profileStore().order + 1] = target end
    return true, target, #self:ProfileNames()
end

F:Register("profiles", {
    title = "Settings profiles",
    category = "Interface",
    description = "Stores named sets of every feature switch and option, and switches between them with /ts profile. Profiles can be global or per character. Import and export use a validated text string, so a corrupt profile cannot apply unknown features or out-of-range options.",
    disableText = "Stops profile switching. The current settings stay exactly as they are and saved profiles remain stored.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "Reflux", "Profiles" },
    options = {
        { key = "scope", type = "choice", title = "Profile scope", default = "global",
          choices = { { value = "global", label = "Shared by every character" }, { value = "character", label = "One profile per character" } },
          description = "A global profile follows the account. A character scope remembers which profile each character used last and switches back to it when that character logs in." },
    },
    available = function() return type(F.db) == "table" or F.db == nil end,
    enable = function()
        local store = profileStore()
        if #F:ProfileNames() == 0 then
            store.data.Default = F:ProfileSnapshot()
            store.order[1] = "Default"
            store.active = "Default"
        elseif not store.active then
            store.active = F:ActiveProfile() or F:ProfileNames()[1]
        end
        F:SetProfileScope(F:GetOption("profiles", "scope"))
        F:Listen("profiles", "PLAYER_LOGIN", function()
            F:SetProfileScope(F:GetOption("profiles", "scope"))
            local active = F:ActiveProfile()
            if active then F:ProfileApply(store.data[active]) end
        end)
    end,
    refresh = function()
        if F.ActiveProfile and F:ActiveProfile() then F:SetProfileScope(F:GetOption("profiles", "scope")) end
    end,
    disable = function() end,
})

-- CVar browser -----------------------------------------------------------------
local function cvars()
    return {
        { name = "autoLootDefault", kind = "bool", default = "0", help = "Automatic looting when the client supports it." },
        { name = "autoSelfCast", kind = "bool", default = "1", help = "Cast helpful spells on yourself when nothing valid is targeted." },
        { name = "alwaysShowActionBars", kind = "bool", default = "1", help = "Keep action bars visible instead of fading." },
        { name = "lockActionBars", kind = "bool", default = "1", help = "Prevent dragging spells off action buttons." },
        { name = "ActionButtonUseKeyDown", kind = "bool", default = "0", help = "Activate action buttons on key press instead of release." },
        { name = "buffDurations", kind = "bool", default = "1", help = "Show remaining aura durations." },
        { name = "cameraBobbing", kind = "bool", default = "1", help = "Camera movement while walking." },
        { name = "cameraTerrainTilt", kind = "bool", default = "1", help = "Camera tilt following terrain." },
        { name = "cameraWaterCollision", kind = "bool", default = "1", help = "Camera stops at the water surface." },
        { name = "cameraDistanceMaxZoomFactor", kind = "number", min = 1, max = 4, default = "2",
          help = "How far the camera may zoom out." },
        { name = "chatBubbles", kind = "bool", default = "1", help = "Chat bubbles above player heads." },
        { name = "chatBubblesParty", kind = "bool", default = "1", help = "Chat bubbles for party members." },
        { name = "chatMouseScroll", kind = "bool", default = "1", help = "Scroll chat with the mouse wheel." },
        { name = "countdownForCooldowns", kind = "bool", default = "1", help = "Numeric cooldown countdowns." },
        { name = "displaySpellActivationOverlays", kind = "bool", default = "1", help = "Spell activation artwork on the action bar." },
        { name = "doNotFlashLowHealthWarning", kind = "bool", default = "0", help = "Disable the red low-health screen flash." },
        { name = "ffxGlow", kind = "bool", default = "1", help = "Full-screen glow effect." },
        { name = "ffxDeath", kind = "bool", default = "1", help = "Desaturated death screen effect." },
        { name = "floatingCombatTextCombatDamage", kind = "bool", default = "1", help = "Floating damage numbers." },
        { name = "floatingCombatTextCombatHealing", kind = "bool", default = "1", help = "Floating healing numbers." },
        { name = "instantQuestText", kind = "bool", default = "0", help = "Show quest text immediately." },
        { name = "nameplateMaxDistance", kind = "number", min = 10, max = 60, default = "40",
          help = "Maximum distance in yards for nameplates." },
        { name = "nameplateMotion", kind = "number", min = 0, max = 2, default = "0",
          help = "Nameplate layout: 0 overlapping, 1 stacked, 2 stacked (client enumeration)." },
        { name = "nameplateShowAll", kind = "bool", default = "0", help = "Always show enemy nameplates." },
        { name = "nameplateShowEnemyPets", kind = "bool", default = "1", help = "Show enemy pet nameplates." },
        { name = "nameplateShowEnemyTotems", kind = "bool", default = "1", help = "Show enemy totem nameplates." },
        { name = "nameplateShowFriendlyGuardians", kind = "bool", default = "1", help = "Show friendly guardian nameplates." },
        { name = "nameplateShowFriendlyPets", kind = "bool", default = "1", help = "Show friendly pet nameplates." },
        { name = "nameplateShowFriendlyTotems", kind = "bool", default = "1", help = "Show friendly totem nameplates." },
        { name = "nameplateShowFriends", kind = "bool", default = "0", help = "Show friendly player nameplates." },
        { name = "noBuffDebuffFilterOnTarget", kind = "bool", default = "0", help = "Show all auras on the target frame." },
        { name = "rotateMinimap", kind = "bool", default = "0", help = "Rotate the minimap with the character." },
        { name = "showTargetCastbar", kind = "bool", default = "1", help = "Target cast bar." },
        { name = "showTimestamps", kind = "bool", default = "0", help = "Timestamps in chat." },
        { name = "showTargetOfTarget", kind = "bool", default = "0", help = "Target of target frame." },
        { name = "secureAbilityToggle", kind = "bool", default = "1", help = "Prevent right-click auto-cast toggling." },
        { name = "breakUpLargeNumbers", kind = "bool", default = "1", help = "Group long numbers with separators." },
        { name = "UnitNameOwn", kind = "bool", default = "1", help = "Your own overhead name." },
        { name = "UnitNamePlayerGuild", kind = "bool", default = "1", help = "Guild names above players." },
        { name = "UnitNamePlayerPVPTitle", kind = "bool", default = "1", help = "Player titles above players." },
    }
end

local function findCvar(name)
    for _, entry in ipairs(cvars()) do
        if entry.name == name then return entry end
    end
end

function F:CvarInfo(name)
    local entry = findCvar(name)
    if not entry then return nil end
    local current
    if C_CVar and C_CVar.GetCVar then current = C_CVar.GetCVar(name) end
    return { entry = entry, current = current }
end

function F:ValidateCvarValue(entry, raw)
    if not entry then return nil, "unknown CVar" end
    raw = trim(raw):lower()
    if entry.kind == "bool" then
        if raw == "1" or raw == "on" or raw == "true" then return "1" end
        if raw == "0" or raw == "off" or raw == "false" then return "0" end
        return nil, "use on or off"
    end
    local number = tonumber(raw)
    if not number or number ~= number or number == math.huge or number == -math.huge then
        return nil, "use a number"
    end
    if entry.min and number < entry.min then return nil, "minimum is " .. entry.min end
    if entry.max and number > entry.max then return nil, "maximum is " .. entry.max end
    return tostring(number)
end

function F:SetCvarValue(name, raw)
    if self.readOnly then return false, "settings are read only" end
    local info = self:CvarInfo(name)
    if not info then return false, "unknown CVar" end
    local value, problem = self:ValidateCvarValue(info.entry, raw)
    if not value then return false, problem end
    if not C_CVar or not C_CVar.SetCVar then return false, "CVar API unavailable" end
    local before = C_CVar.GetCVar(name)
    C_CVar.SetCVar(name, value)
    local after = C_CVar.GetCVar(name)
    if after ~= value then return false, "the client refused the value" end
    if type(self.db.cvarHistory) ~= "table" then self.db.cvarHistory = {} end
    self.db.cvarHistory[#self.db.cvarHistory + 1] = name .. ": " .. tostring(before) .. " -> " .. tostring(after)
    while #self.db.cvarHistory > 20 do table.remove(self.db.cvarHistory, 1) end
    return true, after
end

function F:SearchCvars(query)
    query = trim(query):lower()
    local rows = {}
    for _, entry in ipairs(cvars()) do
        local haystack = (entry.name .. " " .. entry.help):lower()
        if query == "" or haystack:find(query, 1, true) then rows[#rows + 1] = entry end
    end
    return rows
end

F:Register("cvarBrowser", {
    title = "Advanced CVar browser",
    category = "Interface",
    description = "Lists a curated set of client settings with their current value, default, meaning and validation. /ts cvar <name> explains one entry, /ts cvar <name> <value> changes it, /ts cvar list <text> searches, and /ts cvar history shows the last 20 changes made here.",
    disableText = "Stops the CVar commands. Values already changed stay changed.",
    conflicts = { "AdvancedInterfaceOptions", "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL" },
    available = function() return C_CVar and C_CVar.GetCVar ~= nil end,
    enable = function() end,
    disable = function() end,
})
