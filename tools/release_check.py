#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Launch-client regression suite: the checks to run before packaging a release.

1. Every Lua file parses and the whole addon loads in the mock client.
2. The behavioural test suite passes.
3. The backlog and the registered features agree (tools/coverage.py).
4. Licence and asset provenance are clean (tools/provenance.py).
5. Every file listed in the three TOCs exists, and the version string matches.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PYTHON = sys.executable


def run(label, command):
    print(f"== {label}")
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    output = (result.stdout + result.stderr).strip().splitlines()
    for line in output[-4:]:
        print("   " + line)
    return result.returncode == 0


def toc_check():
    print("== TOC consistency")
    problems = []
    versions = set()
    for toc in sorted((ROOT / "ForeverSuite").glob("*.toc")):
        text = toc.read_text()
        version = re.search(r"^## Version:\s*(\S+)", text, re.M)
        if version:
            versions.add(version.group(1))
        for line in text.splitlines():
            if line and not line.startswith("#"):
                path = ROOT / "ForeverSuite" / line.replace("\\", "/")
                if not path.exists():
                    problems.append(f"{toc.name} lists a missing file: {line}")
    core = (ROOT / "ForeverSuite" / "Core.lua").read_text()
    core_version = re.search(r'F\.version\s*=\s*"([^"]+)"', core)
    if core_version:
        versions.add(core_version.group(1))
    if len(versions) > 1:
        problems.append("version strings disagree: " + ", ".join(sorted(versions)))
    for problem in problems:
        print("   PROBLEM: " + problem)
    if not problems:
        print(f"   {len(list((ROOT / 'ForeverSuite').glob('*.toc')))} TOC files consistent at version {sorted(versions)[0] if versions else 'unknown'}")
    return not problems


def main():
    checks = [
        ("Lua load check", run("load check", [PYTHON, "tools/loadcheck.py"])),
        ("Behaviour tests", run("behaviour tests", [PYTHON, "tests/run_tests.py"])),
        ("Backlog coverage", run("backlog coverage", [PYTHON, "tools/coverage.py", "--quiet"])),
        ("Provenance audit", run("provenance", [PYTHON, "tools/provenance.py"])),
    ]
    results = {label: ok for label, ok in checks}
    results["TOC consistency"] = toc_check()
    print()
    failed = [label for label, ok in results.items() if not ok]
    print("release check: " + ("PASS" if not failed else "FAIL - " + ", ".join(failed)))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
