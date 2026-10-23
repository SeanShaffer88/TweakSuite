#!/usr/bin/env python3
# TweakSuite - Copyright (C) 2026 Malikor
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reconcile the capability backlog with the features registered in the Lua sources.

Every registered feature must be named by at least one backlog row, and every row
marked as implemented must name a feature that really exists. Run it after adding a
feature: it fails loudly instead of letting the documentation drift.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTER = re.compile(r'Register\(\s*"([^"]+)"')


def registered():
    """Load the addon in the mock client and ask it which features exist.

    Reading the sources is not enough: several modules register whole groups of
    features through helpers, so the runtime list is the only complete answer.
    """
    result = subprocess.run([sys.executable, "tests/run_tests.py", "--features"],
                            cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit("could not list features:\n" + result.stderr[-2000:])
    features = []
    for line in result.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) >= 2:
            features.append(parts[1])
    return features


def backlog():
    data = json.loads((ROOT / "docs" / "feature-backlog.json").read_text())
    return data["capabilities"] if isinstance(data, dict) else data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--quiet", action="store_true", help="only print problems")
    args = parser.parse_args()

    features = registered()
    rows = backlog()
    implemented = [row for row in rows if "implemented" in row.get("status", "")]
    scoped = [row for row in rows if row.get("status") == "scoped-out"]
    planned = [row for row in rows if row.get("status") == "planned"]

    problems = []
    for row in implemented:
        key = row.get("feature_key")
        if not key and row.get("implementation"):
            continue
        if not key:
            problems.append(f"{row['id']} is implemented but names no feature_key")
        elif not all(name.strip() in features for name in key.split(",")):
            problems.append(f"{row['id']} names feature '{key}', which is not registered")

    claimed = set()
    for row in implemented:
        for name in (row.get("feature_key") or "").split(","):
            if name.strip():
                claimed.add(name.strip())
    orphans = sorted(set(features) - claimed)
    for feature in orphans:
        problems.append(f"feature '{feature}' is not named by any backlog row")

    if not args.quiet:
        print(f"{len(rows)} backlog rows: {len(implemented)} implemented, {len(scoped)} scoped out, {len(planned)} planned")
        print(f"{len(features)} registered features")
        print(f"{len(orphans)} registered feature(s) without a backlog row")
    for problem in problems:
        print("PROBLEM: " + problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
