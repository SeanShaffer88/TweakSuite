-- TweakSuite - Copyright (C) 2026 Malikor
-- SPDX-License-Identifier: GPL-3.0-or-later
-- Invite, duel, summon, resurrection, release and whisper rules.
-- Every rule is opt-in, skips combat and Shift, and never accepts money or items.
local _, F = ...
local common = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "TweaksForever", "BadBoy" }

local function isFriend(name)
    return name ~= nil and UnitIsFriend ~= nil and UnitIsFriend("player", name) == true
end

local function isGuild(name)
    return name ~= nil and UnitIsInMyGuild ~= nil and UnitIsInMyGuild(name) == true
end

local function isTrusted(name)
    return isFriend(name) or isGuild(name)
end

local function acceptSummon()
    if not F:Active("summonRules") or not F:CanAutomate() then return false end
    if C_SummonInfo and C_SummonInfo.ConfirmSummon then
        local ok = pcall(C_SummonInfo.ConfirmSummon)
        if ok then return true end
    end
    if AcceptSummon then
        local ok = pcall(AcceptSummon)
        if ok then return true end
    end
    return false
end

local summonTicker
local function summonWatch()
    if not F:Active("summonRules") then return end
    if not (C_SummonInfo and C_SummonInfo.GetSummonConfirmTimeLeft) then return end
    local left = C_SummonInfo.GetSummonConfirmTimeLeft()
    if type(left) ~= "number" or left <= 0 then return end
    if not F:CanAutomate() then return end
    local option = F:GetOption("summonRules", "trust")
    if option == "trusted" then
        local summoner = C_SummonInfo.GetSummonConfirmSummoner and C_SummonInfo.GetSummonConfirmSummoner()
        if type(summoner) == "string" and not isTrusted(summoner) then return end
    end
    acceptSummon()
end

function F:CheckSummonNow()
    summonWatch()
end

F:Register("friendlyInvites", {
    title = "Accept invites from friends and guild",
    category = "Automation",
    description = "Accepts party invitations that come from a friend or a guild member automatically. Strangers are never accepted, nothing is invited in return, and the rule pauses in combat or while Shift is held.",
    disableText = "Stops accepting invitations. An invitation already accepted stays accepted.",
    conflicts = common,
    options = {
        { key = "announce", type = "boolean", title = "Say when an invite was accepted", default = true,
          description = "Prints who was accepted in chat so an automatic join is never silent." },
    },
    available = function() return AcceptGroup ~= nil and UnitIsFriend ~= nil end,
    enable = function()
        F:Listen("friendlyInvites", "PARTY_INVITE_REQUEST", function(_, name)
            if not F:CanAutomate() then return end
            if type(name) ~= "string" or not isTrusted(name) then return end
            AcceptGroup()
            if F:GetOption("friendlyInvites", "announce") ~= false then
                F:Print("Accepted an invite from " .. name .. ".")
            end
        end)
    end,
})

F:Register("duelRules", {
    title = "Decline duel requests by rule",
    category = "Automation",
    description = "Declines duel requests that match a rule you choose, for example duels from strangers or from players far below your level. Friends and guild members are exempt unless you turn that off. Declining a duel is not a combat action and nothing is reported to the other player.",
    disableText = "Stops declining duels immediately. A duel already declined stays declined.",
    conflicts = common,
    options = {
        { key = "strangers", type = "boolean", title = "Decline duels from strangers", default = true,
          description = "Declines duels from players who are neither friends nor guild members." },
        { key = "allowTrusted", type = "boolean", title = "Always allow friends and guild", default = true,
          description = "Friends and guild members can still challenge you. Turn this off to apply the stranger rule to them too." },
        { key = "levelGap", type = "number", title = "Decline players this many levels below", default = 0,
          min = 0, max = 60, step = 5, unit = " levels",
          description = "Zero turns the level rule off. Any other value declines duels from players whose level is that far below yours." },
    },
    available = function() return DeclineDuel ~= nil or (C_DuelInfo and C_DuelInfo.Decline) end,
    enable = function()
        F:Listen("duelRules", "DUEL_REQUESTED", function(_, name)
            if not F:CanAutomate() then return end
            if type(name) ~= "string" then return end
            local trusted = isTrusted(name)
            local decline = false
            if F:GetOption("duelRules", "strangers") and not (trusted and F:GetOption("duelRules", "allowTrusted")) then
                decline = true
            end
            local gap = F:GetOption("duelRules", "levelGap") or 0
            if not decline and gap > 0 and UnitLevel and UnitLevel("player") then
                local other = UnitLevel(name)
                if type(other) == "number" and other > 0 and UnitLevel("player") - other >= gap then decline = true end
            end
            if not decline then return end
            if DeclineDuel then
                pcall(DeclineDuel)
            elseif C_DuelInfo and C_DuelInfo.Decline then
                pcall(C_DuelInfo.Decline)
            end
            F:Print("Declined a duel from " .. name .. ".")
        end)
    end,
})

