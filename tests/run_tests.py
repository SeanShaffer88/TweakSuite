"""Behavior tests in real Lua 5.1 with a deliberately limited WoW host mock.

These test addon decisions, not Blizzard rendering, protected execution, or servers.
Install tests/requirements.txt with Python 3.12, then run this script.
"""
import re
import unittest
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "ForeverSuite"
FILES = [line.strip().replace("\\", "/") for line in (ADDON / "ForeverSuite.toc").read_text().splitlines()
         if line.strip() and not line.startswith("#")]

MOCK = r'''
calls = { repair = 0, sell = 0, loot = 0, accept = 0, reward = 0, hooks = 0 }
combat, shift, loaded, cvars, frames = false, false, {}, {}, {}
repairCost, money, choices, requiredMoney = 10000, 1000000, 0, 0
itemStack, itemLevel, itemEquip, itemReady = 20, 50, "INVTYPE_HEAD", true
clientVersion, clientBuild, clientInterface = "1.60.1", "70532", 16001
SlashCmdList, UISpecialFrames, CHAT_FRAMES = {}, {}, {"ChatFrame1"}
ChatFontNormal = {}
local methods = {}
local noops = {"SetSize", "SetPoint", "SetFrameStrata", "SetClampedToScreen", "EnableMouse",
 "SetMovable", "SetBackdrop", "SetJustifyH", "RegisterForDrag", "StartMoving", "StopMovingOrSizing",
 "SetAutoFocus", "SetFontObject", "SetMaxLetters", "SetMultiLine", "SetScrollChild",
 "UpdateScrollChildRect", "SetFocus", "ClearFocus", "HighlightText", "ClearAllPoints", "SetTextColor", "SetVerticalScroll",
 "SetJustifyV", "SetBackdropColor", "SetBackdropBorderColor", "SetColorTexture", "SetAllPoints", "SetHighlightTexture"}
for _, name in ipairs(noops) do methods[name] = function() end end
function methods:SetHeight(h) self.height = h end
function methods:SetWidth(w) self.width = w end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:HookScript(name, fn)
 self.hooks[name] = self.hooks[name] or {}; table.insert(self.hooks[name], fn)
end
function methods:Trigger(name, ...)
 if self.scripts[name] then self.scripts[name](self, ...) end
 for _, fn in ipairs(self.hooks[name] or {}) do fn(self, ...) end
end
function methods:RegisterEvent(name) if name == badEvent then error("Unknown event") end; self.events[name] = true end
function methods:Show() self.shown = true; self:Trigger("OnShow") end
function methods:Hide() self.shown = false end
function methods:SetShown(value) self.shown = value end
function methods:SetText(text) self.text = text; self:Trigger("OnTextChanged") end
function methods:GetText() return self.text or "" end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(value) self.enabled = value end
function methods:GetFading() return self.fading == true end
function methods:SetFading(value) self.fading = value end
function methods:GetAltArrowKeyMode() return self.arrows == true end
function methods:SetAltArrowKeyMode(value) self.arrows = value end
function methods:GetItem() return "Item", self.link end
function methods:AddLine(text) table.insert(self.lines, text) end
function CreateFrame(_, name)
 local frame = setmetatable({scripts={}, hooks={}, events={}, lines={}}, {__index=methods})
 if name then _G[name] = frame end; frames[#frames+1] = frame; return frame
end
function methods:CreateFontString() return CreateFrame("FontString") end
function methods:CreateTexture() return CreateFrame("Texture") end
function methods:GetStringHeight() return 450 end
UIParent = CreateFrame("Frame")
ChatFrame1 = CreateFrame("Frame", "ChatFrame1"); ChatFrame1.fading = true
ChatFrame1EditBox = CreateFrame("EditBox", "ChatFrame1EditBox"); ChatFrame1EditBox.arrows = true
function InCombatLockdown() return combat end
function IsShiftKeyDown() return shift end
function GetBuildInfo() return clientVersion, clientBuild, "", clientInterface end
function issecretvalue(value) return type(value) == "table" and value.secret == true end
function print() end
function CanMerchantRepair() return true end
function GetRepairAllCost() return repairCost, true end
function GetMoney() return money end
function RepairAllItems(guild) calls.repair=calls.repair+1; calls.guild=guild end
function GetNumLootItems() return 3 end
function LootSlot(index) calls.loot=calls.loot+1; calls.lastSlot=index end
function AcceptQuest() calls.accept=calls.accept+1 end
function GetNumQuestChoices() return choices end
function GetQuestRequiredMoney() return requiredMoney end
function GetQuestReward(choice) calls.reward=calls.reward+1; calls.rewardChoice=choice end
C_MerchantFrame = { IsSellAllJunkEnabled=function() return true end,
 SellAllJunkItems=function() calls.sell=calls.sell+1 end }
C_AddOns = { IsAddOnLoaded=function(name) return loaded[name] == true end }
C_CVar = { GetCVar=function(name) return cvars[name] end,
 SetCVar=function(name, value) if name ~= refusedCVar then cvars[name]=value end end }
Enum={TooltipDataType={Item=0}}
TooltipDataProcessor={AddTooltipPostCall=function(_, fn) tooltipCallback=fn; calls.hooks=calls.hooks+1 end}
C_Item={GetItemInfo=function()
 if not itemReady then return nil end
 return "Item", "item:123", 2, 45, 1, "Armor", "Plate", itemStack, itemEquip
 end, GetDetailedItemLevelInfo=function() return itemLevel end}
Settings={RegisterCanvasLayoutCategory=function() return {} end, RegisterAddOnCategory=function() end}
function fire(event, ...) F.frame:Trigger("OnEvent", event, ...) end
function hover()
 if not tip then tip=CreateFrame("GameTooltip"); tip.link="item:123" end
 tooltipCallback(tip, {id=123})
end
'''


class SuiteTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCK)
        self.g = self.lua.globals()
        self.g.F = self.lua.table()
        for filename in FILES:
            loader = self.lua.eval("function(source) return assert(loadstring(source)) end")
            loader((ADDON / filename).read_text(encoding="utf-8"))("ForeverSuite", self.g.F)
        for name in re.findall(r'cvarFeature\("[^"\n]+", "[^"\n]+", "([^"\n]+)"', (ADDON / "Modules/Interface.lua").read_text()):
            self.g.cvars[name] = "0" if name not in ("ffxGlow", "cameraBobbing") else "1"

    def runlua(self, code):
        self.lua.execute(code)

    def start(self):
        self.runlua('fire("ADDON_LOADED", "ForeverSuite")')

    def test_default_is_inert_and_ui_loads(self):
        self.start()
        self.runlua('fire("MERCHANT_SHOW"); fire("QUEST_DETAIL"); F:OpenSettings()')
        self.assertEqual(len(self.g.F.order), 36)
        self.assertEqual(self.g.calls.repair, 0)
        self.assertEqual(self.g.calls.sell, 0)
        self.assertEqual(self.g.calls.accept, 0)
        self.assertTrue(self.g.F.window.shown)
        self.assertEqual(len(self.g.F.errors), 0)

    def test_saved_data_validation(self):
        self.runlua('ForeverSuiteDB={enabled={repair="yes", fake=true}, cvars=7, repairCap=-1}')
        self.start()
        self.assertIsNone(self.g.ForeverSuiteDB.enabled.repair)
        self.assertIsNone(self.g.ForeverSuiteDB.enabled.fake)
        self.assertEqual(self.g.ForeverSuiteDB.repairCap, 100000)

    def test_future_schema_is_preserved(self):
        self.runlua('ForeverSuiteDB={schema=99, marker="keep", enabled={repair=true}}')
        self.start()
        self.runlua('SlashCmdList.FOREVERSUITE("reset"); fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.ForeverSuiteDB.schema, 99)
        self.assertEqual(self.g.ForeverSuiteDB.marker, "keep")
        self.assertEqual(self.g.calls.repair, 0)

    def test_wrong_client_is_inert(self):
        self.runlua('clientVersion="12.1.5"; clientInterface=120105')
        self.start()
        self.runlua('F:SetEnabled("repair",true); fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.repair, 0)
        self.assertEqual(self.g.F.features.repair.state, "unsupported client")

    def test_repair_budget_shift_and_combat(self):
        self.start()
        self.runlua('F:SetEnabled("repair",true); fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.repair, 1)
        self.assertFalse(self.g.calls.guild)
        self.runlua('repairCost=100001; fire("MERCHANT_SHOW"); repairCost=1; money=0; fire("MERCHANT_SHOW")')
        self.runlua('money=100; shift=true; fire("MERCHANT_SHOW"); shift=false; combat=true; fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.repair, 1)

    def test_repair_cap_command_validation(self):
        self.start()
        self.runlua('SlashCmdList.FOREVERSUITE("cap 25.5")')
        self.assertEqual(self.g.F.db.repairCap, 255000)
        self.runlua('SlashCmdList.FOREVERSUITE("cap -2"); SlashCmdList.FOREVERSUITE("cap nope")')
        self.assertEqual(self.g.F.db.repairCap, 255000)

    def test_loaded_addon_prevents_automation_and_late_load_stops_it(self):
        self.start()
        self.runlua('loaded.TweaksForever=true; F:SetEnabled("repair",true); fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.repair, 0)
        self.assertIn("conflict", self.g.F.features.repair.state)
        self.runlua('loaded.TweaksForever=false; F:Refresh(); fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.repair, 1)
        self.runlua('loaded.EnhanceQoL=true; fire("ADDON_LOADED","EnhanceQoL"); fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.repair, 1)

    def test_sell_junk_disabled_and_shift(self):
        self.start()
        self.runlua('F:SetEnabled("sellJunk",true); fire("MERCHANT_SHOW"); shift=true; fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.sell, 1)
        self.runlua('shift=false; F:SetEnabled("sellJunk",false); fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.sell, 1)

    def test_fast_loot_respects_client_auto_loot_and_leaves_confirmations(self):
        self.start()
        self.runlua('F:SetEnabled("fastLoot",true); fire("LOOT_OPENED",false); fire("LOOT_OPENED",nil)')
        self.assertEqual(self.g.calls.loot, 0)
        self.runlua('fire("LOOT_OPENED",true)')
        self.assertEqual(self.g.calls.loot, 3)
        self.assertEqual(self.g.calls.lastSlot, 1)

    def test_reward_choice_and_money_are_never_automatic(self):
        self.start()
        self.runlua('F:SetEnabled("turnInQuests",true); choices=1; fire("QUEST_COMPLETE"); choices=2; fire("QUEST_COMPLETE")')
        self.runlua('choices=0; requiredMoney=1; fire("QUEST_COMPLETE")')
        self.assertEqual(self.g.calls.reward, 0)
        self.runlua('requiredMoney=0; fire("QUEST_COMPLETE")')
        self.assertEqual(self.g.calls.reward, 1)
        self.assertEqual(self.g.calls.rewardChoice, 0)

    def test_accept_and_pause(self):
        self.start()
        self.runlua('F:SetEnabled("acceptQuests",true); fire("QUEST_DETAIL"); SlashCmdList.FOREVERSUITE("pause"); fire("QUEST_DETAIL")')
        self.assertEqual(self.g.calls.accept, 1)
        self.runlua('SlashCmdList.FOREVERSUITE("pause"); fire("QUEST_DETAIL")')
        self.assertEqual(self.g.calls.accept, 2)

    def test_cvar_restore_all_features(self):
        self.start()
        for ident, name in re.findall(r'cvarFeature\("([^"\n]+)", "[^"\n]+", "([^"\n]+)"', (ADDON / "Modules/Interface.lua").read_text()):
            with self.subTest(feature=ident):
                original = self.g.cvars[name]
                self.g.F.SetEnabled(self.g.F, ident, True)
                self.assertEqual(self.g.F.features[ident].state, "active")
                self.g.F.SetEnabled(self.g.F, ident, False)
                self.assertEqual(self.g.cvars[name], original)

    def test_cvar_external_change_not_overwritten_on_disable(self):
        self.start()
        self.runlua('F:SetEnabled("noGlow",true); cvars.ffxGlow="external"; F:SetEnabled("noGlow",false)')
        self.assertEqual(self.g.cvars.ffxGlow, "external")

    def test_persisted_cvar_ownership_restores_after_restart(self):
        self.runlua('cvars.ffxGlow="0"; ForeverSuiteDB={enabled={},cvars={noGlow={before="1",applied="0"}}}')
        self.start()
        self.assertEqual(self.g.cvars.ffxGlow, "1")

    def test_missing_and_rejected_cvars(self):
        self.start()
        self.runlua('cvars.ffxGlow=nil; F:SetEnabled("noGlow",true)')
        self.assertEqual(self.g.F.features.noGlow.state, "API unavailable")
        self.runlua('refusedCVar="autoLootDefault"; F:SetEnabled("autoLoot",true)')
        self.assertTrue(self.g.F.features.autoLoot.fault)
        self.assertEqual(self.g.cvars.autoLootDefault, "0")

    def test_combat_defers_cvar_changes(self):
        self.start()
        self.runlua('combat=true; F:SetEnabled("noGlow",true)')
        self.assertEqual(self.g.cvars.ffxGlow, "1")
        self.runlua('combat=false; fire("PLAYER_REGEN_ENABLED")')
        self.assertEqual(self.g.cvars.ffxGlow, "0")
        self.runlua('combat=true; F:SetEnabled("noGlow",false)')
        self.assertEqual(self.g.cvars.ffxGlow, "0")
        self.runlua('combat=false; fire("PLAYER_REGEN_ENABLED")')
        self.assertEqual(self.g.cvars.ffxGlow, "1")

    def test_error_isolation_prevents_repeat_errors(self):
        self.start()
        self.runlua('F:SetEnabled("repair",true); F:SetEnabled("acceptQuests",true); RepairAllItems=function() error("failure") end; fire("MERCHANT_SHOW"); fire("MERCHANT_SHOW"); fire("QUEST_DETAIL")')
        self.assertEqual(len(self.g.F.errors), 1)
        self.assertEqual(self.g.calls.accept, 1)

    def test_unknown_event_quarantines_only_feature(self):
        self.start()
        self.runlua('badEvent="MERCHANT_SHOW"; F:SetEnabled("repair",true)')
        self.assertTrue(self.g.F.features.repair.fault)
        self.assertEqual(len(self.g.F.errors), 1)

    def test_tooltip_shared_hook_duplicate_protection_disable_and_rebuild(self):
        self.start()
        self.runlua('F:SetEnabled("maxStack",true); F:SetEnabled("itemLevel",true); F:SetEnabled("itemID",true); hover(); hover()')
        self.assertEqual(self.g.calls.hooks, 1)
        self.assertEqual(len(self.g.tip.lines), 3)
        self.runlua('tip:Trigger("OnTooltipCleared"); tip.lines={}; F:SetEnabled("maxStack",false); hover()')
        self.assertEqual(len(self.g.tip.lines), 2)
        self.runlua('F:SetEnabled("maxStack",true); hover()')
        self.assertEqual(self.g.calls.hooks, 1)
        self.assertEqual(len(self.g.tip.lines), 3)

    def test_uncached_tooltip_can_fill_when_data_arrives(self):
        self.start()
        self.runlua('F:SetEnabled("maxStack",true); itemReady=false; hover()')
        self.assertEqual(len(self.g.tip.lines), 0)
        self.runlua('itemReady=true; hover()')
        self.assertEqual(len(self.g.tip.lines), 1)

    def test_secret_values_and_combat_tooltips_are_skipped(self):
        self.start()
        self.runlua('F:SetEnabled("maxStack",true); itemStack={secret=true}; hover()')
        self.assertEqual(len(self.g.tip.lines), 0)
        self.runlua('itemStack=20; combat=true; hover()')
        self.assertEqual(len(self.g.tip.lines), 0)
        self.assertEqual(len(self.g.F.errors), 0)

    def test_chat_restore_and_new_window(self):
        self.start()
        self.runlua('F:SetEnabled("chatFade",true); F:SetEnabled("chatArrows",true)')
        self.assertFalse(self.g.ChatFrame1.fading)
        self.assertFalse(self.g.ChatFrame1EditBox.arrows)
        self.runlua('ChatFrame2=CreateFrame("Frame","ChatFrame2"); ChatFrame2.fading=true; CHAT_FRAMES[2]="ChatFrame2"; fire("UPDATE_CHAT_WINDOWS")')
        self.assertFalse(self.g.ChatFrame2.fading)
        self.runlua('F:SetEnabled("chatFade",false); F:SetEnabled("chatArrows",false)')
        self.assertTrue(self.g.ChatFrame1.fading)
        self.assertTrue(self.g.ChatFrame2.fading)
        self.assertTrue(self.g.ChatFrame1EditBox.arrows)

    def test_search_and_copyable_diagnostics(self):
        self.start()
        self.runlua('F.window.search:SetText("repair"); SlashCmdList.FOREVERSUITE("report")')
        self.assertTrue(self.g.F.rows.repair.shown)
        self.assertFalse(self.g.F.rows.maxStack.shown)
        self.assertIn("1.60.1.70532", self.g.F.reportWindow.edit.text)

    def test_categories_global_search_and_setting_transparency(self):
        self.start()
        self.runlua('F.categoryButtons.Camera:Trigger("OnClick")')
        self.assertTrue(self.g.F.rows.noCameraBobbing.shown)
        self.assertFalse(self.g.F.rows.repair.shown)
        self.runlua('F.window.search:SetText("repair")')
        self.assertTrue(self.g.F.rows.repair.shown)
        self.runlua('F:ShowDetails("noGlow")')
        self.assertIn("When switched off", self.g.F.detailsWindow.body.text)
        self.assertIn("ffxGlow = 0", self.g.F.detailsWindow.body.text)
        self.assertIn("Default", self.g.F.detailsWindow.body.text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
