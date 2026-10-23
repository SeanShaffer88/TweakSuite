-- SPDX-License-Identifier: MIT
local addonName, F = ...
F.name = addonName
F.version = "0.2.0-alpha.11"
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

local function perfNow()
    if type(debugprofilestop) == "function" then
        local ok, value = pcall(debugprofilestop)
        if ok and type(value) == "number" then return value end
    end
    if type(GetTime) == "function" then
        local ok, value = pcall(GetTime)
        if ok and type(value) == "number" then return value * 1000 end
    end
    return nil
end

function F:Refresh()
    if not self.db or self.refreshing then return end
    local started = perfNow()
    local slowestId, slowest = nil, -1
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
            local enableStart = perfNow()
            if feature.enable then ok, err = pcall(feature.enable) end
            if enableStart then
                local spent = perfNow() - enableStart
                if type(spent) == "number" and spent > slowest then slowest, slowestId = spent, id end
            end
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
    if started then
        local spent = perfNow() - started
        if type(spent) == "number" then
            self.performance = { lastRefreshMs = spent, slowestMs = slowest > 0 and slowest or nil,
                slowestId = slowest > 0 and slowestId or nil }
        end
    end
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
        if type(db.neverSell) ~= "table" then db.neverSell = nil else
            local kept = {}
            for _, value in ipairs(db.neverSell) do
                if type(value) == "number" and value > 0 then kept[#kept + 1] = value end
            end
            if #kept > 0 then db.neverSell = kept else db.neverSell = nil end
        end
        if type(db.junk) ~= "table" then db.junk = nil else
            for key, value in pairs(db.junk) do
                if type(key) ~= "number" or key <= 0 or value ~= true then db.junk[key] = nil end
            end
            if next(db.junk) == nil then db.junk = nil end
        end
        if type(db.except) ~= "table" then db.except = nil else
            for key, list in pairs(db.except) do
                if type(key) ~= "string" or type(list) ~= "table" then db.except[key] = nil else
                    local kept = {}
                    for _, value in ipairs(list) do
                        if type(value) == "string" and value ~= "" and #value <= 120 then kept[#kept + 1] = value end
                    end
                    if #kept > 0 then db.except[key] = kept else db.except[key] = nil end
                end
            end
            if next(db.except) == nil then db.except = nil end
        end
        if type(db.profiles) == "table" then
            local store = db.profiles
            if type(store.data) ~= "table" then store.data = {} end
            if type(store.order) ~= "table" then store.order = {} end
            local kept, seen = {}, {}
            for _, name in ipairs(store.order) do
                if type(name) == "string" and name ~= "" and #name <= 24 and not seen[name] and store.data[name] then
                    kept[#kept + 1] = name
                    seen[name] = true
                end
            end
            for name in pairs(store.data) do
                if type(name) ~= "string" or name == "" or #name > 24 then store.data[name] = nil
                elseif not seen[name] then
                    kept[#kept + 1] = name
                    seen[name] = true
                end
            end
            store.order = kept
            if type(store.active) ~= "string" or not store.data[store.active] then
                store.active = kept[1]
            end
            if store.scope ~= "character" then store.scope = "global" end
            if type(store.perCharacter) ~= "table" then store.perCharacter = nil end
            if #kept == 0 then db.profiles = nil end
        else
            db.profiles = nil
        end
        if type(db.cvarHistory) == "table" then
            local kept = {}
            for _, line in ipairs(db.cvarHistory) do
                if type(line) == "string" and #line <= 200 then kept[#kept + 1] = line end
            end
            while #kept > 20 do table.remove(kept, 1) end
            if #kept > 0 then db.cvarHistory = kept else db.cvarHistory = nil end
        else
            db.cvarHistory = nil
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
        if type(db.anchors) == "table" then
            for name, entry in pairs(db.anchors) do
                local valid = type(name) == "string" and type(entry) == "table"
                    and type(entry.target) == "string" and entry.target ~= name
                    and type(entry.x) == "number" and type(entry.y) == "number"
                    and math.abs(entry.x) <= 2000 and math.abs(entry.y) <= 2000
                if not valid then db.anchors[name] = nil end
            end
            if next(db.anchors) == nil then db.anchors = nil end
        else
            db.anchors = nil
        end
        if type(db.windowLayouts) == "table" then
            for name, snapshot in pairs(db.windowLayouts) do
                if type(name) ~= "string" or name == "" or #name > 24 or type(snapshot) ~= "table" then
                    db.windowLayouts[name] = nil
                else
                    for windowName, entry in pairs(snapshot) do
                        local valid = type(windowName) == "string" and type(entry) == "table"
                            and type(entry.point) == "string" and type(entry.x) == "number" and type(entry.y) == "number"
                            and (entry.width == nil or (type(entry.width) == "number" and entry.width >= 1 and entry.width <= 4000))
                            and (entry.height == nil or (type(entry.height) == "number" and entry.height >= 1 and entry.height <= 4000))
                        if not valid then snapshot[windowName] = nil end
                    end
                    if next(snapshot) == nil then db.windowLayouts[name] = nil end
                end
            end
            if next(db.windowLayouts) == nil then db.windowLayouts = nil end
        else
            db.windowLayouts = nil
        end
        if type(db.questExceptions) == "table" then
            local store = db.questExceptions
            local ids, titles = {}, {}
            if type(store.ids) == "table" then
                for _, value in ipairs(store.ids) do
                    if type(value) == "number" and value > 0 and value % 1 == 0 and #ids < 200 then ids[#ids + 1] = value end
                end
            end
            if type(store.titles) == "table" then
                for _, value in ipairs(store.titles) do
                    if type(value) == "string" and value ~= "" and #value <= 120 and #titles < 200 then titles[#titles + 1] = value end
                end
            end
            if #ids == 0 and #titles == 0 then db.questExceptions = nil
            else db.questExceptions = { ids = ids, titles = titles } end
        else
            db.questExceptions = nil
        end
        if type(db.gossipPrefs) == "table" then
            for key, value in pairs(db.gossipPrefs) do
                if type(key) ~= "string" or not key:match("^%d+$") or #key > 12
                    or type(value) ~= "number" or value < 1 or value > 9 or value % 1 ~= 0 then
                    db.gossipPrefs[key] = nil
                end
            end
            if next(db.gossipPrefs) == nil then db.gossipPrefs = nil end
        else
            db.gossipPrefs = nil
        end
        if type(db.sellWhitelist) == "table" then
            local kept = {}
            for _, value in ipairs(db.sellWhitelist) do
                if type(value) == "number" and value > 0 and value % 1 == 0 and #kept < 500 then kept[#kept + 1] = value end
            end
            if #kept > 0 then db.sellWhitelist = kept else db.sellWhitelist = nil end
        else
            db.sellWhitelist = nil
        end
        if type(db.lastWhisper) ~= "string" or db.lastWhisper == "" or #db.lastWhisper > 120 then
            db.lastWhisper = nil
        end
        if type(db.gearGroups) == "table" then
            local groups, keptNames = db.gearGroups, 0
            for name, list in pairs(groups) do
                if type(name) ~= "string" or name == "" or #name > 20 or type(list) ~= "table" or keptNames >= 10 then
                    groups[name] = nil
                else
                    local kept = {}
                    for _, value in ipairs(list) do
                        if type(value) == "number" and value > 0 and value % 1 == 0 and #kept < 40 then kept[#kept + 1] = value end
                    end
                    groups[name] = kept
                    if #kept == 0 then groups[name] = nil else keptNames = keptNames + 1 end
                end
            end
            if next(db.gearGroups) == nil then db.gearGroups = nil end
        else
            db.gearGroups = nil
        end
        if type(db.lures) == "table" then
            local kept = {}
            for _, entry in ipairs(db.lures) do
                if type(entry) == "table" and type(entry.name) == "string" and entry.name ~= ""
                    and #entry.name <= 30 and type(entry.id) == "number" and entry.id > 0
                    and entry.id % 1 == 0 and #kept < 10 then
                    kept[#kept + 1] = { name = entry.name, id = entry.id }
                end
            end
            if #kept > 0 then db.lures = kept else db.lures = nil end
        else
            db.lures = nil
        end
        if type(db.teleports) == "table" then
            local kept = {}
            for _, entry in ipairs(db.teleports) do
                if type(entry) == "table" and type(entry.name) == "string" and entry.name ~= ""
                    and #entry.name <= 30 and type(entry.id) == "number" and entry.id > 0
                    and entry.id % 1 == 0 and #kept < 20 then
                    kept[#kept + 1] = { name = entry.name, id = entry.id }
                end
            end
            if #kept > 0 then db.teleports = kept else db.teleports = nil end
        else
            db.teleports = nil
        end
        if type(db.chatLog) == "table" then
            local kept = {}
            for _, entry in ipairs(db.chatLog) do
                if type(entry) == "table" and type(entry.text) == "string" and entry.text ~= ""
                    and #entry.text <= 400 then
                    kept[#kept + 1] = { channel = type(entry.channel) == "string" and entry.channel:sub(1, 20) or "",
                        name = type(entry.name) == "string" and entry.name:sub(1, 120) or "",
                        text = entry.text }
                end
            end
            while #kept > 200 do table.remove(kept, 1) end
            if #kept > 0 then db.chatLog = kept else db.chatLog = nil end
        else
            db.chatLog = nil
        end
        if type(db.channels) == "table" then
            local kept = {}
            for _, value in ipairs(db.channels) do
                if type(value) == "string" and value ~= "" and #value <= 40 and #kept < 10 then kept[#kept + 1] = value end
            end
            if #kept > 0 then db.channels = kept else db.channels = nil end
        else
            db.channels = nil
        end
        if type(db.chatFilters) == "table" then
            local kept = {}
            for _, value in ipairs(db.chatFilters) do
                if type(value) == "string" and value ~= "" and #value <= 40 and #kept < 50 then kept[#kept + 1] = value end
            end
            if #kept > 0 then db.chatFilters = kept else db.chatFilters = nil end
        else
            db.chatFilters = nil
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
    local performance = ""
    if self.performance then
        performance = string.format("Refresh %.2f ms", self.performance.lastRefreshMs or 0)
        if self.performance.slowestId then
            performance = performance .. string.format("; slowest enable %s %.2f ms",
                self.performance.slowestId, self.performance.slowestMs or 0)
        end
    end
    local lines = { "ForeverSuite " .. self.version, "Client: " .. (self.build or "unknown"),
        performance ~= "" and ("Performance: " .. performance) or "Performance: not measured yet",
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

local function confirmRequired(rest)
    if not F:Active("typedConfirm") then return false end
    local lower = tostring(rest or ""):lower()
    return lower:match("confirm%s*$") == nil
end

local function helpText()
    F:Print("Commands:")
    F:Print("  /fs - open settings; /fs on <id> / /fs off <id> switch one feature")
    F:Print("  /fs set <id> <option> <value>, /fs options <id>, /fs resetoptions")
    F:Print("  /fs cap <gold>, /fs pause, /fs reset [id], /fs report")
    F:Print("  /fs windows [list | reset [name]], /fs gold")
    F:Print("  /fs junk <item> / /fs unjunk <item>, /fs neversell [add|remove|clear] <item>, /fs except [accept|turnin] <text>")
    F:Print("  /fs copy [lines], /fs xp, /fs bag <text>, /fs watch <button> | clear")
    F:Print("  /fs profile [list|new|use|save|delete|scope|export|import], /fs cvar [name] [value] | list | history")
    F:Print("  /fs size <window> <width> <height>, /fs anchor <window> <target|clear> [x] [y], /fs layout [save|use|delete] <name>")
    F:Print("  /fs bugreport, /fs popups, /fs sockets")
    F:Print("  /fs quest [list|except <id|title>|allow <id|title>], /fs whitelist [list|add <itemID>|remove <itemID>], /fs gossip [list|prefer <1-9>|clear]")
    F:Print("  /fs chatlog [lines|clear], /fs channels [list|add|remove], /fs filter [list|add|remove], /fs whisper <name>|close, /fs reply <text>")
    F:Print("  /fs quests, /fs useq <name|itemID>, /fs qtarget <name>, /fs rested")
    F:Print("  /fs gear [list|add|remove|show], /fs fish [restore], /fs lure [list|add|remove|<name>], /fs eat, /fs drink, /fs petfood, /fs reagentbag <0-4|off>, /fs minimap [collect|restore|list]")
    F:Print("  /fs trainer [missing|ranks], /fs train [cap], /fs regen, /fs bartext [hotkeys|macros|show], /fs range")
    F:Print("  /fs where, /fs zone, /fs way <x> <y>|clear, /fs dungeon [name], /fs tele [list|add <name> <spellID>|remove <name>|menu|<name>], /fs taxi [list|<n>], /fs flight")
    F:Print("  Feature IDs appear in settings and in /fs report.")
end

SlashCmdList.FOREVERSUITE = function(message)
    F:Initialize()
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "help" then
        helpText()
    elseif command == "pause" then
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
    elseif command == "junk" or command == "unjunk" then
        if F.readOnly then F:Print("Settings are read only."); return end
        local id = tonumber(tostring(rest):match("item:(%d+)") or rest)
        if not id or id <= 0 then F:Print("Use /fs " .. command .. " <itemID or shift-clicked link>."); return end
        if type(F.db.junk) ~= "table" then F.db.junk = {} end
        F.db.junk[id] = command == "junk" and true or nil
        if next(F.db.junk) == nil then F.db.junk = nil end
        F:Print((command == "junk" and "Marked as junk: " or "Removed junk mark: ") .. id)
    elseif command == "neversell" then
        if F.readOnly then F:Print("Settings are read only."); return end
        local action, value = rest:match("^(%S*)%s*(.-)$")
        action = action:lower()
        if action == "clear" then
            F.db.neverSell = nil
            F:Print("Never-sell list cleared.")
        elseif action == "remove" then
            if F.RemoveNeverSell and F:RemoveNeverSell(tonumber(value)) then
                F:Print("Removed " .. value .. " from the never-sell list.")
            else
                F:Print("That item ID is not on the never-sell list.")
            end
        elseif action == "add" or action == "" then
            local target = action == "add" and value or rest
            local ok, id
            if F.AddNeverSell then ok, id = F:AddNeverSell(target) end
            if ok then F:Print("Added " .. tostring(id) .. " to the never-sell list.")
            else F:Print("Use /fs neversell add <itemID or link>, or /fs neversell to list.") end
        else
            local list = (F.db and F.db.neverSell) or {}
            if #list == 0 then F:Print("The never-sell list is empty.")
            else F:Print("Never sell: " .. table.concat(list, ", ")) end
        end
    elseif command == "except" then
        if F.readOnly then F:Print("Settings are read only."); return end
        local kind, text = rest:match("^(%S*)%s*(.-)%s*$")
        kind = kind:lower()
        if kind ~= "accept" and kind ~= "turnin" then
            local accept = (F.db.except or {}).accept or {}
            local turnin = (F.db.except or {}).turnin or {}
            F:Print("Never accept (" .. #accept .. "): "
                .. (#accept > 0 and table.concat(accept, "; ") or "none"))
            F:Print("Never turn in (" .. #turnin .. "): "
                .. (#turnin > 0 and table.concat(turnin, "; ") or "none"))
            return
        end
        if type(F.db.except) ~= "table" then F.db.except = {} end
        local list = F.db.except[kind] or {}
        if text == "" then
            F:Print(table.concat(list, "; "))
            return
        end
        for index = #list, 1, -1 do
            if list[index] == text then table.remove(list, index) end
        end
        list[#list + 1] = text
        F.db.except[kind] = list
        F:Print("Added to the " .. kind .. " exception list: " .. text)
    elseif command == "copy" then
        if F.CopyChat then
            local lines = F:CopyChat(rest)
            if lines == 0 then F:Print("Nothing to copy.") else F:Print("Copied " .. lines .. " chat line(s) to the copy box.") end
        else F:Print("Chat copying is unavailable.") end
    elseif command == "xp" then
        if not F.features.xpTracker or not F:Active("xpTracker") then
            F:Print("Enable Experience per hour first.")
        elseif F.XPRate then
            local gained, elapsed, perHour = F:XPRate()
            if not gained then F:Print("Tracking starts when experience is next gained.")
            else F:Print(string.format("%d XP in %d seconds, about %d XP per hour.", gained, math.floor(elapsed), perHour)) end
        end
    elseif command == "bag" then
        if not F.features.bagSearch or not F:Active("bagSearch") then
            F:Print("Enable Bag item search first."); return
        end
        if rest == "" then F:Print("Use /fs bag <text> to search your bags."); return end
        local filters = {}
        local needle = rest:lower()
        if F.Active and F:Active("bagFilters") and F.ParseBagSearch then
            local parsedFilters, words = F:ParseBagSearch(rest)
            filters = parsedFilters
            needle = words
            if #filters > 0 and needle == "" then needle = "" end
        end
        local found = {}
        local function scan(bag)
            local slots = 0
            if C_Container and C_Container.GetContainerNumSlots then slots = C_Container.GetContainerNumSlots(bag) or 0
            elseif GetContainerNumSlots then slots = GetContainerNumSlots(bag) or 0 end
            for slot = 1, slots do
                local link
                if C_Container and C_Container.GetContainerItemLink then link = C_Container.GetContainerItemLink(bag, slot)
                elseif GetContainerItemLink then link = GetContainerItemLink(bag, slot) end
                if type(link) == "string" then
                    local name = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(link)
                    local values = { C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(link) }
                    local info = { classID = values[12], quality = values[3] }
                    local nameOK = (needle == "" or (type(name) == "string" and name:lower():find(needle, 1, true)))
                    local filterOK = true
                    if F.BagFilterMatch then filterOK = F:BagFilterMatch(link, info, filters) end
                    if type(name) == "string" and nameOK and filterOK then
                        found[#found + 1] = name .. " (bag " .. bag .. ", slot " .. slot .. ")"
                    end
                end
            end
        end
        for bag = 0, (NUM_BAG_SLOTS or 4) do scan(bag) end
        if #found == 0 then F:Print("No bag item matches \"" .. rest .. "\".")
        else
            F:Print(#found .. " matching item(s):")
            for index = 1, math.min(#found, 20) do F:Print("  " .. found[index]) end
        end
    elseif command == "watch" then
        if F.readOnly then F:Print("Settings are read only."); return end
        if rest == "" then
            local list = (F.db and F.db.watch) or {}
            F:Print(#list .. " watched button(s): " .. (#list > 0 and table.concat(list, ", ") or "none"))
            return
        end
        if rest:lower() == "clear" then
            F.db.watch = nil; F:Print("Watched button list cleared."); return
        end
        if not F.db.watch then F.db.watch = {} end
        for index = #F.db.watch, 1, -1 do
            if F.db.watch[index] == rest then table.remove(F.db.watch, index) end
        end
        F.db.watch[#F.db.watch + 1] = rest
        F:Print("Also watching button " .. rest .. " for the dialog key.")
    elseif command == "trainer" then
        if not F:Active("trainerHelper") then F:Print("Enable Trainer list and rank upgrades first."); return end
        local mode = rest:lower()
        if mode ~= "" and mode ~= "missing" and mode ~= "ranks" then
            F:Print("Use /fs trainer, /fs trainer missing or /fs trainer ranks."); return
        end
        F:TrainerReport(mode)
    elseif command == "train" then
        if not F:Active("trainerBulk") then F:Print("Enable Bulk trainer purchases first."); return end
        if rest ~= "" and confirmRequired(rest) then
            F:Print("This spends gold. Type /fs train confirm to continue.")
            return
        end
        local cap = tonumber(rest) or F:GetOption("trainerBulk", "cap")
        local ok, learned, spent = F:TrainAll(cap and cap * 10000)
        if ok then
            F:Print("Learned " .. learned .. " trainer service(s) for "
                .. (GetMoneyString and GetMoneyString(spent) or (spent .. "c")) .. ".")
        else
            F:Print("Not trained: " .. tostring(learned))
        end
    elseif command == "regen" then
        if not F:Active("manaRegen") then F:Print("Enable Mana regeneration timing first."); return end
        local report = F:ManaReport()
        if not report then F:Print("This client does not report mana for your character."); return end
        F:Print(string.format("Mana %d/%d (%.0f%%).", report.mana, report.max, report.percent))
        if report.sinceSpend then
            F:Print(string.format("Last mana spent %.1f s ago; five-second rule %s.",
                report.sinceSpend, report.ruleActive and "is running" or "has ended"))
        else
            F:Print("No mana spent since the feature started tracking.")
        end
    elseif command == "bartext" then
        if not F:Active("actionBarText") then F:Print("Enable Action bar text first."); return end
        local action = rest:lower()
        if action == "hotkeys" then
            local on = not F:GetOption("actionBarText", "hideHotkeys")
            F:SetOption("actionBarText", "hideHotkeys", on); F:SetOption("actionBarText", "hideMacroNames", false)
            F:Print(on and "Keybind letters hidden." or "Keybind letters shown.")
        elseif action == "macros" then
            local on = not F:GetOption("actionBarText", "hideMacroNames")
            F:SetOption("actionBarText", "hideMacroNames", on); F:SetOption("actionBarText", "hideHotkeys", false)
            F:Print(on and "Macro names hidden." or "Macro names shown.")
        elseif action == "show" or action == "" then
            F:SetOption("actionBarText", "hideHotkeys", false); F:SetOption("actionBarText", "hideMacroNames", false)
            F:Print("Both keybind letters and macro names are shown.")
        else
            F:Print("Use /fs bartext hotkeys | macros | show.")
        end
    elseif command == "range" then
        if not F:Active("actionRange") then F:Print("Enable Action button range colouring first."); return end
        local counts = { inRange = 0, outOfRange = 0, unusable = 0, unknown = 0 }
        for index = 1, 120 do
            if _G["ActionButton" .. index] or index == 1 then
                local state = F:ActionRangeState(index)
                counts[state] = (counts[state] or 0) + 1
                if index <= 12 then
                    F:Print("Action " .. index .. ": " .. state)
                end
            end
        end
    elseif command == "gear" then
        if not F:Active("gearGroups") then F:Print("Enable Gear groups first."); return end
        local action, group, item = rest:match("^(%S*)%s*(%S*)%s*(%S*)$")
        action = action:lower()
        if action == "" or action == "list" then
            local lines = F:GearGroupReport()
            if #lines == 0 then F:Print("No gear groups yet. Use /fs gear add <group> <itemID>.")
            else for _, line in ipairs(lines) do F:Print(line) end end
        elseif action == "add" then
            local ok, result = F:GearAdd(group, item)
            F:Print(ok and ("Added item " .. result .. " to gear group " .. group .. ".") or ("Not added: " .. tostring(result)))
        elseif action == "remove" then
            local ok, problem = F:GearRemove(group, item)
            F:Print(ok and "Removed the item from the gear group." or ("Not removed: " .. tostring(problem)))
        elseif action == "show" then
            if not F:Active("gearBagMarks") then F:Print("Enable Gear group bag markers first."); return end
            if group == "clear" or group == "" then
                F.markedGearGroup = nil
                F:MarkGearInBags(nil)
                F:Print("Cleared gear group marks.")
            else
                F.markedGearGroup = group
                local count = F:MarkGearInBags(group)
                F:Print("Marked " .. count .. " bag slot(s) for gear group " .. group .. ".")
            end
        else
            F:Print("Use /fs gear list | add <group> <itemID> | remove <group> <itemID> | show <group>|clear.")
        end
    elseif command == "fish" then
        if not F:Active("fishingSet") and not F:Active("fishingCast") then
            F:Print("Enable Fishing gear restoration or Fishing cast shortcut first."); return
        end
        if rest:lower() == "restore" then
            local ok, result = F:RestoreFishingSet()
            F:Print(ok and ("Restored " .. tostring(result) .. " weapon(s).") or ("Not restored: " .. tostring(result)))
            return
        end
        local ok, problem = F:Fish()
        if ok then
            if F:GetOption("fishingLure", "remind") and F:Active("fishingLure") and F:HasLure() == false then
                F:Print("No lure is active. Use /fs lure <name> to apply a saved lure.")
            end
            F:Print("Casting Fishing.")
        else
            F:Print("Not cast: " .. tostring(problem))
        end
    elseif command == "lure" then
        local action, name, item = rest:match("^(%S*)%s*(%S*)%s*(%S*)$")
        action = action:lower()
        if action == "" then
            if not F:Active("fishingLure") then F:Print("Enable Fishing lure selection first."); return end
            local ok, result = F:ApplyLure()
            F:Print(ok and ("Applied lure " .. tostring(result) .. ".") or ("Not applied: " .. tostring(result)))
        elseif action == "list" then
            local list = F.LureList and F:LureList() or {}
            local parts = {}
            for _, entry in ipairs(list) do parts[#parts + 1] = entry.name .. " (" .. entry.id .. ")" end
            F:Print(#parts .. " saved lure(s): " .. (#parts > 0 and table.concat(parts, ", ") or "none"))
        elseif action == "add" then
            if not F:Active("fishingLure") then F:Print("Enable Fishing lure selection first."); return end
            local ok, result, id = F:SetLure(name, item)
            F:Print(ok and ("Saved lure " .. result .. " for item " .. id .. ".") or ("Not saved: " .. tostring(result)))
        elseif action == "remove" then
            local removed = false
            local list = F.LureList and F:LureList() or {}
            for index = #list, 1, -1 do
                if list[index].name:lower() == name:lower() then table.remove(list, index); removed = true end
            end
            F:Print(removed and ("Removed lure " .. name .. ".") or "That lure does not exist.")
        else
            if not F:Active("fishingLure") then F:Print("Enable Fishing lure selection first."); return end
            local ok, result = F:ApplyLure(action)
            F:Print(ok and ("Applied lure " .. tostring(result) .. ".") or ("Not applied: " .. tostring(result)))
        end
    elseif command == "eat" or command == "drink" then
        if not F:Active("foodDrink") then F:Print("Enable Eat and drink shortcuts first."); return end
        local ok, result = F:UseFoodOrDrink(command)
        F:Print(ok and ("Used " .. tostring(result) .. ".") or ("Not used: " .. tostring(result)))
    elseif command == "petfood" then
        if not F:Active("petFood") then F:Print("Enable Pet food highlights first."); return end
        local rows = F.PetFoodList and F:PetFoodList() or {}
        if #rows == 0 then F:Print("No pet food found in your bags.")
        else
            for index = 1, math.min(#rows, 20) do
                F:Print("  " .. rows[index].name .. " (bag " .. rows[index].bag .. ", slot " .. rows[index].slot .. ")")
            end
        end
    elseif command == "reagentbag" then
        if not F:Active("reagentBag") then F:Print("Enable Protect the reagent bag first."); return end
        if rest:lower() == "off" then
            F:SetOption("reagentBag", "bag", 0)
            F:Print("Bag 0 (the backpack) is now the protected bag. Use /fs reagentbag <0-4> to change it.")
            return
        end
        local number = tonumber(rest)
        if not number then F:Print("Use /fs reagentbag <0-4> or /fs reagentbag off."); return end
        local ok = F:SetOption("reagentBag", "bag", number)
        F:Print(ok and ("Protected bag " .. number .. " from selling.") or "Bag number must be between 0 and 4.")
    elseif command == "minimap" then
        if not F:Active("minimapButtons") then F:Print("Enable Minimap button collection first."); return end
        local action = rest:lower()
        if action == "" or action == "collect" then
            F:Print("Hid " .. F:CollectMinimapButtons() .. " minimap button(s).")
        elseif action == "restore" then
            F:Print("Showed " .. F:RestoreMinimapButtons() .. " minimap button(s).")
        elseif action == "list" then
            local rows = F.MinimapButtons and F:MinimapButtons() or {}
            local names = {}
            for _, button in ipairs(rows) do
                names[#names + 1] = (button.GetName and button:GetName()) or "unnamed"
            end
            F:Print(#names .. " button(s): " .. (#names > 0 and table.concat(names, ", ") or "none"))
        else
            F:Print("Use /fs minimap collect | restore | list.")
        end
    elseif command == "quests" then
        if not F:Active("questList") then F:Print("Enable Quest list with levels first."); return end
        F:PrintQuestList(F:Active("questDistance"))
    elseif command == "useq" then
        if not F:Active("questItemUse") then F:Print("Enable Use quest items by name first."); return end
        local ok, result = F:UseQuestItem(rest)
        F:Print(ok and ("Used " .. tostring(result) .. ".") or ("Not used: " .. tostring(result)))
    elseif command == "qtarget" then
        if not F:Active("questTarget") then F:Print("Enable Target a quest mob by name first."); return end
        if rest == "" then F:Print("Use /fs qtarget <creature name>."); return end
        local ok = false
        if TargetByName then
            local called, found = pcall(TargetByName, rest, true)
            ok = called and found ~= false
        elseif TargetUnit then
            local called = pcall(TargetUnit, rest)
            ok = called
        end
        F:Print(ok and ("Targeting " .. rest .. ".") or "No creature with that name is nearby.")
    elseif command == "rested" then
        if not F:Active("restedInfo") then F:Print("Enable Rested experience report first."); return end
        F:PrintRested()
    elseif command == "where" then
        if not F:Active("worldMapCoords") then F:Print("Enable World map cursor coordinates first."); return end
        local x, y
        if F.CursorMapPosition then x, y = F:CursorMapPosition() end
        if x then
            F:Print("Map coordinates: " .. x .. ", " .. y)
        else
            F:Print("Move the mouse over the open world map and try again.")
        end
    elseif command == "zone" then
        local zone = GetRealZoneText and GetRealZoneText() or (GetZoneText and GetZoneText())
        local range = F.ZoneLevelRange and F:ZoneLevelRange(zone) or nil
        if not zone then F:Print("The client did not report a zone.")
        elseif range then F:Print(zone .. ": levels " .. range .. ".")
        else F:Print(zone .. ": no level range recorded for this zone.") end
    elseif command == "way" then
        if not F:Active("waypoints") then F:Print("Enable Waypoint commands first."); return end
        if rest:lower() == "clear" then
            F:Print(F:ClearWaypoint() and "Cleared the waypoint." or "This client has no waypoint to clear.")
            return
        end
        local x, y, map = rest:match("^(%S+)%s+(%S+)%s*(%S*)$")
        local ok, result = F:SetWaypoint(x, y, tonumber(map))
        F:Print(ok and ("Set a waypoint at " .. x .. ", " .. y .. ".") or ("Waypoint not set: " .. tostring(result)))
    elseif command == "dungeon" then
        if not F:Active("dungeonMarkers") then F:Print("Enable Dungeon entrance notes first."); return end
        if rest ~= "" then
            local data = F:DungeonEntrance(rest)
            if not data then F:Print("Unknown dungeon. Use /fs dungeon to list them."); return end
            F:Print(rest .. ": entrance in " .. data.zone .. " at " .. data.x .. ", " .. data.y .. " (levels " .. data.level .. ").")
            F:SetWaypoint(data.x, data.y)
        else
            local names = F:DungeonNames()
            for index = 1, math.min(#names, 25) do
                local data = F:DungeonEntrance(names[index])
                F:Print(names[index] .. " - " .. data.zone .. " " .. data.x .. ", " .. data.y .. " (" .. data.level .. ")")
            end
        end
    elseif command == "tele" then
        local action, name, spell = rest:match("^(%S*)%s*(%S*)%s*(%S*)$")
        action = action:lower()
        if action == "" or action == "list" then
            local list = F.TeleportList and F:TeleportList() or {}
            local parts = {}
            for _, entry in ipairs(list) do parts[#parts + 1] = entry.name .. " (" .. entry.id .. ")" end
            F:Print(#parts .. " teleport favorite(s): " .. (#parts > 0 and table.concat(parts, ", ") or "none"))
        elseif action == "add" then
            if not F:Active("teleportFavorites") then F:Print("Enable Teleport favorites first."); return end
            local ok, result, id = F:AddTeleport(name, spell)
            if ok then F:Print("Saved teleport favorite " .. result .. " for spell " .. id .. ".")
            else F:Print("Not saved: " .. tostring(result)) end
        elseif action == "remove" then
            F:Print(F:RemoveTeleport(name) and ("Removed teleport favorite " .. name .. ".") or "That favorite does not exist.")
        elseif action == "menu" then
            local ok, problem = F:ToggleTeleportMenu()
            if not ok then F:Print(tostring(problem)) end
        else
            if not F:Active("teleportFavorites") then F:Print("Enable Teleport favorites first."); return end
            local ok, result = F:CastTeleport(action)
            if ok then
                if F:GetOption("teleportFavorites", "confirm") ~= false then F:Print("Casting " .. tostring(result) .. ".") end
            else F:Print("Not cast: " .. tostring(result)) end
        end
    elseif command == "taxi" then
        if not F:Active("flightShortcuts") then F:Print("Enable Flight map shortcuts first."); return end
        local number = tonumber(rest)
        if rest == "" or rest:lower() == "list" then
            local rows = F.TaxiNodes and F:TaxiNodes() or {}
            if #rows == 0 then F:Print("No flight points are listed right now. Open the taxi map first.")
            else
                for _, row in ipairs(rows) do F:Print("  " .. row.index .. ". " .. row.name) end
                F:Print("Use /fs taxi <number> to take a flight point.")
            end
        elseif number and TakeTaxiNode then
            local ok = pcall(TakeTaxiNode, number)
            F:Print(ok and ("Taking flight point " .. number .. ".") or "The client refused that flight point.")
        else
            F:Print("Use /fs taxi list or /fs taxi <number>.")
        end
    elseif command == "flight" then
        if not F:Active("flightTimer") then F:Print("Enable Flight time display first."); return end
        local elapsed = F.FlightElapsed and F:FlightElapsed() or 0
        if elapsed > 0 then F:Print(string.format("This flight has taken %.1f seconds.", elapsed))
        else F:Print("Not on a taxi flight right now.") end
    elseif command == "chatlog" then
        local action = rest:lower()
        if action == "clear" or action == "clear confirm" then
            if confirmRequired(rest) then
                F:Print("This deletes stored chat lines. Type /fs chatlog clear confirm to continue.")
                return
            end
            if F.db then F.db.chatLog = nil end
            F:Print("Stored chat history cleared.")
        else
            local count = tonumber(action) or 40
            local text = F.ChatLogText and F:ChatLogText(count) or ""
            if text == "" then F:Print("No stored chat lines yet.")
            else
                if F.ShowReport then F:ShowReport(text) end
                F:Print("Showing the last stored chat lines in the copy window.")
            end
        end
    elseif command == "channels" then
        local action, value = rest:match("^(%S*)%s*(.-)%s*$")
        action = action:lower()
        if action == "" or action == "list" then
            local list = F.ChannelList and F:ChannelList() or {}
            F:Print(#list .. " saved channel(s): " .. (#list > 0 and table.concat(list, ", ") or "none"))
        elseif action == "add" then
            if not F:Active("chatChannels") then F:Print("Enable Saved chat channels first."); return end
            local ok, problem = F:AddChannel(value)
            F:Print(ok and ("Saved channel " .. value .. ".") or ("Not saved: " .. tostring(problem)))
        elseif action == "remove" then
            local ok, problem = F:RemoveChannel(value)
            F:Print(ok and ("Removed and left channel " .. value .. ".") or ("Not removed: " .. tostring(problem)))
        else
            F:Print("Use /fs channels list | add <name> | remove <name>.")
        end
    elseif command == "filter" then
        local action, value = rest:match("^(%S*)%s*(.-)%s*$")
        action = action:lower()
        if action == "" or action == "list" then
            local list = F.ChatFilterList and F:ChatFilterList() or {}
            F:Print(#list .. " chat filter(s): " .. (#list > 0 and table.concat(list, ", ") or "none"))
        elseif action == "add" then
            if not F:Active("chatFilters") then F:Print("Enable Chat word filter first."); return end
            local ok, problem = F:AddChatFilter(value)
            F:Print(ok and ("Filtering lines containing " .. value .. ".") or ("Not added: " .. tostring(problem)))
        elseif action == "remove" then
            local ok = F:RemoveChatFilter(value)
            F:Print(ok and "Removed the chat filter." or "That filter does not exist.")
        else
            F:Print("Use /fs filter list | add <word> | remove <word>.")
        end
    elseif command == "whisper" then
        if rest:lower() == "close" or rest == "" then
            if F.HideWhisper then F:HideWhisper() end
            F:Print("Closed the whisper window.")
        elseif not F:Active("whisperWindow") then
            F:Print("Enable Whisper conversation window first.")
        else
            local ok, problem = F:ShowWhisper(rest)
            F:Print(ok and ("Opened the whisper log for " .. rest .. ".") or ("Not opened: " .. tostring(problem)))
        end
    elseif command == "reply" then
        if F.db and type(F.db.lastWhisper) == "string" and rest ~= "" and SendChatMessage then
            pcall(SendChatMessage, rest, "WHISPER", nil, F.db.lastWhisper)
            F:Print("Whispered " .. F.db.lastWhisper .. ".")
        elseif F.db and type(F.db.lastWhisper) == "string" then
            F:Print("Use /fs reply <text> to answer " .. F.db.lastWhisper .. ".")
        else
            F:Print("No whisper to reply to yet.")
        end
    elseif command == "quest" then
        local action, value = rest:match("^(%S*)%s*(.-)%s*$")
        action = action:lower()
        if action == "" or action == "list" then
            local store = F.QuestExceptionList and F:QuestExceptionList() or { ids = {}, titles = {} }
            local parts = {}
            for _, id in ipairs(store.ids or {}) do parts[#parts + 1] = tostring(id) end
            for _, title in ipairs(store.titles or {}) do parts[#parts + 1] = title end
            F:Print(#parts .. " quest exception(s): " .. (#parts > 0 and table.concat(parts, ", ") or "none"))
        elseif action == "except" then
            if not F:Active("questExceptions") then F:Print("Enable Quest acceptance exceptions first."); return end
            local ok, what = F:AddQuestException(value)
            F:Print(ok and ("Added quest exception " .. tostring(what) .. ".") or "Use /fs quest except <questID|title>.")
        elseif action == "allow" then
            local ok = F:RemoveQuestException(value)
            F:Print(ok and "Removed the quest exception." or "That quest is not in the exception list.")
        else
            F:Print("Use /fs quest list | except <questID|title> | allow <questID|title>.")
        end
    elseif command == "whitelist" then
        local action, value = rest:match("^(%S*)%s*(.-)%s*$")
        action = action:lower()
        if action == "" or action == "list" then
            local list = F.SellWhitelist and F:SellWhitelist() or {}
            local parts = {}
            for _, id in ipairs(list) do parts[#parts + 1] = tostring(id) end
            F:Print(#parts .. " whitelisted item(s): " .. (#parts > 0 and table.concat(parts, ", ") or "none"))
        elseif action == "add" then
            if not F:Active("sellWhitelist") then F:Print("Enable Sell whitelist first."); return end
            local ok, id = F:AddSellWhitelist(value)
            F:Print(ok and ("Whitelisted item " .. id .. ".") or "Use /fs whitelist add <itemID>.")
        elseif action == "remove" then
            local ok = F:RemoveSellWhitelist(value)
            F:Print(ok and "Removed the item from the whitelist." or "That item is not whitelisted.")
        else
            F:Print("Use /fs whitelist list | add <itemID> | remove <itemID>.")
        end
    elseif command == "gossip" then
        local action, value = rest:match("^(%S*)%s*(.-)%s*$")
        action = action:lower()
        if action == "" or action == "list" then
            local rows = F.GossipPreferenceList and F:GossipPreferenceList() or {}
            if #rows == 0 then F:Print("No NPC gossip preferences yet.")
            else
                for _, row in ipairs(rows) do
                    F:Print("NPC " .. tostring(row.npc) .. " -> option " .. tostring(row.index))
                end
            end
        elseif action == "prefer" then
            if not F:Active("gossipPreferences") then F:Print("Enable Per-NPC gossip preferences first."); return end
            local ok, key, index = F:SetGossipPreference(value)
            F:Print(ok and ("NPC " .. tostring(key) .. " now chooses gossip option " .. index .. ".")
                or ("Not saved: " .. tostring(key)))
        elseif action == "clear" then
            local ok, key = F:ClearGossipPreference()
            F:Print(ok and ("Cleared the preference for NPC " .. tostring(key) .. ".") or ("Nothing cleared: " .. tostring(key)))
        else
            F:Print("Use /fs gossip list | prefer <1-9> | clear.")
        end
    elseif command == "bugreport" then
        if F.OpenBugReporter and F:OpenBugReporter() then
            F:Print("Opened the client bug reporter.")
        else
            F:Print("This client has no script-visible bug reporter. Use the client's own Help menu to report a bug.")
        end
    elseif command == "popups" then
        local surveys = F.BetaFrames and F:BetaFrames("surveys") or {}
        local buttons = F.BetaFrames and F:BetaFrames("buttons") or {}
        F:Print("Detected survey frames: " .. (#surveys > 0 and table.concat(surveys, ", ") or "none"))
        F:Print("Detected report buttons: " .. (#buttons > 0 and table.concat(buttons, ", ") or "none"))
    elseif command == "sockets" then
        if not F:Active("socketInfo") then F:Print("Enable Socket inspection first."); return end
        local rows = F.InspectSockets and F:InspectSockets() or {}
        if #rows == 0 then
            F:Print("No equipped item has an empty socket (or this client does not report socket data).")
        else
            for _, row in ipairs(rows) do
                F:Print("Slot " .. row.slot .. ": " .. tostring(row.link) .. " has "
                    .. row.empty .. " of " .. row.total .. " sockets empty.")
            end
        end
    elseif command == "size" then
        local name, width, height = rest:match("^(%S+)%s+(%S+)%s+(%S+)$")
        if not name then F:Print("Use /fs size <window> <width> <height>, for example /fs size MerchantFrame 900 700."); return end
        local ok, problem = F:SetWindowSize(name, tonumber(width), tonumber(height))
        F:Print(ok and (name .. " resized to " .. width .. " x " .. height .. ".") or ("Not resized: " .. tostring(problem)))
    elseif command == "anchor" then
        local name, target, x, y = rest:match("^(%S+)%s*(%S*)%s*(%S*)%s*(%S*)$")
        if not name then F:Print("Use /fs anchor <window> <target|clear> [x] [y]."); return end
        local ok, problem = F:SetWindowAnchor(name, target, x, y)
        if not ok then F:Print("Anchor not changed: " .. tostring(problem)); return end
        if target == "" or target == "clear" then
            F:Print("Anchor cleared for " .. name .. ".")
        else
            F:ApplyWindowAnchor(name)
            F:Print(name .. " anchored to " .. target .. " at " .. tostring(x) .. ", " .. tostring(y) .. ".")
        end
    elseif command == "layout" then
        local action, name = rest:match("^(%S*)%s*(.-)%s*$")
        action = action:lower()
        if action == "" or action == "list" then
            local names = F.WindowLayoutNames and F:WindowLayoutNames() or {}
            F:Print(#names .. " window layout(s): " .. (#names > 0 and table.concat(names, ", ") or "none"))
        elseif action == "save" then
            local ok, problem = F:SaveWindowLayout(name)
            F:Print(ok and ("Saved window layout " .. name .. ".") or ("Not saved: " .. tostring(problem)))
        elseif action == "use" then
            local ok, result = F:ApplyWindowLayout(name)
            F:Print(ok and ("Applied window layout " .. name .. " to " .. result .. " window(s).")
                or ("Not applied: " .. tostring(result)))
        elseif action == "delete" then
            local ok, problem = F:DeleteWindowLayout(name)
            F:Print(ok and ("Deleted window layout " .. name .. ".") or ("Not deleted: " .. tostring(problem)))
        else
            F:Print("Use /fs layout list | save <name> | use <name> | delete <name>.")
        end
    elseif command == "profile" then
        if not F.ProfileNames then F:Print("Profiles are unavailable."); return end
        if not F:Active("profiles") and command ~= "profile" then
            F:Print("Enable Settings profiles first."); return
        end
        local action, rest2 = rest:match("^(%S*)%s*(.-)%s*$")
        action = action:lower()
        if action == "" or action == "list" then
            local names = F:ProfileNames()
            local active = F:ActiveProfile()
            F:Print("Profiles (" .. #names .. "): " .. table.concat(names, ", "))
            F:Print("Active: " .. tostring(active) .. "  Scope: " .. tostring((F.db.profiles or {}).scope or "global"))
        elseif not F:Active("profiles") then
            F:Print("Enable Settings profiles first.")
        elseif action == "new" then
            local ok, problem = F:NewProfile(rest2)
            F:Print(ok and ("Created and saved profile " .. rest2 .. ".") or ("Profile not created: " .. tostring(problem)))
        elseif action == "use" then
            local ok, problem = F:UseProfile(rest2)
            F:Print(ok and ("Switched to profile " .. rest2 .. ".") or ("Profile not switched: " .. tostring(problem)))
        elseif action == "save" then
            local target = rest2 ~= "" and rest2 or F:ActiveProfile()
            if not target then F:Print("No active profile. Use /fs profile new <name>."); return end
            F:SaveProfile(target)
            F:Print("Saved current settings into profile " .. target .. ".")
        elseif action == "delete" then
            if confirmRequired(rest2) then
                F:Print("This deletes saved settings. Type /fs profile delete " .. rest2 .. " confirm to continue.")
                return
            end
            rest2 = rest2:gsub("%s*confirm%s*$", "")
            local ok, problem = F:DeleteProfile(rest2)
            F:Print(ok and ("Deleted profile " .. rest2 .. ".") or ("Profile not deleted: " .. tostring(problem)))
        elseif action == "scope" then
            local scope = rest2:lower()
            if F:SetProfileScope(scope) then
                F:SetOption("profiles", "scope", scope)
                F:Print("Profiles are now " .. (scope == "character" and "per character." or "shared by every character."))
            else
                F:Print("Use /fs profile scope global or /fs profile scope character.")
            end
        elseif action == "export" then
            local text, problem = F:ExportProfile(rest2 ~= "" and rest2 or nil)
            if text then
                if F.ShowReport then F:ShowReport(text) end
                F:Print("Exported profile " .. tostring(rest2 ~= "" and rest2 or F:ActiveProfile()) .. " to the copy box.")
            else F:Print("Export failed: " .. tostring(problem)) end
        elseif action == "import" then
            if rest2 == "" then F:Print("Use /fs profile import <text> [name]."); return end
            local ok, target, count = F:ImportProfile(rest2)
            F:Print(ok and ("Imported profile as " .. target .. " (" .. count .. " total).")
                or ("Import failed: " .. tostring(target)))
        else
            F:Print("Use /fs profile list|new|use|save|delete|scope|export|import.")
        end
    elseif command == "cvar" then
        if not F:Active("cvarBrowser") then F:Print("Enable Advanced CVar browser first."); return end
        local action, rest2 = rest:match("^(%S*)%s*(.-)%s*$")
        if action == "" or action == "list" then
            local rows = F:SearchCvars(rest2)
            F:Print(#rows .. " CVar(s) match" .. (rest2 ~= "" and (" \"" .. rest2 .. "\"") or "") .. ":")
            for index = 1, math.min(#rows, 12) do
                local info = F:CvarInfo(rows[index].name)
                F:Print("  " .. rows[index].name .. " = " .. tostring(info and info.current))
            end
        elseif action == "history" then
            local history = F.db.cvarHistory or {}
            if #history == 0 then F:Print("No CVar changes recorded yet.")
            else for _, line in ipairs(history) do F:Print("  " .. line) end end
        else
            local value = rest2
            local info = F:CvarInfo(action)
            if not info then F:Print("Unknown CVar. Use /fs cvar list <text> to search."); return end
            if value == "" then
                F:Print(info.entry.name .. " = " .. tostring(info.current) .. " (default " .. info.entry.default .. ")")
                F:Print("  " .. info.entry.help)
                if info.entry.kind == "number" then
                    F:Print("  Range " .. info.entry.min .. " to " .. info.entry.max .. ".")
                else
                    F:Print("  Accepts on or off.")
                end
            else
                local ok, result = F:SetCvarValue(action, value)
                F:Print(ok and (action .. " set to " .. tostring(result) .. ".") or ("Not changed: " .. tostring(result)))
            end
        end
    elseif command == "sell" then
        if F.readOnly then F:Print("Settings are read only."); return end
        local rows = F.SaleCandidates and F:SaleCandidates() or {}
        if #rows == 0 then F:Print("No bag item matches the current merchant rules.")
        else
            F:Print(#rows .. " item(s) match: " .. table.concat((function()
                local names = {}
                for _, row in ipairs(rows) do names[#names + 1] = row.name or row.link end
                return names
            end)(), ", "))
        end
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
