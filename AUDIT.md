# Engineering audit — TweakSuite 0.3.0-alpha.2

Date: October 22, 2026. Scope: the whole addon (29 Lua files, ~12,200 lines, 227 features plus the minimap button) after the rename from ForeverSuite, plus the changes made in this release.

Evidence labels: **Verified** = exercised under the stated conditions. **Partially verified** = exercised under some conditions (named). **Unverified** = inferred from code, documentation or analogy.

## Results

| Check | Result | Evidence |
|---|---|---|
| Lua 5.1 syntax of every shipped file | Pass | **Verified** — `tools/loadcheck.py`, 29 files, 0 errors |
| Behaviour tests | 196 / 196 pass | **Partially verified** — real Lua 5.1 (Lupa 2.8) against a mock WoW host; not the game client |
| Backlog coverage | 267 rows: 260 implemented, 7 scoped out with reasons, 0 planned; 227 features, none without a row | **Verified** — `tools/coverage.py` |
| Licence headers | All Lua and tool sources carry the `MIT` SPDX header | **Verified** — `tools/provenance.py` |
| Bundled assets | Only TweakSuite's own credited artwork | **Verified** — `tools/provenance.py` with the CREDITS.md rule |
| TOC consistency | 3 TOC files agree on version 0.3.0-alpha.2, Interface 16001, file list | **Verified** — `tools/release_check.py` |
| Icon file | 64×64, 32-bit, uncompressed TGA (type 2) | **Verified** — header inspected; in-game display **Unverified** |
| Global API use | See next section | **Partially verified** — static audit against an older dump |
| In-game behaviour on beta and launch clients | Not yet run | **Unverified** — needs the VALIDATION.md checklist |

## Defects found and fixed in this release

1. **Compatibility shims polluted the global table (high impact on other addons).** `Compat.lua` installed Classic-era globals such as `GetContainerItemInfo`, `UnitAura`, `GetQuestLogTitle` and `GetGossipOptions` when Forever lacked them. Other addons commonly test for those globals to choose an older code path, and `GetContainerItemInfo` returned a table where older callers expect positional values, so this could break unrelated bag, quest and aura addons. Fix: shims are private (`F.compat`); modules alias only what they use via `F.Compat(name)`. A test fails if any shim reaches `_G` (mutation-checked).
2. **Free quest turn-in could ignore a money requirement.** The `GetQuestRequiredMoney` shim read the quest *log* selection rather than the quest open at the NPC, so the "no money requirement" guard could pass for a quest that needs gold. Fix: use `GetQuestMoneyToGet`, which the Forever API dump lists. Covered by a new test.
3. **TweakSuite's window closed whenever Options closed.** Closing Options returns to the game menu, which closes every frame in `UISpecialFrames`. Fix: TweakSuite windows handle Escape themselves and join `UISpecialFrames` only during combat (when keyboard propagation cannot be changed). Covered by new tests; in-game behaviour **Unverified**.
4. **Running ForeverSuite and TweakSuite together would apply every tweak twice.** Fix: a previous-name guard blocks every TweakSuite feature while ForeverSuite is loaded. Covered by a new test.

## Static API audit

`tools/api_audit.py --api forever_api.json` (Forever Addon Kit dump: client 1.60.1 build 69893, interface 16001; kit commit 8dc2976, September 25, 2026). The installed clients are build 70532, so a newer build may add or remove functions.

After the fixes, the remaining reports fall into three groups:
- **Guarded fallbacks (safe):** calls such as `GetContainerNumSlots`, `UseContainerItem` and `DeclineInvite` only run when the modern `C_Container` / `C_PartyInfo` path is missing.
- **False positives:** capitalised words inside strings (`Poor(`, `Level(`, `Bottom(`, `CVar(`, `NUMPAD(`).
- **Features that will report "API unavailable" on Forever:** the trade/craft reagent summary uses `GetTradeSkill*` globals, which the dump does not list. The feature disables itself instead of erroring; a `C_TradeSkillUI` port is a follow-up.

## Architecture review (unchanged in this release)

- One registry owns feature IDs, options, conflicts, lifecycle and diagnostics; every feature is opt-in and fault-isolated (`pcall` around handlers; a failing feature disables itself for the session and appears in `/ts report`).
- Owned client settings (CVars and frame state) record the previous value and restore it only if nothing else changed it since.
- Combat: automation and frame changes defer to `PLAYER_REGEN_ENABLED`; the keyboard catcher hides on combat entry without calling restricted functions in combat.
- Secret values: client values are checked with `issecretvalue` before arithmetic or comparison.
- No network access, no loading of external code, no always-on polling loop.

## Known limitations

- **No in-game verification yet** on either client. Taint, protected-frame behaviour, real item-cache ordering, secret values in live combat, gamepad navigation, rendering and performance are not reproduced by the mock.
- 7 backlog capabilities are scoped out with written reasons (context-menu links, dungeon floor maps, fog-of-war reveal, external route planners, Questie tooltip integration, item-API quest-start markers, friendly-fire warnings) — see FEATURE-BACKLOG.md.
- Settings do not migrate from ForeverSuite (new saved-variables name) or between the beta and launch clients.
- The trade/craft summary is unavailable on Forever until it is ported to `C_TradeSkillUI`.
- The API dump used for the static audit predates the installed client build.
- Overlapping-addon detection checks whether an addon is loaded, not which of its options are on.

## Recommended next steps
1. Run the VALIDATION.md checklist on `_classic_beta_`, starting with `/ts`, the icon on the AddOns screen and one feature per category.
2. Capture `/ts report` and BugSack output for anything that misbehaves.
3. Port the trade/craft summary to `C_TradeSkillUI`.