F:Register("summonRules", {
    title = "Summon acceptance rules",
    category = "Automation",
    description = "Confirms a warlock summon automatically while the summon timer is running, either from anyone in your group or only from friends and guild members. It pauses in combat and while Shift is held, and it never accepts a summon you did not receive through the client's own confirmation window.",
    disableText = "Stops confirming summons. A summon that is already confirmed still moves you.",
    conflicts = common,
    options = {
        { key = "trust", type = "choice", title = "Accept summons from", default = "group",
          choices = { { value = "group", label = "Anyone in my group" },
              { value = "trusted", label = "Friends and guild members only" } },
          description = "The narrower setting uses the summoning player's name and only confirms when that player is a friend or guild member." },
    },
    available = function()
        return (C_SummonInfo and C_SummonInfo.ConfirmSummon) or AcceptSummon ~= nil
    end,
    enable = function()
        if not summonTicker then
            summonTicker = CreateFrame("Frame")
            local elapsed = 0
            summonTicker:SetScript("OnUpdate", function(_, delta)
                elapsed = elapsed + (type(delta) == "number" and delta or 0)
                if elapsed < 0.5 then return end
                elapsed = 0
                summonWatch()
            end)
        end
        summonTicker:Show()
        summonWatch()
    end,
    disable = function()
        if summonTicker then summonTicker:Hide() end
    end,
})

F:Register("resurrectRules", {
    title = "Resurrection acceptance rules",
    category = "Automation",
    description = "Accepts a resurrection offer while you are a ghost and out of combat, either from anyone or only from friends and guild members. It never accepts while you are alive or in combat, so it cannot interrupt a fight.",
    disableText = "Stops accepting resurrections. An offer that is already accepted is not undone.",
    conflicts = common,
    options = {
        { key = "trust", type = "choice", title = "Accept resurrections from", default = "group",
          choices = { { value = "group", label = "Anyone nearby" },
              { value = "trusted", label = "Friends and guild members only" } },
          description = "Choose who may resurrect you automatically. The narrow setting ignores everyone else." },
    },
    available = function() return AcceptResurrect ~= nil end,
    enable = function()
        F:Listen("resurrectRules", "RESURRECT_REQUEST", function(_, name)
            if not F:CanAutomate() then return end
            if not UnitIsDeadOrGhost or not UnitIsDeadOrGhost("player") then return end
            if F:GetOption("resurrectRules", "trust") == "trusted" then
                if type(name) ~= "string" or not isTrusted(name) then return end
            end
            pcall(AcceptResurrect)
            F:Print("Accepted a resurrection from " .. (type(name) == "string" and name or "a nearby player") .. ".")
        end)
    end,
})

local function releaseSpirit()
    if not F:Active("battlegroundRelease") then return end
    if not UnitIsDeadOrGhost or not UnitIsDeadOrGhost("player") then return end
    if RepopMe then pcall(RepopMe) end
end

