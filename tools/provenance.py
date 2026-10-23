#!/usr/bin/env python3
# TweakSuite - Copyright (C) 2026 Malikor
# SPDX-License-Identifier: MIT
"""License and asset provenance audit.

Checks that every Lua and Python source carries the project's SPDX header, that the only
binary assets are TweakSuite's own generated artwork in TweakSuite/Media (each one must be
listed in CREDITS.md with its origin), and that the licence file and the source list in the
validation notes exist. Run it before packaging a release.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPDX = "SPDX-License-Identifier: MIT"
BINARY_SUFFIXES = {".blp", ".tga", ".m2", ".wav", ".mp3", ".ogg", ".ttf", ".otf", ".dll", ".exe", ".psd"}
TEXT_SUFFIXES = {".lua", ".py", ".md", ".toc", ".json", ".txt", ".yml", ".yaml", ".ps1", ".sha256"}
SKIP_DIRS = {".git", ".venv", "dist", "__pycache__", "node_modules"}
SKIP_FILES = {".gitattributes", ".gitignore"}


def main():
    problems = []
    lua_files = sorted((ROOT / "TweakSuite").rglob("*.lua"))
    for path in lua_files:
        head = path.read_text(errors="replace")[:400]
        if SPDX not in head:
            problems.append(f"{path.relative_to(ROOT)} has no {SPDX} header")
    for path in sorted((ROOT / "tools").glob("*.py")):
        if SPDX not in path.read_text(errors="replace")[:400]:
            problems.append(f"{path.relative_to(ROOT)} has no {SPDX} header")

    credits_file = ROOT / "CREDITS.md"
    credits = credits_file.read_text(errors="replace") if credits_file.exists() else ""
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT).as_posix()
        if any(part in SKIP_DIRS for part in Path(relative).parts):
            continue
        if path.name in SKIP_FILES:
            continue
        if path.suffix.lower() in BINARY_SUFFIXES or path.suffix.lower() == ".png":
            own_art = relative.startswith(("TweakSuite/Media/", "media/")) and path.suffix.lower() in (".tga", ".png")
            if not own_art:
                problems.append(f"{relative} is a binary asset outside TweakSuite/Media and media/")
            elif path.name not in credits:
                problems.append(f"{relative} is not listed in CREDITS.md")
        elif path.suffix.lower() not in TEXT_SUFFIXES and path.name not in ("LICENSE", ".gitignore"):
            problems.append(f"{relative} is an unexpected file type")

    for required in ("LICENSE", "VALIDATION.md", "docs/feature-backlog.json", "CREDITS.md", "CHANGELOG.md"):
        if not (ROOT / required).exists():
            problems.append(f"{required} is missing")

    print(f"{len(lua_files)} Lua files checked for the SPDX header")
    for problem in problems:
        print("PROBLEM: " + problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
