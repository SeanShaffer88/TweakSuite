-- SPDX-License-Identifier: MIT
local addonName, F = ...
F.name = addonName
F.version = "0.2.0-alpha.5"
F.features, F.order, F.listeners, F.errors = {}, {}, {}, {}
F.frame = CreateFrame("Frame")
F.paused = false
F.pendingOptions = {}

local function normalizeOption(featureId, option, index)
    assert(type(option) == "table", "Option must be a table: " .. featureId)
    option.key = option.key or ("option" .. index)
    assert(type(option.key) == "string" and option.key ~= "", "Option key missing: " .. featureId)
    assert(type(option.title) == "string" and option.title ~= "", "Option title missing: " .. featureId .. "." .. option.key)
    assert(type(option.description) == "string" and option.description ~= "", "Option description missing: " .. featureId .. "." .. option.key)
    if option.type == "boolean" then
        option.default = option.default == true
    elseif option.type == "number" then
        assert(type(option.min) == "number" and type(option.max) == "number" and option.min <= option.max,
            "Option range invalid: " .. featureId .. "." .. option.key)
        option.step = option.step or 1
        assert(type(option.step) == "number" and option.step > 0, "Option step invalid: " .. featureId .. "." .. option.key)
        if option.integer == nil then option.integer = true end
        if option.integer then assert(option.step % 1 == 0, "Fractional step: " .. featureId .. "." .. option.key) end
        assert(type(option.default) == "number" and option.default >= option.min and option.default <= option.max,
            "Option default outside range: " .. featureId .. "." .. option.key)
        if option.integer then assert(option.default % 1 == 0, "Fractional default: " .. featureId .. "." .. option.key) end
        option.unit = option.unit or ""
    elseif option.type == "choice" then
        local choices = {}
        for _, choice in ipairs(option.choices or {}) do
            local value, label = choice, choice
            if type(choice) == "table" then value, label = choice.value, choice.label end
            assert(value ~= nil and type(label) == "string", "Invalid choice: " .. featureId .. "." .. option.key)
            choices[#choices + 1] = { value = value, label = label }
        end
        assert(#choices > 0, "Option needs choices: " .. featureId .. "." .. option.key)
        option.choices = choices
        if option.default == nil then option.default = choices[1].value end
        local found = false
        for _, choice in ipairs(choices) do
            if choice.value == option.default then found = true end
        end
        assert(found, "Option default is not a choice: " .. featureId .. "." .. option.key)
    else
        error("Unknown option type: " .. featureId .. "." .. option.key)
    end
end

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
    definition.options = definition.options or {}
    definition.optionByKey = {}
    for index, option in ipairs(definition.options) do
        normalizeOption(id, option, index)
        assert(not definition.optionByKey[option.key], "Duplicate option: " .. id .. "." .. option.key)
        definition.optionByKey[option.key] = option
    end
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
    for id in pairs(self.pendingOptions) do
        local feature = self.features[id]
        if feature and feature.active and feature.refresh and not feature.fault then
            local ok, err = pcall(feature.refresh)
            if not ok then self:RecordError(id, err) end
        end
    end
    self.pendingOptions = {}
    self.refreshing = false
    if self.RefreshSettings then self:RefreshSettings() end
end

function F:SetEnabled(id, enabled)
    if self.readOnly or not self.features[id] or type(enabled) ~= "boolean" then return false end
    self.db.enabled[id] = enabled
    self:Refresh()
    return true
end

function F:ValidateOption(option, value)
    if not option then return nil end
    if option.type == "boolean" then
        if type(value) == "boolean" then return value end
        return nil
    elseif option.type == "number" then
        if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nil end
        if option.integer and value % 1 ~= 0 then return nil end
        if value < option.min or value > option.max then return nil end
        if not option.integer then
            -- Keep fractional options stable when the options panel steps them repeatedly.
            value = math.floor(value * 1000 + 0.5) / 1000
        end
        return value
    elseif option.type == "choice" then
        for _, choice in ipairs(option.choices) do
            if choice.value == value then return choice.value end
        end
        return nil
    end
end

function F:GetOption(id, key)
    local feature = self.features[id]
    local option = feature and feature.optionByKey[key]
    if not option then return nil end
    local stored = self.db and self.db.options and self.db.options[id]
    local value = stored and stored[key]
    if value ~= nil then return value end
    return option.default
end

function F:OptionText(option, value)
    if not option then return "" end
    if option.type == "boolean" then return value and "On" or "Off" end
    if option.type == "choice" then
        for _, choice in ipairs(option.choices) do
            if choice.value == value then return choice.label end
        end
        return tostring(value)
    end
    return tostring(value) .. (option.unit or "")
end

function F:OptionValueText(id, key)
    local feature = self.features[id]
    local option = feature and feature.optionByKey[key]
    if not option then return "" end
    return self:OptionText(option, self:GetOption(id, key))
end

function F:OptionDefaultText(option)
    return self:OptionText(option, option.default)
end

function F:OptionSummary(id)
    local feature = self.features[id]
    local stored = self.db and self.db.options and self.db.options[id]
    if not feature or not stored or next(stored) == nil then return nil end
    local parts = {}
    for _, option in ipairs(feature.options) do
        if stored[option.key] ~= nil then
            parts[#parts + 1] = option.key .. "=" .. self:OptionText(option, stored[option.key])
        end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, ", ")
end

function F:NotifyFeature(id)
    local feature = self.features[id]
    if not feature or not feature.refresh or not feature.active or self.readOnly then return end
    if InCombatLockdown() then
        self.pendingOptions[id] = true
        self.pending = true
        return
    end
    local ok, err = pcall(feature.refresh)
    if not ok then self:RecordError(id, err) end
end

function F:SetOption(id, key, value)
    local feature = self.features[id]
    if not feature or self.readOnly or not self.db then return false, "unknown feature or read only" end
    local option = feature.optionByKey[key]
    if not option then return false, "unknown option" end
    local normalized = self:ValidateOption(option, value)
    if normalized == nil then return false, "invalid value" end
    if type(self.db.options) ~= "table" then self.db.options = {} end
    local stored = self.db.options[id]
    if type(stored) ~= "table" then stored = {}; self.db.options[id] = stored end
    stored[key] = normalized
    self:NotifyFeature(id)
    if self.RefreshSettings then self:RefreshSettings() end
    return true, normalized
end

function F:ResetOptions(id)
    if not self.features[id] or self.readOnly or not self.db then return false end
    if type(self.db.options) == "table" then self.db.options[id] = nil end
    self:NotifyFeature(id)
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
        self.db = { enabled = {}, options = {}, cvars = {}, repairCap = 100000 }
    else
        db.schema = 1
        if type(db.enabled) ~= "table" then db.enabled = {} end
        if type(db.options) ~= "table" then db.options = {} end
        if type(db.cvars) ~= "table" then db.cvars = {} end
        if type(db.repairCap) ~= "number" or db.repairCap ~= db.repairCap
            or db.repairCap < 0 or db.repairCap > 100000000 then db.repairCap = 100000 end
        for key, value in pairs(db.enabled) do
            if not self.features[key] or type(value) ~= "boolean" then db.enabled[key] = nil end
        end
        if type(db.gold) == "table" then
            for key, value in pairs(db.gold) do
                if type(key) ~= "string" or type(value) ~= "number" or value ~= value
                    or value < 0 or value > 1000000000000 then db.gold[key] = nil end
            end
            if next(db.gold) == nil then db.gold = nil end
        else
            db.gold = nil
        end
        if type(db.layouts) == "table" then
            for name, stored in pairs(db.layouts) do
                local valid = type(name) == "string" and type(stored) == "table"
                    and type(stored.point) == "string"
                    and type(stored.x) == "number" and stored.x == stored.x and math.abs(stored.x) <= 20000
                    and type(stored.y) == "number" and stored.y == stored.y and math.abs(stored.y) <= 20000
                    and (stored.relativePoint == nil or type(stored.relativePoint) == "string")
                if not valid then db.layouts[name] = nil end
            end
            if next(db.layouts) == nil then db.layouts = nil end
        else
            db.layouts = nil
        end
        for key, stored in pairs(db.options) do
            local feature = self.features[key]
            if not feature or type(stored) ~= "table" then
                db.options[key] = nil
            else
                for optionKey, value in pairs(stored) do
                    local option = feature.optionByKey[optionKey]
                    local normalized = option and self:ValidateOption(option, value)
                    if normalized == nil then stored[optionKey] = nil else stored[optionKey] = normalized end
                end
                if next(stored) == nil then db.options[key] = nil end
            end
        end
        self.db = db
        ForeverSuiteDB = db
    end
    if self.SetupSettings then self:SetupSettings() end
    self:Refresh()
end

function F:Report()
    local lines = { "ForeverSuite " .. self.version, "Client: " .. (self.build or "unknown"),
        "Stage 2 preview. In-game validation still required.",
        "All features are opt-in. Conflict detection checks loaded addons, not their settings.",
        "Repair cap: " .. tostring(self.db.repairCap / 10000) .. " gold" }
    for _, id in ipairs(self.order) do
        local feature = self.features[id]
        local summary = self:OptionSummary(id)
        lines[#lines + 1] = id .. ": " .. feature.state .. (summary and ("  [" .. summary .. "]") or "")
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
local function optionFromCommand(feature, key, raw)
    local option = feature and feature.optionByKey[key]
    if not option then return nil, "Unknown feature or option." end
    local value = raw
    if option.type == "boolean" then
        local lower = raw:lower()
        if lower == "on" or lower == "true" or lower == "yes" or lower == "1" then value = true
        elseif lower == "off" or lower == "false" or lower == "no" or lower == "0" then value = false
        else return nil, option.title .. " accepts on or off." end
    elseif option.type == "number" then
        value = tonumber(raw)
        if not value then return nil, option.title .. " accepts a number from " .. option.min .. " to " .. option.max .. "." end
    elseif option.type == "choice" then
        value = nil
        for _, choice in ipairs(option.choices) do
            if tostring(choice.value):lower() == raw:lower() or choice.label:lower() == raw:lower() then
                value = choice.value
            end
        end
        if value == nil then
            local labels = {}
            for _, choice in ipairs(option.choices) do labels[#labels + 1] = choice.label end
            return nil, option.title .. " choices: " .. table.concat(labels, ", ") .. "."
        end
    end
    return value
end

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
    elseif command == "set" then
        local id, key, raw = rest:match("^(%S+)%s+(%S+)%s+(.-)$")
        local feature = id and F.features[id]
        if not feature or raw == "" then
            F:Print("Use /fs set <feature> <option> <value>. /fs options <feature> lists options.")
            return
        end
        local value, problem = optionFromCommand(feature, key, raw)
        if value == nil then F:Print(problem); return end
        local ok, reason = F:SetOption(id, key, value)
        if not ok then F:Print("Option not changed: " .. tostring(reason) .. ".")
        else F:Print(feature.title .. ": " .. feature.optionByKey[key].title .. " = " .. F:OptionValueText(id, key) .. ".") end
    elseif command == "options" then
        local feature = F.features[rest]
        if not feature then F:Print("Use /fs options <feature>."); return end
        if #feature.options == 0 then F:Print(feature.title .. " has no options."); return end
        for _, option in ipairs(feature.options) do
            F:Print(option.title .. ": " .. F:OptionValueText(rest, option.key)
                .. " (default " .. F:OptionDefaultText(option) .. "). " .. option.description)
        end
    elseif command == "report" then F:ShowReport(F:Report())
    elseif command == "resetoptions" then
        if F.readOnly then F:Print("Settings are read only."); return end
        if type(F.db.options) == "table" then F.db.options = {} end
        F:Refresh(); F:Print("All feature options reset to their defaults. On/off states were kept.")
    elseif command == "windows" then
        local action, target = rest:match("^(%S*)%s*(.-)%s*$")
        action = action:lower()
        if action == "reset" then
            if F.readOnly then F:Print("Settings are read only."); return end
            if target ~= "" then
                if F.ResetWindowLayout and F:ResetWindowLayout(target) then
                    F:Print("Reset the saved position of " .. target .. ".")
                else
                    F:Print("Unknown window. Use /fs windows list to see the managed names.")
                end
                return
            end
            F.db.layouts = nil
            local feature = F.features.moveWindows
            if feature and feature.active and feature.disable then feature.disable() end
            F:Refresh()
            F:Print("Saved window positions cleared; windows returned to their default place.")
        elseif action == "list" then
            local names = F.WindowNames and F:WindowNames() or {}
            F:Print(#names .. " managed window(s): " .. table.concat(names, ", "))
        elseif action == "" then
            local count = 0
            for _ in pairs((F.db and F.db.layouts) or {}) do count = count + 1 end
            F:Print(count .. " saved window position(s). Use /fs windows list or /fs windows reset.")
        else
            F:Print("Use /fs windows, /fs windows list, or /fs windows reset [window].")
        end
    elseif command == "gold" then
        if F.PrintGold then F:PrintGold() else F:Print("Gold tracking is unavailable.") end
    elseif command == "reset" then
        if F.readOnly then return end
        if rest ~= "" then
            if not F.features[rest] then F:Print("Unknown feature."); return end
            F:SetEnabled(rest, false)
            F:ResetOptions(rest)
            F:Print("Switched off " .. rest .. " and reset its options.")
            return
        end
        for _, id in ipairs(F.order) do F.db.enabled[id] = false end
        F:Refresh(); F:Print("Features switched off; owned interface settings restored where possible.")
    else F:OpenSettings() end
end
