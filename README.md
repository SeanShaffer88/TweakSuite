# TweakSuite

![TweakSuite](media/logo.png)

A comprehensive, modular quality-of-life addon for **World of Warcraft: Forever** by **Malikor**. Source: [github.com/SeanShaffer88/TweakSuite](https://github.com/SeanShaffer88/TweakSuite) (formerly `ForeverSuite`; old links redirect). It combines overlapping ideas into one settings surface while keeping distinct useful features, and every feature starts **off**.

**0.3.0-alpha.1** renames the project from ForeverSuite to TweakSuite, relicenses it under the GNU GPL v3 (or later), adds an addon icon and logo, and keeps all 227 opt-in features. The capability backlog has no planned rows left: every row is implemented in preview or scoped out with a written reason. Original code; no other addons or their assets are bundled. Beta and launch client executables were both observed at 1.60.1.70532 on October 22, 2026. **In-game gameplay and visual verification are still pending**, so treat this as a preview and keep the addons you rely on until each replacement is tested.

### Upgrading from ForeverSuite

TweakSuite is the same addon under a new name, with a new settings store (`TweakSuiteDB`), so settings start fresh.

1. In game, with ForeverSuite still installed, type `/fs reset` outside combat and log out normally. This restores any client settings ForeverSuite changed.
2. Delete the `Interface/AddOns/ForeverSuite` folder, then install TweakSuite.
3. If ForeverSuite is still loaded, TweakSuite blocks every feature and its status reads *conflict: ForeverSuite (previous name of this addon)*, so nothing runs twice.

The chat command is now `/ts` (or `/tweaksuite`).

### Opening TweakSuite

- Click the **minimap button** (left-click opens or closes the window, right-click opens Options > AddOns > TweakSuite, drag to move it). Hide it with **Show minimap button** on that Options page or `/ts button`.
- Type `/ts`, or use **Open TweakSuite** in Options > AddOns > TweakSuite.
- The TweakSuite window is standalone: it stays open when you close Options. Escape closes it.

## Install and open

Extract the release ZIP into the intended client's `Interface/AddOns` folder. The final path must end in `Interface/AddOns/TweakSuite/TweakSuite.toc`.

- Beta client folder: `_classic_beta_`.
- Launch client folder: `_forever_`.
- Restart the game after installing. Enable **TweakSuite** on the AddOns screen, then type `/ts`.
- Every feature starts off. Browse categories or search across all settings, tick a feature, and read its status.
- **Details** explains what the setting changes, its default, what switching it off does, combat behavior and overlapping addons. CVar options also identify the underlying client setting and its current target value. Search covers categories, descriptions and option text.
- Features with variants show an **Opt** button. It opens a per-feature options panel with the current value, the default, valid choices or ranges, and a reset button. Options never switch a feature on by themselves.
- The interface takes visual inspiration from Leatrix Plus: a dark brown window, gold headings, a flat category sidebar with live feature counts, a Home page and compact grouped checkboxes. Short explanations stay beside controls; hover or click **?** for the complete setting details. The implementation and layout code are original.
- The same package targets both clients. Each client maintains its own SavedVariables. This preview does not migrate settings between them.

Optional PowerShell installer, from the source repository:

```powershell
.\tools\install.ps1 -ClientPath 'your WoW directory\_classic_beta_'
.\tools\install.ps1 -ClientPath 'your WoW directory\_forever_' -Install
```

Without `-Install`, it only checks the selected client. It refuses to overwrite an existing TweakSuite folder or copy while WoW is running. It does not modify other addons or saved settings.

## Available now (227 features, 13 categories)

- **Automation (16):** personal-gold repairs with a configurable cap, a funding choice (personal, guild bank, or personal then guild) and optional cost reporting; native Sell All Junk; faster auto-looting; accepting quests with optional daily and repeatable filters; turning in quests with no reward choices and no money requirement; declining group invites from players who are neither friends nor guild members; selling by quality, item level and bind rules with a preview and a never-sell list; manual junk marking; a sell whitelist; invite, duel, summon, resurrect and battleground-release rules; whisper-keyword invites; and reagent bag protection.
- **Dialogs (7):** a configurable key (Space, Enter, E or the common letter keys) presses the visible Accept/Continue button, with an optional key hint; number keys 1-6 select a quest reward without turning the quest in, number keys 1-9 choose gossip options while never selecting one that costs money; extra turn-in and decline keys; a quest exception list; a trivial-quest notice; and per-NPC gossip preferences.
- **Windows (7):** Shift-drag 14 common Blizzard windows and keep each position; resize with a corner grip or `/ts size`; keep windows on screen; anchor one window to another; save and restore named window layout sets; reopen panels that the client closes when another opens; and exclude fragile panels.
- **Tooltips (33):** maximum stack size, item ID, actual equipment item level, an equipped-item comparison with upgrade and downgrade deltas, owned count with optional bank, spell ID, NPC ID, currency ID, quest ID, vendor sell price (per item or per stack), binding type, tooltip border colour, hiding tooltips in combat, a tooltip scale percentage; item levels in flyout and shopping tooltips; missing enchant and empty socket markers; socket summaries with `/ts sockets`; class-coloured unit tooltips; health in unit tooltips; reputation token details and quest-starting item notes read from the client's own tooltip text; spell damage per second, per minute and per mana with the mana cost percentage and damage-over-time share plus `/ts spellcalc` and `/ts spelllabels`; a fixed tooltip corner, what your target is casting with the time left, a `/ts tcast` spell reference for the target's cast, and a talking-head replacement that prints the line to chat.
- **Inventory (22):** actual item levels on character-panel, inspect, bag and bank slots with position and size options; item levels on the loot window and on need/greed rolls; average equipped item level; durability percentages on character slots; free bag slots on the backpack; and per-character gold recording with `/ts gold`, bag search with `/ts bag` and its filter keywords, gear groups with bag markers, fishing gear restoration and lures, food and drink shortcuts, pet food listing, a fishing cast shortcut, a compact loot list, loot notifications, a tracked-item bar and merchant currency cost details.
- **Interface (80):** auto-loot default, cast on key down, instant quest text, full-screen glow, low-health flash, target of target, loot history, spell activation artwork, quest tracking and progress, map quest difficulty, quest tooltips, numeric cooldowns, target cast bar, action bar lock and visibility, auto-cast protection, target aura filtering, aura durations, self-cast, spell effect emphasis, combat text toggles, minimap rotation, camera zoom distance, automatic reputation tracking, death screen effect, hidden objective tracker, gryphon end caps, zone name text, the boss banner, the minimap clock and zone label, thousands separators, new-spell action bar placement, minimap scale, micro menu hiding, action bar dimming, experience-per-hour tracking, settings-window scaling, the profiles command set, the CVar browser, beta survey suppression, the beta reporter button, minimap button collection, action button range tinting, action bar text hiding, a cursor ring and a cursor trail; hazard warnings driven by a list you maintain with `/ts hazard`, action failure warnings, fatigue and breath warnings, per-category alert sounds, alert exemptions, client aura sounds through `C_UnitAuras.AddAuraSound`; player, target, party and raid frame scaling; power and absorb readouts; a native damage-meter session list with `/ts meter`; a macro drawer; a sound browser with `/ts music`; settings navigation for controllers; interface language resolution with `/ts locale`; settings migration with `/ts migrate`; and event toast and sound-channel controls.
- **Nameplates (13):** enemy and friendly visibility, maximum distance, scale, stacking, class colors, friendly/enemy pet, guardian and totem plates, and the personal resource bar.
- **Overhead names (5):** your own name, titles, guild names, guild ranks and critter names.
- **Camera (3):** bobbing, terrain tilt and water collision.
- **Maps (9):** map cursor coordinates with `/ts where`, a cursor coordinate label, zone level ranges, dungeon entrance notes and waypoints with `/ts dungeon` and `/ts way`, teleport favorites and a teleport panel, taxi node shortcuts with `/ts taxi`, and a flight timer.
- **Character (3):** trainer listings with rank upgrades, capped bulk training, and mana regeneration timing.
- **Quests (9):** a quest list with levels and distance sorting, quest item use with `/ts useq`, quest target with `/ts qtarget`, rested experience reports and a full-rest notice, rare mob alerts, trade and craft summaries, and typed confirmation for settings resets.
- **Chat (20):** mouse-wheel scrolling, persistent text, arrow-key editing without Alt, chat font size, chat bubbles and party bubbles, timestamps, hidden chat window buttons, unclamped chat windows, a whisper sound alert, a configurable chat scrollback length, sticky chat buttons, an optional input line above the chat frame, `/ts copy` for the last chat lines; saved chat history with `/ts chatlog`; saved channels that rejoin after login; class-coloured chat names; a word filter; a whisper notification sound with an optional chat tab flash; and a whisper conversation window with `/ts whisper` and `/ts reply`.

Unsupported CVars appear as **API unavailable** when requested. Enabling a setting means TweakSuite owns the listed value; disabling restores its previous value only if another tool has not changed it. To restore those values before uninstalling, use `/ts reset` outside combat, then log out normally. Merely deleting the addon cannot run restoration code.

## Windows, inventory and tooltips

- **Moving windows** works on the character, spellbook, merchant, quest, gossip, mail, bank, trade, tabard, trainer, pet stable, friends, auction house and world map windows. Shift is required by default so tabs and buttons stay clickable; a left drag without Shift is left to the client. Positions are saved per window and restored when the window opens again. Drags are ignored in combat, and switching the feature off returns each window to where it was before the first move in that session.
- Loot and need/greed roll frames show item levels too, so a roll can be judged before its timer ends; nothing is looted or rolled automatically.
- Character, inspect, bag and bank overlays show `C_Item.GetDetailedItemLevelInfo` for equipped or contained slots. Empty slots, unavailable data and secret values show nothing. The inspect overlay waits for the client's normal inspect data and does not request extra inspection.
- Bag overlays default to the top-left corner so the stack count stays readable. Enable **Include bank** to number the main bank slots and bank bags; the client only knows bank contents after the bank has been opened in this session.
- **Durability percentages** appear in the lower-left corner of character slots and are colored green, yellow (50% or less) or red (20% or less). **Free bag slots** appear on the backpack button and update with bag changes.
- Tooltip lines are added outside combat only, to avoid restricted values. Move the mouse away and hover again after changing a tooltip option.
- **Item count** counts bags by default; enable **Include bank** to add bank contents. Other characters and other accounts are not counted.
- **NPC ID** is shown only for creature and vehicle units, extracted from the standard GUID. Player, pet and game-object tooltips are left alone. Spell and currency IDs require the client to label the tooltip with that data type; otherwise the feature reports **API unavailable**.
- **Tooltip scale** applies a percentage (80-200%) to the game, item, shopping and friend tooltips and restores each tooltip's previous scale when switched off.
- **Sell price** has an option to multiply the price by the item's stack size, showing what a full stack vendors for.
- **Item level comparison** compares the hovered equippable item with the item you are wearing in that slot, including rings, trinkets and two-hand weapons. It never equips or sells anything; an option hides downgrades.
- Saved window positions are validated on load; corrupt or out-of-range entries are discarded instead of breaking a window.
- **Gold recording** stores one total per character while enabled and reports the list with `/ts gold`. It never moves, mails or trades gold, and stale or malformed saved entries are dropped on load.

## Keyboard dialogs

The dialog features are independently opt-in and stay off in combat and while Shift is held.

- **Keyboard accept and continue** clicks only the visible Accept or Continue button on the client's quest frame. It never clicks Decline, Goodbye or a popup confirmation. It also refuses to complete a quest that still offers reward choices, so a reward cannot be turned in by an accidental key press.
- The default key is Space. Change it to Enter, E or a common letter key in the feature's options. Capturing an arbitrary key press is still planned. When no matching dialog button is visible, the key is passed through to the game, so jumping and normal bindings still work.
- The optional key hint appears above the one button the key would press. Turn it off in options.
- **Number keys select quest rewards** clicks the reward icon for 1-6. Selecting a reward does not turn in the quest; you still confirm with the client's own button.
- **Gossip numbers** choose a visible gossip option, but never one that costs money, so a number key cannot buy anything or pay a bribe. Quest acceptance and turn-in stay manual.
- A small invisible keyboard catcher is shown only while one of these features is enabled. It is hidden during combat because the client restricts keyboard-propagation changes in combat. Nothing is clicked in combat.
- Static popups, gossip text, paid gossip options, trainer windows and bonus rolls are not automated.

## Commands

| Command | Purpose |
|---|---|
| `/ts` | Searchable shared settings |
| `/ts help` | Print the command list in chat |
| `/ts on repair` / `/ts off repair` | Switch a named feature on/off; feature IDs appear in settings |
| `/ts set dialogAccept key enter` | Change a feature option; accepts choice labels, on/off, or a number |
| `/ts options dialogAccept` | Print the feature's options, defaults and descriptions in chat |
| `/ts cap 25` | Set personal repair limit to 25 gold per merchant visit; default 10 |
| `/ts pause` | Pause/resume the suite for this session |
| `/ts reset` | Switch every feature off and restore owned settings when possible; options are kept |
| `/ts reset dialogAccept` | Switch one feature off and reset its options to defaults |
| `/ts report` | Copyable client, feature, option, conflict and recent-error report |
| `/ts windows` | Count saved window positions; `list` names the managed windows; `reset [window]` clears one or all |
| `/ts resetoptions` | Reset every feature option to its default without changing on/off states |
| `/ts gold` | Print recorded gold per character and the total across them |
| `/ts copy [lines]` | Open the last 20 (or N) chat lines in a selectable box |
| `/ts bag <text>` | List carried items whose name contains the text |
| `/ts xp` | Print experience gained and the hourly rate |
| `/ts junk <item>` / `/ts unjunk <item>` | Mark or unmark a bag item as junk |
| `/ts neversell [add|remove|clear] <item>` | Manage the merchant never-sell list |
| `/ts except [accept|turnin] <text>` | Manage quest title exceptions |
| `/ts watch <button>` / `/ts watch clear` | Add extra buttons for the dialog key |
| `/ts sell` | List the items the current merchant rules would sell |

Hold **Shift** when opening a merchant or quest dialog to skip automation. Automation also pauses during combat. Junk sale uses Blizzard's bulk operation, including items manually marked as junk. It does not yet have custom exclusions or buyback-cap logic. Quest acceptance can skip daily and repeatable quests through its options; a named never-accept list is still planned. Enable it only when this behavior is wanted. Reward choices remain manual unless you explicitly use the reward number keys to select an icon.

## Migration and conflicts

The preview conservatively blocks overlapping features when another relevant addon is **loaded**. It does not inspect that addon's private settings. Disabling only the other addon's internal toggle will not clear the block in this stage. Disable the overlapping addon and reload in a controlled test session, or leave the TweakSuite feature off for now. There is no override that silently enables competing owners.

Keep the existing addons available until the feature coverage you need has been implemented and tested. Do not disable GTFO or other specialized addons expecting this preview to replace them. The remaining scope is tracked in [ROADMAP.md](ROADMAP.md), [FEATURE-BACKLOG.md](FEATURE-BACKLOG.md), and the machine-readable backlog in `docs/feature-backlog.json`.

## Development and verification

```sh
python -m pip install -r tests/requirements.txt
python tests/run_tests.py
python tools/package.py
```

The tests execute every shipped Lua file using Lupa's **Lua 5.1** runtime. They use a limited mock of WoW's host APIs; they do not reproduce protected execution, real secret values, rendering, live item caches, keyboard focus, or the game server. See [VALIDATION.md](VALIDATION.md) for evidence and the in-game acceptance checklist.

No Lua runtime or Python dependency is required by players. WoW supplies Lua. Lupa is a development-only dependency. The addon performs no network calls, loads no external executable code, and has no always-running polling loop.

## License, credits and project files

TweakSuite is free software under the [GNU General Public License v3.0 or later](LICENSE). Copyright (C) 2026 Malikor. Any later upstream integration must retain provenance and compatible terms; a source addon having a public repository does not grant permission to relicense it. See [SOURCES.md](SOURCES.md) and [CREDITS.md](CREDITS.md).

| File | Contents |
|---|---|
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [DESCRIPTION.md](DESCRIPTION.md) | Short and long store-page descriptions |
| [AUDIT.md](AUDIT.md) | Engineering audit, evidence labels and known limitations |
| [CREDITS.md](CREDITS.md) | Author, contributors, references and asset origins |
| [VALIDATION.md](VALIDATION.md) | Test evidence and the in-game acceptance checklist |
