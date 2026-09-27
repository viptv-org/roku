"""Create the installable Roku runtime archive from a BrighterScript staging tree."""

import argparse
import hashlib
from pathlib import Path
import zipfile


parser = argparse.ArgumentParser()
parser.add_argument("--output-dir", type=Path, help="New artifact directory; existing archives are never overwritten")
parser.add_argument(
    "--input",
    type=Path,
    required=True,
    help="BrighterScript staging directory; raw source is not an installable runtime tree",
)
parser.add_argument(
    "--public",
    action="store_true",
    help=(
        "Public flavor: omit the origin lock (data/connection.json) so the "
        "installed app keeps a user-configurable server origin. The default "
        "flavor packages the staging tree verbatim, including any lock."
    ),
)
args = parser.parse_args()

root = Path(__file__).resolve().parents[1]
package_root = args.input.resolve()
required = ("manifest", "source", "components", "images", "data", "fonts")
missing = [name for name in required if not (package_root / name).exists()]
if missing:
    raise SystemExit(f"Invalid staged package root {package_root}: missing {', '.join(missing)}")

if not (package_root / "source/bslib.brs").is_file():
    raise SystemExit("Compiled staging must include source/bslib.brs")
out = args.output_dir.resolve() if args.output_dir else root / "artifacts"
out.mkdir(exist_ok=True, parents=True)
files = [package_root / "manifest"]
for name in ("source", "components", "images", "data", "fonts"):
    files += [p for p in (package_root / name).rglob("*") if p.is_file()]
if args.public:
    lock = package_root / "data" / "connection.json"
    if lock.exists():
        files = [p for p in files if p != lock]
target = out / ("viptv-roku-public.zip" if args.public else "viptv-roku.zip")
if target.exists(): raise SystemExit('Refusing to overwrite an existing package; use a clean build directory')
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(files):
        info=zipfile.ZipInfo(str(p.relative_to(package_root)), (2026,1,1,0,0,0))
        info.compress_type=zipfile.ZIP_DEFLATED
        info.external_attr=0o100644 << 16
        z.writestr(info,p.read_bytes())
checksums = out / 'SHA256SUMS'
previous = checksums.read_text() if checksums.exists() else ''
checksums.write_text(previous + hashlib.sha256(target.read_bytes()).hexdigest()+'  '+target.name+'\n')
print(target)
