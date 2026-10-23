# Credits

## Author
- **Malikor** — TweakSuite design, implementation and maintenance. Copyright (C) 2026 Malikor, released under the MIT License.

## Contributors
- Development assistance: Claude (Anthropic), including the arena-agent build sessions that produced the 0.2.0 series.

## Artwork and media
Every asset below was generated for TweakSuite by a script; no third-party image, font in the addon, sound, or game asset is bundled.

| File | Origin |
|---|---|
| `TweakSuite/Media/Icon.tga` | Original 64×64, 32-bit uncompressed TGA icon (three slider controls on a dark gold-framed tile), drawn procedurally with Pillow. Used by the TOC `IconTexture` and the settings window titles. |
| `media/icon-256.png` | 256×256 rendering of the same icon for documentation and store pages. |
| `media/logo.png` | Original 1200×300 project banner. Lettering rendered with DejaVu Sans (Bitstream Vera derived licence, permits embedding in images); the font itself is not distributed. |

## Reference addons
TweakSuite consolidates ideas from the addons listed in [SOURCES.md](SOURCES.md): Enhance QoL, Leatrix Plus, AdvancedInterfaceOptions, BlizzMove, DialogKey (Numy Edition), DamageTips, GTFO, Max Stack Tooltip, No Bug Report Popups, NoAutoClose, Plumber, Simple Item Levels and Tweaks Forever. Their authors' work informed the feature list and the visual direction. No code, data, artwork or sound from them is included; all implementations are original. Thanks to every one of those authors.

## Platform references
- Blizzard's interface source as mirrored at [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source) (Forever branch), used to verify hook targets and API shapes.
- [Warcraft Wiki](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API) API reference.
- [Forever Addon Kit](https://github.com/Thunderz96/forever-addon-kit) API dump, used by `tools/api_audit.py`.

## Development tools
- [Lupa](https://pypi.org/project/lupa/) (MIT) for running the addon in a real Lua 5.1 interpreter during tests. Development only; not shipped.
- [Pillow](https://python-pillow.org/) for generating the artwork. Development only; not shipped.
