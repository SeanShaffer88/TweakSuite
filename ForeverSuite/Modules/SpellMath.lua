-- SPDX-License-Identifier: MIT
-- Spell calculation tooltips: damage per second, per minute, per mana and DoT share.
-- Every number comes from the client: the spell's own tooltip text (C_TooltipInfo),
-- its cast time (C_Spell.GetSpellInfo) and its power cost (C_Spell.GetSpellPowerCost).
-- Values the client marks secret are skipped instead of being compared, and nothing is
-- calculated in combat when the secrecy check says the spell's data is hidden.
local _, F = ...

local LABELS = {
    enUS = {
        dps = "Damage per second",
        dpm = "Damage per minute",
        perMana = "Damage per mana",
        manaPercent = "Mana cost",
        dotShare = "DoT share",
        direct = "Direct share",
        ticks = "ticks",
        perSecond = "/s",
        perMinute = "/min",
        percent = "%",
    },
}
local LOCALE_FALLBACK = "enUS"

local function localeName()
    local option = F:GetOption("spellLabels", "locale") or "auto"
    if option ~= "auto" then return option end
    local client = GetLocale and GetLocale() or "enUS"
    if LABELS[client] then return client end
    return LOCALE_FALLBACK
end

-- Labels resolve through the chosen locale with an English fallback, so a missing
-- translation never shows a key name to the player.
function F:SpellLabel(key)
    local locale = localeName()
    local table_ = LABELS[locale] or LABELS[LOCALE_FALLBACK]
    if table_ and table_[key] then return table_[key] end
    return LABELS[LOCALE_FALLBACK][key] or key
end

function F:SpellLabelReport()
    local locale = localeName()
    local table_ = LABELS[locale]
    local missing = 0
    if table_ then
        for key in pairs(LABELS[LOCALE_FALLBACK]) do
            if table_[key] == nil then missing = missing + 1 end
        end
    end
    return locale, missing, table_ ~= nil and locale ~= LOCALE_FALLBACK
end

local function decimals()
    local value = F:GetOption("spellDps", "decimals")
    if type(value) ~= "number" then value = 1 end
    return math.max(0, math.min(2, value))
end

function F:FormatSpellNumber(value)
    if type(value) ~= "number" then return nil end
    local places = decimals()
    if places == 0 then return tostring(math.floor(value + 0.5)) end
    local text = string.format("%." .. places .. "f", value)
    -- Keep the client's own thousand separator behaviour out of this: the numbers are
    -- small enough that a plain decimal point is unambiguous in every locale we ship.
    return text
end

-- Pure calculation. `input` may hold:
--   minDamage, maxDamage, castTime (s), cooldown (s), manaCost, manaMax,
--   duration (s), tickInterval (s), ticks (number), isDot (boolean)
function F:SpellMath(input)
    if type(input) ~= "table" then return nil end
    local min = tonumber(input.minDamage)
    local max = tonumber(input.maxDamage)
    if not min and not max then return nil end
    min = min or max
    max = max or min
    if min > max then min, max = max, min end
    local average = (min + max) / 2

    local cast = tonumber(input.castTime) or 0
    if cast < 0 then cast = 0 end
    local cooldown = tonumber(input.cooldown) or 0
    if cooldown < 0 then cooldown = 0 end
    local duration = tonumber(input.duration)
    local tickInterval = tonumber(input.tickInterval)
    local ticks = tonumber(input.ticks)
    if not ticks and duration and tickInterval and tickInterval > 0 then
        ticks = math.floor(duration / tickInterval + 0.5)
    end
    if ticks and ticks < 1 then ticks = 1 end

    local perTick = average
    local direct = average
    local total = average
    if input.isDot then
        -- For a damage over time spell the tooltip's number is per tick, so the total
        -- is the tick value times the number of ticks the client's text implies.
        total = average * (ticks or 1)
        direct = 0
    end

    local cycle = cast + cooldown
    if cycle <= 0 and input.isDot and duration and duration > 0 then cycle = duration end
    if cycle <= 0 then cycle = nil end
    local dps = cycle and total / cycle or nil
    local dpm = dps and dps * 60 or nil
    local perMana = nil
    local manaCost = tonumber(input.manaCost)
    if manaCost and manaCost > 0 then perMana = total / manaCost end
    local manaPercent = nil
    local manaMax = tonumber(input.manaMax)
    if manaCost and manaMax and manaMax > 0 then manaPercent = manaCost / manaMax * 100 end
    local dotShare = nil
    if input.isDot and ticks and ticks > 0 then
        dotShare = (1 - direct / (total > 0 and total or 1)) * 100
    elseif input.isDot then
        dotShare = 100
    end

    return {
        min = min, max = max, average = average, ticks = ticks,
        total = total, perTick = perTick, dotShare = dotShare,
        dps = dps, dpm = dpm, perMana = perMana, manaPercent = manaPercent,
        castTime = cast, cooldown = cooldown, manaCost = manaCost, isDot = input.isDot == true,
    }
