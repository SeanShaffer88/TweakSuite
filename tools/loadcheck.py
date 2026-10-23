#!/usr/bin/env python3
# TweakSuite - Copyright (C) 2026 Malikor
# SPDX-License-Identifier: MIT
"""Parse every addon Lua file with the Lua 5.1 loader the client uses.

This catches syntax errors and typos that the behavioural tests only find when a
particular feature is enabled. It does not need a game client.
"""
import sys
from pathlib import Path

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    check = lua.eval("function(s, n) local f, e = loadstring(s, n); return f ~= nil, e end")
    files = sorted((ROOT / "TweakSuite").rglob("*.lua"))
    bad = 0
    for path in files:
        ok, error = check(path.read_text(), str(path))
        if not ok:
            print("SYNTAX ERROR in", path.relative_to(ROOT), error)
            bad += 1
    print(f"checked {len(files)} files, errors: {bad}")
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
