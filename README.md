# ForeverSuite

A comprehensive, modular quality-of-life addon for **World of Warcraft: Forever**, combining overlapping ideas into one settings surface while retaining distinct useful features. The goal is broad feature coverage across all 13 requested addons, delivered in stages. There is no target cap on the number of tweaks.

**0.2.0-alpha.1 starts Stage 2 with 44 opt-in features: the 36 Stage 1 settings plus keyboard dialogs, character/inspect item levels and four more tooltip lines. It is not yet a replacement for the complete source addon collection.** Stage 2 is incomplete: window movement, bag/bank overlays, beta report controls and most tooltip styling remain planned. Original code; no other addons or their assets are bundled. Beta and preinstalled launch client executables were both observed at 1.60.1.70532 on October 22, 2026. Gameplay and visual verification are still pending.

## Install and open

Extract the release ZIP into the intended client's `Interface/AddOns` folder. The final path must end in `Interface/AddOns/ForeverSuite/ForeverSuite.toc`.

- Beta client folder: `_classic_beta_`.
- Launch client folder: `_forever_`.
- Restart the game after installing. Enable **ForeverSuite** on the AddOns screen, then type `/fs`.
- Every feature starts off. Browse categories or search across all settings, tick a feature, and read its status.
- **Details** explains what the setting changes, its default, what switching it off does, combat behavior and overlapping addons. CVar options also identify the underlying client setting. Search works across categories.
- Features with variants show an **Opt** button. It opens a per-feature options panel with the current value, the default, valid choices or ranges, and a reset button. Options never switch a feature on by themselves.
- The interface takes visual inspiration from Leatrix Plus: a dark brown window, gold headings, a flat category sidebar, a Home page and compact grouped checkboxes. Short explanations stay beside controls; hover or click **?** for the complete setting details. The implementation and layout code are original.
- The same package targets both clients. Each client maintains its own SavedVariables. This preview does not migrate settings between them.

Optional PowerShell installer, from the source repository:

```powershell
.\tools\install.ps1 -ClientPath 'your WoW directory\_classic_beta_'
.\tools\install.ps1 -ClientPath 'your WoW directory\_forever_' -Install
```

Without `-Install`, it only checks the selected client. It refuses to overwrite an existing ForeverSuite folder or copy while WoW is running. It does not modify other addons or saved settings.

## Available now

- **Automation (5):** personal-gold repairs with a configurable cap, native Sell All Junk, faster auto-looting, accepting quests, turning in quests with no reward choices and no money requirement.
- **Dialogs (2):** a configurable key (Space, Enter or E) presses the visible Accept/Continue button, with an optional key hint; number keys 1-6 select a quest reward without turning the quest in.
- **Tooltips (7):** maximum stack size, item ID, actual equipment item level, owned count, spell ID, NPC ID and currency ID.
- **Inventory (2):** actual item levels on equipped character-panel slots and on the inspect panel, with configurable text position and size.
- **Interface (8):** auto-loot default, cast on key down, instant quest text, full-screen glow, low-health flash, target of target, loot history and spell activation artwork.
- **Nameplates (9):** visibility, stacking, class colors, friendly/enemy pet, guardian and totem plates, and the personal resource bar.
- **Overhead names (5):** your own name, titles, guild names, guild ranks and critter names.
- **Camera (3):** bobbing, terrain tilt and water collision.
- **Chat (3):** mouse-wheel scrolling, persistent text and arrow-key editing without Alt.

Unsupported CVars appear as **API unavailable** when requested. Enabling a setting means ForeverSuite owns the listed value; disabling restores its previous value only if another tool has not changed it. To restore those values before uninstalling, use `/fs reset` outside combat, then log out normally. Merely deleting the addon cannot run restoration code.

## Keyboard dialogs

The dialog features are independently opt-in and stay off in combat and while Shift is held.

