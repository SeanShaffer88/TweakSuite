-- SPDX-License-Identifier: MIT
-- Default unit frames: layout and readouts that stay out of the tainted path. Every
-- feature here only scales, moves or reads; none of them replace Blizzard's unit frames.
local _, F = ...

local common = { "ElvUI", "Tukui", "ShadowedUnitFrames", "PitBull", "Grid2", "CompactRaidFrames" }

local function frameOf(name)
    local frame = _G[name]
    if frame and frame.SetScale then return frame end
end

local function setScale(name, percent)
    local frame = frameOf(name)
    if not frame then return false end
    local scale = math.max(0.5, math.min(2, (tonumber(percent) or 100) / 100))
    frame:SetScale(scale)
    return true
end

local function hidePortrait(name, hide)
    local frame = frameOf(name)
    if not frame then return false end
    local portrait = frame.portrait or frame.Portrait or _G[name .. "Portrait"]
    if not portrait or not portrait.SetAlpha then return false end
    portrait:SetAlpha(hide and 0 or 1)
    return true
end

local function applyPlayerTarget()
    local scale = F:GetOption("playerTargetFrames", "scale")
    local hide = F:GetOption("playerTargetFrames", "hidePortraits") == true
    setScale("PlayerFrame", scale)
    setScale("TargetFrame", scale)
    hidePortrait("PlayerFrame", hide)
    hidePortrait("TargetFrame", hide)
end

F:Register("playerTargetFrames", {
    title = "Player and target frame layout",
    category = "Interface",
    description = "Scales the default player and target frames and can hide their 3D portraits. Only SetScale and portrait alpha are touched, so health, power and combat behaviour stay with the client.",
    disableText = "Puts both frames back to scale 1 and restores portrait alpha.",
    conflicts = common,
    options = {
        { key = "scale", type = "number", title = "Frame scale (%)", default = 100, min = 50, max = 200, step = 5,
          description = "Scales the player and target frames together. The target of target frame follows the client's own layout." },
        { key = "hidePortraits", type = "boolean", title = "Hide 3D portraits", default = false,
          description = "Fades the portrait region of both frames to full transparency. The portrait still exists, so nothing else about the frame changes." },
    },
    available = function() return PlayerFrame ~= nil and PlayerFrame.SetScale ~= nil end,
    enable = applyPlayerTarget,
    refresh = applyPlayerTarget,
    disable = function()
        setScale("PlayerFrame", 100)
        setScale("TargetFrame", 100)
        hidePortrait("PlayerFrame", false)
        hidePortrait("TargetFrame", false)
    end,
})

-- ---------------------------------------------------------------------------
-- Party and raid frames

local function applyPartyFrames()
    if not F:Active("partyFrames") then return false end
    local scale = F:GetOption("partyFrames", "scale")
    setScale("CompactPartyFrame", scale)
    setScale("CompactRaidFrameContainer", scale)
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, "useCompactPartyFrames", F:GetOption("partyFrames", "compact") == true and "1" or "0")
    end
    return true
end

F:Register("partyFrames", {
    title = "Party and raid frame scale",
    category = "Interface",
    description = "Scales the client's compact party and raid frames and can ask the client to use the compact party layout. The frames themselves, their click behaviour and their secure attributes are untouched.",
    disableText = "Returns party and raid frames to 100% and leaves the compact layout as the client has it.",
    conflicts = common,
    options = {
        { key = "scale", type = "number", title = "Frame scale (%)", default = 100, min = 50, max = 200, step = 5,
          description = "Applies to CompactPartyFrame and CompactRaidFrameContainer when the client creates them." },
        { key = "compact", type = "boolean", title = "Use the compact party layout", default = false,
          description = "Sets the client CVar useCompactPartyFrames. This is the same setting as the interface option, so changing it here changes it there." },
    },
    available = function() return CompactPartyFrame ~= nil or CompactRaidFrameContainer ~= nil end,
    enable = applyPartyFrames,
    refresh = applyPartyFrames,
    disable = function()
        setScale("CompactPartyFrame", 100)
        setScale("CompactRaidFrameContainer", 100)
    end,
})

