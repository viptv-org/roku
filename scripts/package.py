"""Create the installable Roku runtime archive from a BrighterScript staging tree."""

import argparse
import hashlib
from pathlib import Path
import zipfile


parser = argparse.ArgumentParser()
parser.add_argument(
    "--input",
    type=Path,
    required=True,
    help="BrighterScript staging directory; raw source is not an installable runtime tree",
)
args = parser.parse_args()

root = Path(__file__).resolve().parents[1]
package_root = args.input.resolve()
required = ("manifest", "source", "components", "images", "data")
missing = [name for name in required if not (package_root / name).exists()]
if missing:
    raise SystemExit(f"Invalid staged package root {package_root}: missing {', '.join(missing)}")

out = root / "artifacts"
out.mkdir(exist_ok=True)
files = [package_root / "manifest"]
for name in ("source", "components", "images", "data"):
    files += [p for p in (package_root / name).rglob("*") if p.is_file()]
target=out/'viptv-roku.zip'
if target.exists(): raise SystemExit('Refusing to overwrite an existing package; use a clean build directory')
with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(files):
        info=zipfile.ZipInfo(str(p.relative_to(package_root)), (2026,1,1,0,0,0))
        info.compress_type=zipfile.ZIP_DEFLATED
        info.external_attr=0o100644 << 16
        z.writestr(info,p.read_bytes())
(out/'SHA256SUMS').write_text(hashlib.sha256(target.read_bytes()).hexdigest()+'  '+target.name+'\n')
print(target)
