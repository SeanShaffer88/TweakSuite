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

MOCK = r"""
calls = { repair = 0, sell = 0, loot = 0, accept = 0, reward = 0, hooks = 0 }
combat, shift, loaded, cvars, frames = false, false, {}, {}, {}
repairCost, money, choices, requiredMoney = 10000, 1000000, 0, 0
itemStack, itemLevel, itemEquip, itemReady = 20, 50, "INVTYPE_HEAD", true
itemSellPrice = 1234
itemCountValue, bankCountValue = 5, 9
clientVersion, clientBuild, clientInterface = "1.60.1", "70532", 16001
SlashCmdList, UISpecialFrames, CHAT_FRAMES = {}, {}, {"ChatFrame1"}
ChatFontNormal, GameFontNormalSmall = {}, {}
STANDARD_TEXT_FONT = "Fonts/FRIZQT__.TTF"
guids = { target = "Creature-0-1465-0-2105-448-000043F59F", player = "Player-970-0002FD64" }
inventoryLinks = { player = { [1] = "item:1001", [16] = "item:1002" }, target = { [1] = "item:2001" } }
inventoryLevels = { ["item:1001"] = 82, ["item:1002"] = 90, ["item:2001"] = 75 }
tips = {}
local methods = {}
local noops = {"SetSize", "SetFrameStrata", "EnableMouse", "SetAlpha",
 "SetMovable", "SetBackdrop", "SetJustifyH", "SetJustifyV", "RegisterForDrag", "StartMoving", "StopMovingOrSizing",
 "SetAutoFocus", "SetFontObject", "SetMaxLetters", "SetMultiLine", "SetScrollChild",
 "UpdateScrollChildRect", "SetFocus", "ClearFocus", "HighlightText", "ClearAllPoints", "SetTextColor", "SetVerticalScroll",
 "SetBackdropColor", "SetBackdropBorderColor", "SetColorTexture", "SetAllPoints", "SetHighlightTexture"}
for _, name in ipairs(noops) do methods[name] = function() end end
function methods:SetPoint(...) self.points = {...} end
function methods:SetHeight(h) self.height = h end
function methods:SetWidth(w) self.width = w end
function methods:SetFont(_, size, flags) self.fontSize = size; self.fontFlags = flags end
function methods:GetName() return self.name end
function methods:SetClampedToScreen(value) self.clamped = value end
function methods:IsClampedToScreen() return self.clamped ~= false end
function methods:GetPoint() if self.points then return unpack(self.points) end end
function methods:SetScale(value) self.scale = value end
function methods:GetScale() return self.scale or 1 end
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
function methods:IsShown() return self.shown == true end
function methods:IsVisible() return self.shown == true end
function methods:IsEnabled() return self.enabled ~= false end
function methods:Click() self.clicks = (self.clicks or 0) + 1; if self.scripts.OnClick then self.scripts.OnClick(self) end end
function methods:EnableKeyboard(value) self.keyboard = value end
function methods:SetPropagateKeyboardInput(value)
 if combat then error("SetPropagateKeyboardInput is restricted in combat") end
 self.propagate = value
end
function methods:SetText(text) self.text = text; self:Trigger("OnTextChanged") end
function methods:GetText() return self.text or "" end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(value) self.enabled = value end
function methods:GetFont() return "Fonts/FRIZQT__.TTF", self.fontSize or 14, "" end
function methods:GetFading() return self.fading == true end
function methods:SetFading(value) self.fading = value end
function methods:GetAltArrowKeyMode() return self.arrows == true end
function methods:SetAltArrowKeyMode(value) self.arrows = value end
function methods:GetItem() return "Item", self.link end
function methods:GetUnit() return "Unit", self.unit end
function methods:GetID() return self.bag or 0 end
function methods:AddLine(text) table.insert(self.lines, text) end
function CreateFrame(_, name)
 local frame = setmetatable({scripts={}, hooks={}, events={}, lines={}, name=name}, {__index=methods})
 if name then _G[name] = frame end; frames[#frames+1] = frame; return frame
end
function methods:CreateFontString()
 local font = CreateFrame("FontString")
 self.fontstrings = self.fontstrings or {}; table.insert(self.fontstrings, font); return font
end
function methods:CreateTexture() return CreateFrame("Texture") end
function methods:GetStringHeight() return 450 end
UIParent = CreateFrame("Frame")
ChatFrame1 = CreateFrame("Frame", "ChatFrame1"); ChatFrame1.fading = true; ChatFrame1.clamped = true
ChatFrame1EditBox = CreateFrame("EditBox", "ChatFrame1EditBox"); ChatFrame1EditBox.arrows = true
CharacterFrame = CreateFrame("Frame", "CharacterFrame"); CharacterFrame.shown = false
InspectFrame = CreateFrame("Frame", "InspectFrame"); InspectFrame.shown = false; InspectFrame.unit = "target"
local function namedButton(name, shown)
 local button = CreateFrame("Button", name); button.shown = shown == true; return button
end
local dialogButtons = { "QuestFrameAcceptButton", "QuestFrameCompleteButton", "QuestFrameCompleteQuestButton" }
for _, name in ipairs(dialogButtons) do namedButton(name) end
function showButton(name)
 for _, label in ipairs(dialogButtons) do _G[label].shown = (label == name) end
end
for index = 1, 6 do namedButton("QuestInfoItem" .. index) end
function showRewards(count)
 for index = 1, 6 do _G["QuestInfoItem" .. index].shown = index <= count end
end
local slotButtons = { "Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist",
 "Hands", "Finger0", "Finger1", "Trinket0", "Trinket1", "Back", "MainHand", "SecondaryHand", "Ranged", "Tabard" }
for _, slot in ipairs(slotButtons) do
 namedButton("Character" .. slot .. "Slot", true)
 namedButton("Inspect" .. slot .. "Slot", true)
end
NUM_BAG_SLOTS, NUM_BANKBAGSLOTS, NUM_BANKGENERIC_SLOTS = 4, 7, 7
containerLinks, containerSlots = {}, {}
function GetMoneyString(copper) return copper .. "c" end
lootLinks = {}
function GetLootSlotLink(index) return lootLinks[index] end
function GetContainerItemLink(bag, slot) local contents = containerLinks[bag]; return contents and contents[slot] end
function GetContainerNumSlots(bag) return containerSlots[bag] or 0 end
for index = 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
 local frame = CreateFrame("Frame", "ContainerFrame" .. index)
 frame.bag = index - 1; containerSlots[index - 1] = 2
 for slot = 1, 2 do namedButton("ContainerFrame" .. index .. "Item" .. slot, true) end
end
for slot = 1, NUM_BANKGENERIC_SLOTS do namedButton("BankFrameItem" .. slot, true) end
BankFrame = CreateFrame("Frame", "BankFrame")
for _, name in ipairs({ "MerchantFrame", "QuestFrame", "GossipFrame", "MailFrame", "TradeFrame",
    "TabardFrame", "TrainerFrame", "PetStableFrame", "SpellBookFrame", "FriendsFrame",
    "AuctionHouseFrame", "WorldMapFrame" }) do
 local frame = CreateFrame("Frame", name); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end
ObjectiveTrackerFrame = CreateFrame("Frame", "ObjectiveTrackerFrame"); ObjectiveTrackerFrame.shown = true
TimeManagerClockButton = CreateFrame("Button", "TimeManagerClockButton"); TimeManagerClockButton.shown = true
MinimapZoneText = CreateFrame("FontString", "MinimapZoneText"); MinimapZoneText.shown = true
MainMenuBarBackpackButton = CreateFrame("Button", "MainMenuBarBackpackButton"); MainMenuBarBackpackButton.shown = true
LootFrame = CreateFrame("Frame", "LootFrame")
for index = 1, 4 do CreateFrame("Button", "LootButton" .. index) end
for index = 1, 4 do CreateFrame("Frame", "GroupLootFrame" .. index) end
rollLinks = {}
function GetLootRollItemLink(index) return rollLinks[index] end
for _, name in ipairs({ "ChatFrame1ButtonFrame", "ChatFrameMenuButton", "ChatFrame1UpButton", "ChatFrame1DownButton", "ChatFrame1BottomButton" }) do
 local frame = CreateFrame("Button", name); frame.shown = true
end
for _, name in ipairs({ "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap", "BossBanner", "ZoneTextFrame", "SubZoneTextFrame" }) do
 local frame = CreateFrame("Frame", name); frame.shown = true
end
GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip")
ShoppingTooltip1 = CreateFrame("GameTooltip", "ShoppingTooltip1")
ShoppingTooltip2 = CreateFrame("GameTooltip", "ShoppingTooltip2")
FriendsTooltip = CreateFrame("GameTooltip", "FriendsTooltip")
function GetAverageItemLevel() return overallItemLevel or 84, equippedItemLevel or 82, 0 end
durabilities = { [1] = { 80, 100 }, [16] = { 12, 100 } }
function GetInventoryItemDurability(slot)
 local entry = durabilities[slot]
 if entry then return entry[1], entry[2] end
 return nil, nil
end
freeBagSlots = 12
function GetNumFreeBagSlots() return freeBagSlots end
function InCombatLockdown() return combat end
function IsShiftKeyDown() return shift end
function GetBuildInfo() return clientVersion, clientBuild, "", clientInterface end
function issecretvalue(value) return type(value) == "table" and value.secret == true end
prints = {}
function print(message) table.insert(prints, tostring(message)) end
function CanMerchantRepair() return true end
function CanGuildBankRepair() return guildRepairAvailable == true end
guildRepairAvailable = true
function GetRepairAllCost() return repairCost, true end
function GetMoney() return money end
function RepairAllItems(guild) calls.repair=calls.repair+1; calls.guild=guild end
function GetNumLootItems() return 3 end
function LootSlot(index) calls.loot=calls.loot+1; calls.lastSlot=index end
function AcceptQuest() calls.accept=calls.accept+1 end
function GetNumQuestChoices() return choices end
function GetQuestItemInfo() return "Reward", "item:999" end
function GetQuestRequiredMoney() return requiredMoney end
function GetQuestReward(choice) calls.reward=calls.reward+1; calls.rewardChoice=choice end
function UnitGUID(unit) return guids[unit] end
function GetInventoryItemLink(unit, slot) local links = inventoryLinks[unit]; return links and links[slot] end
function GetItemCount(_, includeBank) return includeBank and bankCountValue or itemCountValue end
C_MerchantFrame = { IsSellAllJunkEnabled=function() return true end,
 SellAllJunkItems=function() calls.sell=calls.sell+1 end }
C_AddOns = { IsAddOnLoaded=function(name) return loaded[name] == true end }
C_CVar = { GetCVar=function(name) return cvars[name] end,
 SetCVar=function(name, value) if name ~= refusedCVar then cvars[name]=value end end }
Enum={TooltipDataType={Item=0, Spell=1, Unit=2, Currency=3, Quest=4}}
tooltipCallbacks = {}
TooltipDataProcessor={AddTooltipPostCall=function(dataType, fn)
 tooltipCallbacks[dataType]=fn; calls.hooks=calls.hooks+1
end}
C_Item={GetItemInfo=function()
 if not itemReady then return nil end
 return "Item", "item:123", 2, 45, 1, "Armor", "Plate", itemStack, itemEquip, "", itemSellPrice
 end, GetDetailedItemLevelInfo=function(link) return inventoryLevels[link] or itemLevel end,
 GetItemCount=function(_, includeBank) return includeBank and bankCountValue or itemCountValue end}
Settings={RegisterCanvasLayoutCategory=function() return {} end, RegisterAddOnCategory=function() end}
function fire(event, ...) F.frame:Trigger("OnEvent", event, ...) end
function pressKey(key) ForeverSuiteKeyCatcher:Trigger("OnKeyDown", key) end
function tipFor(kind)
 if not tips[kind] then tips[kind] = CreateFrame("GameTooltip"); tips[kind].lines = {} end
 tips[kind].lines = {}; return tips[kind]
end
function hover()
 if not tip then tip = CreateFrame("GameTooltip"); tip.link = "item:123" end
 tooltipCallbacks[Enum.TooltipDataType.Item](tip, { id = 123 })
end
function hoverSpell(id)
 local frame = tipFor("spell")
 tooltipCallbacks[Enum.TooltipDataType.Spell](frame, { id = id })
 return frame
end
function hoverUnit(unit)
 local frame = tipFor("unit"); frame.unit = unit
 tooltipCallbacks[Enum.TooltipDataType.Unit](frame, {})
 return frame
end
function hoverQuest(id)
 local frame = tipFor("quest")
 tooltipCallbacks[Enum.TooltipDataType.Quest](frame, { id = id })
 return frame
end
function hoverCurrency(data)
 local frame = tipFor("currency")
 tooltipCallbacks[Enum.TooltipDataType.Currency](frame, data)
 return frame
end
"""


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
        self.assertEqual(len(self.g.F.order), 87)
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
        self.runlua('F.window.search:SetText("bank")')
        self.assertTrue(self.g.F.rows.bagItemLevel.shown)
        self.assertFalse(self.g.F.rows.repair.shown)
        self.runlua('F:ShowDetails("noGlow")')
        self.assertIn("When switched off", self.g.F.detailsWindow.body.text)
        self.assertIn("ffxGlow = 0", self.g.F.detailsWindow.body.text)
        self.assertIn("Default", self.g.F.detailsWindow.body.text)


    def test_options_defaults_validation_commands_and_details(self):
        self.start()
        self.assertEqual(self.g.F.GetOption(self.g.F, "dialogAccept", "key"), "SPACE")
        self.assertTrue(self.g.F.GetOption(self.g.F, "dialogAccept", "hint"))
        self.runlua('SlashCmdList.FOREVERSUITE("set dialogAccept key enter")')
        self.assertEqual(self.g.F.GetOption(self.g.F, "dialogAccept", "key"), "ENTER")
        self.runlua('SlashCmdList.FOREVERSUITE("set dialogAccept key NOPE")')
        self.assertEqual(self.g.F.GetOption(self.g.F, "dialogAccept", "key"), "ENTER")
        self.runlua('SlashCmdList.FOREVERSUITE("set dialogAccept hint off")')
        self.assertFalse(self.g.F.GetOption(self.g.F, "dialogAccept", "hint"))
        self.runlua('SlashCmdList.FOREVERSUITE("set charItemLevel size 99")')
        self.assertEqual(self.g.F.GetOption(self.g.F, "charItemLevel", "size"), 11)
        self.runlua('SlashCmdList.FOREVERSUITE("set charItemLevel size 12")')
        self.assertEqual(self.g.F.GetOption(self.g.F, "charItemLevel", "size"), 12)
        self.runlua('F:ShowDetails("dialogAccept")')
        body = self.g.F.detailsWindow.body.text
        self.assertIn("Options", body)
        self.assertIn("Dialog key: Enter", body)
        self.assertIn("Show key hint: Off", body)
        self.assertIn("Choices: Space, Enter, E", body)
        self.runlua('F:ShowDetails("charItemLevel")')
        body = self.g.F.detailsWindow.body.text
        self.assertIn("Text position: Bottom right", body)
        self.assertIn("Text size: 12", body)
        self.assertIn("Range 6 to 24; step 1", body)
        self.assertIn("Choices: Bottom right, Top left, Center", body)

    def test_option_persistence_and_invalid_saved_values(self):
        self.runlua('ForeverSuiteDB={schema=1,enabled={},options={dialogAccept={key="ENTER",hint=false,bogus=1},ghost={x=1},charItemLevel={size=99},itemCount={includeBank="yes"}}}')
        self.start()
        self.assertEqual(self.g.F.GetOption(self.g.F, "dialogAccept", "key"), "ENTER")
        self.assertFalse(self.g.F.GetOption(self.g.F, "dialogAccept", "hint"))
        self.assertIsNone(self.g.ForeverSuiteDB.options.dialogAccept.bogus)
        self.assertIsNone(self.g.ForeverSuiteDB.options.ghost)
        self.assertIsNone(self.g.ForeverSuiteDB.options.charItemLevel)
        self.assertFalse(self.g.F.GetOption(self.g.F, "itemCount", "includeBank"))

    def test_reset_single_feature_clears_options(self):
        self.start()
        self.runlua('F:SetOption("dialogAccept","key","ENTER"); F:SetEnabled("dialogAccept",true)')
        self.runlua('SlashCmdList.FOREVERSUITE("reset dialogAccept")')
        self.assertFalse(self.g.F.db.enabled.dialogAccept)
        self.assertEqual(self.g.F.GetOption(self.g.F, "dialogAccept", "key"), "SPACE")
        self.assertIsNone(self.g.ForeverSuiteDB.options.dialogAccept)

    def test_future_schema_rejects_option_writes(self):
        self.runlua('ForeverSuiteDB={schema=99,options={dialogAccept={key="ENTER"}},marker="keep"}')
        self.start()
        self.assertEqual(self.g.F.GetOption(self.g.F, "dialogAccept", "key"), "SPACE")
        self.runlua('assert(not F:SetOption("dialogAccept","key","E"))')
        self.assertEqual(self.g.ForeverSuiteDB.options.dialogAccept.key, "ENTER")
        self.runlua('SlashCmdList.FOREVERSUITE("set dialogAccept key E")')
        self.assertEqual(self.g.ForeverSuiteDB.options.dialogAccept.key, "ENTER")

    def test_options_panel_cycles_choices_and_steps_numbers(self):
        self.start()
        self.runlua('F:OpenSettings(); F:ShowOptions("dialogAccept")')
        self.assertTrue(self.g.F.optionsWindow.shown)
        self.assertEqual(self.g.F.optionsWindow.cache.dialogAccept.controls[1].widget.text, "Space   >")
        self.runlua('F.optionsWindow.cache.dialogAccept.controls[1].widget:Trigger("OnClick")')
        self.assertEqual(self.g.F.GetOption(self.g.F, "dialogAccept", "key"), "ENTER")
        self.assertEqual(self.g.F.optionsWindow.cache.dialogAccept.controls[1].widget.text, "Enter   >")
        self.runlua('local c=F.optionsWindow.cache.dialogAccept.controls[2].widget; c:SetChecked(false); c:Trigger("OnClick")')
        self.assertFalse(self.g.F.GetOption(self.g.F, "dialogAccept", "hint"))
        self.runlua('F:ShowOptions("charItemLevel")')
        self.runlua('F.optionsWindow.cache.charItemLevel.controls[2].widget:Trigger("OnClick")')
        self.assertEqual(self.g.F.GetOption(self.g.F, "charItemLevel", "size"), 12)
        self.runlua('F:ShowOptions("charItemLevel")')
        self.runlua('F.optionsWindow.cache.charItemLevel.controls[2].widget:Trigger("OnClick")')
        self.assertEqual(self.g.F.GetOption(self.g.F, "charItemLevel", "size"), 13)

    def test_dialog_key_clicks_visible_button_and_propagates(self):
        self.start()
        self.runlua('F:SetEnabled("dialogAccept", true)')
        self.assertTrue(self.g.ForeverSuiteKeyCatcher.shown)
        self.runlua('showButton("QuestFrameAcceptButton"); pressKey("SPACE")')
        self.assertEqual(self.g.QuestFrameAcceptButton.clicks, 1)
        self.assertFalse(self.g.ForeverSuiteKeyCatcher.propagate)
        self.runlua('pressKey("SPACE")')
        self.assertEqual(self.g.QuestFrameAcceptButton.clicks, 2)
        self.runlua('showButton(nil); pressKey("SPACE")')
        self.assertEqual(self.g.QuestFrameAcceptButton.clicks, 2)
        self.assertTrue(self.g.ForeverSuiteKeyCatcher.propagate)

    def test_dialog_key_respects_shift_combat_and_custom_key(self):
        self.start()
        self.runlua('F:SetOption("dialogAccept","key","ENTER"); F:SetEnabled("dialogAccept", true)')
        self.runlua('showButton("QuestFrameAcceptButton"); shift=true; pressKey("ENTER")')
        self.assertIsNone(self.g.QuestFrameAcceptButton.clicks)
        self.runlua('shift=false; pressKey("SPACE")')
        self.assertIsNone(self.g.QuestFrameAcceptButton.clicks)
        self.runlua('pressKey("ENTER")')
        self.assertEqual(self.g.QuestFrameAcceptButton.clicks, 1)
        self.runlua('combat=true; fire("PLAYER_REGEN_DISABLED")')
        self.assertFalse(self.g.ForeverSuiteKeyCatcher.shown)
        self.runlua('pressKey("ENTER")')
        self.assertEqual(self.g.QuestFrameAcceptButton.clicks, 1)
        self.runlua('combat=false; fire("PLAYER_REGEN_ENABLED")')
        self.assertTrue(self.g.ForeverSuiteKeyCatcher.shown)
        self.runlua('pressKey("ENTER")')
        self.assertEqual(self.g.QuestFrameAcceptButton.clicks, 2)

    def test_dialog_accept_never_completes_with_reward_choices(self):
        self.start()
        self.runlua('F:SetEnabled("dialogAccept", true); showButton("QuestFrameCompleteQuestButton"); choices=2; pressKey("SPACE")')
        self.assertIsNone(self.g.QuestFrameCompleteQuestButton.clicks)
        self.runlua('choices=0; pressKey("SPACE")')
        self.assertEqual(self.g.QuestFrameCompleteQuestButton.clicks, 1)

    def test_reward_number_keys_select_without_turning_in(self):
        self.start()
        self.runlua('F:SetEnabled("rewardKeys", true); showRewards(3); choices=3')
        self.assertTrue(self.g.ForeverSuiteKeyCatcher.shown)
        self.runlua('pressKey("2")')
        self.assertEqual(self.g.QuestInfoItem2.clicks, 1)
        self.assertEqual(self.g.calls.reward, 0)
        self.runlua('shift=true; pressKey("1")')
        self.assertIsNone(self.g.QuestInfoItem1.clicks)
        self.runlua('shift=false; combat=true; pressKey("3")')
        self.assertIsNone(self.g.QuestInfoItem3.clicks)
        self.runlua('combat=false; fire("PLAYER_REGEN_ENABLED"); pressKey("3")')
        self.assertEqual(self.g.QuestInfoItem3.clicks, 1)
        self.assertEqual(self.g.calls.reward, 0)

    def test_dialog_key_hint_option_and_disable(self):
        self.start()
        self.runlua('F:SetEnabled("dialogAccept", true); showButton("QuestFrameAcceptButton"); fire("QUEST_DETAIL")')
        hint = self.g.QuestFrameAcceptButton.fontstrings[1]
        self.assertEqual(hint.text, "[Space]")
        self.assertTrue(hint.shown)
        self.runlua('F:SetOption("dialogAccept","hint",false)')
        self.assertFalse(hint.shown)
        self.runlua('F:SetOption("dialogAccept","hint",true); F:SetEnabled("dialogAccept", false)')
        self.assertFalse(hint.shown)

    def test_character_item_level_overlays_follow_options(self):
        self.start()
        self.runlua('F:SetEnabled("charItemLevel", true)')
        head = self.g.CharacterHeadSlot.fontstrings[1]
        self.assertEqual(head.text, "82")
        self.assertEqual(head.fontSize, 11)
        self.assertEqual(head.points[1], "BOTTOMRIGHT")
        self.assertEqual(self.g.CharacterMainHandSlot.fontstrings[1].text, "90")
        self.runlua('F:SetOption("charItemLevel","size",16); F:SetOption("charItemLevel","position","TOPLEFT")')
        self.assertEqual(head.fontSize, 16)
        self.assertEqual(head.points[1], "TOPLEFT")
        self.runlua('inventoryLevels["item:1001"]={secret=true}; fire("PLAYER_EQUIPMENT_CHANGED")')
        self.assertFalse(head.shown)
        self.runlua('inventoryLevels["item:1001"]=82; F:SetEnabled("charItemLevel", false)')
        self.assertFalse(head.shown)
        self.runlua('F:SetEnabled("charItemLevel", true)')
        self.assertTrue(head.shown)
        self.assertEqual(head.text, "82")

    def test_inspect_item_level_overlays_check_guid(self):
        self.start()
        self.runlua('F:SetEnabled("inspectItemLevel", true)')
        head = self.g.InspectHeadSlot.fontstrings[1]
        self.assertEqual(head.text, "75")
        self.runlua('inventoryLevels["item:2001"]=80; fire("INSPECT_READY", guids.player)')
        self.assertEqual(head.text, "75")
        self.runlua('fire("INSPECT_READY", guids.target)')
        self.assertEqual(head.text, "80")

    def test_tooltip_spell_npc_and_currency_ids(self):
        self.start()
        self.runlua('F:SetEnabled("spellID", true); F:SetEnabled("npcID", true); F:SetEnabled("currencyID", true)')
        self.assertEqual(self.g.calls.hooks, 3)
        self.runlua('local f=hoverSpell(133); f:Trigger("OnTooltipCleared"); hoverSpell(133)')
        self.assertEqual(len(self.g.tips.spell.lines), 1)
        self.assertEqual(self.g.tips.spell.lines[1], "Spell ID: 133")
        self.runlua('hoverUnit("target")')
        self.assertEqual(self.g.tips.unit.lines[1], "NPC ID: 448")
        self.runlua('guids.target="Player-970-0002FD64"; hoverUnit("target")')
        self.assertEqual(len(self.g.tips.unit.lines), 0)
        self.runlua('hoverCurrency({id=3008})')
        self.assertEqual(self.g.tips.currency.lines[1], "Currency ID: 3008")
        self.runlua('hoverCurrency({id={secret=true}})')
        self.assertEqual(len(self.g.tips.currency.lines), 0)
        self.runlua('F:SetEnabled("spellID", false); hoverSpell(200)')
        self.assertEqual(len(self.g.tips.spell.lines), 0)
        self.runlua('F:SetEnabled("spellID", true); local f=hoverSpell(201); f:Trigger("OnTooltipCleared"); hoverSpell(201)')
        self.assertEqual(len(self.g.tips.spell.lines), 1)
        self.assertEqual(self.g.calls.hooks, 3)

    def test_tooltip_item_count_and_lazy_hooks(self):
        self.start()
        self.runlua('F:SetEnabled("itemCount", true); hover()')
        self.assertEqual(self.g.calls.hooks, 1)
        self.assertEqual(self.g.tip.lines[1], "Owned: 5 (bags)")
        self.runlua('F:SetOption("itemCount","includeBank",true); tip:Trigger("OnTooltipCleared"); tip.lines={}; hover()')
        self.assertEqual(self.g.tip.lines[1], "Owned: 9 (bags and bank)")
        self.runlua('F:SetEnabled("spellID", true)')
        self.assertEqual(self.g.calls.hooks, 2)
        self.runlua('F:SetEnabled("itemCount", false); tip:Trigger("OnTooltipCleared"); tip.lines={}; hover()')
        self.assertEqual(len(self.g.tip.lines), 0)


    def test_saved_options_apply_when_feature_enables(self):
        self.runlua('ForeverSuiteDB={schema=1,enabled={charItemLevel=true},options={charItemLevel={size=14}}}')
        self.start()
        self.assertEqual(self.g.CharacterHeadSlot.fontstrings[1].fontSize, 14)
        self.assertEqual(self.g.CharacterHeadSlot.fontstrings[1].text, "82")

    def test_report_lists_changed_options(self):
        self.start()
        self.runlua('F:SetOption("dialogAccept","key","E"); SlashCmdList.FOREVERSUITE("report")')
        self.assertIn("dialogAccept: off  [key=E]", self.g.F.reportWindow.edit.text)


    def test_every_feature_uses_a_listed_category(self):
        self.start()
        listed = {}
        for index in range(1, len(self.g.F.categories) + 1):
            listed[self.g.F.categories[index]] = True
        for index in range(1, len(self.g.F.order) + 1):
            ident = self.g.F.order[index]
            category = self.g.F.features[ident].category
            self.assertIn(category, listed, ident)


    def test_option_type_validation_rejects_bad_values(self):
        self.start()
        self.runlua('assert(not F:SetOption("dialogAccept","key",nil))')
        self.runlua('assert(not F:SetOption("charItemLevel","size",12.5))')
        self.runlua('assert(not F:SetOption("charItemLevel","size",0/0))')
        self.runlua('assert(not F:SetOption("charItemLevel","size",math.huge))')
        self.runlua('assert(not F:SetOption("itemCount","includeBank","true"))')
        self.runlua('assert(not F:SetOption("nope","key","SPACE"))')
        self.runlua('assert(F:GetOption("nope","key") == nil)')
        self.assertIsNone(self.g.ForeverSuiteDB.options.charItemLevel)
        self.assertIsNone(self.g.ForeverSuiteDB.options.itemCount)
        self.runlua('assert(F:SetOption("dialogAccept","key","SPACE"))')


    def test_option_refresh_is_deferred_out_of_combat(self):
        self.start()
        self.runlua('F:SetEnabled("charItemLevel", true)')
        self.assertEqual(self.g.CharacterHeadSlot.fontstrings[1].fontSize, 11)
        self.runlua('combat=true; F:SetOption("charItemLevel","size",16)')
        self.assertEqual(self.g.CharacterHeadSlot.fontstrings[1].fontSize, 11)
        self.runlua('combat=false; fire("PLAYER_REGEN_ENABLED")')
        self.assertEqual(self.g.CharacterHeadSlot.fontstrings[1].fontSize, 16)


    def test_option_command_feedback(self):
        self.start()
        self.runlua('SlashCmdList.FOREVERSUITE("options dialogAccept")')
        self.assertEqual(len(self.g.prints), 2)
        self.assertIn("Dialog key", self.g.prints[1])
        self.assertIn("Show key hint", self.g.prints[2])
        self.runlua('SlashCmdList.FOREVERSUITE("set charItemLevel size 99")')
        self.assertIn("Option not changed", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("set dialogAccept key nope")')
        self.assertIn("choices: Space, Enter, E", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("options fastLoot")')
        self.assertIn("has no options", self.g.prints[len(self.g.prints)])


    def test_bag_item_levels_and_bank_option(self):
        self.start()
        self.runlua('containerLinks[1]={[1]="item:1001",[2]="item:2001"};'
                    'containerLinks[5]={[1]="item:1002"};'
                    'containerLinks[-1]={[1]="item:1002",[2]="item:2001"}')
        self.runlua('F:SetEnabled("bagItemLevel", true)')
        bagSlot = self.g.ContainerFrame2Item1.fontstrings[1]
        self.assertEqual(bagSlot.text, "82")
        self.assertEqual(bagSlot.fontSize, 11)
        self.assertEqual(bagSlot.points[1], "TOPLEFT")
        self.assertTrue(bagSlot.shown)
        self.assertIsNone(self.g.ContainerFrame6Item1.fontstrings)
        self.runlua('F:SetOption("bagItemLevel","includeBank",true)')
        bankSlot = self.g.ContainerFrame6Item1.fontstrings[1]
        self.assertEqual(bankSlot.text, "90")
        self.assertTrue(bankSlot.shown)
        self.assertEqual(self.g.BankFrameItem2.fontstrings[1].text, "75")
        self.runlua('containerLinks[1]=nil; fire("BAG_UPDATE", 1)')
        self.assertFalse(bagSlot.shown)
        self.runlua('containerLinks[1]={[1]="item:1001"}; fire("BAG_UPDATE_DELAYED")')
        self.assertTrue(bagSlot.shown)
        self.runlua('F:SetOption("bagItemLevel","position","CENTER"); F:SetOption("bagItemLevel","size",18)')
        self.assertEqual(bagSlot.points[1], "CENTER")
        self.assertEqual(bagSlot.fontSize, 18)
        self.runlua('combat=true; F:SetEnabled("bagItemLevel", false)')
        self.assertTrue(bagSlot.shown)
        self.runlua('combat=false; fire("PLAYER_REGEN_ENABLED")')
        self.assertFalse(bagSlot.shown)
        self.runlua('F:SetEnabled("bagItemLevel", true)')
        self.assertTrue(bagSlot.shown)
        self.runlua('F:SetEnabled("bagItemLevel", false)')
        self.assertFalse(bagSlot.shown)
        self.assertFalse(self.g.BankFrameItem2.fontstrings[1].shown)
        self.runlua('ContainerFrame2:Show(); BankFrame:Show()')
        self.assertFalse(bagSlot.shown)
        self.assertFalse(self.g.BankFrameItem2.fontstrings[1].shown)


    def test_vendor_sell_price_in_tooltips(self):
        self.start()
        self.runlua('F:SetEnabled("sellPrice", true); hover(); tip:Trigger("OnTooltipCleared"); hover()')
        self.assertEqual(self.g.tip.lines[1], "Sells for: 1234c")
        self.runlua('itemSellPrice=0; tip.lines={}; tip:Trigger("OnTooltipCleared"); hover()')
        self.assertEqual(len(self.g.tip.lines), 0)
        self.runlua('itemSellPrice={secret=true}; tip.lines={}; tip:Trigger("OnTooltipCleared"); hover()')
        self.assertEqual(len(self.g.tip.lines), 0)
        self.runlua('itemSellPrice=1234; F:SetEnabled("sellPrice", false); tip.lines={}; tip:Trigger("OnTooltipCleared"); hover()')
        self.assertEqual(len(self.g.tip.lines), 0)

    def test_stage_two_tweak_categories_and_disable(self):
        self.start()
        self.runlua('F:SetEnabled("chatBubbles", true); F:SetEnabled("cooldownCount", true)')
        self.assertEqual(self.g.F.features["chatBubbles"].category, "Chat")
        self.assertEqual(self.g.F.features["cooldownCount"].category, "Interface")
        self.assertEqual(self.g.F.features["cooldownCount"].state, "active")
        self.assertEqual(self.g.cvars.countdownForCooldowns, "1")
        self.runlua('F:SetEnabled("cooldownCount", false)')
        self.assertEqual(self.g.cvars.countdownForCooldowns, "0")


    def test_move_blizzard_windows_requires_shift_and_saves_layout(self):
        self.start()
        self.runlua('F:SetEnabled("moveWindows", true)')
        self.runlua('MerchantFrame:Trigger("OnDragStart")')
        self.runlua('MerchantFrame:Trigger("OnDragStop")')
        self.assertIsNone(self.g.ForeverSuiteDB.layouts)
        self.runlua('shift=true; MerchantFrame:Trigger("OnDragStart"); '
                    'MerchantFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100); '
                    'shift=false; MerchantFrame:Trigger("OnDragStop")')
        stored = self.g.ForeverSuiteDB.layouts.MerchantFrame
        self.assertEqual(stored.point, "TOPLEFT")
        self.assertEqual(stored.x, 100)
        self.assertEqual(stored.y, -100)
        self.runlua('MerchantFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0); MerchantFrame:Hide(); MerchantFrame:Show()')
        self.assertEqual(self.g.MerchantFrame.points[1], "TOPLEFT")
        self.assertEqual(self.g.MerchantFrame.points[3], 100)
        self.runlua('F:SetEnabled("moveWindows", false)')
        self.assertEqual(self.g.MerchantFrame.points[1], "CENTER")
        self.assertEqual(self.g.MerchantFrame.points[3], 0)

    def test_move_windows_combat_and_remember_off(self):
        self.start()
        self.runlua('F:SetEnabled("moveWindows", true); shift=true; combat=true')
        self.runlua('MerchantFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -50); MerchantFrame:Trigger("OnDragStart")')
        self.runlua('combat=false; MerchantFrame:Trigger("OnDragStop")')
        self.assertIsNone(self.g.ForeverSuiteDB.layouts)
        self.runlua('F:SetOption("moveWindows", "remember", false); '
                    'shift=true; MerchantFrame:Trigger("OnDragStart"); '
                    'MerchantFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 25, -25); '
                    'MerchantFrame:Trigger("OnDragStop")')
        self.assertIsNone(self.g.ForeverSuiteDB.layouts)

    def test_average_item_level_on_character_panel(self):
        self.start()
        self.runlua('F:SetEnabled("averageItemLevel", true)')
        text = self.g.CharacterFrame.fontstrings[1]
        self.assertEqual(text.text, "Item level 82")
        self.assertTrue(text.shown)
        self.runlua('F:SetOption("averageItemLevel", "showOverall", true)')
        self.assertEqual(text.text, "Item level 82 (overall 84)")
        self.runlua('equippedItemLevel=0; overallItemLevel=0; fire("PLAYER_EQUIPMENT_CHANGED")')
        self.assertFalse(text.shown)
        self.runlua('equippedItemLevel=82; overallItemLevel=84; fire("PLAYER_EQUIPMENT_CHANGED")')
        self.assertTrue(text.shown)
        self.runlua('F:SetEnabled("averageItemLevel", false)')
        self.assertFalse(text.shown)

    def test_hide_objective_tracker_hides_and_restores(self):
        self.start()
        self.runlua('F:SetEnabled("hideObjectiveTracker", true)')
        self.assertFalse(self.g.ObjectiveTrackerFrame.shown)
        self.runlua('ObjectiveTrackerFrame:Show()')
        self.assertFalse(self.g.ObjectiveTrackerFrame.shown)
        self.runlua('fire("QUEST_LOG_UPDATE")')
        self.assertFalse(self.g.ObjectiveTrackerFrame.shown)
        self.runlua('F:SetEnabled("hideObjectiveTracker", false)')
        self.assertTrue(self.g.ObjectiveTrackerFrame.shown)

    def test_tooltip_scale_option_combat_and_restore(self):
        self.start()
        self.runlua('F:SetEnabled("tooltipScale", true)')
        self.assertEqual(self.g.GameTooltip.scale, 1)
        self.runlua('F:SetOption("tooltipScale", "scale", 150)')
        self.assertEqual(self.g.GameTooltip.scale, 1.5)
        self.assertEqual(self.g.ShoppingTooltip1.scale, 1.5)
        self.runlua('combat=true; F:SetOption("tooltipScale", "scale", 120)')
        self.assertEqual(self.g.GameTooltip.scale, 1.5)
        self.runlua('combat=false; fire("PLAYER_REGEN_ENABLED")')
        self.assertEqual(self.g.GameTooltip.scale, 1.2)
        self.runlua('F:SetEnabled("tooltipScale", false)')
        self.assertEqual(self.g.GameTooltip.scale, 1)


    def test_repair_funding_choices_and_cap(self):
        self.start()
        self.runlua('F:SetEnabled("repair", true); money=0; fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.repair, 0)
        self.runlua('F:SetOption("repair", "funding", "guild"); fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.repair, 1)
        self.assertTrue(self.g.calls.guild)
        self.runlua('F:SetOption("repair", "funding", "both"); money=1000000; fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.repair, 2)
        self.assertFalse(self.g.calls.guild)
        self.runlua('money=0; fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.repair, 3)
        self.assertTrue(self.g.calls.guild)
        self.runlua('guildRepairAvailable=false; money=0; fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.repair, 3)
        self.runlua('guildRepairAvailable=true; F:SetOption("repair", "funding", "guild"); repairCost=100001; fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.repair, 3)

    def test_chat_font_size_applies_and_restores(self):
        self.start()
        self.runlua('F:SetEnabled("chatFont", true)')
        self.assertEqual(self.g.ChatFrame1.fontSize, 14)
        self.runlua('F:SetOption("chatFont", "size", 20)')
        self.assertEqual(self.g.ChatFrame1.fontSize, 20)
        self.runlua('F:SetEnabled("chatFont", false)')
        self.assertEqual(self.g.ChatFrame1.fontSize, 14)

    def test_camera_zoom_option_drives_cvar(self):
        self.start()
        self.runlua('F:SetEnabled("cameraZoom", true)')
        self.assertEqual(self.g.cvars.cameraDistanceMaxZoomFactor, "2")
        self.runlua('F:SetOption("cameraZoom", "distance", 3.5)')
        self.assertEqual(self.g.cvars.cameraDistanceMaxZoomFactor, "3.5")
        self.runlua('F:SetOption("cameraZoom", "distance", 2.0500000000000003)')
        self.assertEqual(self.g.F.GetOption(self.g.F, "cameraZoom", "distance"), 2.05)
        self.runlua('F:SetOption("cameraZoom", "distance", 3.5)')
        self.runlua('F:SetEnabled("cameraZoom", false)')
        self.assertEqual(self.g.cvars.cameraDistanceMaxZoomFactor, "0")

    def test_combat_text_cvars(self):
        self.start()
        self.runlua('F:SetEnabled("fctDamage", true); F:SetEnabled("fctHealing", true)')
        self.assertEqual(self.g.cvars.floatingCombatTextCombatDamage, "0")
        self.assertEqual(self.g.cvars.floatingCombatTextCombatHealing, "0")
        self.runlua('F:SetEnabled("fctDamage", false)')
        self.assertEqual(self.g.cvars.floatingCombatTextCombatDamage, "0")


    def test_hidden_client_frames_restore(self):
        self.start()
        self.runlua('F:SetEnabled("hideGryphons", true); F:SetEnabled("hideBossBanner", true);'
                    'F:SetEnabled("hideZoneText", true)')
        self.assertFalse(self.g.MainMenuBarLeftEndCap.shown)
        self.assertFalse(self.g.MainMenuBarRightEndCap.shown)
        self.assertFalse(self.g.BossBanner.shown)
        self.assertFalse(self.g.ZoneTextFrame.shown)
        self.assertFalse(self.g.SubZoneTextFrame.shown)
        self.runlua('MainMenuBarLeftEndCap:Show(); fire("PLAYER_ENTERING_WORLD")')
        self.assertFalse(self.g.MainMenuBarLeftEndCap.shown)
        self.runlua('F:SetEnabled("hideChatButtons", true)')
        self.assertFalse(self.g.ChatFrameMenuButton.shown)
        self.assertFalse(self.g.ChatFrame1UpButton.shown)
        self.runlua('F:SetEnabled("hideBossBanner", false); F:SetEnabled("hideZoneText", false)')
        self.runlua('BossBanner:Show(); ZoneTextFrame:Show()')
        self.assertTrue(self.g.BossBanner.shown)
        self.assertTrue(self.g.ZoneTextFrame.shown)
        self.runlua('F:SetEnabled("hideChatButtons", false)')
        self.assertTrue(self.g.ChatFrameMenuButton.shown)
        self.assertTrue(self.g.ChatFrame1UpButton.shown)
        self.runlua('F:SetEnabled("hideMinimapClock", true); F:SetEnabled("hideMinimapZone", true)')
        self.assertFalse(self.g.TimeManagerClockButton.shown)
        self.assertFalse(self.g.MinimapZoneText.shown)
        self.runlua('F:SetEnabled("hideMinimapClock", false); F:SetEnabled("hideMinimapZone", false)')
        self.assertTrue(self.g.TimeManagerClockButton.shown)
        self.assertTrue(self.g.MinimapZoneText.shown)
        self.runlua('F:SetEnabled("hideGryphons", false)')
        self.assertTrue(self.g.MainMenuBarLeftEndCap.shown)
        self.assertTrue(self.g.MainMenuBarRightEndCap.shown)

    def test_new_chat_and_minimap_cvars(self):
        self.start()
        self.runlua('F:SetEnabled("rotateMinimap", true); F:SetEnabled("chatTimestamps", true)')
        self.assertEqual(self.g.cvars.rotateMinimap, "1")
        self.assertEqual(self.g.cvars.showTimestamps, "1")
        self.assertEqual(self.g.F.features.chatTimestamps.category, "Chat")
        self.runlua('F:SetEnabled("rotateMinimap", false); F:SetEnabled("chatTimestamps", false)')
        self.assertEqual(self.g.cvars.rotateMinimap, "0")
        self.assertEqual(self.g.cvars.showTimestamps, "0")


    def test_durability_percentages_and_bag_space(self):
        self.start()
        self.runlua('F:SetEnabled("slotDurability", true)')
        head = self.g.CharacterHeadSlot.fontstrings[1]
        self.assertEqual(head.text, "80%")
        self.assertTrue(head.shown)
        main = self.g.CharacterMainHandSlot.fontstrings[1]
        self.assertEqual(main.text, "12%")
        self.runlua('durabilities[1]=nil; fire("UPDATE_INVENTORY_DURABILITY")')
        self.assertFalse(head.shown)
        self.runlua('durabilities[1]={ 40, 100 }; fire("UPDATE_INVENTORY_DURABILITY")')
        self.assertEqual(head.text, "40%")
        self.runlua('F:SetEnabled("slotDurability", false)')
        self.assertFalse(head.shown)
        self.runlua('F:SetEnabled("bagSpace", true)')
        label = self.g.MainMenuBarBackpackButton.fontstrings[1]
        self.assertEqual(label.text, "12")
        self.runlua('freeBagSlots=3; fire("BAG_UPDATE")')
        self.assertEqual(label.text, "3")
        self.runlua('F:SetEnabled("bagSpace", false)')
        self.assertFalse(label.shown)


    def test_quest_id_tooltip_and_loot_item_levels(self):
        self.start()
        self.runlua('F:SetEnabled("questID", true); hoverQuest(4242)')
        self.assertEqual(self.g.tips.quest.lines[1], "Quest ID: 4242")
        self.runlua('F:SetEnabled("lootItemLevel", true)')
        self.runlua('lootLinks[1]="item:2001"; lootLinks[2]="item:1001"; lootLinks[3]="item:1002"; fire("LOOT_OPENED")')
        self.assertEqual(self.g.LootButton1.fontstrings[1].text, "75")
        self.assertEqual(self.g.LootButton2.fontstrings[1].text, "82")
        self.assertEqual(self.g.LootButton3.fontstrings[1].text, "90")
        self.assertIsNone(self.g.LootButton4.fontstrings)
        self.runlua('lootLinks[1]=nil; fire("LOOT_SLOT_CLEARED")')
        self.assertFalse(self.g.LootButton1.fontstrings[1].shown)
        self.runlua('F:SetEnabled("lootItemLevel", false)')
        self.assertFalse(self.g.LootButton2.fontstrings[1].shown)

    def test_chat_unclamp_and_nameplate_distance(self):
        self.start()
        self.runlua('F:SetEnabled("chatUnclamp", true)')
        self.assertFalse(self.g.ChatFrame1.clamped)
        self.runlua('F:SetEnabled("chatUnclamp", false)')
        self.assertTrue(self.g.ChatFrame1.clamped)
        self.runlua('F:SetEnabled("autoTrackFaction", true); F:SetEnabled("nameplateDistance", true)')
        self.assertEqual(self.g.cvars.autoTrackReputation, "1")
        self.assertEqual(self.g.cvars.nameplateMaxDistance, "40")
        self.assertEqual(self.g.F.features.nameplateDistance.category, "Nameplates")
        self.runlua('F:SetOption("nameplateDistance", "distance", 55)')
        self.assertEqual(self.g.cvars.nameplateMaxDistance, "55")
        self.runlua('F:SetEnabled("nameplateDistance", false)')
        self.assertEqual(self.g.cvars.nameplateMaxDistance, "0")

    def test_windows_command_lists_and_resets_layouts(self):
        self.start()
        self.runlua('F:SetEnabled("moveWindows", true); shift=true;'
                    'MerchantFrame:Trigger("OnDragStart");'
                    'MerchantFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100);'
                    'MerchantFrame:Trigger("OnDragStop")')
        self.assertIsNotNone(self.g.ForeverSuiteDB.layouts)
        self.runlua('SlashCmdList.FOREVERSUITE("windows")')
        self.assertIn("1 saved window position", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("windows reset")')
        self.assertIsNone(self.g.ForeverSuiteDB.layouts)
        self.assertEqual(self.g.MerchantFrame.points[1], "CENTER")


    def test_group_loot_roll_item_levels(self):
        self.start()
        self.runlua('F:SetEnabled("rollItemLevel", true)')
        self.runlua('rollLinks[2]="item:2001"; fire("START_LOOT_ROLL", 2)')
        self.assertEqual(self.g.GroupLootFrame2.fontstrings[1].text, "75")
        self.assertTrue(self.g.GroupLootFrame2.fontstrings[1].shown)
        self.runlua('rollLinks[2]=nil; fire("START_LOOT_ROLL", 2)')
        self.assertFalse(self.g.GroupLootFrame2.fontstrings[1].shown)
        self.runlua('rollLinks[3]="item:1002"; fire("START_LOOT_ROLL", 3); F:SetEnabled("rollItemLevel", false)')
        self.assertFalse(self.g.GroupLootFrame3.fontstrings[1].shown)

    def test_death_effect_cvar_and_reset_options_command(self):
        self.start()
        self.runlua('F:SetEnabled("noDeathEffect", true)')
        self.assertEqual(self.g.cvars.ffxDeath, "0")
        self.runlua('F:SetOption("charItemLevel", "size", 18); F:SetOption("dialogAccept", "key", "ENTER")')
        self.runlua('SlashCmdList.FOREVERSUITE("resetoptions")')
        self.assertEqual(len(self.g.ForeverSuiteDB.options), 0)
        self.assertEqual(self.g.F.GetOption(self.g.F, "charItemLevel", "size"), 11)
        self.assertEqual(self.g.F.GetOption(self.g.F, "dialogAccept", "key"), "SPACE")
        self.assertIn("reset to their defaults", self.g.prints[len(self.g.prints)])


    def test_nameplate_scale_and_sell_price_stack_option(self):
        self.start()
        self.runlua('F:SetEnabled("nameplateScale", true)')
        self.assertEqual(self.g.cvars.nameplateGlobalScale, "1")
        self.runlua('F:SetOption("nameplateScale", "scale", 150)')
        self.assertEqual(self.g.cvars.nameplateGlobalScale, "1.5")
        self.runlua('F:SetEnabled("nameplateScale", false)')
        self.assertEqual(self.g.cvars.nameplateGlobalScale, "0")
        self.runlua('F:SetEnabled("sellPrice", true); F:SetOption("sellPrice", "stackTotal", true);'
                    'hover(); tip.lines={}; tip:Trigger("OnTooltipCleared"); hover()')
        self.assertEqual(self.g.tip.lines[1], "Stack sells for: 24680c")
        self.runlua('itemStack=1; tip.lines={}; tip:Trigger("OnTooltipCleared"); hover()')
        self.assertEqual(self.g.tip.lines[1], "Sells for: 1234c")

    def test_category_counts_and_layout_sanitation(self):
        self.start()
        self.assertEqual(self.g.F.categoryButtons.Interface.label.text, "Interface (33)")
        self.assertEqual(self.g.F.categoryButtons.Home.label.text, "Home")
        self.runlua('F:SetEnabled("moveWindows", true); shift=true;'
                    'MerchantFrame:Trigger("OnDragStart");'
                    'MerchantFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -10);'
                    'MerchantFrame:Trigger("OnDragStop")')
        self.assertIsNotNone(self.g.ForeverSuiteDB.layouts)


    def test_saved_layout_sanitation(self):
        self.runlua('ForeverSuiteDB={schema=1, layouts={Bad={point=5},'
                    'Bogus={point="CENTER", x=0/0, y=0}, Far={point="CENTER", x=50000, y=0},'
                    'MerchantFrame={point="CENTER", relativePoint="CENTER", x=10, y=-10}}}')
        self.start()
        self.assertIsNone(self.g.ForeverSuiteDB.layouts.Bad)
        self.assertIsNone(self.g.ForeverSuiteDB.layouts.Bogus)
        self.assertIsNone(self.g.ForeverSuiteDB.layouts.Far)
        self.assertEqual(self.g.ForeverSuiteDB.layouts.MerchantFrame.x, 10)
        self.runlua('F:SetEnabled("moveWindows", true); MerchantFrame:Show()')
        self.assertEqual(self.g.MerchantFrame.points[1], "CENTER")
        self.assertEqual(self.g.MerchantFrame.points[3], 10)


if __name__ == "__main__":
    unittest.main(verbosity=2)
