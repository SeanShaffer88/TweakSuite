# Validation record — October 22, 2026

Status: development preview, not a completed replacement or gameplay-validated release.

## Performed

- Both installed client build metadata rows: 1.60.1.70532. Beta and launch are separate installation targets.
- All shipped Lua source parsed and executed in Lua 5.1 via Lupa 2.8 on Windows x64 / CPython 3.12.
- 24 behavioral test methods passed, including a subtest for each of the 26 CVar-backed features.
- Covered: inert defaults, settings schema validation and preservation, unsupported-client guard, repair budget and personal funds, Shift/combat suppression, loaded and late-loaded addon conflicts, opt-in junk sale, auto-loot mode, reward choice/money preservation, pause/resume, CVar restoration and external edits, saved ownership after restart, unavailable/refused APIs, event error isolation, tooltip duplicate control/cache readiness/secret-value guard, chat restoration/new windows, search and diagnostic report UI construction.
- Category navigation, cross-category search and per-setting effect/default/restore/conflict explanations passed mock UI tests. The UI mock catches missing methods in its defined host surface; it does not prove WoW's exact widget behavior or visual layout.

## Before enabling broadly

Perform separately in `_classic_beta_` and `_forever_` once each can be played. The launch client being preinstalled is not evidence of a successful login or gameplay test.

1. Start with all original addons available and ForeverSuite features off. Confirm `/fs`, search, scrolling, checkboxes, Escape, moving the settings window, and the report's copy box. Test at the user's UI scale and resolution.
2. Choose a small feature group; disable the conflicting reference addon for that test and reload. Verify conflict status changes. Do not remove its saved settings.
3. Test stackable/nonstackable/uncached item tooltips; equipment with different actual item levels; repeated hovering; comparison tooltips; combat entry/exit. Ensure no duplicate suite lines or Lua errors.
4. Test repair with enough/insufficient funds and below/above the cap; Shift override; merchant with no repair; junk with an explicitly marked item. Verify actual buyback behavior and do not assume unlimited recovery.
5. Test quest reading with Shift, zero/one/multiple choice rewards, a quest requiring money, autoaccept quests, and combat transitions. Only the documented zero-choice free hand-in is automated.
6. Toggle interface settings individually. Confirm visual effect, restore behavior and another addon's external changes. Turn features off before uninstalling. Test normal logout/restart persistence independently in both clients.
7. Capture `/fs report` and actual errors through the existing BugGrabber/BugSack setup. Do not suppress Lua errors as a substitute for fixing them.
8. Record client build, feature IDs, locale, UI mode, outcome, taint/error evidence and performance observations. No character/account data is required for a public issue.

Combat lockdown, client secrets, real item-cache event ordering, Lua taint, gamepad navigation and secure frame behavior are not emulated by the tests. Settings rendering, memory/CPU performance and encounter correctness remain unmeasured in game.
