-- SPDX-License-Identifier: MIT
local _, F = ...
local function cvarFeature(id, title, name, desired, description)
    local function restore()
        local saved = F.db.cvars[id]
        if type(saved) ~= "table" then F.db.cvars[id] = nil; return end
        if type(saved.before) == "string" and saved.applied == desired and C_CVar and C_CVar.GetCVar and C_CVar.SetCVar then
            if C_CVar.GetCVar(name) == saved.applied then
                C_CVar.SetCVar(name, saved.before)
                if C_CVar.GetCVar(name) ~= saved.before then return end
            end
        end
        F.db.cvars[id] = nil
    end
    F:Register(id, { title = title, category = "Interface", description = description .. " Your prior value is restored when switched off, unless another tool changed it.",
        cvar = name, value = desired,
        disableText = "Restores the saved previous value if the client still has ForeverSuite's value. If another tool changed it, that later value is preserved. Switching off does not necessarily set the opposite value.",
        conflicts = { "AdvancedInterfaceOptions", "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "TweaksForever" },
        available = function()
            return C_CVar and C_CVar.GetCVar and C_CVar.SetCVar and C_CVar.GetCVar(name) ~= nil
        end,
        enable = function()
            local current = C_CVar.GetCVar(name)
            local saved = F.db.cvars[id]
            if type(saved) ~= "table" or type(saved.before) ~= "string" or saved.applied ~= desired
                or current ~= saved.applied then
                F.db.cvars[id] = { before = current, applied = desired }
            end
            C_CVar.SetCVar(name, desired)
            assert(C_CVar.GetCVar(name) == desired, "Client refused CVar " .. name)
        end, disable = restore })
end
cvarFeature("autoLoot", "Auto-loot by default", "autoLootDefault", "1", "Enables the client's auto-loot setting.")
cvarFeature("keyDown", "Cast on key press", "ActionButtonUseKeyDown", "1", "Activates action buttons on key press instead of release.")
cvarFeature("noGlow", "Disable full-screen glow", "ffxGlow", "0", "Disables the full-screen glow effect when this CVar exists.")
cvarFeature("nameplates", "Always show enemy nameplates", "nameplateShowAll", "1", "Keeps enabled enemy nameplates visible outside combat.")
cvarFeature("noLowHealthFlash", "Disable low-health screen flash", "doNotFlashLowHealthWarning", "1", "Disables the red screen flash at low health.")
cvarFeature("questText", "Instant quest text", "instantQuestText", "1", "Shows quest text immediately when supported by the client.")
cvarFeature("stackPlates", "Stack nameplates vertically", "nameplateMotion", "1", "Uses the client's stacking layout for nameplates.")
cvarFeature("classPlates", "Class colors on enemy nameplates", "ShowClassColorInNameplate", "1", "Uses class colors for supported player nameplates.")
cvarFeature("hideFriendlyPets", "Hide friendly pet nameplates", "nameplateShowFriendlyPets", "0", "Hides pet plates without hiding friendly players.")
cvarFeature("hideFriendlyGuardians", "Hide friendly guardian nameplates", "nameplateShowFriendlyGuardians", "0", "Reduces nameplate clutter from friendly guardians.")
cvarFeature("hideFriendlyTotems", "Hide friendly totem nameplates", "nameplateShowFriendlyTotems", "0", "Hides friendly totem plates.")
cvarFeature("hideEnemyPets", "Hide enemy pet nameplates", "nameplateShowEnemyPets", "0", "Hides enemy pet plates; enemy player plates keep their own setting.")
cvarFeature("enemyTotems", "Show enemy totem nameplates", "nameplateShowEnemyTotems", "1", "Enables nameplates for enemy totems.")
cvarFeature("personalResource", "Always show personal resource bar", "nameplatePersonalShowAlways", "1", "Keeps the enabled personal resource display visible outside combat.")
cvarFeature("targetOfTarget", "Show target of target", "showTargetOfTarget", "1", "Enables the client's target-of-target display.")
cvarFeature("hideOwnName", "Hide your overhead name", "UnitNameOwn", "0", "Removes your character's own overhead name.")
cvarFeature("hideTitles", "Hide player titles", "UnitNamePlayerPVPTitle", "0", "Hides titles in overhead player names.")
cvarFeature("hideGuildNames", "Hide overhead guild names", "UnitNamePlayerGuild", "0", "Hides guild names above player characters.")
cvarFeature("hideGuildRanks", "Hide overhead guild ranks", "UnitNameGuildTitle", "0", "Hides guild ranks above player characters.")
cvarFeature("hideCritterNames", "Hide critter names", "UnitNameNonCombatCreatureName", "0", "Hides overhead names on noncombat creatures.")
cvarFeature("noCameraBobbing", "Disable camera bobbing", "cameraBobbing", "0", "Disables the client camera's bobbing setting.")
cvarFeature("noTerrainTilt", "Disable camera terrain tilt", "cameraTerrainTilt", "0", "Disables automatic terrain tilt when the CVar exists.")
cvarFeature("noWaterCollision", "Disable camera water collision", "cameraWaterCollision", "0", "Allows the camera to cross the water surface.")
cvarFeature("chatWheel", "Enable chat mouse-wheel scrolling", "chatMouseScroll", "1", "Enables chat scrolling with the mouse wheel when supported.")
cvarFeature("noLootHistory", "Do not auto-open loot history", "autoOpenLootHistory", "0", "Keeps loot history from opening automatically.")
cvarFeature("noSpellAlerts", "Hide spell activation overlays", "displaySpellActivationOverlays", "0", "Hides the client's on-screen spell activation artwork.")

for category, ids in pairs({
    Nameplates = { "nameplates", "stackPlates", "classPlates", "hideFriendlyPets", "hideFriendlyGuardians", "hideFriendlyTotems", "hideEnemyPets", "enemyTotems", "personalResource" },
    ["Overhead names"] = { "hideOwnName", "hideTitles", "hideGuildNames", "hideGuildRanks", "hideCritterNames" },
    Camera = { "noCameraBobbing", "noTerrainTilt", "noWaterCollision" },
    Chat = { "chatWheel" },
}) do
    for _, id in ipairs(ids) do F.features[id].category = category end
end

local fadeSaved, arrowSaved = {}, {}
local function chatFrames(callback)
    for _, name in ipairs(CHAT_FRAMES or {}) do if _G[name] then callback(_G[name], name) end end
end
F:Register("chatFade", { title = "Keep chat text visible", category = "Chat",
    disableText = "Restores each chat window's previous fading setting if it still has the value applied by ForeverSuite.",
    description = "Disables fading on existing chat windows. Restores their previous fading setting when switched off.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "EnhanceQoLChatSocial", "Prat-3.0" },
    available = function() return ChatFrame1 and ChatFrame1.GetFading and ChatFrame1.SetFading end,
    enable = function()
        local function apply()
            chatFrames(function(frame)
                if frame.GetFading and frame.SetFading then
                    if fadeSaved[frame] == nil then fadeSaved[frame] = frame:GetFading() end
                    frame:SetFading(false)
                end
            end)
        end
        apply(); F:Listen("chatFade", "UPDATE_CHAT_WINDOWS", apply)
    end,
    disable = function()
        for frame, value in pairs(fadeSaved) do
            if not frame:GetFading() then frame:SetFading(value) end
            fadeSaved[frame] = nil
        end
    end })
F:Register("chatArrows", { title = "Arrow keys edit chat", category = "Chat",
    disableText = "Restores each chat edit box's previous Alt-arrow behavior if it still has the value applied by ForeverSuite.",
    description = "Lets arrow keys move the text cursor without holding Alt. Restores each edit box when switched off.",
    conflicts = { "Leatrix_Plus", "Leatrix_Plus_Forever", "EnhanceQoL", "EnhanceQoLChatSocial", "Prat-3.0" },
    available = function() return ChatFrame1EditBox and ChatFrame1EditBox.GetAltArrowKeyMode end,
    enable = function()
        local function apply()
            chatFrames(function(_, name)
                local edit = _G[name .. "EditBox"]
                if edit and edit.GetAltArrowKeyMode and edit.SetAltArrowKeyMode then
                    if arrowSaved[edit] == nil then arrowSaved[edit] = edit:GetAltArrowKeyMode() end
                    edit:SetAltArrowKeyMode(false)
                end
            end)
        end
        apply(); F:Listen("chatArrows", "UPDATE_CHAT_WINDOWS", apply)
    end,
    disable = function()
        for edit, value in pairs(arrowSaved) do
            if not edit:GetAltArrowKeyMode() then edit:SetAltArrowKeyMode(value) end
            arrowSaved[edit] = nil
        end
    end })
