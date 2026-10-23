-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Cooldown panel, cooldown pulse, swing timer and nameplate cast indicator.
-- Timers use the client's own cooldown and cast data; a value the client marks secret
-- is shown as "hidden" instead of being compared.
local _, F = ...

local panel, panelText
local pulses = {}
local lastReady = {}

local function trackedCooldowns()
    local list = F.db and F.db.cooldownSpells
    return type(list) == "table" and list or {}
end

local function cooldownSecret(spellID)
    if not (C_Secrets and C_Secrets.ShouldSpellCooldownBeSecret) then return false end
    local ok, secret = pcall(C_Secrets.ShouldSpellCooldownBeSecret, spellID)
    return ok and secret == true
end

-- Returns remaining seconds and whether the spell is ready. A secret cooldown gives
-- secret = true and no numbers, so callers never do arithmetic on it.
function F:CooldownState(spellID)
    if cooldownSecret(spellID) then return { secret = true, ready = false } end
    if not (C_Spell and C_Spell.GetSpellCooldown) then return { unknown = true, ready = false } end
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
    if not ok or type(info) ~= "table" then return { unknown = true, ready = false } end
    local startTime, duration = tonumber(info.startTime), tonumber(info.duration)
    if not startTime or not duration then return { unknown = true, ready = false } end
    local now = GetTime and GetTime() or 0
    if duration <= 0 or startTime <= 0 then return { remaining = 0, ready = true } end
    local remaining = math.max(0, (startTime + duration) - now)
    return { remaining = remaining, ready = remaining <= 0, duration = duration }
end

