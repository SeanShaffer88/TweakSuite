#!/usr/bin/env python3
"""Update backlog rows, feature counts and version strings in one pass.

Usage: python tools/update_docs.py --version 0.2.0-alpha.8 --features 138 [--tests 122]
Rows are read from a small JSON map on the command line via --rows file.json.
Keep this tool in sync with the manual edits it replaces; it only touches counts,
version strings and the status columns of the rows named in the map.
"""
import argparse, json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATUS = "implemented-preview; in-game validation pending"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--features", type=int, required=True)
    parser.add_argument("--tests", type=int)
    parser.add_argument("--rows", help="JSON file mapping FS-id to {feature_key, detail}")
    args = parser.parse_args()

    rows = {}
    if args.rows:
        rows = json.loads(Path(args.rows).read_text())

    backlog = ROOT / "docs" / "feature-backlog.json"
    items = json.loads(backlog.read_text())
    by_id = {item["id"]: item for item in items}
    for ident, payload in rows.items():
        if ident not in by_id:
            raise SystemExit("unknown backlog row: " + ident)
        item = by_id[ident]
        item["status"] = payload.get("status", STATUS)
        if payload.get("feature_key"):
            item["feature_key"] = payload["feature_key"]
        item["detail"] = payload["detail"]
    backlog.write_text(json.dumps(items, indent=2) + "\n")
    implemented = sum(1 for item in items if "implemented" in item["status"])
    scoped = sum(1 for item in items if item["status"] == "scoped-out")

    markdown = ROOT / "FEATURE-BACKLOG.md"
    text = markdown.read_text()
    labels = {"implemented-preview; in-game validation pending": "Preview; game test pending",
              "scoped-out": "Scoped out; see note"}
    for ident, payload in rows.items():
        label = labels.get(payload.get("status", STATUS), "Preview; game test pending")
        pattern = re.compile(r"^\| " + ident + r" \| (.*?) \| (\d) \| .*? \|$", re.M)
        text = pattern.sub(lambda m: "| %s | %s | %s | %s |"
                           % (ident, m.group(1), m.group(2), label), text)
    text = re.sub(r"^\d+ tracked capabilities: \d+ implemented and \d+ planned[,.]",
                  "%d tracked capabilities: %d implemented, %d scoped out with a reason and %d planned."
                  % (len(items), implemented, scoped, len(items) - implemented - scoped), text, count=1, flags=re.M)
    text = re.sub(r"The shipped preview has \d+ independently configurable features;",
                  "The shipped preview has %d independently configurable features;" % args.features,
                  text, count=1)
    markdown.write_text(text)

    for name in ("ForeverSuite/Core.lua", "ForeverSuite/ForeverSuite.toc",
                 "ForeverSuite/ForeverSuite_Camelot.toc", "ForeverSuite/ForeverSuite_Forever.toc",
                 "tools/package.py"):
        path = ROOT / name
        content = path.read_text()
        content = re.sub(r"0\.2\.0-alpha\.\d+", args.version, content)
        path.write_text(content)

    readme = ROOT / "README.md"
    content = readme.read_text()
    content = re.sub(r"\*\*0\.2\.0-alpha\.\d+ continues", "**%s continues" % args.version, content)
    content = re.sub(r"## Available now \(\d+ features, (\d+) categories\)",
                     "## Available now (%d features, \\1 categories)" % args.features, content)
    readme.write_text(content)

    validation = ROOT / "VALIDATION.md"
    content = validation.read_text()
    content = re.sub(r"`0\.2\.0-alpha\.\d+`", "`%s`" % args.version, content)
    if args.tests:
        content = re.sub(r"- \d+ behavioral test methods passed",
                         "- %d behavioral test methods passed" % args.tests, content)
    validation.write_text(content)
    print("implemented %d of %d; version %s" % (implemented, len(items), args.version))

if __name__ == "__main__":
    main()