F:Register("battlegroundRelease", {
    title = "Release spirit in battlegrounds",
    category = "Automation",
    description = "Releases your spirit automatically after you die in a battleground or arena, after a delay you choose. It never releases in the open world, never releases while alive, and the delay gives you time to be resurrected by another player first.",
    disableText = "Stops releasing spirits. If you are already a ghost, use the client's own release button.",
    conflicts = common,
    options = {
        { key = "bgOnly", type = "boolean", title = "Only inside battlegrounds and arenas", default = true,
          description = "Keeps automatic release inside player-versus-player instances. Turn this off to release anywhere, which is rarely what you want." },
        { key = "delay", type = "number", title = "Delay before releasing", default = 2, min = 0, max = 30, step = 1, unit = " s",
          description = "Time to wait after death before releasing, so a resurrection offered right away can still be taken." },
    },
    available = function() return RepopMe ~= nil and UnitIsDeadOrGhost ~= nil and GetTime ~= nil end,
    enable = function()
        F:Listen("battlegroundRelease", "PLAYER_DEAD", function()
            if not F:CanAutomate() then return end
            if F:GetOption("battlegroundRelease", "bgOnly") ~= false and IsInInstance then
                local kind = select(2, IsInInstance())
                if kind ~= "pvp" and kind ~= "arena" then return end
            end
            local delay = F:GetOption("battlegroundRelease", "delay") or 0
            if delay <= 0 then releaseSpirit(); return end
            if type(C_Timer) == "table" and C_Timer.After then
                C_Timer.After(delay, releaseSpirit)
            elseif type(GetTime) == "function" then
                local due = GetTime() + delay
                local waiter = CreateFrame("Frame")
                waiter:SetScript("OnUpdate", function(self)
                    if GetTime() >= due then self:SetScript("OnUpdate", nil); self:Hide(); releaseSpirit() end
                end)
                waiter:Show()
            end
        end)
    end,
})

F:Register("whisperInvites", {
    title = "Invite by whisper keyword",
    category = "Automation",
    description = "Invites a player who whispers a keyword such as inv or invite. By default only friends and guild members are invited; strangers are ignored unless you allow anyone. It never whispers back, never invites during combat and never invites while Shift is held.",
    disableText = "Stops watching whispers. A player already invited stays in the group.",
    conflicts = { "BadBoy", "GlobalIgnore", "Leatrix_Plus", "Leatrix_Plus_Forever" },
    options = {
        { key = "keyword", type = "choice", title = "Invite keyword", default = "inv",
          choices = { { value = "inv", label = "inv" }, { value = "invite", label = "invite" }, { value = "plus", label = "+" } },
          description = "The whisper must match this word exactly, ignoring case and surrounding spaces." },
        { key = "allowAnyone", type = "boolean", title = "Allow strangers to ask", default = false,
          description = "Off by default: only friends and guild members are invited. Turning it on lets any player join by whispering the keyword." },
        { key = "announce", type = "boolean", title = "Say when a whisper invite was sent", default = true,
          description = "Prints the invited name in chat so an automatic invitation is never silent." },
    },
    available = function() return InviteUnit ~= nil or (C_PartyInfo and C_PartyInfo.InviteUnit) end,
    enable = function()
        F:Listen("whisperInvites", "CHAT_MSG_WHISPER", function(_, text, name)
            if not F:CanAutomate() then return end
            if type(text) ~= "string" or type(name) ~= "string" then return end
            local keyword = F:GetOption("whisperInvites", "keyword")
            local wanted = keyword == "invite" and "invite" or (keyword == "plus" and "+" or "inv")
            if text:lower():match("^%s*" .. wanted:gsub("%+", "%%+") .. "%s*$") == nil then return end
            if F:GetOption("whisperInvites", "allowAnyone") ~= true and not isTrusted(name) then return end
            if C_PartyInfo and C_PartyInfo.InviteUnit then
                pcall(C_PartyInfo.InviteUnit, name)
            else
                pcall(InviteUnit, name)
            end
            F:Print("Invited " .. name .. " after a whisper request.")
        end)
    end,
})
