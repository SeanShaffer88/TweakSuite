-- SPDX-License-Identifier: MIT
-- Group, difficulty and availability tools. Everything here only reads the client's
-- own group data and prints it; nothing invites, kicks, promotes or starts anything
-- without an explicit command from the player.
local _, F = ...

local ROLE_LABEL = { TANK = "Tank", HEALER = "Healer", DAMAGER = "Damage", NONE = "No role" }

function F:RoleLabel(role)
    return ROLE_LABEL[role] or role or "No role"
end

function F:GroupRows()
    local rows = {}
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    if type(count) ~= "number" or count <= 0 then
        if UnitExists and UnitExists("player") then
            rows[1] = { unit = "player", name = UnitName("player") }
        end
    elseif IsInRaid and IsInRaid() then
        for index = 1, count do
            local name, _, subgroup, _, _, classFile = GetRaidRosterInfo(index)
            if type(name) == "string" and name ~= "" then
                rows[#rows + 1] = { unit = "raid" .. index, name = name, subgroup = subgroup, class = classFile }
            end
        end
    else
        rows[1] = { unit = "player", name = UnitName("player") }
        for index = 1, math.min(4, count - 1) do
            local unit = "party" .. index
            if UnitExists and UnitExists(unit) then
                rows[#rows + 1] = { unit = unit, name = UnitName(unit) }
            end
        end
    end
    for _, row in ipairs(rows) do
        row.role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(row.unit) or "NONE"
        row.leader = UnitIsGroupLeader and UnitIsGroupLeader(row.unit) == true
        row.assistant = UnitIsGroupAssistant and UnitIsGroupAssistant(row.unit) == true
    end
    return rows
end

function F:GroupSummary()
    local rows = self:GroupRows()
    local info = { members = #rows, inRaid = IsInRaid and IsInRaid() == true or false,
        group = IsInGroup and IsInGroup() == true or false }
    if GetInstanceInfo then
        local name, kind, difficultyID, difficultyName = GetInstanceInfo()
        info.instance, info.instanceType, info.difficultyID, info.difficultyName = name, kind, difficultyID, difficultyName
    end
    return info, rows
end

-- Ready check reminders keep the last result so /fs ready can repeat who has not
-- answered yet. Comparing booleans only; no health or power value is involved.
local readyState = {}

function F:ReadyCheckStart()
    readyState = { pending = true, answered = 0, total = 0, missing = {} }
    local rows = self:GroupRows()
    for _, row in ipairs(rows) do
        readyState.total = readyState.total + 1
        readyState.missing[#readyState.missing + 1] = row.name or row.unit
    end
    return readyState.total
end

function F:ReadyCheckConfirm(unit, isReady)
    if type(unit) ~= "string" or not readyState.pending then return false end
    local name = UnitName and UnitName(unit) or unit
    for index = #readyState.missing, 1, -1 do
        if readyState.missing[index] == name then
            table.remove(readyState.missing, index)
            readyState.answered = readyState.answered + 1
            if isReady == false then
                readyState.notReady = readyState.notReady or {}
                readyState.notReady[#readyState.notReady + 1] = name
            end
            return true
        end
    end
    return false
end

function F:ReadyCheckReport()
    if not readyState.pending then return nil end
    return { total = readyState.total, answered = readyState.answered,
        missing = readyState.missing, notReady = readyState.notReady or {} }
end

function F:DifficultyLabel(kind)
    local id
    if kind == "raid" then
        id = GetRaidDifficultyID and GetRaidDifficultyID() or nil
    else
        id = GetDungeonDifficultyID and GetDungeonDifficultyID() or nil
    end
    if type(id) ~= "number" then return nil end
    local name = _G["DIFFICULTY_" .. id] or ("Difficulty " .. id)
    return id, name
end

function F:SetDifficulty(kind, id)
    id = tonumber(id)
    if not id or id % 1 ~= 0 or id < 1 or id > 40 then return false, "difficulty must be a whole number from 1 to 40" end
    if InCombatLockdown() then return false, "change difficulty after combat" end
    local setter = kind == "raid" and SetRaidDifficultyID or SetDungeonDifficultyID
    if type(setter) ~= "function" then return false, "this client cannot change that difficulty" end
    local ok = pcall(setter, id)
    if not ok then return false, "the client refused the change" end
    return true
end

-- Availability audit: checks the API families the addon relies on and every
-- registered feature's own availability function, so a missing client system shows
-- up as a line instead of a broken feature.
local AUDIT_APIS = {
    { key = "items", label = "Item data", probe = function() return C_Item and C_Item.GetItemInfo end },
    { key = "spells", label = "Spell data", probe = function() return C_Spell and C_Spell.GetSpellInfo end },
    { key = "tooltips", label = "Tooltip data", probe = function() return C_TooltipInfo and C_TooltipInfo.GetItemByID end },
    { key = "auras", label = "Aura data", probe = function() return C_UnitAuras and C_UnitAuras.GetUnitAuras end },
    { key = "containers", label = "Bag data", probe = function() return C_Container and C_Container.GetContainerItemLink end },
    { key = "map", label = "Map data", probe = function() return C_Map and C_Map.GetBestMapForUnit end },
    { key = "quests", label = "Quest log", probe = function() return C_QuestLog and C_QuestLog.GetNumQuestLogEntries end },
    { key = "party", label = "Group tools", probe = function() return C_PartyInfo and C_PartyInfo.DoReadyCheck end },
    { key = "toasts", label = "Event toasts", probe = function() return C_EventToastManager and C_EventToastManager.RemoveCurrentToast end },
    { key = "talkinghead", label = "Talking heads", probe = function() return C_TalkingHead and C_TalkingHead.GetCurrentLineInfo end },
    { key = "gamepad", label = "Gamepad", probe = function() return C_GamePad and C_GamePad.IsEnabled end },
    { key = "damagemeter", label = "Damage meter", probe = function() return C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable end },
    { key = "secrets", label = "Secrecy checks", probe = function() return C_Secrets and C_Secrets.ShouldSpellAuraBeSecret end },
}

function F:AuditRows()
    local rows = {}
    for _, entry in ipairs(AUDIT_APIS) do
        local ok, result = pcall(entry.probe)
        rows[#rows + 1] = { key = entry.key, label = entry.label, ok = ok and result ~= nil }
    end
    for index = 1, #self.order do
        local id = self.order[index]
        local feature = self.features[id]
        if feature and feature.available then
            local ok, result = pcall(feature.available)
            if not ok or not result then
                rows[#rows + 1] = { key = id, label = feature.title or id, ok = false, feature = true }
            end
        end
    end
    return rows
end

function F:AuditSummary()
    local rows = self:AuditRows()
    local available, missing = 0, 0
    for _, row in ipairs(rows) do
        if row.ok then available = available + 1 else missing = missing + 1 end
    end
    return rows, available, missing
end

function F:ActivitySummary()
    local summary = {}
    summary.level = UnitLevel and UnitLevel("player") or nil
    summary.money = GetMoney and GetMoney() or nil
    summary.rested = GetXPExhaustion and GetXPExhaustion() or nil
    summary.completed = 0
    if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
        local ok, list = pcall(C_QuestLog.GetAllCompletedQuestIDs)
        if ok and type(list) == "table" then summary.completed = #list end
    end
    summary.watched = 0
    if C_QuestLog and C_QuestLog.GetNumQuestWatches then
        local ok, count = pcall(C_QuestLog.GetNumQuestWatches)
        if ok and type(count) == "number" then summary.watched = count end
    end
    summary.gold = GetMoney and math.floor((GetMoney() or 0) / 10000) or 0
    return summary
end

F:Register("readyCheckReminder", {
    title = "Ready check reminders",
    category = "Interface",
    description = "Prints who has not answered a ready check, without blocking the check, and can start one with /fs readycheck or answer it with /fs ready yes|no. Only readiness booleans are used.",
    disableText = "Stops tracking ready checks. A check already running is finished by the client.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function() return true end,
    enable = function()
        readyState = {}
        F:Listen("readyCheckReminder", "READY_CHECK", function(_, name)
            F:ReadyCheckStart()
            if type(name) == "string" then F:Print((name or "Someone") .. " started a ready check.") end
        end)
        F:Listen("readyCheckReminder", "READY_CHECK_CONFIRM", function(_, unit, isReady)
            F:ReadyCheckConfirm(unit, isReady)
        end)
        F:Listen("readyCheckReminder", "READY_CHECK_FINISHED", function()
            local report = F:ReadyCheckReport()
            if not report then return end
            if #report.missing == 0 then
                F:Print("Ready check: everyone answered (" .. report.answered .. ").")
            else
                F:Print("Ready check: waiting on " .. table.concat(report.missing, ", ") .. ".")
            end
            readyState.pending = false
        end)
    end,
    disable = function() readyState = {} end,
})

F:Register("roleIndicators", {
    title = "Group roles and leader",
    category = "Interface",
    description = "Lists every group member with their assigned role and marks the leader and assistants with /fs roles. It only reads group state and never changes a role.",
    disableText = "Stops the /fs roles listing.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function() return GetNumGroupMembers ~= nil end,
    enable = function() end,
})

F:Register("difficultySelector", {
    title = "Instance difficulty selection",
    category = "Interface",
    description = "Shows and changes the dungeon or raid difficulty with /fs difficulty and /fs difficulty raid 14, refusing in combat and refusing values outside 1-40.",
    disableText = "Stops the difficulty command. The difficulty stays where it is.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function() return SetDungeonDifficultyID ~= nil or SetRaidDifficultyID ~= nil end,
    enable = function() end,
})

F:Register("groupTools", {
    title = "Group summary",
    category = "Interface",
    description = "Prints a summary of the group with /fs group: members, their roles, the instance, its difficulty and the current loot method. Read only.",
    disableText = "Stops the /fs group summary.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever" },
    available = function() return GetNumGroupMembers ~= nil end,
    enable = function() end,
})

F:Register("activitySummary", {
    title = "Activity summary",
    category = "Interface",
    description = "Prints a short progress summary with /fs activity: level, completed quest count, watched quests, rested experience and gold. It reads the quest log and money only.",
    disableText = "Stops the /fs activity summary.",
    conflicts = {},
    available = function() return true end,
    enable = function() end,
})

F:Register("availabilityAudit", {
    title = "Gameplay system availability audit",
    category = "Interface",
    description = "Runs /fs audit, which checks the client API families ForeverSuite relies on and calls every feature's availability check, listing anything this client does not offer. Useful right after a client update.",
    disableText = "Stops the audit command.",
    conflicts = {},
    available = function() return true end,
    enable = function() end,
})
