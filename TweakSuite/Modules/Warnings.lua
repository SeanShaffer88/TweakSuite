-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Audio warnings for hazards, failures and environmental timers.
-- Every list is user maintained: nothing is hardcoded from another addon, and a spell
-- that the client marks as a secret aura is skipped instead of being read.
local _, F = ...

local CATEGORY_KITS = {
    alarm = { file = "Sound\\Doodad\\BellTollAlliance.wav", kit = 895 },
    bell = { file = "Sound\\DingSmall.wav", kit = 3157 },
    soft = { file = "Sound\\Interface\\iTellMessage.wav", kit = 3081 },
}

local FAILURE_KEYWORDS = { "no mana", "out of range", "not enough", "immune", "cannot", "can't", "too far", "facing" }

local alerted, registered, timerAlerted = {}, {}, {}

local function hazardList()
    local list = F.db and F.db.hazards
    return type(list) == "table" and list or {}
end

local function exemptList()
    local list = F.db and F.db.hazardExempt
    return type(list) == "table" and list or {}
end

local function isExempt(spellID)
    for _, value in ipairs(exemptList()) do
        if value == spellID then return true end
    end
    return false
end

local function findHazard(spellID)
    for index, entry in ipairs(hazardList()) do
        if entry.id == spellID then return entry, index end
    end
end