function F:CooldownRows()
    local rows = {}
    for _, entry in ipairs(trackedCooldowns()) do
        local state = F:CooldownState(entry.id)
        rows[#rows + 1] = { id = entry.id, label = entry.label, state = state }
    end
    return rows
end

function F:CooldownLine(row)
    local state = row.state or {}
    local label = row.label or ("Spell " .. row.id)
    if state.secret then return label .. ": hidden in combat" end
    if state.unknown then return label .. ": unavailable" end
    if state.ready then return label .. ": ready" end
    return label .. ": " .. string.format("%.1f s", state.remaining or 0)
end

function F:TrackCooldown(spellID, label)
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 or spellID > 1000000 then return false, "spell ID must be between 1 and 1000000" end
    for _, entry in ipairs(trackedCooldowns()) do
        if entry.id == spellID then return false, "that spell is already tracked" end
    end
    if #trackedCooldowns() >= 20 then return false, "at most 20 spells can be tracked" end
    if type(F.db) ~= "table" then return false, "settings are read only" end
    if type(F.db.cooldownSpells) ~= "table" then F.db.cooldownSpells = {} end
    if type(label) == "string" and #label > 40 then label = label:sub(1, 40) end
    F.db.cooldownSpells[#F.db.cooldownSpells + 1] = { id = spellID, label = (label ~= "" and label or nil) }
    F:UpdateCooldownPanel()
    return true
end

function F:UntrackCooldown(spellID)
    spellID = tonumber(spellID)
    if not spellID then return false, "a spell ID is required" end
    for index, entry in ipairs(trackedCooldowns()) do
        if entry.id == spellID then
            table.remove(F.db.cooldownSpells, index)
            if next(F.db.cooldownSpells) == nil then F.db.cooldownSpells = nil end
            F:UpdateCooldownPanel()
            return true
        end
    end
    return false, "that spell is not tracked"
end

local function ensurePanel()
    if panel then return panel end
    panel = CreateFrame("Frame", "TweakSuiteCooldownPanel", UIParent)
    panel:SetSize(180, 20)
    panel:SetPoint("CENTER", UIParent, "CENTER", 260, 120)
    panel:SetFrameStrata("LOW")
    panelText = panel:CreateFontString(nil, "OVERLAY")
    if GameFontNormalSmall then panelText:SetFontObject(GameFontNormalSmall) end
    panelText:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panelText:SetJustifyH("LEFT")
    panel:Hide()
    return panel
end

function F:UpdateCooldownPanel()
    if not F:Active("cooldownPanel") then return end
    ensurePanel()
    local rows = F:CooldownRows()
    if #rows == 0 then panel:Hide(); return end
    local lines = {}
    for _, row in ipairs(rows) do lines[#lines + 1] = F:CooldownLine(row) end
    if panelText and panelText.SetText then panelText:SetText(table.concat(lines, "\n")) end
    panel:SetSize(180, math.max(16, 14 * #rows))
    panel:Show()
end

function F:CooldownAlerts()
    if not F:Active("cooldownPulse") then return end
    for _, row in ipairs(F:CooldownRows()) do
        local ready = row.state and row.state.ready == true
        if ready and lastReady[row.id] == false then
            if F:GetOption("cooldownPulse", "sound") and PlaySound then pcall(PlaySound, 3157, "Master") end
            if F:GetOption("cooldownPulse", "flash") and panel then
                if panel.SetAlpha then panel:SetAlpha(1) end
                if UIFrameFlash then pcall(UIFrameFlash, panel, 0.4, 0.4, 1.2, 0.2, 0.1) end
                pulses[#pulses + 1] = row.id
            end
            F:Print((row.label or ("Spell " .. row.id)) .. " is ready.")
        end
        lastReady[row.id] = ready
    end
end

F:Register("cooldownPanel", {
    title = "Cooldown panel",
    category = "Interface",
    description = "Shows a small text panel with the remaining cooldown of each spell you add with /ts cds add <spellID> [label]. The list is read from the client's cooldown API and a secret cooldown is shown as hidden rather than guessed.",
    disableText = "Hides the panel and stops the spell list commands. The stored list is kept.",
    conflicts = { "WeakAuras", "TellMeWhen", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "interval", type = "number", title = "Refresh every", default = 1, min = 1, max = 3, step = 1, unit = " s",
          description = "How often the panel recalculates while the client reports a cooldown change. Shorter intervals look smoother and cost a little more performance." },
    },
    available = function() return C_Spell ~= nil and C_Spell.GetSpellCooldown ~= nil end,
    enable = function()
        ensurePanel()
        F:UpdateCooldownPanel()
        F:Listen("cooldownPanel", "SPELL_UPDATE_COOLDOWN", function() F:UpdateCooldownPanel() end)
        F:Listen("cooldownPanel", "PLAYER_ENTERING_WORLD", function() F:UpdateCooldownPanel() end)
    end,
    refresh = function() F:UpdateCooldownPanel() end,
    disable = function()
        if panel then panel:Hide() end
    end,
})

F:Register("cooldownPulse", {
    title = "Cooldown ready alert",
    category = "Interface",
    description = "Prints one line and can play a sound or flash the cooldown panel when a tracked spell becomes ready. It compares only ready states, so a secret cooldown never breaks it.",
    disableText = "Stops the ready lines, sounds and flashes.",
    conflicts = { "WeakAuras", "TellMeWhen" },
    options = {
        { key = "sound", type = "boolean", title = "Play a sound", default = true,
          description = "Plays a quiet chime when a tracked spell becomes ready." },
        { key = "flash", type = "boolean", title = "Flash the panel", default = true,
          description = "Flashes the cooldown panel briefly. Needs the cooldown panel feature to be enabled." },
    },
    available = function() return C_Spell ~= nil and C_Spell.GetSpellCooldown ~= nil end,
    enable = function()
        lastReady = {}
        F:Listen("cooldownPulse", "SPELL_UPDATE_COOLDOWN", function() F:CooldownAlerts() end)
        F:Listen("cooldownPulse", "PLAYER_ENTERING_WORLD", function() F:CooldownAlerts() end)
        F:CooldownAlerts()
    end,
    disable = function() lastReady = {}; pulses = {} end,
})

-- ---------------------------------------------------------------------------
-- Swing timer: the client fires PLAYER_SWING with the swing duration for every auto
-- attack, so no combat log parsing is needed.

local swingFrame, swingText, swingStart, swingDuration, swingKind

local SWING_LABEL = { [0] = "Main hand", [1] = "Off hand", [2] = "Ranged" }

local function ensureSwing()
    if swingFrame then return swingFrame end
    swingFrame = CreateFrame("Frame", "TweakSuiteSwingBar", UIParent)
    swingFrame:SetSize(150, 16)
    swingFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
    swingFrame:SetFrameStrata("LOW")
    swingText = swingFrame:CreateFontString(nil, "OVERLAY")
    if GameFontNormalSmall then swingText:SetFontObject(GameFontNormalSmall) end
    swingText:SetPoint("CENTER", swingFrame, "CENTER", 0, 0)
    swingFrame:Hide()
    return swingFrame
end

function F:StartSwing(duration, kind)
    duration = tonumber(duration)
    if not duration or duration <= 0 or duration > 30 then return false end
    ensureSwing()
    swingStart = GetTime and GetTime() or 0
    swingDuration = duration
    swingKind = tonumber(kind) or 0
    swingFrame:Show()
    if swingText and swingText.SetText then
        swingText:SetText((SWING_LABEL[swingKind] or "Swing") .. ": " .. string.format("%.1f s", duration))
    end
    return true
end

function F:UpdateSwing()
    if not swingFrame or not swingStart then return false end
    local now = GetTime and GetTime() or 0
    local remaining = swingDuration - (now - swingStart)
    if remaining <= 0 then
        swingFrame:Hide()
        swingStart = nil
        return false
    end
    if swingText and swingText.SetText then
        swingText:SetText((SWING_LABEL[swingKind] or "Swing") .. ": " .. string.format("%.1f s", remaining))
    end
    return true
end

F:Register("swingBar", {
    title = "Swing timer",
    category = "Interface",
    description = "Shows a small countdown for each auto attack using the client's PLAYER_SWING event, which works without the combat log. Main hand, off hand and ranged swings are labelled separately.",
    disableText = "Hides the swing countdown.",
    conflicts = { "ForeverSwingTimer", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function() return true end,
    enable = function()
        ensureSwing()
        F:Listen("swingBar", "PLAYER_SWING", function(_, duration, kind) F:StartSwing(duration, kind) end)
        F:Listen("swingBar", "PLAYER_ENTERING_WORLD", function()
            if swingFrame then swingFrame:Hide() end
            swingStart = nil
        end)
    end,
    refresh = function() F:UpdateSwing() end,
    disable = function()
        swingStart = nil
        if swingFrame then swingFrame:Hide() end
    end,
})

-- ---------------------------------------------------------------------------
-- Nameplate cast indicator

local plateCasts = {}

local function plateFor(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok then return plate end
end

function F:ShowPlateCast(unit, spellName)
    local plate = plateFor(unit)
    if not plate then return false end
    local text = plateCasts[plate]
    if not text then
        text = plate:CreateFontString(nil, "OVERLAY")
        if GameFontNormalSmall then text:SetFontObject(GameFontNormalSmall) end
        text:SetPoint("BOTTOM", plate, "TOP", 0, 6)
        text:SetTextColor(1, 0.82, 0.22)
        plateCasts[plate] = text
    end
    text:SetText("Casting: " .. (spellName or "spell"))
    return true
end

function F:ClearPlateCast(unit)
    local plate = plateFor(unit)
    if not plate then return false end
    local text = plateCasts[plate]
    if text then text:SetText("") end
    return true
end

F:Register("plateCast", {
    title = "Nameplate cast indicator",
    category = "Nameplates",
    description = "Writes the spell name above an enemy nameplate while that unit is casting, using the client's cast events and C_NamePlate. It uses no threat or health data and clears the text when the cast ends.",
    disableText = "Clears every nameplate cast label.",
    conflicts = { "Plater", "ThreatPlates", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function() return C_NamePlate ~= nil and C_NamePlate.GetNamePlateForUnit ~= nil end,
    enable = function()
        F:Listen("plateCast", "UNIT_SPELLCAST_START", function(_, unit, _, spellID)
            if type(unit) ~= "string" or not unit:match("^nameplate") then return end
            local name
            if spellID and C_Spell and C_Spell.GetSpellInfo then
                local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
                if ok and type(info) == "table" then name = info.name end
            end
            F:ShowPlateCast(unit, name)
        end)
        for _, event in ipairs({ "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
            F:Listen("plateCast", event, function(_, unit)
                if type(unit) == "string" and unit:match("^nameplate") then F:ClearPlateCast(unit) end
            end)
        end
    end,
    disable = function()
        for plate, text in pairs(plateCasts) do text:SetText(""); plateCasts[plate] = nil end
    end,
})

-- ---------------------------------------------------------------------------
-- Ability reference

function F:AbilityInfo(spellID)
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 then return nil end
    if not (C_Spell and C_Spell.GetSpellInfo) then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    if not ok or type(info) ~= "table" then return nil end
    local result = { id = spellID, name = info.name, castTime = tonumber(info.castTime), link = info.originalIconID and nil or nil }
    if C_Spell.GetSpellDescription then
        local descOk, description = pcall(C_Spell.GetSpellDescription, spellID)
        if descOk and type(description) == "string" and F:Plain(description) then result.description = description end
    end
    if C_Spell.GetSpellLink then
        local linkOk, link = pcall(C_Spell.GetSpellLink, spellID)
        if linkOk and type(link) == "string" then result.link = link end
    end
    if C_Spell.GetSpellPowerCost then
        local costOk, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
        if costOk and type(costs) == "table" and costs[1] and type(costs[1].cost) == "number" then
            result.cost = costs[1].cost
        end
    end
    return result
end

F:Register("abilityRef", {
    title = "Spell reference",
    category = "Tooltips",
    description = "Prints a spell's name, ID, cast time, power cost and description with /ts ability <spellID>, using only C_Spell. It is a reference tool and never casts the spell.",
    disableText = "Stops the reference command.",
    conflicts = {},
    available = function() return C_Spell ~= nil and C_Spell.GetSpellInfo ~= nil end,
    enable = function() end,
})

-- ---------------------------------------------------------------------------
-- Target ability reference: remembers the spell a target or nameplate started
-- casting, so /ts tcast can print its reference entry without parsing text.

local lastTargetCast = {}

function F:TargetAbility()
    local now = GetTime and GetTime() or 0
    if UnitCastingInfo then
        local ok, name, _, _, startTime, endTime = pcall(UnitCastingInfo, "target")
        if ok and type(name) == "string" and name ~= "" then
            local remaining = ((tonumber(endTime) or 0) / 1000) - now
            return { name = name, spellID = lastTargetCast.spellID, remaining = remaining > 0 and remaining or 0 }
        end
    end
    if lastTargetCast.spellID or lastTargetCast.name then
        return { name = lastTargetCast.name or "Unknown spell", spellID = lastTargetCast.spellID, remaining = 0, stale = true }
    end
    return nil
end

F:Register("targetAbilityRef", {
    title = "Target ability reference",
    category = "Tooltips",
    description = "Remembers the spell your target starts casting and prints its name, spell ID, cast time and description with /ts tcast. It reads the client's cast events and C_Spell and never interrupts or casts anything.",
    disableText = "Forgets the remembered target cast and stops the command.",
    conflicts = {},
    available = function() return C_Spell ~= nil and C_Spell.GetSpellInfo ~= nil end,
    enable = function()
        lastTargetCast = {}
        F:Listen("targetAbilityRef", "UNIT_SPELLCAST_START", function(_, unit, _, spellID)
            if unit ~= "target" and not (type(unit) == "string" and unit:match("^nameplate")) then return end
            local name
            if C_Spell and C_Spell.GetSpellInfo and spellID then
                local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
                if ok and type(info) == "table" then name = info.name end
            end
            lastTargetCast = { spellID = spellID, name = name }
        end)
        F:Listen("targetAbilityRef", "PLAYER_TARGET_CHANGED", function() lastTargetCast = {} end)
    end,
    disable = function() lastTargetCast = {} end,
})