- **Keyboard accept and continue** clicks only the visible Accept or Continue button on the client's quest frame. It never clicks Decline, Goodbye or a popup confirmation. It also refuses to complete a quest that still offers reward choices, so a reward cannot be turned in by an accidental key press.
- The default key is Space. Change it to Enter or E in the feature's options. When no matching dialog button is visible, the key is passed through to the game, so jumping and normal bindings still work.
- The optional key hint appears above the one button the key would press. Turn it off in options.
- **Number keys select quest rewards** clicks the reward icon for 1-6. Selecting a reward does not turn in the quest; you still confirm with the client's own button.
- A small invisible keyboard catcher is shown only while one of these features is enabled. It is hidden during combat because the client restricts keyboard-propagation changes in combat. Nothing is clicked in combat.
- Static popups, gossip text, paid gossip options, trainer windows and bonus rolls are not automated.

## Inventory and tooltips

- Character and inspect overlays show `C_Item.GetDetailedItemLevelInfo` for equipped slots. Empty slots, unavailable data and secret values show nothing. The inspect overlay waits for the client's normal inspect data and does not request extra inspection.
- Bag, bank, loot and equipment-flyout overlays are still planned; only the character and inspect panels are covered in this build.
- Tooltip lines are added outside combat only, to avoid restricted values. Move the mouse away and hover again after changing a tooltip option.
- **Item count** counts bags by default; enable **Include bank** to add bank contents. The client only knows bank contents after the bank has been opened in the session. Other characters and other accounts are not counted.
- **NPC ID** is shown only for creature and vehicle units, extracted from the standard GUID. Player, pet and game-object tooltips are left alone. Spell and currency IDs require the client to label the tooltip with that data type; otherwise the feature reports **API unavailable**.

## Commands

| Command | Purpose |
|---|---|
| `/fs` | Searchable shared settings |
| `/fs on repair` / `/fs off repair` | Switch a named feature on/off; feature IDs appear in settings |
| `/fs set dialogAccept key enter` | Change a feature option; accepts choice labels, on/off, or a number |
| `/fs options dialogAccept` | Print the feature's options, defaults and descriptions in chat |
| `/fs cap 25` | Set personal repair limit to 25 gold per merchant visit; default 10 |
| `/fs pause` | Pause/resume the suite for this session |
| `/fs reset` | Switch every feature off and restore owned settings when possible; options are kept |
| `/fs reset dialogAccept` | Switch one feature off and reset its options to defaults |
| `/fs report` | Copyable client, feature, option, conflict and recent-error report |

Hold **Shift** when opening a merchant or quest dialog to skip automation. Automation also pauses during combat. Junk sale uses Blizzard's bulk operation, including items manually marked as junk. It does not yet have custom exclusions or buyback-cap logic. Quest acceptance has no exception list yet; enable it only when this behavior is wanted. Reward choices remain manual unless you explicitly use the reward number keys to select an icon.

## Migration and conflicts

The preview conservatively blocks overlapping features when another relevant addon is **loaded**. It does not inspect that addon's private settings. Disabling only the other addon's internal toggle will not clear the block in this stage. Disable the overlapping addon and reload in a controlled test session, or leave the ForeverSuite feature off for now. There is no override that silently enables competing owners.

Keep the existing addons available until the feature coverage you need has been implemented and tested. Do not disable GTFO or other specialized addons expecting this preview to replace them. The remaining scope is tracked in [ROADMAP.md](ROADMAP.md), [FEATURE-BACKLOG.md](FEATURE-BACKLOG.md), and the machine-readable backlog in `docs/feature-backlog.json`.

## Development and verification

```sh
python -m pip install -r tests/requirements.txt
python tests/run_tests.py
python tools/package.py
```

The tests execute every shipped Lua file using Lupa's **Lua 5.1** runtime. They use a limited mock of WoW's host APIs; they do not reproduce protected execution, real secret values, rendering, live item caches, keyboard focus, or the game server. See [VALIDATION.md](VALIDATION.md) for evidence and the in-game acceptance checklist.

No Lua runtime or Python dependency is required by players. WoW supplies Lua. Lupa is a development-only dependency. The addon performs no network calls, loads no external executable code, and has no always-running polling loop.

MIT for this original implementation. Any later licensed upstream integration must retain provenance and compatible terms; a source addon having a public repository does not grant permission to relicense it. See [SOURCES.md](SOURCES.md).