function F:HazardNames()
    local rows = {}
    for _, entry in ipairs(hazardList()) do
        rows[#rows + 1] = { id = entry.id, name = entry.name or ("Spell " .. entry.id), kind = entry.kind or "debuff" }
    end
    return rows
end

function F:AddHazard(spellID, name, kind)
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 or spellID > 1000000 then return false, "spell ID must be between 1 and 1000000" end
    if findHazard(spellID) then return false, "that spell is already in the list" end
    local list = hazardList()
    if #list >= 80 then return false, "the list holds at most 80 spells" end
    if type(name) == "string" and #name > 80 then name = name:sub(1, 80) end
    if kind ~= "debuff" and kind ~= "cast" then kind = "debuff" end
    if type(F.db) ~= "table" then return false, "settings are read only" end
    if type(F.db.hazards) ~= "table" then F.db.hazards = {} end
    F.db.hazards[#F.db.hazards + 1] = { id = spellID, name = name, kind = kind }
    F:RegisterAuraSound(spellID)
    return true
end

function F:RemoveHazard(spellID)
    spellID = tonumber(spellID)
    if not spellID then return false, "a spell ID is required" end
    local entry, index = findHazard(spellID)
    if not entry then return false, "that spell is not in the list" end
    table.remove(F.db.hazards, index)
    if next(F.db.hazards) == nil then F.db.hazards = nil end
    F:UnregisterAuraSound(spellID)
    return true
end

-- The client's own aura sound API is the supported way to be told about an aura.
-- When it is missing we fall back to reading the player's auras ourselves.
function F:RegisterAuraSound(spellID)
    if not F:Active("auraSoundApi") then return false end
    if not (C_UnitAuras and C_UnitAuras.AddAuraSound) then return false end
    if registered[spellID] then return true end
    local kit = (CATEGORY_KITS[F:GetOption("alertSounds", "auraSound") or "alarm"] or CATEGORY_KITS.alarm).kit
    local ok = pcall(C_UnitAuras.AddAuraSound, spellID, kit)
    if ok then registered[spellID] = true end
    return ok
end

function F:UnregisterAuraSound(spellID)
    if not registered[spellID] then return false end
    registered[spellID] = nil
    if C_UnitAuras and C_UnitAuras.RemoveAuraSound then pcall(C_UnitAuras.RemoveAuraSound, spellID) end
    return true
end

function F:PlayAlert(category, force)
    if not F:Active("alertSounds") then return false end
    if not force and F:GetOption("alertSounds", "enabled") == false then return false end
    local kit = CATEGORY_KITS[F:GetOption("alertSounds", category) or "alarm"] or CATEGORY_KITS.alarm
    if PlaySoundFile and kit.file then
        local ok = pcall(PlaySoundFile, kit.file, "Master")
        if ok then return true end
    end
    if PlaySound and kit.kit then
        local ok = pcall(PlaySound, kit.kit, "Master")
        return ok == true
    end
    return false
end

local function auraIsSecret(spellID)
    if not (C_Secrets and C_Secrets.ShouldSpellAuraBeSecret) then return false end
    local ok, secret = pcall(C_Secrets.ShouldSpellAuraBeSecret, spellID)
    return ok and secret == true
end

local function hasAura(spellID)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, data = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if ok then return data ~= nil end
    end
    return nil
end

-- Check the tracked hazards against the player's current auras. Returns the list of
-- spells that are newly present, so both the warning sound and the chat line use the
-- same decision.
function F:CheckHazards()
    local found = {}
    if not F:Active("hazardAlerts") then return found end
    if F:GetOption("hazardAlerts", "onlyInstances") and IsInInstance then
        local inInstance = IsInInstance()
        if inInstance ~= true then return found end
    end
    for _, entry in ipairs(hazardList()) do
        local spellID = entry.id
        if not isExempt(spellID) and not auraIsSecret(spellID) then
            local present = hasAura(spellID)
            if present == true and not alerted[spellID] then
                alerted[spellID] = true
                found[#found + 1] = entry
                F:PlayAlert("auraSound")
                F:Print("Warning: " .. (entry.name or ("spell " .. spellID)) .. " is affecting you.")
            elseif present == false then
                alerted[spellID] = nil
            end
        end
    end
    return found
end

local function watchAuras()
    if not F:Active("hazardAlerts") then return end
    F:CheckHazards()
end

local function onFailure(_, messageType, message)
    if not F:Active("failureWarnings") then return end
    if type(message) ~= "string" or not F:Plain(message) then return end
    local lower = message:lower()
    local matched
    for _, keyword in ipairs(FAILURE_KEYWORDS) do
        if lower:find(keyword, 1, true) then matched = keyword; break end
    end
    if not matched then return end
    F:PlayAlert("failureSound")
    if F:GetOption("failureWarnings", "print") ~= false then
        F:Print("Action failed: " .. message)
    end
end

local function onMirrorTimer(_, timerType, value, maxValue)
    if not F:Active("environmentWarnings") then return end
    if type(timerType) ~= "string" or type(value) ~= "number" or type(maxValue) ~= "number" then return end
    local threshold = F:GetOption("environmentWarnings", "threshold") or 25
    if maxValue <= 0 then return end
    local percent = value / maxValue * 100
    if percent > threshold then timerAlerted[timerType] = nil; return end
    if timerAlerted[timerType] then return end
    timerAlerted[timerType] = true
    F:PlayAlert("environmentSound")
    local label = timerType == "FATIGUE" and "Fatigue" or (timerType == "BREATH" and "Breath" or timerType)
    F:Print("Environment warning: " .. label .. " at " .. string.format("%.0f", percent) .. "%.")
end

F:Register("hazardAlerts", {
    title = "Hazard warnings",
    category = "Interface",
    description = "Plays a sound and prints one chat line when a spell you added to the hazard list starts affecting you. The list starts empty, so nothing is warned about until you add a spell. Spells whose auras the client hides are skipped.",
    disableText = "Stops checking auras and forgets which warnings were already shown.",
    conflicts = { "GTFO", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "onlyInstances", type = "boolean", title = "Only inside instances", default = false,
          description = "Warns only while you are inside a dungeon or raid, which keeps open-world play quiet." },
    },
    available = function() return C_UnitAuras ~= nil and C_UnitAuras.GetPlayerAuraBySpellID ~= nil end,
    enable = function()
        alerted = {}
        F:Listen("hazardAlerts", "UNIT_AURA", function(_, unit)
            if unit == "player" then watchAuras() end
        end)
        F:Listen("hazardAlerts", "PLAYER_ENTERING_WORLD", watchAuras)
        watchAuras()
    end,
    refresh = watchAuras,
    disable = function() alerted = {} end,
})

F:Register("failureWarnings", {
    title = "Action failure warnings",
    category = "Interface",
    description = "Plays a short sound when the client reports a failed action such as out of range, no mana or an immune target. It reads only the client's own error text and never retries the action.",
    disableText = "Stops the sound and the chat line for failed actions.",
    conflicts = { "GTFO", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "print", type = "boolean", title = "Also print the reason", default = true,
          description = "Repeats the client's error text as a chat line so you can read why the action failed." },
    },
    available = function() return true end,
    enable = function() F:Listen("failureWarnings", "UI_ERROR_MESSAGE", onFailure) end,
})

F:Register("environmentWarnings", {
    title = "Environmental warnings",
    category = "Interface",
    description = "Warns when the client's fatigue or breath bar falls below a percentage of its maximum. It uses the client's mirror timer events, so no health or power value is read.",
    disableText = "Stops watching fatigue and breath timers.",
    conflicts = { "GTFO", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "threshold", type = "number", title = "Warn below", default = 25, min = 5, max = 90, step = 5, unit = "%",
          description = "Percentage of the bar at which the warning fires once. It fires again only after the bar recovers above the threshold." },
    },
    available = function() return true end,
    enable = function()
        timerAlerted = {}
        F:Listen("environmentWarnings", "MIRROR_TIMER_START", onMirrorTimer)
        F:Listen("environmentWarnings", "MIRROR_TIMER_PAUSE", function(_, timerType, paused)
            if paused == false then timerAlerted[timerType] = nil end
        end)
    end,
    disable = function() timerAlerted = {} end,
})

