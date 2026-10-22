# ForeverSuite staged delivery

## Product contract

Sean requested the full distinct feature sets of Enhance QoL, Leatrix Plus, AdvancedInterfaceOptions, BlizzMove, DialogKey, DamageTips, GTFO, Max Stack Tooltip, No Bug Report Popups, NoAutoClose, Plumber, Simple Item Levels, and Tweaks Forever. Preserve breadth; consolidate actual duplicates. Every feature must be independently configurable. Preserve meaningful variants and filters rather than reducing rich features to a single checkbox.

The target is both Forever beta and the launch client. This does not promise Retail or Classic support. A feature unavailable in Forever must have a recorded reason, such as absent game content or a restricted API, and remain tracked for reevaluation. Never silently drop it from scope.

The interface must remain organized and transparent as coverage grows. Use category navigation, global search, visible status, and per-setting Details. Every setting must describe its effect in plain language, default state, disable/restore behavior, triggers and exceptions, conflicts and client availability. Advanced controls need units, valid ranges, examples and reset behavior. Do not hide consequential effects behind vague names such as "smart" or "enhanced". Keep new features discoverable without forcing users to enable whole bundles.

Use Leatrix Plus as the visual inspiration: a restrained dark brown/gold palette, flat left navigation, a simple Home page and compact grouped checkboxes. Preserve global search and transparent help as the suite becomes larger. Reimplement the visual design independently; do not copy its proprietary UI code or assets.

## Stages and exit criteria

1. **Shared foundation and first tweaks — implemented preview.** Search, per-feature state, conflict reporting, schema validation, session pause, fault isolation, owned CVar restoration, 36 initial toggles, package and dual-client installer. Exit: local tests plus in-game smoke test on both clients when playable. Current status: local tests passed; in-game checks pending.
2. **Windows, dialogs and presentation.** Movable/scalable Blizzard windows with saved layouts, coordinated panel lifetimes, keep-windows-open exceptions, keyboard dialog handling, selective beta report controls, bags/character/inspect item levels, tooltip positioning and styles. Exit: mouse/gamepad, combat transitions, reload, delayed addon loading and protected frame checks; restore and reset tested.
3. **Automation and character workflow.** Full merchant rules and exclusions, guild repair policy, quest/gossip filters, trusted social actions, chat tools, minimap collection, maps/travel, trainer/spellbook helpers, equipment groups, fishing and pet care. Exit: explicit opt-in for consequential actions, exceptions and cancellation verified, localization and cache-miss tests.
4. **Specialized systems.** DamageTips-equivalent spell efficiency with documented calculations; GTFO-equivalent allowed warning mechanisms, independently sourced hazard data and sounds; Plumber-style merchant/loot/currency/difficulty tools; resource bars, cursor tools, unit frames and cooldown views where allowed. Exit: use sanctioned APIs, no secret-value arithmetic or combat-log assumptions; fixture tests and real encounter comparisons. These are substantial systems, not checkboxes pretending to be complete.
5. **Coverage, migration and release.** Profiles, import/export with validation, feature-by-feature migration, localization, performance profiling, controller layouts, accessible settings and complete coverage audit. A source addon is considered replaceable only when each relevant capability is implemented and validated or explicitly classified as unavailable on the target client. Final release requires both launch client verification and a provenance/license audit.

## Architecture rules

- One feature registry owns IDs, configuration, capability checks, conflicts, lifecycle and diagnostics.
- Prefer events and shared handlers. Idle modules must not poll. Shared tooltip and frame services avoid duplicate hooks.
- Register hooks once; gate their behavior dynamically. Operations touching protected state are deferred outside combat.
- Feature failure must be visible and bounded. Do not globally suppress Lua errors to conceal suite defects.
- Restore only values the suite still owns; do not undo another addon's later changes.
- No automatic arbitrary reward selection, item destruction, paid gossip, talent choices or macro rewrites without an explicit feature contract and opt-in.
- Maintain compatibility adapters per actual API capability. Interface 16001 is modern Forever, not the old Classic API surface.
- Beta-specific features are optional and become unavailable cleanly on clients without beta UI.
- Reuse licensed code only after checking the exact file/version and dependencies. All-rights-reserved code and proprietary assets are not bundled by default. GNU GPL integrations may require changing distribution terms; retain notices and corresponding source.

## Coverage audit method

`docs/source-options.json` is a mechanical index of setting identifiers and module filenames in the installed reference versions, not a count of finished features. It deliberately contains candidates that may be internal state, styling parameters, duplicates, or Retail-only features. The curated backlog groups the major capabilities. Before claiming full parity, every candidate must be reviewed and mapped to a feature, parameter, duplicate, unsupported item, or irrelevant implementation detail. Leatrix was not installed in the inspected folder, so its baseline currently comes from its author-published feature page and needs a versioned source/options audit.
