-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Moving settings in from older TweakSuite builds or from a reference addon, plus the
-- small translation layer every user-facing string can go through.
local _, F = ...

-- ---------------------------------------------------------------------------
-- Localization

-- English is the source language and the only complete table. A translation is a plain
-- table of the same keys; a missing key falls back to English instead of showing a raw id.
F.strings = {
    enabled = "Enabled %s.",
    disabled = "Disabled %s.",
    readOnly = "Settings are read only right now.",
    migrated = "Migrated %d setting(s).",
    nothingToMigrate = "Nothing to migrate.",
}

F.translations = F.translations or {}

function F:ClientLocale()
    if type(GetLocale) ~= "function" then return "enUS" end
    local ok, locale = pcall(GetLocale)
    if ok and type(locale) == "string" and locale ~= "" then return locale end
    return "enUS"
end

function F:ActiveLocale()
    local choice = self.features and self.features.localization and self:GetOption("localization", "locale") or "auto"
    if type(choice) ~= "string" or choice == "" or choice == "auto" then return self:ClientLocale() end
    return choice
end

function F:L(key, ...)
    local locale = self:ActiveLocale()
    local translated = self.translations[locale]
    local text = (translated and translated[key]) or self.strings[key] or tostring(key)
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        return ok and formatted or text
    end
    return text
end

function F:AddTranslation(locale, key, text)
    if type(locale) ~= "string" or type(key) ~= "string" or type(text) ~= "string" then
        return false, "a locale, a key and a text are needed"
    end
    if not self.strings[key] then return false, "unknown string key" end
    self.translations[locale] = self.translations[locale] or {}
    self.translations[locale][key] = text
    return true
end

function F:LocaleReport()
    local locale = self:ActiveLocale()
    local total = 0
    for _ in pairs(self.strings) do total = total + 1 end
    local translated = 0
    for _ in pairs(self.translations[locale] or {}) do translated = translated + 1 end
    return { locale = locale, client = self:ClientLocale(), total = total, translated = translated }
end

F:Register("localization", {
    title = "Interface language",
    category = "Interface",
    description = "Resolves every user-facing string through one table so a translation can be added without touching code. English is the only shipped language; a missing translation falls back to English and /ts locale shows the coverage.",
    disableText = "Uses the client locale for every string. Nothing else changes.",
    conflicts = {},
    options = {
        { key = "locale", type = "choice", title = "Language", default = "auto",
          choices = { { value = "auto", label = "Follow the client" }, { value = "enUS", label = "English" },
              { value = "deDE", label = "German" }, { value = "frFR", label = "French" },
              { value = "esES", label = "Spanish" }, { value = "ruRU", label = "Russian" } },
          description = "Chooses which translation table is read. Only English is complete today, so other choices fall back per key." },
    },
    available = function() return true end,
    enable = function() end,
})

F:Command("locale", function()
    if not F:Active("localization") then F:Print("Enable Interface language first."); return end
    local report = F:LocaleReport()
    F:Print("Language: " .. report.locale .. " (client reports " .. report.client .. "), "
        .. report.translated .. " of " .. report.total .. " strings translated.")
    if report.translated < report.total then
        F:Print("Missing strings fall back to English. Add translations with F:AddTranslation(locale, key, text).")
    end
end, "/ts locale shows the resolved interface language and translation coverage")

-- ---------------------------------------------------------------------------
-- Setting migration

-- Flat keys that older builds stored directly on the saved variables table.
local LEGACY_FLAGS = {
    instantQuestText = "questText",
    autoAcceptQuests = "acceptQuests",
    autoTurnIn = "turnInQuests",
    autoRepair = "repair",
    sellJunk = "sellJunk",
    autoLoot = "autoLoot",
    hideBossBanner = "hideBossBanner",
    chatTimestamps = "chatTimestamps",
}

-- Reference addons whose options overlap ours. Only the overlap is listed: no value is
-- copied, because the client never reads another addon's saved variables back.
local REFERENCE_OVERLAP = {
    Leatrix_Plus = { "questText", "autoLoot", "chatTimestamps", "hideGryphons", "minimapButtons", "hideZoneText" },
    Leatrix_Plus_Forever = { "questText", "autoLoot", "chatTimestamps" },
    Details = { "damageMeter" },
    DialogKey = { "dialogAccept", "gossipKeys", "rewardKeys" },
    TinyTooltip = { "itemID", "itemLevel", "bindType" },
    Questie = { "questTooltips", "autoQuestWatch" },
    Pawn = { "upgradeHint", "itemLevel" },
}