end

-- Text parsing for the client's own spell tooltip lines.
function F:ParseSpellText(lines)
    local parsed = {}
    if type(lines) ~= "table" then return parsed end
    for _, raw in ipairs(lines) do
        if type(raw) == "string" and F:Plain(raw) then
            if not parsed.minDamage then
                local min, max = raw:match("(%d+) to (%d+)")
                if min and max then
                    parsed.minDamage, parsed.maxDamage = tonumber(min), tonumber(max)
                    if raw:match("[Hh]ealing") then parsed.healing = true end
                else
                    local single = raw:match("([%d,]+) ([%a%s]-)[Dd]amage")
                    if single and not parsed.minDamage then
                        local number = tonumber((single:gsub(",", "")))
                        if number then parsed.minDamage, parsed.maxDamage = number, number end
                    end
                end
            end
            local duration = raw:match("over (%d+) sec")
            if duration then parsed.duration = tonumber(duration) end
            local tick = raw:match("every (%d+) sec")
            if tick then parsed.tickInterval = tonumber(tick) end
            local cooldown = raw:match("(%d+) min cooldown") or raw:match("(%d+) sec cooldown")
            if cooldown then parsed.cooldown = tonumber(cooldown) end
        end
    end
    if parsed.duration and parsed.tickInterval then parsed.isDot = true end
    if parsed.duration and not parsed.tickInterval then parsed.isDot = true; parsed.tickInterval = 2 end
    return parsed
end