-- ---------------------------------------------------------------------------
-- Resource readout

local resourceFrame

function F:ResourceSnapshot(unit)
    unit = unit or "player"
    local secret = C_Secrets and C_Secrets.ShouldUnitPowerBeSecret and C_Secrets.ShouldUnitPowerBeSecret(unit)
    if secret then return { secret = true } end
    local powerType, powerToken = nil, nil
    if UnitPowerType then
        local ok, kind, token = pcall(UnitPowerType, unit)
        if ok then powerType, powerToken = kind, token end
    end
    local current = UnitPower and UnitPower(unit) or nil
    local maximum = UnitPowerMax and UnitPowerMax(unit) or nil
    if type(current) ~= "number" or type(maximum) ~= "number" or maximum <= 0 then
        return { unavailable = true }
    end
    return { current = current, maximum = maximum, kind = powerType, token = powerToken }
end

function F:ResourceText(snapshot)
    snapshot = snapshot or F:ResourceSnapshot()
    if snapshot.secret then return "Power: hidden in combat" end
    if snapshot.unavailable then return "Power: unavailable" end
    local percent = math.floor(snapshot.current / snapshot.maximum * 100 + 0.5)
    local label = snapshot.token or "Power"
    return string.format("%s: %d / %d (%d%%)", label, snapshot.current, snapshot.maximum, percent)
end

local function updateResourceFrame()
    if not resourceFrame then return end
    if not F:Active("resourceBars") then resourceFrame:Hide(); return end
    resourceFrame.text:SetText(F:ResourceText())
    resourceFrame:Show()
end

local function buildResourceFrame()
    if resourceFrame then return resourceFrame end
    local frame = CreateFrame("Frame", "ForeverSuiteResourceBar", UIParent)
    frame:SetSize(200, 22)
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 180)
    if frame.SetBackdrop then frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" }) end
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.text:SetAllPoints()
    frame.text:SetText("Power")
    resourceFrame = frame
    return frame
end

F:Register("resourceBars", {
    title = "Resource readout",
    category = "Interface",
    description = "Shows a small text readout of your current power type, value and percentage. The values come from UnitPower and are hidden while the client marks them secret in combat.",
    disableText = "Hides the readout. No unit frame is modified.",
    conflicts = common,
    options = {
        { key = "inCombat", type = "boolean", title = "Hide in combat", default = true,
          description = "Hides the readout during combat instead of showing the secret placeholder. Turn off to keep the placeholder line visible." },
    },
    available = function() return UnitPower ~= nil and UnitPowerMax ~= nil end,
    enable = function()
        buildResourceFrame():Show()
        F:Listen("resourceBars", "UNIT_POWER_UPDATE", updateResourceFrame)
        F:Listen("resourceBars", "PLAYER_ENTERING_WORLD", updateResourceFrame)
        updateResourceFrame()
    end,
    refresh = updateResourceFrame,
    disable = function() if resourceFrame then resourceFrame:Hide() end end,
})

-- ---------------------------------------------------------------------------
-- Absorb readout

local absorbFrame

function F:AbsorbSnapshot(unit)
    unit = unit or "player"
    if not UnitGetTotalAbsorbs then return { unavailable = true } end
    local ok, amount = pcall(UnitGetTotalAbsorbs, unit)
    if not ok then return { secret = true } end
    local heals
    if UnitGetTotalHealAbsorbs then
        local healOK, healAmount = pcall(UnitGetTotalHealAbsorbs, unit)
        if healOK then heals = healAmount end
    end
    if type(amount) ~= "number" then return { unavailable = true } end
    return { absorb = amount, healAbsorb = heals }
end

