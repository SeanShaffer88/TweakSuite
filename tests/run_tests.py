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
guids = { target = "Creature-0-1465-0-2105-448-000043F59F", player = "Player-970-0002FD64",
 npc = "Creature-0-1465-0-2105-12345-000043F59F" }
inventoryLinks = { player = { [1] = "item:1001", [16] = "item:1002" }, target = { [1] = "item:2001" } }
inventoryLevels = { ["item:1001"] = 82, ["item:1002"] = 90, ["item:2001"] = 75 }
tips = {}
local methods = {}
local noops = {"SetFrameStrata", "EnableMouse",
 "SetMovable", "SetBackdrop", "SetJustifyH", "SetJustifyV", "RegisterForDrag", "StartMoving", "StopMovingOrSizing",
 "SetAutoFocus", "SetFontObject", "SetMaxLetters", "SetMultiLine", "SetScrollChild",
 "UpdateScrollChildRect", "SetFocus", "ClearFocus", "HighlightText", "ClearAllPoints", "SetTextColor", "SetVerticalScroll",
 "SetBackdropColor", "SetBackdropBorderColor", "SetColorTexture", "SetAllPoints", "SetHighlightTexture"}
for _, name in ipairs(noops) do methods[name] = function() end end
function methods:SetPoint(...) self.points = {...} end
function methods:SetHeight(h) self.height = h end
function methods:SetSize(w, h) self.width = w; self.height = h end
function methods:SetWidth(w) self.width = w end
function methods:SetFont(_, size, flags) self.fontSize = size; self.fontFlags = flags end
function methods:GetName() return self.name end
function methods:SetClampedToScreen(value) self.clamped = value end
function methods:IsClampedToScreen() return self.clamped ~= false end
function methods:GetPoint() if self.points then return unpack(self.points) end end
function methods:SetScale(value) self.scale = value end
function methods:SetAlpha(value) self.alpha = value end
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
function methods:GetWidth() return self.width or 0 end
function methods:GetHeight() return self.height or 0 end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(value) self.enabled = value end
function methods:GetFont() return "Fonts/FRIZQT__.TTF", self.fontSize or 14, "" end
function methods:SetMaxLines(value) self.maxLines = value end
function methods:GetMaxLines() return self.maxLines or 128 end
function methods:GetFading() return self.fading == true end
function methods:SetFading(value) self.fading = value end
function methods:GetAltArrowKeyMode() return self.arrows == true end
function methods:SetAltArrowKeyMode(value) self.arrows = value end
function methods:GetItem() return "Item", self.link end
function methods:GetUnit() return "Unit", self.unit end
function methods:GetID() return self.bag or 0 end
function methods:AddLine(text) table.insert(self.lines, text) end
function CreateFrame(kind, name, parent)
 local frame = setmetatable({scripts={}, hooks={}, events={}, lines={}, name=name, kind=kind}, {__index=methods})
 if parent then parent.children = parent.children or {}; table.insert(parent.children, frame) end
 if name then _G[name] = frame end; frames[#frames+1] = frame; return frame
end
function methods:GetObjectType() return self.kind or "Frame" end
function methods:GetChildren() return unpack(self.children or {}) end
function methods:SetParent(parent) self.parent = parent; if parent then parent.children = parent.children or {}; table.insert(parent.children, self) end end
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
sold = {}
function UseContainerItem(bag, slot)
 local contents = containerLinks[bag]
 local link = contents and contents[slot]
 table.insert(sold, { bag = bag, slot = slot, link = link })
 if contents then contents[slot] = nil end
 calls.sold = (calls.sold or 0) + 1
end
C_Container = { GetContainerItemLink = GetContainerItemLink, GetContainerNumSlots = GetContainerNumSlots,
 UseContainerItem = UseContainerItem }
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
questDaily, questRepeatable = false, false
function IsDailyQuest() return questDaily end
function GetQuestID() return questID end
function GetTitleText() return questTitle end
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return completedQuests[id] == true end }
completedQuests = {}
questID, questTitle = 1001, "A Test Quest"
function IsRepeatableQuest() return questRepeatable end
playedSounds = {}
function PlaySound(id) table.insert(playedSounds, id) end
SOUNDKIT = { TELL_MESSAGE = 3081 }
gossipOptions = {}
function GetNumGossipOptions() return #gossipOptions end
function GetGossipOptions()
 local flattened = {}
 for _, entry in ipairs(gossipOptions) do
  flattened[#flattened+1] = entry.text; flattened[#flattened+1] = entry.kind
 end
 return unpack(flattened)
end
function SelectGossipOption(index) calls.gossip = (calls.gossip or 0) + 1; calls.gossipIndex = index end
friends, guildmates = {}, {}
function UnitIsFriend(_, name) return friends[name] == true end
function UnitIsInMyGuild(name) return guildmates[name] == true end
function DeclineGroup() calls.declines = (calls.declines or 0) + 1 end
socialLog = { acceptGroup = 0, duel = 0, acceptRes = 0, repop = 0, invite = 0, summon = 0, knocked = 0 }
function AcceptGroup() socialLog.acceptGroup = socialLog.acceptGroup + 1 end
function DeclineDuel() socialLog.duel = socialLog.duel + 1 end
function AcceptResurrect() socialLog.acceptRes = socialLog.acceptRes + 1 end
function RepopMe() socialLog.repop = socialLog.repop + 1 end
function InviteUnit(name) socialLog.invite = socialLog.invite + 1; socialLog.invitedName = name end
function knockout(name) socialLog.knocked = socialLog.knocked + 1 end
summonLeft, summonSummoner = 0, nil
C_SummonInfo = { ConfirmSummon = function() socialLog.summon = socialLog.summon + 1 end,
 GetSummonConfirmTimeLeft = function() return summonLeft end,
 GetSummonConfirmSummoner = function() return summonSummoner end }
deadUnits, unitLevels = {}, { player = 40, target = 30 }
function UnitIsDeadOrGhost(unit) return deadUnits[unit] == true end
function UnitLevel(unit) return unitLevels[unit] or 0 end
instanceKind = "none"
function IsInInstance() return true, instanceKind end
questLevelValue, questGreenRange = 10, 5
function GetQuestLevel() return questLevelValue end
function GetQuestGreenRange() return questGreenRange end
questLogEntries = {}
function GetNumQuestLogEntries() return #questLogEntries, #questLogEntries end
function GetQuestLogTitle(index)
 local entry = questLogEntries[index]
 if not entry then return nil end
 return entry.title, entry.level, entry.tag, nil, entry.header, false, entry.complete, entry.frequency, entry.id
end
C_QuestLog = { IsQuestFlaggedCompleted = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted,
 GetDistanceSqToQuest = function(id) return questDistances[id] end }
questDistances = {}
function GetQuestDifficultyColor(level) return { red = 1, green = 0.5, blue = 0.25 } end
function TargetByName(name) targetedName = name; return name ~= "Nobody" end
targetedName = nil
function UnitClassification(unit) return unitClassifications[unit] end
unitClassifications = {}
function GetTradePlayerItemLink(index) return tradeLinks[index] end
tradeLinks = {}
tsRecipes, tsSelection, tsReagents = {}, 0, {}
function GetTradeSkillSelectionIndex() return tsSelection end
function GetTradeSkillInfo(index) return tsRecipes[index] end
function GetTradeSkillNumReagents(index) return #(tsReagents[index] or {}) end
function GetTradeSkillReagentInfo(index, r) local entry = (tsReagents[index] or {})[r]; if entry then return entry[1], nil, entry[2] end end
function UnitName(unit) if unit == "player" then return "Tester" end return unit end
unitClasses, unitHealths = {}, {}
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
function UnitClass(unit)
 local entry = unitClasses[unit]
 if entry then return entry[1], entry[2] end
 return nil, nil
end
function UnitHealth(unit) local entry = unitHealths[unit]; return entry and entry[1] or 0 end
function UnitHealthMax(unit) local entry = unitHealths[unit]; return entry and entry[2] or 0 end
socketStats = {}
function GetItemStats(link) return socketStats[link] end
function GetRealmName() return "TestRealm" end
GossipFrame = CreateFrame("Frame", "GossipFrame")
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame"); WorldMapFrame.width = 1000; WorldMapFrame.height = 700
WorldMapFrame.left = 100; WorldMapFrame.top = 800; WorldMapFrame.cursor = { 500, 450 }
function GetCursorPosition() return WorldMapFrame.cursor[1], WorldMapFrame.cursor[2] end
function methods:GetLeft() return self.left or 0 end
function methods:GetTop() return self.top or 0 end
function methods:GetEffectiveScale() return self.effectiveScale or 1 end
function GetRealZoneText() return zoneName end
function GetZoneText() return zoneName end
function GetSubZoneText() return "" end
zoneName = "Elwynn Forest"
taxiNodes = {}
function NumTaxiNodes() return #taxiNodes end
function GetTaxiNodeName(index) return taxiNodes[index] end
takenTaxi, castSpells = {}, {}
function TakeTaxiNode(index) table.insert(takenTaxi, index) end
function CastSpellByID(id) table.insert(castSpells, id) end
equippedByCalls = {}
function EquipItemByName(link) table.insert(equippedByCalls, link) end
userWaypoint = nil
function SetUserWaypoint(point) userWaypoint = point end
function ClearUserWaypoint() userWaypoint = nil end
unitOnTaxi = false
function UnitOnTaxi() return unitOnTaxi end
C_Map = { GetBestMapForUnit = function() return 1429 end,
 SetUserWaypoint = function(point) userWaypoint = point end,
 GetUserWaypoint = function() return userWaypoint end,
 ClearUserWaypoint = function() userWaypoint = nil end }
MicroMenuContainer = CreateFrame("Frame", "MicroMenuContainer"); MicroMenuContainer.shown = true
MainMenuBar = CreateFrame("Frame", "MainMenuBar"); MainMenuBar.alpha = 1
function methods:IsMouseOver() return self.mouseOver == true end
MinimapCluster = CreateFrame("Frame", "MinimapCluster"); MinimapCluster.scale = 1
Minimap = CreateFrame("Frame", "Minimap")
GameTooltipSetBackdrop = {}
function methods:SetBackdropBorderColor(r, g, b, a) self.border = { r, g, b, a } end
function methods:GetBackdropBorderColor() local b = self.border or { 0, 0, 0, 1 }; return b[1], b[2], b[3], b[4] end
UnitXPValue, UnitXPMaxValue, now = 0, 1000, 0
function UnitXP() return UnitXPValue end
function UnitXPMax() return UnitXPMaxValue end
function GetTime() return now end
ChatFrame1.text = ""
function methods:GetText() return self.text or "" end
function methods:GetWidth() return self.width or 0 end
function methods:GetHeight() return self.height or 0 end
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
itemMeta = {}
local function metaFor(link)
 local meta = itemMeta[link]
 if meta then
  return meta.name or "Test Item", link, meta.quality or 1, meta.itemLevel or 1, 1,
   "Armor", meta.subType or "Plate", meta.stack or 1, meta.equipLoc or "", nil, meta.sellPrice or 0,
   meta.classID == nil and 4 or meta.classID, 0, meta.bindType or 2, 0, 0, false
 end
 return "Item", "item:123", 2, 45, 1, "Armor", "Plate", itemStack, itemEquip, "", itemSellPrice
end
C_Item={GetItemInfo=function(link)
 if not itemReady then return nil end
 return metaFor(link)
end,
 GetItemInfoLegacy=function()
 if not itemReady then return nil end
 return "Item", "item:123", 2, 45, 1, "Armor", "Plate", itemStack, itemEquip, "", itemSellPrice
 end, GetDetailedItemLevelInfo=function(link) return inventoryLevels[link] or itemLevel end,
 GetItemCount=function(_, includeBank) return includeBank and bankCountValue or itemCountValue end}
Settings={RegisterCanvasLayoutCategory=function() return {} end, RegisterAddOnCategory=function() end}
function fire(event, ...) F.frame:Trigger("OnEvent", event, ...) end
chatFilters = {}
function ChatFrame_AddMessageEventFilter(event, filter) chatFilters[event] = filter end
function ApplyChatFilter(event, ...)
 local filter = chatFilters[event]
 if not filter then return true, ... end
 local hide, t, n, rest = filter(ChatFrame1, event, ...)
 return hide, t, n
end
classForGUID = {}
function GetPlayerInfoByGUID(guid) return nil, classForGUID[guid] end
joinedChannels, leftChannels, sentMessages = {}, {}, {}
function JoinChannelByName(name) table.insert(joinedChannels, name) end
function LeaveChannelByName(name) table.insert(leftChannels, name) end
function SendChatMessage(text, chatType, language, target)
 table.insert(sentMessages, { text = text, kind = chatType, target = target })
end
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
        self.assertEqual(len(self.g.F.order), 172)
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
        self.assertEqual(self.g.F.categoryButtons.Interface.label.text, "Interface (46)")
        self.assertEqual(self.g.F.categoryButtons.Home.label.text, "Home")
        self.assertEqual(self.g.F.categoryButtons.Windows.label.text, "Windows (7)")
        self.assertEqual(self.g.F.categoryButtons.Dialogs.label.text, "Dialogs (7)")
        self.assertEqual(self.g.F.categoryButtons.Tooltips.label.text, "Tooltips (21)")
        self.assertEqual(self.g.F.categoryButtons.Chat.label.text, "Chat (19)")
        self.assertEqual(self.g.F.categoryButtons.Maps.label.text, "Maps (9)")
        self.assertEqual(self.g.F.categoryButtons.Quests.label.text, "Quests (9)")
        self.assertEqual(self.g.F.categoryButtons.Inventory.label.text, "Inventory (18)")
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


    def test_upgrade_comparison_against_equipped_item(self):
        self.start()
        self.runlua('F:SetEnabled("upgradeHint", true); inventoryLevels["item:123"]=100; hover()')
        self.assertEqual(self.g.tip.lines[1], "Upgrade: +18 item levels")
        self.runlua('inventoryLevels["item:123"]=82; tip.lines={}; tip:Trigger("OnTooltipCleared"); hover()')
        self.assertEqual(self.g.tip.lines[1], "Same item level as equipped")
        self.runlua('inventoryLevels["item:123"]=50; tip.lines={}; tip:Trigger("OnTooltipCleared"); hover()')
        self.assertEqual(self.g.tip.lines[1], "Downgrade: -32 item levels")
        self.runlua('F:SetOption("upgradeHint", "showDowngrades", false); tip.lines={}; tip:Trigger("OnTooltipCleared"); hover()')
        self.assertEqual(len(self.g.tip.lines), 0)
        self.runlua('F:SetEnabled("upgradeHint", false); inventoryLevels["item:123"]=100; tip.lines={}; tip:Trigger("OnTooltipCleared"); hover()')
        self.assertEqual(len(self.g.tip.lines), 0)

    def test_whisper_sound_and_combat_option(self):
        self.start()
        self.runlua('F:SetEnabled("whisperSound", true); fire("CHAT_MSG_WHISPER", "hello", "Friend")')
        self.assertEqual(len(self.g.playedSounds), 1)
        self.assertEqual(self.g.playedSounds[1], 3081)
        self.runlua('F:SetOption("whisperSound", "muteInCombat", true); combat=true; fire("CHAT_MSG_WHISPER", "hi", "Friend")')
        self.assertEqual(len(self.g.playedSounds), 1)
        self.runlua('combat=false; fire("CHAT_MSG_WHISPER", "hi", "Friend")')
        self.assertEqual(len(self.g.playedSounds), 2)
        self.runlua('F:SetEnabled("whisperSound", false); fire("CHAT_MSG_WHISPER", "hi", "Friend")')
        self.assertEqual(len(self.g.playedSounds), 2)

    def test_quest_accept_filters(self):
        self.start()
        self.runlua('F:SetEnabled("acceptQuests", true); F:SetOption("acceptQuests", "skipDailies", true);'
                    'questDaily=true; fire("QUEST_DETAIL")')
        self.assertEqual(self.g.calls.accept, 0)
        self.runlua('questDaily=false; fire("QUEST_DETAIL")')
        self.assertEqual(self.g.calls.accept, 1)
        self.runlua('F:SetOption("acceptQuests", "skipRepeatable", true); questRepeatable=true; fire("QUEST_DETAIL")')
        self.assertEqual(self.g.calls.accept, 1)
        self.runlua('questRepeatable=false; shift=true; fire("QUEST_DETAIL"); shift=false')
        self.assertEqual(self.g.calls.accept, 1)

    def test_repair_reporting_option(self):
        self.start()
        self.runlua('F:SetEnabled("repair", true); fire("MERCHANT_SHOW")')
        self.assertIn("Repaired for 10000c.", self.g.prints[len(self.g.prints)])
        before = len(self.g.prints)
        self.runlua('F:SetOption("repair", "report", false); fire("MERCHANT_SHOW")')
        self.assertEqual(len(self.g.prints), before)
        self.assertEqual(self.g.calls.repair, 2)
        self.runlua('F:SetOption("repair", "report", true); money=0; fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.repair, 2)

    def test_new_interface_cvars(self):
        self.start()
        self.runlua('F:SetEnabled("thousandsSeparators", true); F:SetEnabled("autoPushSpells", true);'
                    'F:SetEnabled("friendlyNameplates", true)')
        self.assertEqual(self.g.cvars.breakUpLargeNumbers, "1")
        self.assertEqual(self.g.cvars.autoPushSpellToActionBar, "1")
        self.assertEqual(self.g.cvars.nameplateShowFriends, "1")
        self.assertEqual(self.g.F.features.friendlyNameplates.category, "Nameplates")
        self.runlua('F:SetEnabled("friendlyNameplates", false)')
        self.assertEqual(self.g.cvars.nameplateShowFriends, "0")


    def test_numbered_gossip_selection_excludes_money(self):
        self.start()
        self.runlua('gossipOptions={{text="Read the note", kind="gossip"},'
                    '{text="Buy a clue", kind="money"}, {text="Fight", kind="option"}};'
                    'F:SetEnabled("gossipKeys", true); GossipFrame:Show(); fire("GOSSIP_SHOW")')
        self.runlua('pressKey("1")')
        self.assertEqual(self.g.calls.gossip, 1)
        self.assertEqual(self.g.calls.gossipIndex, 1)
        self.runlua('pressKey("2")')
        self.assertEqual(self.g.calls.gossip, 1)
        self.runlua('pressKey("3")')
        self.assertEqual(self.g.calls.gossip, 2)
        self.assertEqual(self.g.calls.gossipIndex, 3)
        self.runlua('shift=true; pressKey("1"); shift=false')
        self.assertEqual(self.g.calls.gossip, 2)
        self.runlua('combat=true; pressKey("1")')
        self.assertEqual(self.g.calls.gossip, 2)
        self.runlua('combat=false; F:SetEnabled("gossipKeys", false); pressKey("1")')
        self.assertEqual(self.g.calls.gossip, 2)
        self.runlua('F:SetEnabled("gossipKeys", true); GossipFrame:Hide(); pressKey("1")')
        self.assertEqual(self.g.calls.gossip, 2)

    def test_stranger_invite_filter(self):
        self.start()
        self.runlua('F:SetEnabled("blockStrangerInvites", true); fire("PARTY_INVITE_REQUEST", "Stranger")')
        self.assertEqual(self.g.calls.declines, 1)
        self.assertIn("Declined a group invite from Stranger.", self.g.prints[len(self.g.prints)])
        self.runlua('friends.Stranger=true; fire("PARTY_INVITE_REQUEST", "Stranger")')
        self.assertEqual(self.g.calls.declines, 1)
        self.runlua('friends.Stranger=nil; guildmates.Stranger=true; fire("PARTY_INVITE_REQUEST", "Stranger")')
        self.assertEqual(self.g.calls.declines, 1)
        self.runlua('F:SetOption("blockStrangerInvites", "allowGuild", false); fire("PARTY_INVITE_REQUEST", "Stranger")')
        self.assertEqual(self.g.calls.declines, 2)
        before = len(self.g.prints)
        self.runlua('F:SetOption("blockStrangerInvites", "announce", false); fire("PARTY_INVITE_REQUEST", "Stranger")')
        self.assertEqual(self.g.calls.declines, 3)
        self.assertEqual(len(self.g.prints), before)
        self.runlua('shift=true; fire("PARTY_INVITE_REQUEST", "Stranger"); shift=false')
        self.assertEqual(self.g.calls.declines, 3)

    def test_chat_history_length_and_restore(self):
        self.start()
        self.runlua('F:SetEnabled("chatHistory", true)')
        self.assertEqual(self.g.ChatFrame1.maxLines, 512)
        self.runlua('F:SetOption("chatHistory", "lines", 1024)')
        self.assertEqual(self.g.ChatFrame1.maxLines, 1024)
        self.runlua('F:SetEnabled("chatHistory", false)')
        self.assertEqual(self.g.ChatFrame1.maxLines, 128)

    def test_gold_tracker_records_and_reports(self):
        self.start()
        self.runlua('F:SetEnabled("goldTracker", true)')
        self.assertEqual(self.g.ForeverSuiteDB.gold["TestRealm - Tester"], 1000000)
        self.runlua('money=2500000; fire("PLAYER_MONEY")')
        self.assertEqual(self.g.ForeverSuiteDB.gold["TestRealm - Tester"], 2500000)
        self.runlua('SlashCmdList.FOREVERSUITE("gold")')
        self.assertIn("TestRealm - Tester: 2500000c", self.g.prints[len(self.g.prints) - 1])
        self.assertIn("Total across 1 character(s)", self.g.prints[len(self.g.prints)])
        self.runlua('F:SetEnabled("goldTracker", false); money=1; fire("PLAYER_MONEY")')
        self.assertEqual(self.g.ForeverSuiteDB.gold["TestRealm - Tester"], 2500000)

    def test_gold_saved_data_sanitation(self):
        self.runlua('ForeverSuiteDB={schema=1, gold={["A - B"]=5, [7]=1, ["Bad"]=0/0, ["Huge"]=1e15}}')
        self.start()
        self.assertEqual(self.g.ForeverSuiteDB.gold["A - B"], 5)
        self.assertIsNone(self.g.ForeverSuiteDB.gold["Bad"])
        self.assertIsNone(self.g.ForeverSuiteDB.gold["Huge"])
        self.assertIsNone(self.g.ForeverSuiteDB.gold[7])

    def test_reset_single_window_layout(self):
        self.start()
        self.runlua('F:SetEnabled("moveWindows", true); shift=true;'
                    'MerchantFrame:Trigger("OnDragStart");'
                    'MerchantFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100);'
                    'MerchantFrame:Trigger("OnDragStop");'
                    'QuestFrame:Trigger("OnDragStart");'
                    'QuestFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -50);'
                    'QuestFrame:Trigger("OnDragStop")')
        self.assertIsNotNone(self.g.ForeverSuiteDB.layouts.MerchantFrame)
        self.assertIsNotNone(self.g.ForeverSuiteDB.layouts.QuestFrame)
        self.runlua('SlashCmdList.FOREVERSUITE("windows reset MerchantFrame")')
        self.assertIsNone(self.g.ForeverSuiteDB.layouts.MerchantFrame)
        self.assertIsNotNone(self.g.ForeverSuiteDB.layouts.QuestFrame)
        self.assertEqual(self.g.MerchantFrame.points[1], "CENTER")
        self.assertEqual(self.g.QuestFrame.points[4], 50)
        self.runlua('SlashCmdList.FOREVERSUITE("windows reset NoSuchFrame")')
        self.assertIn("Unknown window", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("windows list")')
        self.assertIn("MerchantFrame", self.g.prints[len(self.g.prints)])


    def test_help_command_and_last_category_persistence(self):
        self.runlua('ForeverSuiteDB={schema=1, lastCategory="Tooltips"}')
        self.start()
        self.runlua('F:OpenSettings()')
        self.assertEqual(self.lua.eval('F.selectedCategory'), "Tooltips")
        self.runlua('F.categoryButtons.Camera:Trigger("OnClick")')
        self.assertEqual(self.g.ForeverSuiteDB.lastCategory, "Camera")
        before = len(self.g.prints)
        self.runlua('SlashCmdList.FOREVERSUITE("help")')
        self.assertGreater(len(self.g.prints), before)
        self.assertIn("Commands:", self.g.prints[before + 1])
        texts = " ".join([self.g.prints[i] for i in range(before + 1, len(self.g.prints) + 1)])
        self.assertIn("/fs gold", texts)
        self.assertIn("/fs windows", texts)


    def test_merchant_rules_preview_filters_and_batch(self):
        self.start()
        self.runlua('itemMeta["item:3001"]={name="Gray Trinket", quality=0, itemLevel=5, sellPrice=10}'
                    ';itemMeta["item:3002"]={name="Green Sword", quality=2, itemLevel=80, sellPrice=200}'
                    ';itemMeta["item:3003"]={name="Quest Thing", quality=1, itemLevel=10, sellPrice=50, classID=12}'
                    ';itemMeta["item:3004"]={name="White Cloth", quality=1, itemLevel=20, sellPrice=5}'
                    ';itemMeta["item:3005"]={name="Recipe: Thing", quality=1, itemLevel=1, sellPrice=5, classID=9}'
                    ';containerLinks[1]={[1]="item:3001",[2]="item:3002",[3]="item:3003",[4]="item:3004"}'
                    ';containerLinks[2]={[1]="item:3005"};containerSlots[1]=4;containerSlots[2]=1')
        self.runlua('F:SetEnabled("merchantRules", true); fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.sold or 0, 0)
        self.assertIsNotNone(self.g.F.previewRows)
        self.assertEqual(self.g.F.previewRows[1].link, "item:3001")
        self.assertEqual(len(self.g.F.previewRows), 1)
        self.runlua('F.previewRows=nil; F:SetOption("merchantRules", "preview", false);'
                    'F:SetOption("merchantRules", "quality", "Common"); fire("MERCHANT_SHOW")')
        links = [row.link for row in (self.g.sold[i] for i in range(1, len(self.g.sold) + 1))]
        self.assertIn("item:3001", links)
        self.assertIn("item:3004", links)
        self.assertNotIn("item:3002", links)
        self.assertNotIn("item:3003", links)
        self.assertNotIn("item:3005", links)
        self.assertEqual(len(self.g.sold), 2)

    def test_merchant_never_sell_list_and_batch_cap(self):
        self.start()
        self.runlua('itemMeta["item:4001"]={name="Keep Me", quality=0, itemLevel=1, sellPrice=5}'
                    ';itemMeta["item:4002"]={name="Sell Me", quality=0, itemLevel=1, sellPrice=5}'
                    ';containerLinks[1]={[1]="item:4001",[2]="item:4002"};containerSlots[1]=2')
        self.runlua('F:SetEnabled("merchantRules", true); F:SetOption("merchantRules", "preview", false)')
        self.runlua('SlashCmdList.FOREVERSUITE("neversell add 4001")')
        self.assertIn("Added 4001", self.g.prints[len(self.g.prints)])
        self.runlua('fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.sold, 1)
        self.assertEqual(self.g.sold[1].link, "item:4002")
        self.runlua('containerLinks[1]={[1]="item:4001"}; fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.sold, 1)
        self.runlua('SlashCmdList.FOREVERSUITE("neversell remove 4001"); containerLinks[1]={[1]="item:4001"}; fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.sold, 2)
        self.runlua('containerLinks[1]={[1]="item:4001",[2]="item:4002"}; F:SetOption("merchantRules", "batchSize", 1); fire("MERCHANT_SHOW")')
        self.assertEqual(self.g.calls.sold, 3)

    def test_quest_exceptions_and_completed_filter(self):
        self.start()
        self.runlua('F:SetEnabled("acceptQuests", true); SlashCmdList.FOREVERSUITE("except accept A Test Quest");'
                    'fire("QUEST_DETAIL")')
        self.assertEqual(self.g.calls.accept, 0)
        self.runlua('questTitle="Another Quest"; fire("QUEST_DETAIL")')
        self.assertEqual(self.g.calls.accept, 1)
        self.runlua('F:SetOption("acceptQuests", "skipCompleted", true); completedQuests[1001]=true; fire("QUEST_DETAIL")')
        self.assertEqual(self.g.calls.accept, 1)
        self.runlua('completedQuests[1001]=nil; fire("QUEST_DETAIL")')
        self.assertEqual(self.g.calls.accept, 2)
        self.runlua('questTitle="A Test Quest"; SlashCmdList.FOREVERSUITE("except accept A Test Quest")')
        self.runlua('F:SetEnabled("turnInQuests", true); SlashCmdList.FOREVERSUITE("except turnin Another Quest");'
                    'fire("QUEST_COMPLETE")')
        self.assertEqual(self.g.calls.reward, 1)
        self.runlua('questTitle="Another Quest"; fire("QUEST_COMPLETE")')
        self.assertEqual(self.g.calls.reward, 1)

    def test_single_option_gossip_rule(self):
        self.start()
        self.runlua('F:SetEnabled("gossipKeys", true); gossipOptions={{text="Only Option", kind="gossip"}};'
                    'GossipFrame:Show(); fire("GOSSIP_SHOW")')
        self.assertEqual(self.g.calls.gossip, None)
        self.runlua('F:SetOption("gossipKeys", "autoSingle", true); fire("GOSSIP_SHOW")')
        self.assertEqual(self.g.calls.gossip, 1)
        self.runlua('gossipOptions={{text="Buy", kind="money"}}; fire("GOSSIP_SHOW")')
        self.assertEqual(self.g.calls.gossip, 1)
        self.runlua('gossipOptions={{text="A", kind="gossip"},{text="B", kind="gossip"}}; fire("GOSSIP_SHOW")')
        self.assertEqual(self.g.calls.gossip, 1)

    def test_junk_marking_command_and_saved_sanitation(self):
        self.start()
        self.runlua('SlashCmdList.FOREVERSUITE("junk 5001")')
        self.assertTrue(self.g.ForeverSuiteDB.junk[5001])
        self.runlua('SlashCmdList.FOREVERSUITE("unjunk 5001")')
        self.assertIsNone(self.g.ForeverSuiteDB.junk)
        self.runlua('ForeverSuiteDB.junk={[5001]=true, ["bad"]=true, [0]=true}; ForeverSuiteDB.neverSell={"x", 7, -1};'
                    'F.db=nil; F:Initialize()')
        self.assertTrue(self.g.ForeverSuiteDB.junk[5001])
        self.assertIsNone(self.g.ForeverSuiteDB.junk["bad"])
        self.assertEqual(len(self.g.ForeverSuiteDB.neverSell), 1)
        self.assertEqual(self.g.ForeverSuiteDB.neverSell[1], 7)


    def test_bind_type_and_tooltip_border(self):
        self.start()
        self.runlua('itemMeta["item:123"]={name="Blade", quality=2, itemLevel=40, bindType=2, sellPrice=10};'
                    'F:SetEnabled("bindType", true); hover(); tip:Trigger("OnTooltipCleared"); hover()')
        self.assertIn("Binding: Binds when equipped", [self.g.tip.lines[i] for i in range(1, len(self.g.tip.lines) + 1)])
        self.runlua('F:SetEnabled("tooltipBorder", true)')
        self.assertEqual(self.g.GameTooltip.border[1], 1)
        self.assertEqual(self.g.GameTooltip.border[2], 0.82)
        self.runlua('F:SetOption("tooltipBorder", "color", "blue")')
        self.assertEqual(self.g.GameTooltip.border[3], 1)
        self.runlua('F:SetEnabled("tooltipBorder", false)')
        self.assertNotEqual(self.g.GameTooltip.border[3], 1)

    def test_hide_tooltips_in_combat(self):
        self.start()
        self.runlua('F:SetEnabled("tooltipHideCombat", true); GameTooltip:Show()')
        self.assertTrue(self.g.GameTooltip.shown)
        self.runlua('combat=true; fire("PLAYER_REGEN_DISABLED")')
        self.assertFalse(self.g.GameTooltip.shown)
        self.runlua('combat=false; GameTooltip:Show(); fire("PLAYER_REGEN_DISABLED")')
        self.assertTrue(self.g.GameTooltip.shown)

    def test_micro_menu_minimap_and_action_bar_fade(self):
        self.start()
        self.runlua('F:SetEnabled("hideMicroMenu", true)')
        self.assertFalse(self.g.MicroMenuContainer.shown)
        self.runlua('F:SetEnabled("hideMicroMenu", false)')
        self.assertTrue(self.g.MicroMenuContainer.shown)
        self.runlua('F:SetEnabled("minimapScale", true)')
        self.assertEqual(self.g.MinimapCluster.scale, 1)
        self.runlua('F:SetOption("minimapScale", "scale", 80)')
        self.assertEqual(self.g.MinimapCluster.scale, 0.8)
        self.runlua('F:SetEnabled("minimapScale", false)')
        self.assertEqual(self.g.MinimapCluster.scale, 1)
        self.runlua('F:SetEnabled("actionBarFade", true)')
        self.assertEqual(self.g.MainMenuBar.alpha, 0.25)
        self.runlua('MainMenuBar.mouseOver=true; MainMenuBar:Trigger("OnEnter")')
        self.assertEqual(self.g.MainMenuBar.alpha, 1)
        self.runlua('MainMenuBar.mouseOver=false; MainMenuBar:Trigger("OnLeave")')
        self.assertEqual(self.g.MainMenuBar.alpha, 0.25)
        self.runlua('F:SetEnabled("actionBarFade", false)')
        self.assertEqual(self.g.MainMenuBar.alpha, 1)

    def test_copy_chat_and_watched_buttons(self):
        self.start()
        self.runlua('F:SetEnabled("copyChat", true); fire("CHAT_MSG_SAY", "hello there", "Tester")')
        self.runlua('SlashCmdList.FOREVERSUITE("copy")')
        self.assertIn("hello there", self.g.F.reportWindow.edit.text)
        self.runlua('SlashCmdList.FOREVERSUITE("watch QuestFrameAcceptButton")')
        self.assertIn("Also watching button", self.g.prints[len(self.g.prints)])
        self.runlua('F:SetEnabled("dialogAccept", true); showButton("QuestFrameAcceptButton"); fire("QUEST_DETAIL")')
        self.runlua('pressKey("SPACE")')
        self.assertEqual(self.g.QuestFrameAcceptButton.clicks, 1)
        self.runlua('SlashCmdList.FOREVERSUITE("watch clear")')
        self.assertIsNone(self.g.ForeverSuiteDB.watch)

    def test_chat_edit_position_and_sticky_buttons(self):
        self.start()
        self.runlua('F:SetEnabled("chatEditPosition", true); F:SetOption("chatEditPosition", "where", "top")')
        self.assertEqual(self.g.ChatFrame1EditBox.points[1], "BOTTOMRIGHT")
        self.assertEqual(self.g.ChatFrame1EditBox.points[3], "TOPRIGHT")
        self.runlua('F:SetEnabled("chatEditPosition", false)')
        self.assertEqual(self.g.ChatFrame1EditBox.points[1], "BOTTOMRIGHT")
        self.assertEqual(self.g.ChatFrame1EditBox.points[3], "BOTTOMRIGHT")
        self.runlua('ChatFrame1ButtonFrame.alpha=0; F:SetEnabled("stickyChatButtons", true)')
        self.assertEqual(self.g.ChatFrame1ButtonFrame.alpha, 1)

    def test_bag_search_and_xp_rate(self):
        self.start()
        self.runlua('itemMeta["item:6001"]={name="Silver Ore", quality=1, itemLevel=10, sellPrice=5};'
                    'containerLinks[1]={[1]="item:6001"}; containerSlots[1]=2')
        self.runlua('SlashCmdList.FOREVERSUITE("bag silver")')
        self.assertIn("Enable Bag item search", self.g.prints[len(self.g.prints)])
        self.runlua('F:SetEnabled("bagSearch", true); SlashCmdList.FOREVERSUITE("bag silver")')
        self.assertIn("Silver Ore", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("bag zzz")')
        self.assertIn("No bag item matches", self.g.prints[len(self.g.prints)])
        self.runlua('F:SetEnabled("xpTracker", true)')
        self.runlua('UnitXPValue=100; now=100; fire("PLAYER_XP_UPDATE")')
        self.runlua('UnitXPValue=600; now=1060; fire("PLAYER_XP_UPDATE")')
        self.runlua('SlashCmdList.FOREVERSUITE("xp")')
        self.assertIn("XP per hour", self.g.prints[len(self.g.prints)])


    def test_profiles_create_switch_and_restore(self):
        self.start()
        self.runlua('F:SetEnabled("profiles", true)')
        self.runlua('F:SetEnabled("repair", true); F:SetOption("charItemLevel", "size", 18);'
                    'SlashCmdList.FOREVERSUITE("profile new Raiding")')
        self.assertIn("Created and saved profile Raiding", self.g.prints[len(self.g.prints)])
        self.runlua('F:SetEnabled("repair", false); F:SetOption("charItemLevel", "size", 12)')
        self.runlua('SlashCmdList.FOREVERSUITE("profile use Raiding")')
        self.assertTrue(self.g.F.features.repair.state == "active")
        self.assertEqual(self.g.F.GetOption(self.g.F, "charItemLevel", "size"), 18)
        self.runlua('SlashCmdList.FOREVERSUITE("profile list")')
        self.assertIn("Raiding", self.g.prints[len(self.g.prints) - 1] + self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("profile delete Default")')
        self.assertIn("Deleted profile Default", self.g.prints[len(self.g.prints)])

    def test_profile_export_import_validation(self):
        self.start()
        self.runlua('F:SetEnabled("profiles", true); F:SetEnabled("repair", true);'
                    'F:SetOption("charItemLevel", "size", 18); F:SetOption("dialogAccept", "key", "ENTER");'
                    'SlashCmdList.FOREVERSUITE("profile save")')
        self.runlua('F.exported = F:ExportProfile()')
        exported = self.lua.eval('F.exported')
        self.assertTrue(exported.startswith("FS1|"))
        self.assertIn("E=repair", exported)
        self.runlua('imported = F:ImportProfile("FS1|E=repair,ghostFeature;O=charItemLevel.size=99;'
                    'O=dialogAccept.key=NOPE;O=unknownFeature.size=5", "Bad Import")')
        self.assertEqual(self.lua.eval('select(1, imported)'), True)
        self.runlua('F:UseProfile("Bad Import")')
        self.assertEqual(self.g.F.GetOption(self.g.F, "charItemLevel", "size"), 11)
        self.assertEqual(self.g.F.GetOption(self.g.F, "dialogAccept", "key"), "SPACE")
        self.assertTrue(self.g.F.features.repair.state == "active")
        self.runlua('imported2 = F:ImportProfile("not-a-profile")')
        self.assertEqual(self.lua.eval('select(1, imported2)'), False)

    def test_profile_scope_and_saved_sanitation(self):
        self.start()
        self.runlua('F:SetEnabled("profiles", true); SlashCmdList.FOREVERSUITE("profile scope character")')
        self.assertEqual(self.g.ForeverSuiteDB.profiles.scope, "character")
        self.assertEqual(self.g.F.GetOption(self.g.F, "profiles", "scope"), "character")
        self.runlua('ForeverSuiteDB.profiles={data={Good={enabled={repair=true}}, [""]={}},'
                    'order={"Good","", "Missing"}, active="Nope", scope="weird"}; F.db=nil; F:Initialize()')
        profiles = self.g.ForeverSuiteDB.profiles
        self.assertEqual(list(profiles.order.values()), ["Good"])
        self.assertEqual(profiles.active, "Good")
        self.assertEqual(profiles.scope, "global")

    def test_cvar_browser_info_validation_history(self):
        self.start()
        self.runlua('F:SetEnabled("cvarBrowser", true)')
        self.runlua('SlashCmdList.FOREVERSUITE("cvar ffxGlow")')
        self.assertIn("ffxGlow = 1", self.g.prints[len(self.g.prints) - 2])
        self.runlua('SlashCmdList.FOREVERSUITE("cvar ffxGlow off")')
        self.assertEqual(self.g.cvars.ffxGlow, "0")
        self.runlua('SlashCmdList.FOREVERSUITE("cvar cameraDistanceMaxZoomFactor 9")')
        self.assertIn("Not changed", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("cvar cameraDistanceMaxZoomFactor 3.5")')
        self.assertEqual(self.g.cvars.cameraDistanceMaxZoomFactor, "3.5")
        self.runlua('SlashCmdList.FOREVERSUITE("cvar history")')
        self.assertIn("cameraDistanceMaxZoomFactor", self.g.prints[len(self.g.prints)])
        before = len(self.g.prints)
        self.runlua('SlashCmdList.FOREVERSUITE("cvar list nameplate")')
        window = " ".join(self.g.prints[i] for i in range(before + 1, len(self.g.prints) + 1))
        self.assertIn("CVar(s) match", window)
        self.assertIn("nameplateMaxDistance", window)
        self.runlua('SlashCmdList.FOREVERSUITE("cvar madeUpCvar on")')
        self.assertIn("Unknown CVar", self.g.prints[len(self.g.prints)])


    def test_ui_scale_applies_to_foreversuite_windows(self):
        self.start()
        self.runlua('F:OpenSettings(); F:SetEnabled("uiScale", true)')
        self.assertEqual(self.g.F.window.scale, 1)
        self.runlua('F:SetOption("uiScale", "scale", 130)')
        self.assertEqual(self.g.F.window.scale, 1.3)
        self.runlua('F:ShowDetails("repair")')
        self.assertEqual(self.g.F.detailsWindow.scale, 1.3)
        self.runlua('F:SetEnabled("uiScale", false)')
        self.assertEqual(self.g.F.window.scale, 1)

    def test_refresh_performance_is_reported(self):
        self.start()
        self.runlua('F:SetEnabled("repair", true)')
        report = self.g.F.Report(self.g.F)
        self.assertIn("Performance:", report)
        self.assertIn("Refresh", report)


    def test_window_size_command_and_remember(self):
        self.start()
        self.runlua('F:SetEnabled("resizeWindows", true)')
        self.runlua('SlashCmdList.FOREVERSUITE("size MerchantFrame 900 700")')
        self.assertIn("resized to 900 x 700", self.g.prints[len(self.g.prints)])
        self.assertEqual(self.g.ForeverSuiteDB.layouts.MerchantFrame.width, 900)
        self.runlua('SlashCmdList.FOREVERSUITE("size MerchantFrame 10 10")')
        self.assertIn("Not resized", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("size NoSuchFrame 400 400")')
        self.assertIn("unknown window", self.g.prints[len(self.g.prints)])

    def test_window_snap_clamps_to_screen_edge(self):
        self.start()
        self.runlua('UIParent.width=1920; UIParent.height=1080; F:SetEnabled("snapWindows", true);'
                    'MerchantFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 1900, -50)')
        self.runlua('MerchantFrame:Trigger("OnDragStop")')
        point = self.g.MerchantFrame.points
        self.assertEqual(point[1], "TOPLEFT")
        self.assertEqual(point[3], "TOPLEFT")
        self.assertLessEqual(point[4], 1920)
        self.runlua('UIParent.width=1000; F:SetEnabled("snapWindows", false)')

    def test_window_anchor_command(self):
        self.start()
        self.runlua('F:SetEnabled("windowAnchors", true)')
        self.runlua('SlashCmdList.FOREVERSUITE("anchor QuestFrame MerchantFrame 20 -30")')
        self.assertIn("anchored to MerchantFrame", self.g.prints[len(self.g.prints)])
        anchor = self.g.ForeverSuiteDB.anchors.QuestFrame
        self.assertEqual(anchor.target, "MerchantFrame")
        self.runlua('QuestFrame:Trigger("OnShow")')
        self.assertEqual(self.g.QuestFrame.points[2].name, "MerchantFrame")
        self.runlua('SlashCmdList.FOREVERSUITE("anchor QuestFrame NoSuchFrame")')
        self.assertIn("must be another tracked window", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("anchor QuestFrame clear")')
        self.assertIsNone(self.g.ForeverSuiteDB.anchors)

    def test_window_layout_save_use_delete(self):
        self.start()
        self.runlua('F:SetEnabled("moveWindows", true);'
                    'MerchantFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -60);'
                    'MerchantFrame:SetSize(800, 600)')
        self.runlua('SlashCmdList.FOREVERSUITE("layout save Questing")')
        self.assertIn("Saved window layout Questing", self.g.prints[len(self.g.prints)])
        saved = self.g.ForeverSuiteDB.windowLayouts.Questing
        self.assertIsNotNone(saved)
        self.runlua('MerchantFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 500, -500)')
        self.runlua('SlashCmdList.FOREVERSUITE("layout use Questing")')
        self.assertEqual(self.g.MerchantFrame.points[3], 40)
        self.assertEqual(self.g.MerchantFrame.points[4], -60)
        self.runlua('SlashCmdList.FOREVERSUITE("layout list")')
        self.assertIn("Questing", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("layout delete Questing")')
        self.assertIsNone(self.g.ForeverSuiteDB.windowLayouts)

    def test_window_keep_open_and_close_button_wins(self):
        self.start()
        self.runlua('F:SetEnabled("windowKeepOpen", true)')
        self.runlua('QuestFrame:Show()')
        self.runlua('MerchantFrame:SetScript("OnShow", function() QuestFrame:Hide() end); MerchantFrame:Show()')
        self.assertTrue(self.g.QuestFrame.shown)
        self.runlua('local close = CreateFrame("Button", "QuestFrameCloseButton");'
                    'close:SetScript("OnClick", function() end); F.pinnedWindows.QuestFrame=nil')
        self.assertIsNone(self.g.F.pinnedWindows.QuestFrame)

    def test_window_exceptions_skip_auction_house(self):
        self.start()
        self.runlua('F:SetEnabled("windowExceptions", true); F:SetEnabled("moveWindows", true); shift=true')
        self.assertTrue(self.g.F.WindowExcluded(self.g.F, "AuctionHouseFrame"))
        self.assertFalse(self.g.F.WindowExcluded(self.g.F, "MerchantFrame"))
        self.runlua('F:SetOption("windowExceptions", "auctionHouse", false)')
        self.assertFalse(self.g.F.WindowExcluded(self.g.F, "AuctionHouseFrame"))

    def test_window_anchor_and_layout_sanitation(self):
        self.runlua('ForeverSuiteDB={schema=1, anchors={Bad={target="MerchantFrame", x="no"}, Good={target="MerchantFrame", x=5, y=-5},'
                    'Self={target="Self", x=0, y=0}}, windowLayouts={Bad=5, Good={MerchantFrame={point="CENTER", x=1, y=2}},'
                    ' Wide={MerchantFrame={point="CENTER", x=1, y=2, width=99999}}}}')
        self.start()
        self.assertIsNone(self.g.ForeverSuiteDB.anchors.Bad)
        self.assertIsNone(self.g.ForeverSuiteDB.anchors.Self)
        self.assertIsNotNone(self.g.ForeverSuiteDB.anchors.Good)
        self.assertIsNone(self.g.ForeverSuiteDB.windowLayouts.Bad)
        self.assertIsNotNone(self.g.ForeverSuiteDB.windowLayouts.Good)
        self.assertIsNone(self.g.ForeverSuiteDB.windowLayouts.Wide)


    def test_dialog_turn_in_key_respects_reward_choices(self):
        self.start()
        self.runlua('F:SetEnabled("dialogKeys", true); F:SetOption("dialogKeys", "turnInKey", "BACKSPACE")')
        self.runlua('showButton("QuestFrameCompleteQuestButton"); choices=0')
        self.runlua('ForeverSuiteKeyCatcher.scripts.OnKeyDown(ForeverSuiteKeyCatcher, "BACKSPACE")')
        self.assertEqual(self.g.QuestFrameCompleteQuestButton.clicks, 1)
        self.runlua('choices=2; showButton("QuestFrameCompleteQuestButton")')
        self.runlua('ForeverSuiteKeyCatcher.scripts.OnKeyDown(ForeverSuiteKeyCatcher, "BACKSPACE")')
        self.assertEqual(self.g.QuestFrameCompleteQuestButton.clicks, 1)

    def test_dialog_decline_key_clicks_decline_only(self):
        self.start()
        self.runlua('F:SetEnabled("dialogKeys", true); F:SetOption("dialogKeys", "declineKey", "DELETE")')
        self.runlua('local decline = CreateFrame("Button", "QuestFrameDeclineButton"); decline.shown = true')
        self.runlua('ForeverSuiteKeyCatcher.scripts.OnKeyDown(ForeverSuiteKeyCatcher, "DELETE")')
        self.assertEqual(self.g.QuestFrameDeclineButton.clicks, 1)
        self.runlua('showButton("QuestFrameAcceptButton")')
        self.runlua('ForeverSuiteKeyCatcher.scripts.OnKeyDown(ForeverSuiteKeyCatcher, "DELETE")')
        self.assertEqual(self.g.QuestFrameAcceptButton.clicks, None)

    def test_beta_survey_popup_is_closed(self):
        self.start()
        self.runlua('F:SetEnabled("betaPopups", true)')
        self.runlua('local survey = CreateFrame("Frame", "BetaSurveyFrame"); survey:Show()')
        self.assertTrue(self.g.BetaSurveyFrame.shown)
        self.runlua('fire("PLAYER_LOGIN"); BetaSurveyFrame:Show()')
        self.assertFalse(self.g.BetaSurveyFrame.shown)

    def test_beta_reporter_button_toggle_and_command(self):
        self.start()
        self.runlua('local button = CreateFrame("Button", "BetaReportButton"); button:Show()')
        self.runlua('F:SetEnabled("betaReporter", true)')
        self.assertFalse(self.g.BetaReportButton.shown)
        self.runlua('F:SetEnabled("betaReporter", false)')
        self.assertTrue(self.g.BetaReportButton.shown)
        self.runlua('SlashCmdList.FOREVERSUITE("bugreport")')
        self.assertIn("Opened the client bug reporter", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("popups")')
        self.assertIn("BetaReportButton", self.g.prints[len(self.g.prints)])


    def test_flyout_item_level_in_shopping_tooltip(self):
        self.start()
        self.runlua('itemMeta["item:2001"] = { equipLoc = "INVTYPE_HEAD" }; itemReady = true')
        self.runlua('F:SetEnabled("flyoutItemLevel", true)')
        self.runlua('ShoppingTooltip1.link = "item:2001"; ShoppingTooltip1.lines = {};'
                    'tooltipCallbacks[Enum.TooltipDataType.Item](ShoppingTooltip1, { id = 2001 })')
        lines = " | ".join(self.g.ShoppingTooltip1.lines.values())
        self.assertIn("Item Level: 75", lines)
        self.assertIn("equipped 82", lines)
        self.runlua('GameTooltip.link="item:2001"; GameTooltip.lines={};'
                    'tooltipCallbacks[Enum.TooltipDataType.Item](GameTooltip, { id = 2001 })')
        self.assertNotIn("Item Level: 75", " | ".join(self.g.GameTooltip.lines.values()))

    def test_missing_enchant_and_gem_indicators(self):
        self.start()
        self.runlua('itemReady = true; itemMeta["item:1001:0:0:0:0"] = { equipLoc = "INVTYPE_HEAD" };'
                    'inventoryLinks.player[1] = "item:1001:0:0:0:0";'
                    'socketStats["item:1001:0:0:0:0"] = { EMPTY_SOCKET_RED = 1, SOCKET_YELLOW = 1 }')
        self.runlua('F:SetEnabled("missingEnchant", true); F:SetEnabled("missingGems", true); hover();'
                    'tip.link = "item:1001:0:0:0:0"; tip.lines = {}; hover()')
        lines = " | ".join(self.g.tip.lines.values())
        self.assertIn("Missing enchant", lines)
        self.assertIn("Empty socket: 2 of 2", lines)
        self.runlua('itemMeta["item:1001:4827:0:0:0"] = { equipLoc = "INVTYPE_HEAD" };'
                    'inventoryLinks.player[1] = "item:1001:4827:0:0:0"; tip.lines = {};'
                    'tip.link = "item:1001:4827:0:0:0"; hover()')
        self.assertNotIn("Missing enchant", " | ".join(self.g.tip.lines.values()))

    def test_socket_inspection_tooltip_and_command(self):
        self.start()
        self.runlua('itemReady = true;'
                    'inventoryLinks.player[1] = "item:1001:0:0"; socketStats["item:1001:0:0"] = { EMPTY_SOCKET_BLUE = 1 };'
                    'itemMeta["item:1001:0:0"] = { equipLoc = "INVTYPE_HEAD" }')
        self.runlua('F:SetEnabled("socketInfo", true); hover(); tip.link = "item:1001:0:0"; tip.lines = {}; hover()')
        lines = " | ".join(self.g.tip.lines.values())
        self.assertIn("Sockets: 0 of 1 filled", lines)
        self.runlua('SlashCmdList.FOREVERSUITE("sockets")')
        self.assertIn("Slot 1", self.g.prints[len(self.g.prints)])

    def test_unit_tooltip_health_and_class_colour(self):
        self.start()
        self.runlua('unitClasses.target = { "Target", "WARRIOR" }; unitHealths.target = { 500, 1000 }')
        self.runlua('F:SetEnabled("unitHealth", true); F:SetEnabled("tooltipClassColor", true)')
        frame = self.runlua('return hoverUnit("target")')
        lines = " | ".join(self.g.tips["unit"].lines.values())
        self.assertIn("Health: 500 / 1000 (50%)", lines)
        self.assertEqual(self.g.tips["unit"].border[1], 0.78)
        self.runlua('F:SetEnabled("tooltipClassColor", false)')
        self.assertEqual(self.g.tips["unit"].border[1], 0)

    def test_tooltip_anchor_position_option(self):
        self.start()
        self.runlua('F:SetEnabled("tooltipAnchor", true); F:SetOption("tooltipAnchor", "position", "topright")')
        self.runlua('GameTooltip:Show()')
        point = self.g.GameTooltip.points
        self.assertEqual(point[1], "TOPRIGHT")
        self.assertEqual(point[3], "TOPRIGHT")
        self.assertEqual(point[4], -12)
        self.runlua('F:SetOption("tooltipAnchor", "position", "default")')
        self.assertEqual(self.g.ForeverSuiteDB.options.tooltipAnchor.position, "default")


    def test_friendly_invite_and_duel_rules(self):
        self.start()
        self.runlua('friends["Buddy"] = true; F:SetEnabled("friendlyInvites", true); F:SetEnabled("duelRules", true)')
        self.runlua('fire("PARTY_INVITE_REQUEST", "Buddy")')
        self.assertEqual(self.g.socialLog.acceptGroup, 1)
        self.runlua('fire("PARTY_INVITE_REQUEST", "Stranger")')
        self.assertEqual(self.g.socialLog.acceptGroup, 1)
        self.runlua('fire("DUEL_REQUESTED", "Stranger")')
        self.assertEqual(self.g.socialLog.duel, 1)
        self.runlua('fire("DUEL_REQUESTED", "Buddy")')
        self.assertEqual(self.g.socialLog.duel, 1)

    def test_duel_level_gap_rule(self):
        self.start()
        self.runlua('F:SetEnabled("duelRules", true); F:SetOption("duelRules", "strangers", false);'
                    'F:SetOption("duelRules", "levelGap", 10); unitLevels.target = 20')
        self.runlua('fire("DUEL_REQUESTED", "target")')
        self.assertEqual(self.g.socialLog.duel, 1)
        self.runlua('unitLevels.target = 38; fire("DUEL_REQUESTED", "target")')
        self.assertEqual(self.g.socialLog.duel, 1)

    def test_summon_and_resurrection_rules(self):
        self.start()
        self.runlua('F:SetEnabled("summonRules", true); F:SetEnabled("resurrectRules", true);'
                    'summonLeft = 5; summonSummoner = "Buddy"; friends["Buddy"] = true; F:CheckSummonNow()')
        self.assertEqual(self.g.socialLog.summon, 1)
        self.runlua('F:SetOption("summonRules", "trust", "trusted"); summonLeft = 5; summonSummoner = "Stranger";'
                    'F:CheckSummonNow()')
        self.assertEqual(self.g.socialLog.summon, 1)
        self.runlua('deadUnits.player = true; fire("RESURRECT_REQUEST", "Buddy")')
        self.assertEqual(self.g.socialLog.acceptRes, 1)
        self.runlua('combat = true; fire("RESURRECT_REQUEST", "Buddy")')
        self.assertEqual(self.g.socialLog.acceptRes, 1)

    def test_battleground_release_rules(self):
        self.start()
        self.runlua('F:SetEnabled("battlegroundRelease", true); F:SetOption("battlegroundRelease", "delay", 0);'
                    'deadUnits.player = true; instanceKind = "none"; fire("PLAYER_DEAD")')
        self.assertEqual(self.g.socialLog.repop, 0)
        self.runlua('instanceKind = "pvp"; fire("PLAYER_DEAD")')
        self.assertEqual(self.g.socialLog.repop, 1)
        self.runlua('deadUnits.player = false; fire("PLAYER_DEAD")')
        self.assertEqual(self.g.socialLog.repop, 1)

    def test_whisper_invite_rules(self):
        self.start()
        self.runlua('F:SetEnabled("whisperInvites", true); guildmates["Guildie"] = true')
        self.runlua('fire("CHAT_MSG_WHISPER", "inv", "Guildie")')
        self.assertEqual(self.g.socialLog.invite, 1)
        self.assertEqual(self.g.socialLog.invitedName, "Guildie")
        self.runlua('fire("CHAT_MSG_WHISPER", "inv", "Stranger")')
        self.assertEqual(self.g.socialLog.invite, 1)
        self.runlua('fire("CHAT_MSG_WHISPER", "hello", "Guildie")')
        self.assertEqual(self.g.socialLog.invite, 1)
        self.runlua('F:SetOption("whisperInvites", "allowAnyone", true); fire("CHAT_MSG_WHISPER", "  INV  ", "Stranger")')
        self.assertEqual(self.g.socialLog.invite, 2)

    def test_quest_exceptions_block_keyboard_accept(self):
        self.start()
        self.runlua('F:SetEnabled("dialogAccept", true); F:SetEnabled("questExceptions", true);'
                    'showButton("QuestFrameAcceptButton"); questTitle = "A Test Quest"')
        self.runlua('SlashCmdList.FOREVERSUITE("quest except A Test Quest")')
        self.assertIn("Added quest exception", self.g.prints[len(self.g.prints)])
        self.runlua('pressKey("SPACE")')
        self.assertEqual(self.g.QuestFrameAcceptButton.clicks, None)
        self.runlua('SlashCmdList.FOREVERSUITE("quest allow A Test Quest"); pressKey("SPACE")')
        self.assertEqual(self.g.QuestFrameAcceptButton.clicks, 1)

    def test_trivial_quest_notice(self):
        self.start()
        self.runlua('questLevelValue = 10; unitLevels.player = 40; questTitle = "Green Quest";'
                    'F:SetEnabled("trivialQuests", true)')
        self.runlua('fire("QUEST_DETAIL")')
        self.assertIn("trivial for you", self.g.prints[len(self.g.prints)])
        before = len(self.g.prints)
        self.runlua('questLevelValue = 38; fire("QUEST_DETAIL")')
        self.assertEqual(len(self.g.prints), before)

    def test_gossip_preference_and_money_protection(self):
        self.start()
        self.runlua('F:SetEnabled("gossipPreferences", true); gossipOptions = { { text = "Free option", kind = "gossip" },'
                    ' { text = "Buy", kind = "gossip" } }; GossipFrame:Show()')
        self.runlua('SlashCmdList.FOREVERSUITE("gossip prefer 1")')
        self.assertIn("now chooses gossip option 1", self.g.prints[len(self.g.prints)])
        self.runlua('fire("GOSSIP_SHOW")')
        self.assertEqual(self.g.calls.gossipIndex, 1)
        self.runlua('SlashCmdList.FOREVERSUITE("gossip list")')
        self.assertIn("12345", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("gossip clear"); fire("GOSSIP_SHOW")')
        self.assertEqual(self.g.calls.gossipIndex, 1)

    def test_sell_whitelist_overrides_quality_rule(self):
        self.start()
        self.runlua('itemReady = true; itemMeta["item:3001"] = { quality = 2, sellPrice = 500, equipLoc = "INVTYPE_HEAD" };'
                    'containerLinks[0] = { [1] = "item:3001" }; containerSlots[0] = 1;'
                    'F:SetEnabled("sellWhitelist", true); F:SetEnabled("merchantRules", true)')
        self.runlua('SlashCmdList.FOREVERSUITE("whitelist add 3001")')
        self.assertIn("Whitelisted item 3001", self.g.prints[len(self.g.prints)])
        self.runlua('candidateCount = #F:SaleCandidates()')
        self.assertEqual(self.g.candidateCount, 1)
        self.runlua('containerLinks[0] = {}')
        self.runlua('SlashCmdList.FOREVERSUITE("whitelist list")')
        self.assertIn("3001", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("whitelist remove 3001")')
        self.assertIn("Removed the item from the whitelist", self.g.prints[len(self.g.prints)])

    def test_social_sanitation(self):
        self.runlua('ForeverSuiteDB={schema=1, questExceptions={ids={1001, -5, 2.5, 4455}, titles={"A Quest", "", 7}},'
                    'gossipPrefs={["12345"]=3, Bad=4, ["9999999999999"]=5, ["777"]=12},'
                    'sellWhitelist={3001, "x", 0, 3002}}')
        self.start()
        store = self.g.ForeverSuiteDB.questExceptions
        self.assertEqual([store['ids'][i] for i in (1, 2)], [1001, 4455])
        self.assertEqual([store['titles'][i] for i in (1,)], ["A Quest"])
        self.assertIsNone(self.g.ForeverSuiteDB.gossipPrefs.Bad)
        self.assertIsNone(self.g.ForeverSuiteDB.gossipPrefs["777"])
        self.assertEqual([self.g.ForeverSuiteDB.sellWhitelist[i] for i in (1, 2)], [3001, 3002])


    def test_chat_log_store_and_clear(self):
        self.start()
        self.runlua('F:SetEnabled("chatLogStore", true); F:SetOption("chatLogStore", "size", 20)')
        self.runlua('for i = 1, 25 do fire("CHAT_MSG_SAY", "line " .. i, "Tester") end')
        log = self.g.ForeverSuiteDB.chatLog
        self.assertEqual(len(log), 20)
        self.assertEqual(log[len(log)].text, "line 25")
        self.runlua('fire("CHAT_MSG_WHISPER", "secret", "Buddy")')
        self.assertEqual(self.g.ForeverSuiteDB.lastWhisper, "Buddy")
        self.runlua('SlashCmdList.FOREVERSUITE("chatlog")')
        self.assertIn("Buddy: secret", self.g.F.reportWindow.edit.text)
        self.runlua('SlashCmdList.FOREVERSUITE("chatlog clear")')
        self.assertIsNone(self.g.ForeverSuiteDB.chatLog)

    def test_chat_log_whispers_only_option(self):
        self.start()
        self.runlua('F:SetEnabled("chatLogStore", true); F:SetOption("chatLogStore", "whispersOnly", true)')
        self.runlua('fire("CHAT_MSG_SAY", "public", "Tester"); fire("CHAT_MSG_WHISPER", "private", "Buddy")')
        log = self.g.ForeverSuiteDB.chatLog
        self.assertEqual(len(log), 1)
        self.assertEqual(log[1].text, "private")

    def test_saved_channels_join_and_remove(self):
        self.start()
        self.runlua('F:SetEnabled("chatChannels", true); SlashCmdList.FOREVERSUITE("channels add world")')
        self.assertEqual([self.g.ForeverSuiteDB.channels[i] for i in (1,)], ["world"])
        self.runlua('fire("PLAYER_LOGIN")')
        self.assertIn("world", list(self.g.joinedChannels.values()))
        self.runlua('SlashCmdList.FOREVERSUITE("channels remove world")')
        self.assertIn("world", list(self.g.leftChannels.values()))
        self.assertIsNone(self.g.ForeverSuiteDB.channels)

    def test_chat_class_colours_and_word_filter(self):
        self.start()
        self.runlua('classForGUID["Player-970-1"] = "WARRIOR"; F:SetEnabled("chatClassColors", true)')
        self.runlua('hide, shownText, tintedName = ApplyChatFilter("CHAT_MSG_SAY", "hello", "Buddy", "Common", nil, nil, nil, nil, nil, nil, nil, nil, "Player-970-1")')
        hide, name = self.g.hide, self.g.tintedName
        self.assertFalse(hide)
        self.assertIn("|cff", name)
        self.assertIn("Buddy", name)
        self.runlua('F:SetEnabled("chatFilters", true); SlashCmdList.FOREVERSUITE("filter add spam")')
        self.runlua('hide, shownText, tintedName = ApplyChatFilter("CHAT_MSG_SAY", "buy SPAM now", "Buddy", "Common", nil, nil, nil, nil, nil, nil, nil, nil, "Player-970-1")')
        hide = self.g.hide
        self.assertTrue(hide)
        self.runlua('SlashCmdList.FOREVERSUITE("filter remove spam")')
        self.runlua('hide, shownText, tintedName = ApplyChatFilter("CHAT_MSG_SAY", "buy SPAM now", "Buddy", "Common", nil, nil, nil, nil, nil, nil, nil, nil, "Player-970-1")')
        hide = self.g.hide
        self.assertFalse(hide)

    def test_whisper_window_shows_and_replies(self):
        self.start()
        self.runlua('F:SetEnabled("chatLogStore", true); F:SetEnabled("whisperWindow", true)')
        self.runlua('fire("CHAT_MSG_WHISPER", "are you there", "Buddy")')
        self.runlua('SlashCmdList.FOREVERSUITE("whisper Buddy")')
        self.assertTrue(self.g.ForeverSuiteWhisperWindow.shown)
        self.assertIn("are you there", self.g.ForeverSuiteWhisperWindow.body.text)
        self.runlua('ForeverSuiteWhisperWindow.edit:SetText("yes"); F:SendWhisperFromWindow()')
        sent = self.g.sentMessages
        self.assertEqual(sent[len(sent)].text, "yes")
        self.assertEqual(sent[len(sent)].target, "Buddy")
        self.runlua('SlashCmdList.FOREVERSUITE("whisper close")')
        self.assertFalse(self.g.ForeverSuiteWhisperWindow.shown)

    def test_chat_db_sanitation(self):
        self.runlua('ForeverSuiteDB={schema=1, chatLog={ {text="ok", name="A", channel="Say"}, {text="", name="B"}, "junk",'
                    ' {text=string.rep("x", 500)} }, channels={"world", "", 5, string.rep("y", 60)},'
                    ' chatFilters={"spam", "", 7}, lastWhisper=""}')
        self.start()
        log = self.g.ForeverSuiteDB.chatLog
        self.assertEqual(len(log), 1)
        self.assertEqual(log[1].text, "ok")
        channels = self.g.ForeverSuiteDB.channels
        self.assertEqual(len(channels), 1)
        self.assertEqual(channels[1], "world")
        self.assertEqual(len(self.g.ForeverSuiteDB.chatFilters), 1)
        self.assertIsNone(self.g.ForeverSuiteDB.lastWhisper)


    def test_map_cursor_coordinates_and_zone_range(self):
        self.start()
        self.runlua('F:SetEnabled("worldMapCoords", true); F:SetEnabled("zoneLevels", true)')
        self.runlua('SlashCmdList.FOREVERSUITE("where")')
        self.assertIn("40, 50", self.g.prints[len(self.g.prints)])
        self.runlua('WorldMapFrame.cursor = { 1300, 100 }')
        self.runlua('SlashCmdList.FOREVERSUITE("where")')
        self.assertIn("Move the mouse", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("zone")')
        self.assertIn("Elwynn Forest: levels 1-10", self.g.prints[len(self.g.prints)])
        self.runlua('zoneName = "Unknown Isle"; SlashCmdList.FOREVERSUITE("zone")')
        self.assertIn("no level range recorded", self.g.prints[len(self.g.prints)])
        self.runlua('zoneName = "Westfall"; fire("ZONE_CHANGED_NEW_AREA")')
        self.assertIn("Westfall", self.g.prints[len(self.g.prints)])

    def test_waypoint_and_dungeon_commands(self):
        self.start()
        self.runlua('F:SetEnabled("waypoints", true); F:SetEnabled("dungeonMarkers", true)')
        self.runlua('SlashCmdList.FOREVERSUITE("way 40 60")')
        self.assertIn("Set a waypoint at 40, 60", self.g.prints[len(self.g.prints)])
        self.assertEqual(self.g.userWaypoint.position.x, 0.4)
        self.assertEqual(self.g.userWaypoint.position.y, 0.6)
        self.runlua('SlashCmdList.FOREVERSUITE("way 200 10")')
        self.assertIn("Waypoint not set", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("way clear")')
        self.assertIsNone(self.g.userWaypoint)
        self.runlua('SlashCmdList.FOREVERSUITE("dungeon The Deadmines")')
        self.assertIn("Westfall", self.g.prints[len(self.g.prints)])
        self.assertIsNotNone(self.g.userWaypoint)
        before = len(self.g.prints)
        self.runlua('SlashCmdList.FOREVERSUITE("dungeon")')
        listing = " ".join(self.g.prints[i] for i in range(before + 1, len(self.g.prints) + 1))
        self.assertIn("Scarlet Monastery", listing)

    def test_teleport_favorites_and_menu(self):
        self.start()
        self.runlua('F:SetEnabled("teleportFavorites", true); F:SetEnabled("teleportMenu", true)')
        self.runlua('SlashCmdList.FOREVERSUITE("tele add Hearth 8690")')
        self.assertIn("Saved teleport favorite Hearth", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("tele hearth")')
        self.assertIn(8690, list(self.g.castSpells.values()))
        self.runlua('SlashCmdList.FOREVERSUITE("tele menu")')
        self.assertTrue(self.g.ForeverSuiteTeleportMenu.shown)
        self.assertEqual(self.g.ForeverSuiteTeleportMenu.buttons[1].text.text, "Hearth")
        self.runlua('combat = true; SlashCmdList.FOREVERSUITE("tele Hearth")')
        self.assertIn("cannot cast during combat", self.g.prints[len(self.g.prints)])
        self.runlua('combat = false; F:SetEnabled("teleportMenu", false)')
        self.assertFalse(self.g.ForeverSuiteTeleportMenu.shown)
        self.runlua('SlashCmdList.FOREVERSUITE("tele remove Hearth")')
        self.assertIsNone(self.g.ForeverSuiteDB.teleports)

    def test_taxi_shortcuts_and_flight_timer(self):
        self.start()
        self.runlua('F:SetEnabled("flightShortcuts", true); F:SetEnabled("flightTimer", true);'
                    'taxiNodes = { "Goldshire", "Stormwind" }')
        self.runlua('SlashCmdList.FOREVERSUITE("taxi list")')
        self.assertIn("2. Stormwind", self.g.prints[len(self.g.prints) - 1])
        self.runlua('SlashCmdList.FOREVERSUITE("taxi 2")')
        self.assertEqual(list(self.g.takenTaxi.values()), [2])
        self.runlua('unitOnTaxi = true; now = 100; fire("TAXIMAP_CLOSED"); now = 130')
        self.runlua('SlashCmdList.FOREVERSUITE("flight")')
        self.assertIn("30.0 seconds", self.g.prints[len(self.g.prints)])
        self.runlua('fire("PLAYER_CONTROL_GAINED"); SlashCmdList.FOREVERSUITE("flight")')
        self.assertIn("Not on a taxi flight", self.g.prints[len(self.g.prints)])

    def test_teleport_db_sanitation(self):
        self.runlua('ForeverSuiteDB={schema=1, teleports={ {name="Hearth", id=8690}, {name="", id=1},'
                    ' {name="Bad", id="x"}, {name="Huge", id=2.5} }}')
        self.start()
        list_ = self.g.ForeverSuiteDB.teleports
        self.assertEqual(len(list_), 1)
        self.assertEqual(list_[1].name, "Hearth")


    def test_quest_list_levels_and_distance_sorting(self):
        self.start()
        self.runlua('questLogEntries = { { title = "Far Quest", level = 20, id = 11 }, { title = "Near Quest", level = 25, id = 12 },'
                    ' { title = "Header", header = true } }; questDistances = { [11] = 40000, [12] = 100 }')
        self.runlua('F:SetEnabled("questList", true); F:SetEnabled("questDistance", true)')
        self.runlua('SlashCmdList.FOREVERSUITE("quests")')
        first = self.g.prints[len(self.g.prints) - 1]
        self.assertIn("Near Quest", first)
        self.assertIn("[25]", first)
        self.assertIn("10 m", first)
        self.runlua('SlashCmdList.FOREVERSUITE("quests")')
        self.assertIn("Far Quest", self.g.prints[len(self.g.prints)])
        self.assertNotIn("Header", " ".join(self.g.prints.values()))

    def test_use_quest_item_and_target_macro(self):
        self.start()
        self.runlua('F:SetEnabled("questItemUse", true); F:SetEnabled("questTarget", true);'
                    'containerLinks[0] = { [1] = "item:4001" }; containerSlots[0] = 1; sold = {}')
        self.runlua('SlashCmdList.FOREVERSUITE("useq 4001")')
        self.assertIn("Used", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("useq Missing")')
        self.assertIn("no matching item found", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("qtarget Wolf")')
        self.assertEqual(self.g.targetedName, "Wolf")
        self.runlua('SlashCmdList.FOREVERSUITE("qtarget Nobody")')
        self.assertIn("No creature with that name", self.g.prints[len(self.g.prints)])

    def test_rested_report_and_full_notice(self):
        self.start()
        self.runlua('function GetXPExhaustion() return restedValue end; restedValue = 200;'
                    'UnitXPValue = 0; UnitXPMaxValue = 1000;'
                    'F:SetEnabled("restedInfo", true); F:SetEnabled("restedFull", true)')
        self.runlua('SlashCmdList.FOREVERSUITE("rested")')
        self.assertIn("Rested XP: 200", self.g.prints[len(self.g.prints)])
        self.assertIn("20.0%", self.g.prints[len(self.g.prints)])
        self.runlua('restedValue = 1600; F:RefreshRestedForTest()')
        self.assertIn("Rested experience is full", self.g.prints[len(self.g.prints)])

    def test_rare_alert_and_trade_and_craft_summaries(self):
        self.start()
        self.runlua('F:SetEnabled("rareAlerts", true); unitClassifications.target = "rare";'
                    'guids.target = "Creature-0-1465-0-2105-9999-000043F59F";'
                    'F:SetEnabled("tradeWarning", true); itemReady = true; itemMeta["item:5001"] = { quality = 3 };'
                    'tradeLinks[1] = "item:5001"')
        self.runlua('fire("PLAYER_TARGET_CHANGED")')
        self.assertIn("9999", self.g.prints[len(self.g.prints)])
        before = len(self.g.prints)
        self.runlua('fire("PLAYER_TARGET_CHANGED")')
        self.assertEqual(len(self.g.prints), before)
        self.runlua('fire("TRADE_SHOW")')
        self.assertIn("Trade window contains", self.g.prints[len(self.g.prints)])
        self.runlua('F:SetEnabled("craftWarning", true); tsRecipes = { "Test Sword" }; tsSelection = 1;'
                    'tsReagents = { { { "Iron Bar", 2 } } }')
        self.runlua('fire("TRADE_SKILL_UPDATE")')
        self.assertIn("Crafting Test Sword with Iron Bar x2", self.g.prints[len(self.g.prints)])

    def test_typed_confirmation_guards_settings_resets(self):
        self.start()
        self.runlua('F:SetEnabled("typedConfirm", true); F:SetEnabled("chatLogStore", true)')
        self.runlua('fire("CHAT_MSG_SAY", "keep me", "Tester")')
        self.runlua('SlashCmdList.FOREVERSUITE("chatlog clear")')
        self.assertIn("Type /fs chatlog clear confirm", self.g.prints[len(self.g.prints)])
        self.assertIsNotNone(self.g.ForeverSuiteDB.chatLog)
        self.runlua('SlashCmdList.FOREVERSUITE("chatlog clear confirm")')
        self.assertIsNone(self.g.ForeverSuiteDB.chatLog)


    def test_gear_groups_and_bag_marks(self):
        self.start()
        self.runlua('itemReady = true; itemMeta["item:6001"] = { quality = 4 }; itemMeta["item:6002"] = { quality = 3 };'
                    'containerLinks[0] = { [1] = "item:6001", [2] = "item:6002" }; containerSlots[0] = 2;'
                    'CreateFrame("Button", "ContainerFrame1Item1"); CreateFrame("Button", "ContainerFrame1Item2");'
                    'F:SetEnabled("gearGroups", true); F:SetEnabled("gearBagMarks", true)')
        self.runlua('SlashCmdList.FOREVERSUITE("gear add Tank 6001")')
        self.assertIn("Added item 6001", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("gear add Tank 6002"); SlashCmdList.FOREVERSUITE("gear add Tank 9999")')
        self.runlua('SlashCmdList.FOREVERSUITE("gear show Tank")')
        self.assertIn("Marked 2 bag slot(s)", self.g.prints[len(self.g.prints)])
        self.assertEqual(self.g.ContainerFrame1Item1.border[1], 1)
        self.runlua('SlashCmdList.FOREVERSUITE("gear show clear")')
        self.assertIn("Cleared gear group marks", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("gear list")')
        self.assertIn("Tank", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("gear remove Tank 6001")')
        self.assertIn("Removed the item from the gear group", self.g.prints[len(self.g.prints)])

    def test_bag_search_filters(self):
        self.start()
        self.runlua('itemReady = true; itemMeta["item:6101"] = { quality = 4, classID = 4 }; itemMeta["item:6102"] = { quality = 1 };'
                    'containerLinks[0] = { [1] = "item:6101", [2] = "item:6102" }; containerSlots[0] = 2;'
                    'containerLinks[1] = {};'
                    'F:SetEnabled("bagSearch", true); F:SetEnabled("bagFilters", true); F:SetEnabled("gearGroups", true)')
        self.runlua('SlashCmdList.FOREVERSUITE("gear add Fancy 6101")')
        before = len(self.g.prints)
        self.runlua('SlashCmdList.FOREVERSUITE("bag #gear")')
        listing = " ".join(self.g.prints[i] for i in range(before + 1, len(self.g.prints) + 1))
        self.assertIn("1 matching item(s)", listing)
        self.assertIn("slot 1", listing)

    def test_fishing_restore_and_lure(self):
        self.start()
        self.runlua('itemReady = true; itemMeta["item:7001"] = { name = "Fishing Pole", equipLoc = "INVTYPE_2HWEAPON", subType = "Fishing Pole" };'
                    'itemMeta["item:7002"] = { equipLoc = "INVTYPE_WEAPON", subType = "One-Handed Swords" };'
                    'itemMeta["item:7100"] = { classID = 0 };'
                    'inventoryLinks.player[16] = "item:7002"; containerLinks[0] = { [1] = "item:7100" }; containerSlots[0] = 1;'
                    'F:SetEnabled("fishingSet", true); F:SetEnabled("fishingLure", true); F:SetEnabled("fishingCast", true)')
        self.runlua('inventoryLinks.player[16] = "item:7001"; fire("PLAYER_EQUIPMENT_CHANGED", 16)')
        self.runlua('SlashCmdList.FOREVERSUITE("fish restore")')
        self.assertIn("Restored 1 weapon(s)", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("lure add Shiny 7100")')
        self.assertIn("Saved lure Shiny", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("lure Shiny")')
        self.assertIn("Applied lure Shiny", self.g.prints[len(self.g.prints)])

    def test_eat_drink_and_pet_food(self):
        self.start()
        self.runlua('itemReady = true; itemMeta["item:7201"] = { name = "Bread", classID = 0, subType = "Food & Drink" };'
                    'itemMeta["item:7202"] = { name = "Spring Water", classID = 0, subType = "Food & Drink" };'
                    'containerLinks[0] = { [1] = "item:7201", [2] = "item:7202" }; containerSlots[0] = 2;'
                    'F:SetEnabled("foodDrink", true); F:SetEnabled("petFood", true)')
        self.runlua('SlashCmdList.FOREVERSUITE("eat")')
        self.assertIn("Bread", self.g.prints[len(self.g.prints)])
        self.runlua('SlashCmdList.FOREVERSUITE("drink")')
        self.assertIn("Spring Water", self.g.prints[len(self.g.prints)])
        self.runlua('containerLinks[0] = { [1] = "item:7201", [2] = "item:7202" }')
        before = len(self.g.prints)
        self.runlua('SlashCmdList.FOREVERSUITE("petfood")')
        listing = " ".join(self.g.prints[i] for i in range(before + 1, len(self.g.prints) + 1))
        self.assertIn("Bread", listing)

    def test_reagent_bag_protection_skips_bag(self):
        self.start()
        self.runlua('itemReady = true; itemMeta["item:7301"] = { quality = 0, sellPrice = 100 };'
                    'itemMeta["item:7302"] = { quality = 0, sellPrice = 100 };'
                    'containerLinks[4] = { [1] = "item:7301" }; containerSlots[4] = 1;'
                    'containerLinks[0] = { [1] = "item:7302" }; containerSlots[0] = 1;'
                    'F:SetEnabled("merchantRules", true); F:SetEnabled("reagentBag", true)')
        self.runlua('candidates = #F:SaleCandidates()')
        self.assertEqual(self.g.candidates, 1)
        self.runlua('F:SetEnabled("reagentBag", false); candidates = #F:SaleCandidates()')
        self.assertEqual(self.g.candidates, 2)

    def test_minimap_button_collection(self):
        self.start()
        self.runlua('local button = CreateFrame("Button", "SomeAddonMinimapButton", Minimap); button.shown = true;'
                    'F:SetEnabled("minimapButtons", true)')
        self.runlua('SlashCmdList.FOREVERSUITE("minimap collect")')
        self.assertIn("Hid 1 minimap button", self.g.prints[len(self.g.prints)])
        self.assertFalse(self.g.SomeAddonMinimapButton.shown)
        self.runlua('SlashCmdList.FOREVERSUITE("minimap restore")')
        self.assertTrue(self.g.SomeAddonMinimapButton.shown)

    def test_character_db_sanitation(self):
        self.runlua('ForeverSuiteDB={schema=1, gearGroups={Tank={6001, 0, "x"}, Bad=5},'
                    'lures={ {name="Shiny", id=7100}, {name="", id=1}, {name="Bad", id=0} }}')
        self.start()
        groups = self.g.ForeverSuiteDB.gearGroups
        self.assertEqual([groups['Tank'][i] for i in (1,)], [6001])
        self.assertIsNone(groups.Bad)
        self.assertEqual(len(self.g.ForeverSuiteDB.lures), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