function F:SpellTooltipLines(spellID)
    if type(spellID) ~= "number" or not (C_TooltipInfo and C_TooltipInfo.GetSpellByID) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetSpellByID, spellID)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local lines = {}
    for _, line in ipairs(data.lines) do
        if type(line) == "table" and type(line.leftText) == "string" then
            lines[#lines + 1] = line.leftText
        end
    end
    return lines
end

-- Build the calculation input for a spell from the client's own data.
function F:SpellMathInput(spellID)
    if type(spellID) ~= "number" then return nil end
    local parsed = F:ParseSpellText(F:SpellTooltipLines(spellID))
    if not parsed.minDamage then return nil end
    local input = {
        minDamage = parsed.minDamage, maxDamage = parsed.maxDamage,
        cooldown = parsed.cooldown, duration = parsed.duration,
        tickInterval = parsed.tickInterval, isDot = parsed.isDot,
    }
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" then
            local cast = tonumber(info.castTime)
            if cast and cast > 0 then input.castTime = cast / 1000 end
        end
    end
    if C_Spell and C_Spell.GetSpellPowerCost then
        local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
        if ok and type(costs) == "table" then
            for _, cost in ipairs(costs) do
                local amount = type(cost) == "table" and cost.cost or nil
                if type(amount) == "number" and amount > 0 then
                    input.manaCost = amount
                    break
                end
            end
        end
    end
    if UnitPowerMax then
        local ok, maximum = pcall(UnitPowerMax, "player", 0)
        if ok and type(maximum) == "number" and maximum > 0 then input.manaMax = maximum end
    end
    return input
end

function F:SpellMathLines(result)
    local lines = {}
    if type(result) ~= "table" then return lines end
    if F:Active("spellDps") and result.dps then
        lines[#lines + 1] = table.concat({ F:SpellLabel("dps"), ": ", F:FormatSpellNumber(result.dps), " ", F:SpellLabel("perSecond") })
    end
    if F:Active("spellDpm") and result.dpm then
        lines[#lines + 1] = table.concat({ F:SpellLabel("dpm"), ": ", F:FormatSpellNumber(result.dpm), " ", F:SpellLabel("perMinute") })
    end
    if F:Active("spellPerMana") and result.perMana then
        lines[#lines + 1] = table.concat({ F:SpellLabel("perMana"), ": ", F:FormatSpellNumber(result.perMana) })
    end
    if F:Active("spellManaPercent") and result.manaPercent then
        lines[#lines + 1] = table.concat({ F:SpellLabel("manaPercent"), ": ", F:FormatSpellNumber(result.manaPercent), F:SpellLabel("percent") })
    end
    if F:Active("spellDotShare") and result.dotShare then
        lines[#lines + 1] = table.concat({ F:SpellLabel("dotShare"), ": ", F:FormatSpellNumber(result.dotShare), F:SpellLabel("percent"),
            " (", tostring(result.ticks or 1), " ", F:SpellLabel("ticks"), ")" })
    end
    return lines
end

local hooked = {}

local function spellTooltip(tooltip, data)
    if type(data) ~= "table" or not F:Plain(data) then return end
    local id = data.id
    if type(id) ~= "number" or id <= 0 then return end
    if not (F:Active("spellDps") or F:Active("spellDpm") or F:Active("spellPerMana")
        or F:Active("spellManaPercent") or F:Active("spellDotShare")) then return end
    local input = F:SpellMathInput(id)
    if not input then return end
    for _, text in ipairs(F:SpellMathLines(F:SpellMath(input))) do
        pcall(tooltip.AddLine, tooltip, text, 0.55, 0.85, 0.85)
    end
end

local function installSpell()
    if hooked.spell then return end
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum) then return end
    hooked.spell = true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
        local ok, err = pcall(spellTooltip, tooltip, data)
        if not ok and F.RecordError then F:RecordError("spellMath", err) end
    end)
end

local function available()
    return C_TooltipInfo ~= nil and C_TooltipInfo.GetSpellByID ~= nil and C_Spell ~= nil and C_Spell.GetSpellInfo ~= nil
end

F:Register("spellDps", {
    title = "Spell damage per second",
    category = "Tooltips",
    description = "Adds the damage per second of a spell's cast cycle to its tooltip: the total damage divided by the cast time plus any cooldown. Damage and cast time come from the client's own tooltip text and C_Spell data; values the client hides are skipped.",
    disableText = "Removes the damage per second line from spell tooltips.",
    conflicts = { "DrDamage", "TheoryCraft", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "decimals", type = "number", title = "Decimal places", default = 1, min = 0, max = 2, step = 1,
          description = "How many decimals the calculated values use. Zero rounds to whole numbers." },
    },
    available = available,
    enable = installSpell,
})

F:Register("spellDpm", {
    title = "Spell damage per minute",
    category = "Tooltips",
    description = "Adds the damage a spell would deal in sixty seconds at its cast cycle rate. Useful to compare a fast nuke with a slow one without doing the maths in your head.",
    disableText = "Removes the damage per minute line from spell tooltips.",
    conflicts = { "DrDamage", "TheoryCraft", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = available,
    enable = installSpell,
})

F:Register("spellPerMana", {
    title = "Damage per mana",
    category = "Tooltips",
    description = "Adds total damage divided by the spell's power cost, so you can see which rank is the most efficient. Spells without a cost show no line.",
    disableText = "Removes the damage per mana line from spell tooltips.",
    conflicts = { "DrDamage", "TheoryCraft", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = available,
    enable = installSpell,
})

F:Register("spellManaPercent", {
    title = "Mana cost percentage",
    category = "Tooltips",
    description = "Adds the spell's power cost as a percentage of your maximum mana, which stays meaningful as your gear changes.",
    disableText = "Removes the mana cost percentage line from spell tooltips.",
    conflicts = { "DrDamage", "TheoryCraft", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = available,
    enable = installSpell,
})

F:Register("spellDotShare", {
    title = "Damage over time share",
    category = "Tooltips",
    description = "For damage over time spells, adds the number of ticks and the share of the total damage that comes from those ticks. The tick count is taken from the duration and tick interval in the client's tooltip text.",
    disableText = "Removes the damage over time line from spell tooltips.",
    conflicts = { "DrDamage", "TheoryCraft", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = available,
    enable = installSpell,
})

F:Register("spellCalcPreview", {
    title = "Spell calculation preview",
    category = "Tooltips",
    description = "Adds /fs spellcalc <min> <max> <cast> [mana] [cooldown], which runs the same calculation out of game context so you can check a rotation before a fight. It only prints numbers and never casts anything.",
    disableText = "Stops the preview command. Tooltip lines from the other spell calculation features are unaffected.",
    conflicts = { "DrDamage", "TheoryCraft" },
    available = function() return true end,
    enable = function() end,
})

F:Register("spellLabels", {
    title = "Spell calculation labels",
    category = "Tooltips",
    description = "Chooses the language of the calculated tooltip labels. Labels resolve through the client locale with an English fallback, and /fs spelllabels prints which locale is in use and how many labels are missing.",
    disableText = "Falls back to the client locale with English labels.",
    conflicts = {},
    options = {
        { key = "locale", type = "choice", title = "Label language", default = "auto",
          choices = { { value = "auto", label = "Follow the client" }, { value = "enUS", label = "English" } },
          description = "Follow the client uses the client's language when labels exist for it and English otherwise. English is the only translation shipped so far." },
    },
    available = function() return true end,
    enable = function() end,
})
