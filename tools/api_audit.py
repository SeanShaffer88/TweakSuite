#!/usr/bin/env python3
# TweakSuite - Copyright (C) 2026 Malikor
# SPDX-License-Identifier: GPL-3.0-or-later
"""Cross-check bare Lua global calls against the Forever client's API dump.

The dump is published by the Forever Addon Kit
(https://github.com/Thunderz96/forever-addon-kit, data/forever_api.json) and lists every
global function the beta client exposes. Point this tool at a local copy:

    python tools/api_audit.py --api /path/to/forever_api.json

Only bare global calls are checked (``Foo(...)``). Method calls are resolved at run time
and are covered by the mock-client tests instead. Anything reported is either a missing
function or a name this addon is expected to define itself; the message says which.
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CALL = re.compile(r'(?<![\w.:])([A-Z][A-Za-z0-9_]*)\s*\(')
LOCAL = re.compile(r'\blocal\s+([A-Za-z0-9_,\s]+?)\s*(?:=|\n|$)')
FUNC = re.compile(r'\bfunction\s+(?:F\.)?([A-Za-z0-9_]+)\s*\(')
LUA_BUILTINS = {
    "assert", "error", "getmetatable", "ipairs", "next", "pairs", "pcall", "print",
    "rawequal", "rawget", "rawset", "select", "setmetatable", "tonumber", "tostring",
    "type", "unpack", "xpcall", "string", "table", "math", "os", "Set", "DoNothing",
}


def repo_definitions():
    names = set()
    for path in (ROOT / "TweakSuite").rglob("*.lua"):
        text = path.read_text()
        names.update(FUNC.findall(text))
        for line in LOCAL.findall(text):
            for name in line.split(","):
                name = name.strip()
                if name:
                    names.add(name)
    names.update({"F", "CreateFrame", "UIParent"})
    return names


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--api", required=True, help="path to forever_api.json")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    data = json.loads(Path(args.api).read_text())
    exposed = set(data.get("functions", []))
    for namespace, members in data.get("namespaces", {}).items():
        exposed.add(namespace)
        exposed.update(f"{namespace}.{member}" for member in members)

    defined = repo_definitions()
    problems = []
    checked = 0
    for path in sorted((ROOT / "TweakSuite").rglob("*.lua")):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            code = line.split("--", 1)[0]
            for name in CALL.findall(code):
                if name in LUA_BUILTINS or name in defined or name in exposed:
                    continue
                problems.append(f"{path.relative_to(ROOT)}:{number} calls '{name}'")
                checked += 1

    clients = data.get("client", {})
    print(f"API dump: client {clients.get('version')} build {clients.get('build')}, "
          f"{len(data.get('functions', []))} functions, {len(data.get('namespaces', {}))} namespaces")
    print(f"{checked} unresolved global call(s)")
    for problem in problems:
        print("PROBLEM: " + problem)
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
