"""Import native Roku design inputs from an immutable design git revision."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
lock_path = root / "DESIGN_ASSETS.json"

if sys.argv[1:] == ["check"]:
    lock = json.loads(lock_path.read_text())
    assert (root / "DESIGN_REF").read_text().strip() == lock["revision"]
    assert set(lock["files"]) == set(json.loads((root / "DESIGN_IMPORTS.json").read_text()).values())
    for name, digest in lock["files"].items():
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, name
    print(f"Roku design inputs verified: {lock['revision']}, {len(lock['files'])} files")
elif len(sys.argv) == 4 and sys.argv[1] == "sync":
    repo, revision = Path(sys.argv[2]).resolve(), sys.argv[3]
    def git(*args):
        return subprocess.check_output(["git", "-C", str(repo), *args])
    sha = git("rev-parse", revision + "^{commit}").decode().strip()
    mapping = json.loads((root / "DESIGN_IMPORTS.json").read_text())
    files = {}
    for source, target in mapping.items():
        data = git("show", sha + ":" + source)
        destination = root / target
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        files[target] = hashlib.sha256(data).hexdigest()
    (root / "DESIGN_REF").write_text(sha + "\n")
    lock_path.write_text(json.dumps({"revision": sha, "files": files}, indent=2) + "\n")
    print(f"Imported {len(files)} native design files from {sha}")
else:
    raise SystemExit("Usage: design-sync.py check | sync <design-repo> <revision>")