function F:LegacyMigrationPlan(db)
    local plan = { flags = {}, skipped = {} }
    db = db or (type(F.db) == "table" and F.db or nil)
    if type(db) ~= "table" then return plan end
    for legacyKey, feature in pairs(LEGACY_FLAGS) do
        if db[legacyKey] == true and not (type(db.enabled) == "table" and db.enabled[feature] == true) then
            plan.flags[#plan.flags + 1] = { legacy = legacyKey, feature = feature }
        end
    end
    table.sort(plan.flags, function(a, b) return a.legacy < b.legacy end)
    return plan
end

function F:ApplyLegacyMigration(plan, db)
    db = db or (type(F.db) == "table" and F.db or nil)
    if type(db) ~= "table" or type(plan) ~= "table" then return 0 end
    if type(db.enabled) ~= "table" then db.enabled = {} end
    local applied = 0
    for _, entry in ipairs(plan.flags or {}) do
        if F.features[entry.feature] then
            db.enabled[entry.feature] = true
            db[entry.legacy] = nil
            applied = applied + 1
        end
    end
    return applied
end

function F:LoadedReferenceAddons()
    local found = {}
    for name in pairs(REFERENCE_OVERLAP) do
        local loaded
        if C_AddOns and C_AddOns.IsAddOnLoaded then
            local ok, value = pcall(C_AddOns.IsAddOnLoaded, name)
            if ok then loaded = value end
        elseif IsAddOnLoaded then
            local ok, value = pcall(IsAddOnLoaded, name)
            if ok then loaded = value end
        end
        if loaded then found[#found + 1] = name end
    end
    table.sort(found)
    return found
end

function F:ReferenceOverlap()
    local rows = {}
    for _, name in ipairs(F:LoadedReferenceAddons()) do
        rows[#rows + 1] = { name = name, features = REFERENCE_OVERLAP[name] }
    end
    return rows
end

F:Register("settingMigration", {
    title = "Bring settings across",
    category = "Interface",
    description = "Moves flat settings from older TweakSuite builds into the current feature list and reports which loaded reference addons cover the same features. It never copies another addon's saved variables: the beta client does not read them back, so the report tells you what to switch on instead.",
    disableText = "Stops the migration commands. Settings already migrated stay as they are.",
    conflicts = {},
    options = {
        { key = "dryRun", type = "boolean", title = "Report only", default = true,
          description = "Prints what would change without writing it. Turn off to let /ts migrate legacy apply the changes." },
    },
    available = function() return C_AddOns ~= nil or IsAddOnLoaded ~= nil end,
    enable = function() end,
})

F:Command("migrate", function(rest)
    if not F:Active("settingMigration") then F:Print("Enable Bring settings across first."); return end
    local action = (rest or ""):lower()
    if action == "" or action == "legacy" then
        local plan = F:LegacyMigrationPlan()
        if #plan.flags == 0 then F:Print(F:L("nothingToMigrate")); return end
        for _, entry in ipairs(plan.flags) do
            F:Print("  " .. entry.legacy .. " -> " .. entry.feature)
        end
        if F:GetOption("settingMigration", "dryRun") == true then
            F:Print("Report only. Turn off Report only to apply these " .. #plan.flags .. " change(s).")
            return
        end
        local applied = F:ApplyLegacyMigration(plan)
        F:Refresh()
        F:Print(F:L("migrated", applied))
    elseif action == "refs" then
        local rows = F:ReferenceOverlap()
        if #rows == 0 then F:Print("No reference addon with overlapping options is loaded."); return end
        for _, row in ipairs(rows) do
            F:Print(row.name .. " overlaps: " .. table.concat(row.features, ", "))
        end
        F:Print("TweakSuite does not read another addon's saved variables; switch on the features you need instead.")
    else
        F:Print("Use /ts migrate [legacy|refs].")
    end
end, "/ts migrate [legacy|refs] moves old flat settings and lists overlapping addons")
