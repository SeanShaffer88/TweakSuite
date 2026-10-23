"""Build a deterministic install ZIP with the addon directory at its root."""
import argparse
import hashlib
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path, default=ROOT / "dist" / "ForeverSuite-0.2.0-alpha.7.zip")
args = parser.parse_args()
args.output.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(args.output, "w", zipfile.ZIP_DEFLATED) as archive:
    entries = [(p, "ForeverSuite/" + p.relative_to(ROOT / "ForeverSuite").as_posix())
               for p in sorted((ROOT / "ForeverSuite").rglob("*")) if p.is_file()]
    entries += [(ROOT / name, "ForeverSuite/" + name) for name in
                ("LICENSE", "README.md", "ROADMAP.md", "FEATURE-BACKLOG.md", "SOURCES.md", "VALIDATION.md")]
    entries += [(p, "ForeverSuite/docs/" + p.name) for p in sorted((ROOT / "docs").glob("*.json"))]
    for source, name in entries:
        info = zipfile.ZipInfo(name, date_time=(2026, 10, 22, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(info, source.read_bytes())
digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
args.output.with_suffix(".zip.sha256").write_text(digest + "  " + args.output.name + "\n")
print(f"Built {args.output.name}: {args.output.stat().st_size} bytes; SHA256 {digest}")