function F:AbsorbText(snapshot)
    snapshot = snapshot or F:AbsorbSnapshot()
    if snapshot.secret then return "Absorb: hidden in combat" end
    if snapshot.unavailable then return "Absorb: unavailable" end
    local text = string.format("Absorb: %d", snapshot.absorb)
    if type(snapshot.healAbsorb) == "number" and snapshot.healAbsorb > 0 then
        text = text .. string.format("  Heal absorb: %d", snapshot.healAbsorb)
    end
    return text
end

local function updateAbsorbFrame()
    if not absorbFrame then return end
    if not F:Active("absorbDisplay") then absorbFrame:Hide(); return end
    absorbFrame.text:SetText(F:AbsorbText())
    absorbFrame:Show()
end

F:Register("absorbDisplay", {
    title = "Absorb readout",
    category = "Interface",
    description = "Shows the total damage absorb and healing absorb on your character as a short text line, using UnitGetTotalAbsorbs and UnitGetTotalHealAbsorbs. The client can mark these values secret in combat; the line then says so instead of guessing.",
    disableText = "Hides the absorb line.",
    conflicts = common,
    available = function() return UnitGetTotalAbsorbs ~= nil end,
    enable = function()
        if not absorbFrame then
            absorbFrame = CreateFrame("Frame", "ForeverSuiteAbsorbBar", UIParent)
            absorbFrame:SetSize(220, 20)
            absorbFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 156)
            absorbFrame.text = absorbFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            absorbFrame.text:SetAllPoints()
        end
        absorbFrame:Show()
        F:Listen("absorbDisplay", "UNIT_ABSORB_AMOUNT_CHANGED", updateAbsorbFrame)
        F:Listen("absorbDisplay", "PLAYER_ENTERING_WORLD", updateAbsorbFrame)
        updateAbsorbFrame()
    end,
    refresh = updateAbsorbFrame,
    disable = function() if absorbFrame then absorbFrame:Hide() end end,
})

-- ---------------------------------------------------------------------------
-- Native damage meter

function F:DamageSessions()
    local rows = {}
    if not (C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions) then return rows end
    local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not ok or type(sessions) ~= "table" then return rows end
    for _, session in ipairs(sessions) do
        local id = type(session) == "table" and (session.sessionID or session.id) or session
        if type(id) == "number" then
            local duration
            if C_DamageMeter.GetSessionDurationSeconds then
                local durationOK, seconds = pcall(C_DamageMeter.GetSessionDurationSeconds, id)
                if durationOK then duration = seconds end
            end
            rows[#rows + 1] = { id = id, duration = duration }
        end
    end
    return rows
end

F:Register("damageMeter", {
    title = "Native damage meter data",
    category = "Interface",
    description = "Reads the client's own combat sessions through C_DamageMeter and lists them with /fs meter, including their duration. /fs meter reset clears the sessions once the option below allows it. ForeverSuite draws no meter of its own, so the numbers stay the client's.",
    disableText = "Stops the /fs meter commands. Existing sessions are untouched.",
    conflicts = { "Details", "Recount", "Skada", "ElvUI" },
    options = {
        { key = "allowReset", type = "boolean", title = "Allow resetting sessions", default = false,
          description = "Adds /fs meter reset, which calls C_DamageMeter.ResetAllCombatSessions. Off by default because it deletes data another addon may be showing." },
    },
    available = function()
        return C_DamageMeter ~= nil and C_DamageMeter.GetAvailableCombatSessions ~= nil
    end,
    enable = function() end,
})

function F:MeterLines()
    local rows = F:DamageSessions()
    local lines = {}
    if #rows == 0 then return { "No combat sessions recorded." } end
    for _, row in ipairs(rows) do
        lines[#lines + 1] = string.format("Session %d: %s", row.id,
            type(row.duration) == "number" and string.format("%.0f s", row.duration) or "duration unavailable")
    end
    return lines
end
