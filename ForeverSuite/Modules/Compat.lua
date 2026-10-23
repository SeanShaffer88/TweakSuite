-- SPDX-License-Identifier: MIT
-- Compatibility shims for client functions that moved into namespaces.
--
-- The Forever beta client exposes C_Container, C_GossipInfo, C_UnitAuras and C_QuestLog but
-- no longer defines several older globals. Every shim below is installed only when the
-- global is missing, so clients that still define it keep their own implementation and
-- nothing is overwritten twice. Each shim is a thin adapter: no behaviour is added.
local _, F = ...

local shimmed = {}

local function install(name, value)
    if type(value) ~= "function" then return false end
    if _G[name] == nil then
        _G[name] = value
        shimmed[name] = true
    end
    return shimmed[name] == true
end

-- Containers ---------------------------------------------------------------------------
if C_Container then
    install("GetContainerNumSlots", C_Container.GetContainerNumSlots)
    install("GetContainerItemLink", C_Container.GetContainerItemLink)
    install("GetContainerItemInfo", C_Container.GetContainerItemInfo)
    install("UseContainerItem", C_Container.UseContainerItem)
    install("PickupContainerItem", C_Container.PickupContainerItem)
    install("GetContainerItemID", C_Container.GetContainerItemID)
    if C_Container.CalculateTotalNumberOfFreeBagSlots then
        install("GetNumFreeBagSlots", function() return C_Container.CalculateTotalNumberOfFreeBagSlots() end)
    end
end

-- Auras --------------------------------------------------------------------------------
-- The old UnitAura returned positional values; C_UnitAuras.GetAuraDataByIndex returns a
-- table. The order below matches the old return list so existing call sites keep working.
if not UnitAura and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    shimmed.UnitAura = true
    _G.UnitAura = function(unit, index, filter)
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
        if not ok or type(data) ~= "table" then return nil end
        return data.name, data.icon, data.applications, data.dispelName, data.duration,
            data.expirationTime, data.source, data.isStealable, data.nameplateShowPersonal, data.spellId
    end
end

-- Gossip -------------------------------------------------------------------------------
if C_GossipInfo then
    if C_GossipInfo.GetOptions and not GetNumGossipOptions then
        _G.GetNumGossipOptions = function()
            local options = C_GossipInfo.GetOptions()
            return type(options) == "table" and #options or 0
        end
    end
    if C_GossipInfo.GetOptions and not GetGossipOptions then
        -- Old shape: name, optionType, name, optionType, ...
        _G.GetGossipOptions = function()
            local options = C_GossipInfo.GetOptions() or {}
            local out = {}
            for index, option in ipairs(options) do
                if type(option) == "table" then
                    local kind = option.optionType or option.type or "gossip"
                    if type(option.moneyCost) == "number" and option.moneyCost > 0 then kind = "money" end
                    out[(index - 1) * 2 + 1] = option.name
                    out[(index - 1) * 2 + 2] = kind
                end
            end
            return unpack(out)
        end
    end
end

-- Quest log ----------------------------------------------------------------------------
-- C_QuestLog.GetInfo returns a table; GetQuestLogTitle returned a tuple.
if not GetNumQuestLogEntries and C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
    shimmed.GetNumQuestLogEntries = true
    _G.GetNumQuestLogEntries = function() return C_QuestLog.GetNumQuestLogEntries() end
end

if not GetQuestLogTitle and C_QuestLog and C_QuestLog.GetInfo then
    shimmed.GetQuestLogTitle = true
    _G.GetQuestLogTitle = function(index)
        local ok, info = pcall(C_QuestLog.GetInfo, index)
        if not ok or type(info) ~= "table" then return nil end
        return info.title, info.level, info.suggestedGroup, info.isHeader, info.isCollapsed,
            info.isComplete, info.frequency, info.questID, info.startEvent, info.displayQuestID
    end
end

if not GetQuestLevel then
    shimmed.GetQuestLevel = true
    _G.GetQuestLevel = function(questIDOrIndex)
        if not (C_QuestLog and C_QuestLog.GetQuestDifficultyLevel) then return nil end
        local questID = questIDOrIndex
        if type(questID) ~= "number" then
            questID = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest() or nil
        elseif C_QuestLog.GetInfo then
            local ok, info = pcall(C_QuestLog.GetInfo, questIDOrIndex)
            if ok and type(info) == "table" and type(info.level) == "number" and info.level > 0 then
                return info.level
            end
        end
        if type(questID) ~= "number" then return nil end
        local ok, level = pcall(C_QuestLog.GetQuestDifficultyLevel, questID)
        return ok and level or nil
    end
end

if not GetQuestGreenRange then
    -- The old helper returned the level difference at which a quest turns green. The beta
    -- client dropped it; four levels below the player matches the classic difficulty bands
    -- closely enough for the trivial-quest notice, which is a notice and not a rule.
    shimmed.GetQuestGreenRange = true
    _G.GetQuestGreenRange = function()
        local level = UnitLevel and UnitLevel("player") or 0
        if type(level) ~= "number" or level <= 0 then return 0 end
        return math.max(1, math.min(5, level - 1))
    end
end

if not GetQuestRequiredMoney and C_QuestLog and C_QuestLog.GetRequiredMoney then
    shimmed.GetQuestRequiredMoney = true
    _G.GetQuestRequiredMoney = function()
        local questID = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()
        if type(questID) ~= "number" then return 0 end
        local ok, money = pcall(C_QuestLog.GetRequiredMoney, questID)
        return ok and money or 0
    end
end

-- Flight map ---------------------------------------------------------------------------
-- The beta client names the helper TaxiNodeName; the older global was GetTaxiNodeName.
if not GetTaxiNodeName and TaxiNodeName then
    _G.GetTaxiNodeName = TaxiNodeName
    shimmed.GetTaxiNodeName = true
end
if not NumTaxiNodes and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes then
    shimmed.NumTaxiNodes = true
    _G.NumTaxiNodes = function()
        local nodes = C_TaxiMap.GetAllTaxiNodes()
        return type(nodes) == "table" and #nodes or 0
    end
end

-- Reports which shims were installed, so /fs status can show what the client needed.
function F:CompatReport()
    local names = {
        "GetContainerNumSlots", "GetContainerItemLink", "GetContainerItemInfo", "UseContainerItem",
        "PickupContainerItem", "GetContainerItemID", "GetNumFreeBagSlots", "UnitAura",
        "GetNumGossipOptions", "GetGossipOptions", "GetNumQuestLogEntries", "GetQuestLogTitle",
        "GetQuestLevel", "GetQuestGreenRange", "GetQuestRequiredMoney", "GetTaxiNodeName", "NumTaxiNodes",
    }
    local installed = {}
    for _, name in ipairs(names) do
        if shimmed[name] then installed[#installed + 1] = name end
    end
    return installed
end