F:Register("alertSounds", {
    title = "Alert sound choice",
    category = "Interface",
    description = "Chooses which of the three built-in sounds each warning category uses, and can silence them all. The client does not expose per-sound volume to addons, so each category offers different sounds instead of a volume slider.",
    disableText = "Warnings stay enabled but play no sound.",
    conflicts = { "GTFO" },
    options = {
        { key = "enabled", type = "boolean", title = "Play warning sounds", default = true,
          description = "Master switch for every warning sound TweakSuite plays. Chat lines are unaffected." },
        { key = "auraSound", type = "choice", title = "Hazard sound", default = "alarm",
          choices = { { value = "alarm", label = "Alarm bell" }, { value = "bell", label = "Small bell" }, { value = "soft", label = "Soft chime" } },
          description = "Sound for aura and hazard warnings." },
        { key = "failureSound", type = "choice", title = "Failure sound", default = "bell",
          choices = { { value = "alarm", label = "Alarm bell" }, { value = "bell", label = "Small bell" }, { value = "soft", label = "Soft chime" } },
          description = "Sound for failed actions." },
        { key = "environmentSound", type = "choice", title = "Environment sound", default = "soft",
          choices = { { value = "alarm", label = "Alarm bell" }, { value = "bell", label = "Small bell" }, { value = "soft", label = "Soft chime" } },
          description = "Sound for fatigue and breath warnings." },
    },
    available = function() return PlaySoundFile ~= nil or PlaySound ~= nil end,
    enable = function() end,
    disable = function() end,
})

F:Register("auraSoundApi", {
    title = "Client aura sounds",
    category = "Interface",
    description = "Asks the client itself to play a sound for each tracked hazard aura through C_UnitAuras.AddAuraSound, and removes that request when the feature or the hazard is turned off. When the client does not offer the API, TweakSuite falls back to its own aura watcher.",
    disableText = "Removes every registered aura sound and falls back to TweakSuite's own watcher.",
    conflicts = { "GTFO" },
    available = function() return C_UnitAuras ~= nil and C_UnitAuras.AddAuraSound ~= nil end,
    enable = function()
        for _, entry in ipairs(hazardList()) do F:RegisterAuraSound(entry.id) end
    end,
    refresh = function()
        for spellID in pairs(registered) do
            if not findHazard(spellID) then F:UnregisterAuraSound(spellID) end
        end
        for _, entry in ipairs(hazardList()) do F:RegisterAuraSound(entry.id) end
    end,
    disable = function()
        for spellID in pairs(registered) do F:UnregisterAuraSound(spellID) end
        registered = {}
    end,
})

F:Register("alertExemptions", {
    title = "Alert exemptions",
    category = "Interface",
    description = "Lists spell IDs that never raise a warning even when they are on the hazard list, for example a debuff you are meant to carry. /ts hazard exempt <id> adds one and /ts hazard allow <id> removes it again.",
    disableText = "Stops honouring the exemption list; every tracked spell warns again.",
    conflicts = {},
    available = function() return true end,
    enable = function() end,
})

F:Register("hazardData", {
    title = "Hazard list maintenance",
    category = "Interface",
    description = "Maintains the hazard spell list with /ts hazard add <id> [name], remove, list, import and export. Import and export use a plain comma separated list of spell IDs, so a list can be shared as text without shipping data files.",
    disableText = "Stops the hazard commands. The stored list is kept.",
    conflicts = {},
    available = function() return C_Spell ~= nil and C_Spell.DoesSpellExist ~= nil end,
    enable = function() end,
})

-- Import and export are the only maintenance paths, so a list can travel as text.
function F:ImportHazards(text)
    if type(text) ~= "string" then return false, "text required" end
    local added, skipped = 0, 0
    for number in text:gmatch("%d+") do
        local id = tonumber(number)
        if id and id > 0 and id <= 1000000 then
            if F:AddHazard(id) then added = added + 1 else skipped = skipped + 1 end
        else
            skipped = skipped + 1
        end
    end
    return true, added, skipped
end

function F:ExportHazards()
    local ids = {}
    for _, entry in ipairs(hazardList()) do ids[#ids + 1] = tostring(entry.id) end
    return table.concat(ids, ",")
end
