-- SPDX-License-Identifier: MIT
local addonName, F = ...
F.name = addonName
F.version = "0.1.0-alpha.1"
F.features, F.order, F.listeners, F.errors = {}, {}, {}, {}
F.frame = CreateFrame("Frame")
F.paused = false

function F:Plain(value)
    return not (issecretvalue and issecretvalue(value))
end

function F:Print(message)
    print("|cff64d8c6ForeverSuite|r: " .. message)
end

function F:Register(id, definition)
    assert(not self.features[id], "Duplicate feature: " .. id)
    definition.id = id
    definition.defaultText = "Off. No behavior changes until you enable this feature."
    definition.disableText = definition.disableText or "Stops future actions. Completed actions are not undone."
    definition.combatText = "Configuration changes apply after combat ends."
    definition.state = "off"
    self.features[id] = definition
    self.order[#self.order + 1] = id
end

function F:RecordError(id, err)
    local message = self:Plain(err) and tostring(err) or "Restricted error value"
    self.errors[#self.errors + 1] = id .. ": " .. message:sub(1, 500)
    if #self.errors > 20 then table.remove(self.errors, 1) end
    local feature = self.features[id]
    if feature then feature.fault = true; feature.state = "error - disabled for this session" end
    self:Print(id .. " stopped after an error. Use /fs report for details.")
    self:Refresh()
end

function F:Listen(id, event, callback)
    if not self.listeners[event] then
        local ok = pcall(self.frame.RegisterEvent, self.frame, event)
        if not ok then error("Event unavailable: " .. event) end
        self.listeners[event] = {}
    end
    self.listeners[event][id] = callback
end

function F:IsLoaded(name)
    if not C_AddOns or not C_AddOns.IsAddOnLoaded then return false end
    return C_AddOns.IsAddOnLoaded(name) == true
end

function F:Blocker(feature)
    for _, name in ipairs(feature.conflicts or {}) do
        if self:IsLoaded(name) then return name end
    end
end

function F:Active(id)
    local feature = self.features[id]
    return self.db and not self.paused and self.supported and not self.readOnly
        and self.db.enabled[id] == true and feature.active and not feature.fault
end

function F:CanAutomate()
    return not InCombatLockdown() and not IsShiftKeyDown()
end

function F:Refresh()
    if not self.db or self.refreshing then return end
    if InCombatLockdown() then self.pending = true; return end
    self.refreshing = true
    self.pending = false
    for _, id in ipairs(self.order) do
        local feature = self.features[id]
        local reason
        if self.readOnly then reason = "newer settings version - read only"
        elseif not self.supported then reason = "unsupported client"
        elseif feature.fault then reason = "error - disabled for this session"
        elseif not self.db.enabled[id] then reason = "off"
        elseif self.paused then reason = "paused"
        else
            local blocker = self:Blocker(feature)
            if blocker then reason = "conflict: " .. blocker
            elseif feature.available then
                local ok, available = pcall(feature.available)
                if not ok or not available then reason = "API unavailable" end
            end
        end
        if reason then
            feature.active = false
            -- Disable handlers are idempotent, including restoring ownership saved last login.
            if feature.disable and not self.readOnly then
                local ok, err = pcall(feature.disable)
                if not ok then self:RecordError(id, err) end
            end
            feature.state = reason
        elseif not feature.active then
            feature.active = true
            local ok, err = true, nil
            if feature.enable then ok, err = pcall(feature.enable) end
            if not ok then
                feature.active = false
                self:RecordError(id, err)
                if feature.disable then pcall(feature.disable) end
            end
            feature.state = feature.fault and "error - disabled for this session" or "active"
        else
            feature.state = "active"
        end
    end
    self.refreshing = false
    if self.RefreshSettings then self:RefreshSettings() end
end

function F:SetEnabled(id, enabled)
    if self.readOnly or not self.features[id] or type(enabled) ~= "boolean" then return false end
    self.db.enabled[id] = enabled
    self:Refresh()
    return true
end

function F:Initialize()
    if self.db then return end
    local version, build, _, interface = GetBuildInfo()
    self.build = tostring(version) .. "." .. tostring(build)
    self.supported = type(version) == "string" and version:match("^1%.60%.") ~= nil
        and type(interface) == "number" and interface >= 16000 and interface < 17000
    local db = ForeverSuiteDB
    if type(db) ~= "table" then db = {} end
    self.readOnly = type(db.schema) == "number" and db.schema > 1
    if self.readOnly then
        -- Preserve future data verbatim rather than downgrade it.
        self.db = { enabled = {}, cvars = {}, repairCap = 100000 }
    else
        db.schema = 1
        if type(db.enabled) ~= "table" then db.enabled = {} end
        if type(db.cvars) ~= "table" then db.cvars = {} end
        if type(db.repairCap) ~= "number" or db.repairCap ~= db.repairCap
            or db.repairCap < 0 or db.repairCap > 100000000 then db.repairCap = 100000 end
        for key, value in pairs(db.enabled) do
            if not self.features[key] or type(value) ~= "boolean" then db.enabled[key] = nil end
        end
        self.db = db
        ForeverSuiteDB = db
    end
    if self.SetupSettings then self:SetupSettings() end
    self:Refresh()
end

function F:Report()
    local lines = { "ForeverSuite " .. self.version, "Client: " .. (self.build or "unknown"),
        "Stage 1 preview. In-game validation still required.",
        "All features are opt-in. Conflict detection checks loaded addons, not their settings.",
        "Repair cap: " .. tostring(self.db.repairCap / 10000) .. " gold" }
    for _, id in ipairs(self.order) do
        local feature = self.features[id]
        lines[#lines + 1] = id .. ": " .. feature.state
    end
    for _, err in ipairs(self.errors) do lines[#lines + 1] = err end
    return table.concat(lines, "\n")
end

F.frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then F:Initialize()
        elseif F.db then F:Refresh() end
    elseif event == "PLAYER_LOGIN" then F:Initialize(); F:Refresh()
    elseif event == "PLAYER_REGEN_ENABLED" then F:Refresh() end
    for id, callback in pairs(F.listeners[event] or {}) do
        if F:Active(id) then
            local ok, err = pcall(callback, event, ...)
            if not ok then F:RecordError(id, err) end
        end
    end
end)
F.frame:RegisterEvent("ADDON_LOADED")
F.frame:RegisterEvent("PLAYER_LOGIN")
F.frame:RegisterEvent("PLAYER_REGEN_ENABLED")

SLASH_FOREVERSUITE1 = "/fs"
SLASH_FOREVERSUITE2 = "/foreversuite"
SlashCmdList.FOREVERSUITE = function(message)
    F:Initialize()
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "pause" then
        F.paused = not F.paused; F:Refresh()
        F:Print(F.paused and "Paused for this session." or "Resumed.")
    elseif command == "off" or command == "on" then
        if not F:SetEnabled(rest, command == "on") then F:Print("Unknown feature or settings are read only.") end
    elseif command == "cap" then
        local gold = tonumber(rest)
        if not F.readOnly and gold and gold == gold and gold >= 0 and gold <= 10000 then
            F.db.repairCap = math.floor(gold * 10000)
            F:Print("Repair cap set to " .. gold .. " gold per merchant visit.")
        else F:Print("Use /fs cap 10 (0 to 10000 gold).") end
    elseif command == "report" then F:ShowReport(F:Report())
    elseif command == "reset" then
        if F.readOnly then return end
        for _, id in ipairs(F.order) do F.db.enabled[id] = false end
        F:Refresh(); F:Print("Features switched off; owned interface settings restored where possible.")
    else F:OpenSettings() end
end
