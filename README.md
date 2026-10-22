# ForeverSuite

A comprehensive, modular quality-of-life addon for **World of Warcraft: Forever**, combining overlapping ideas into one settings surface while retaining distinct useful features. The goal is broad feature coverage across all 13 requested addons, delivered in stages. There is no target cap on the number of tweaks.

**0.1.0-alpha.1 is Stage 1, with 36 opt-in features. It is not yet a replacement for the complete source addon collection.** Original code; no other addons or their assets are bundled. Beta and preinstalled launch client executables were both observed at 1.60.1.70532 on October 22, 2026. Gameplay and visual verification are still pending.

## Install and open

Extract the release ZIP into the intended client's `Interface/AddOns` folder. The final path must end in `Interface/AddOns/ForeverSuite/ForeverSuite.toc`.

- Beta client folder: `_classic_beta_`.
- Launch client folder: `_forever_`.
- Restart the game after installing. Enable **ForeverSuite** on the AddOns screen, then type `/fs`.
- Every feature starts off. Browse categories or search across all settings, tick a feature, and read its status.
- **Details** explains what the setting changes, its default, what switching it off does, combat behavior and overlapping addons. CVar options also identify the underlying client setting. Search works across categories.
- The same package targets both clients. Each client maintains its own SavedVariables. This preview does not migrate settings between them.

Optional PowerShell installer, from the source repository:

```powershell
.\tools\install.ps1 -ClientPath 'your WoW directory\_classic_beta_'
.\tools\install.ps1 -ClientPath 'your WoW directory\_forever_' -Install
```

Without `-Install`, it only checks the selected client. It refuses to overwrite an existing ForeverSuite folder or copy while WoW is running. It does not modify other addons or saved settings.

## Available now

- **Automation (5):** personal-gold repairs with a configurable cap, native Sell All Junk, faster auto-looting, accepting quests, turning in quests with no reward choices and no money requirement.
- **Tooltips (3):** maximum stack, item ID, actual equipment item level. Tooltips are augmented outside combat; overlays are not implemented yet.
- **Chat (2):** persistent text, arrow-key editing without Alt.
- **Interface (26):** auto-loot default, cast on key down, instant quest text, glow and low-health flash controls, nameplate layout/visibility/class colors, personal resource bar, target of target, overhead names/titles/guilds, camera motion/water options, chat wheel, automatic loot history, spell activation artwork.

Unsupported CVars appear as **API unavailable** when requested. Enabling a setting means ForeverSuite owns the listed value; disabling restores its previous value only if another tool has not changed it. To restore those values before uninstalling, use `/fs reset` outside combat, then log out normally. Merely deleting the addon cannot run restoration code.

## Commands

| Command | Purpose |
|---|---|
| `/fs` | Searchable shared settings |
| `/fs on repair` / `/fs off repair` | Switch a named feature on/off; feature IDs appear in settings |
| `/fs cap 25` | Set personal repair limit to 25 gold per merchant visit; default 10 |
| `/fs pause` | Pause/resume the suite for this session |
| `/fs reset` | Switch every feature off and restore owned settings when possible |
| `/fs report` | Copyable client, feature, conflict and recent-error report |

Hold **Shift** when opening a merchant or quest dialog to skip automation. Automation also pauses during combat. Junk sale uses Blizzard's bulk operation, including items manually marked as junk. It does not yet have custom exclusions or buyback-cap logic. Quest acceptance has no exception list yet; enable it only when this behavior is wanted. Reward choices remain manual.

## Migration and conflicts

The preview conservatively blocks overlapping features when another relevant addon is **loaded**. It does not inspect that addon's private settings. Disabling only the other addon's internal toggle will not clear the block in this stage. Disable the overlapping addon and reload in a controlled test session, or leave the ForeverSuite feature off for now. There is no override that silently enables competing owners.

Keep the existing addons available until the feature coverage you need has been implemented and tested. Do not disable GTFO or other specialized addons expecting this preview to replace them. The remaining scope is tracked in [ROADMAP.md](ROADMAP.md), [FEATURE-BACKLOG.md](FEATURE-BACKLOG.md), and the machine-readable backlog in `docs/feature-backlog.json`.

## Development and verification

```sh
python -m pip install -r tests/requirements.txt
python tests/run_tests.py
python tools/package.py
```

The tests execute every shipped Lua file using Lupa's **Lua 5.1** runtime. They use a limited mock of WoW's host APIs; they do not reproduce protected execution, real secret values, rendering, live item caches, or the game server. See [VALIDATION.md](VALIDATION.md) for evidence and the in-game acceptance checklist.

No Lua runtime or Python dependency is required by players. WoW supplies Lua. Lupa is a development-only dependency. The addon performs no network calls, loads no external executable code, and has no always-running polling loop.

MIT for this original Stage 1 implementation. Any later licensed upstream integration must retain provenance and compatible terms; a source addon having a public repository does not grant permission to relicense it. See [SOURCES.md](SOURCES.md).
