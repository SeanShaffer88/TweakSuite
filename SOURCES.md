# Sources, provenance and scope

Checked October 22, 2026. Installed addon metadata and selected code/API signatures were inspected read-only. No upstream addon code, sound, artwork, or game asset is included in this build. The original implementations use public host API calls and independent control flow. Stage 2 additions (typed feature options, keyboard dialog handling, item-level overlays and tooltip identifiers) were implemented independently from public client API documentation and the reference addons' published feature descriptions, not copied from their code.

| Requested addon | Reference baseline | Observed reuse terms / next step | Main destination |
|---|---|---|---|
| [Enhance QoL](https://www.curseforge.com/wow/addons/eqol) | 13.15.3 plus installed submodules | Author page: All Rights Reserved; original implementations | Broad automation, UI, inventory, chat, frames |
| [Leatrix Plus](https://www.curseforge.com/wow/addons/leatrix-plus) | Author page Forever 1.60.25; not installed | All Rights Reserved; original implementations | QoL, chat, media, UI and automation |
| [AdvancedInterfaceOptions](https://github.com/Stanzilla/AdvancedInterfaceOptions) | 2.1.14 | Author listing: All Rights Reserved; original CVar UI | Advanced settings and discovery |
| [BlizzMove](https://github.com/Kiatra/BlizzMove) | v3.8.5 | Project-specific reuse grant not verified; bundled library licenses are separate | Windows and layouts |
| [DialogKey — Numy Edition](https://github.com/NumyAddon/DialogKey_Numy) | v1.2.62 | GPLv3; behavior reference only, no code copied; exact port and dependencies need review before reuse | Keyboard dialogs and reward selection |
| [DamageTips](https://www.curseforge.com/wow/addons/damagetips) | Installed 1.4.0; page indexed 1.3.0 | Installed GPL-3.0-or-later | Spell tooltip calculations |
| [GTFO](https://www.curseforge.com/wow/addons/gtfo/source) | 6.12.2; Forever TOC uses Retail adapter | All Rights Reserved; independently implement or obtain permission for reused data/assets | Hazard warnings |
| [Max Stack Tooltip](https://www.curseforge.com/wow/addons/max-stack-tooltip) | 1.0 | Author page: All Rights Reserved; independent small implementation | Stack tooltip |
| No Bug Report Popups by Malikor | Installed NoBugReport 1.0.3 | Installed GPL-3.0 license; exact public project URL unresolved | Selective beta feedback controls |
| [NoAutoClose](https://github.com/NumyAddon/NoAutoClose) | v1.3.47 | Installed metadata: All Rights Reserved | Window lifetime policy |
| [Plumber](https://github.com/Peterodox/Plumber) | 1.9.6 d | GPLv3; assets and optional integrations require separate inspection | Merchant, loot, currency, travel and contextual tools |
| [Simple Item Levels](https://github.com/kemayo/wow-simpleitemlevel) | v74.1 | BSD reported by metadata and author listing; behavior reference only, no code copied; exact notice needed before copying | Item overlays and upgrade indicators |
| [Tweaks Forever](https://github.com/cjber/tweaks-forever) | v0.15.2 | GPL-3.0-or-later, with separately sourced data | Forever-specific automation and UI |

Licenses above are evidence notes, not a comprehensive legal review. Each future copied component needs exact license text, source ref, modifications and bundled dependency/asset provenance. A permissive library inside an addon does not license the surrounding addon.

## Platform and development references

- [Leatrix Plus author's gallery](https://www.curseforge.com/wow/addons/leatrix-plus/gallery): `snap6.jpg` inspected as a visual reference for sidebar navigation, gold text, dark background and a simple Home page. This is a historical screenshot; no claim that it depicts today's Forever build. No Leatrix image, code or asset is distributed.

- [Blizzard Forever product page](https://worldofwarcraft.blizzard.com/en-us/forever).
- [Blizzard UI source mirror, Forever branch](https://github.com/Gethe/wow-ui-source/tree/forever), inspected at `ca8368f2f2380cbe696854f7f2646387c278a61b`: generated MerchantFrame, CVar and Item API definitions, tooltip and loot UI. This is a third-party mirror of Blizzard material, not a permissively licensed dependency. A matching interface does not prove every source file matches the local executable build.
- [Tweaks Forever author repository](https://github.com/cjber/tweaks-forever): contemporary Forever feature and compatibility reference.
- [Atraeau's generated Forever API reference](https://atraeau.github.io/WoW-Addons/): useful secondary generated index; recheck against the live client.
- [Thunderz96's beta findings](https://github.com/Thunderz96/forever-addon-kit): historical first-week observations. Some documented bugs were subsequently fixed; do not treat the entire snapshot as current.
- [Lua 5.1 reference](https://www.lua.org/manual/5.1/) and [Lua license](https://www.lua.org/license.html).
- [Lupa 2.8](https://pypi.org/project/lupa/): MIT-style Python/Lua wrapper, Windows CPython 3.12 wheel used only in development; Lua 5.1 test runtime selected explicitly. Not included in the install ZIP.

Online checks found stale indexed versions in some pages. The baseline table prefers the installed TOC when available. Feature inventories inspect addon distribution files only, never account SavedVariables or character data.
