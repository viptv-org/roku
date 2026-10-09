"""Import native Roku design inputs from an immutable design git revision."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
lock_path = root / "DESIGN_ASSETS.json"

if sys.argv[1:] == ["check"]:
    lock = json.loads(lock_path.read_text())
    assert (root / "DESIGN_REF").read_text().strip() == lock["revision"]
    for name, digest in lock["files"].items():
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, name
    print(f"Roku design inputs verified: {lock['revision']}, {len(lock['files'])} files")
elif len(sys.argv) == 4 and sys.argv[1] == "sync":
    repo, revision = Path(sys.argv[2]).resolve(), sys.argv[3]
    def git(*args):
        return subprocess.check_output(["git", "-C", str(repo), *args])
    sha = git("rev-parse", revision + "^{commit}").decode().strip()
    paths = git("ls-tree", "-r", "--name-only", sha).decode().splitlines()
    mapping = {}
    for path in paths:
        if path.startswith("assets/fonts/"):
            mapping[path] = "roku/fonts/" + path.rsplit("/", 1)[1]
        elif path.startswith("assets/roku/roku/images/design/") or path.startswith("assets/roku/roku/images/lucide/"):
            mapping[path] = path.removeprefix("assets/roku/")
    for path in ["ROKU_DESIGN.md", "DESIGN_SYNC.md", "viptv-design-system/components.md", "viptv-design-system/copy.md", "viptv-design-system/decisions.md", "viptv-design-system/tokens/tokens.json"]:
        source = path if path in paths else {"ROKU_DESIGN.md":"docs/platforms/ROKU_DESIGN.md", "DESIGN_SYNC.md":"docs/process/DESIGN_SYNC.md"}.get(path,path)
        mapping[source] = "design-contract/" + path
    for source in ["PLAYBACK_ERROR_COPY.md", "docs/playback/PLAYBACK_ERROR_COPY.md"]:
        if source in paths: mapping[source] = "design-contract/PLAYBACK_ERROR_COPY.md"
    if "specs/behavior/torrent-runtime-v2.md" in paths:
        mapping["specs/behavior/torrent-runtime-v2.md"] = "design-contract/torrent-runtime-v2.md"
    files = {}
    for source, target in mapping.items():
        data = git("show", sha + ":" + source)
        destination = root / target
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
        files[target] = hashlib.sha256(data).hexdigest()
    # Run the canonical generator in an isolated workspace: another client's
    # intentionally older pin must not be changed as a side effect of this sync.
    with tempfile.TemporaryDirectory(prefix="roku-theme-") as directory:
        workspace = Path(directory)
        for source in ["viptv-design-system/tokens/tokens.json", "viptv-design-system/tools/gen-themes.mjs", "viptv-design-system/tools/targets.json"]:
            destination = workspace / "design" / source
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(git("show", sha + ":" + source))
        (workspace / "roku/roku/source").mkdir(parents=True)
        subprocess.run(["node", str(workspace / "design/viptv-design-system/tools/gen-themes.mjs")], check=True, capture_output=True)
        data = (workspace / "roku/roku/source/ViptvTokens.brs").read_bytes()
        target = "roku/source/ViptvTokens.brs"
        (root / target).write_bytes(data)
        files[target] = hashlib.sha256(data).hexdigest()
    (root / "DESIGN_REF").write_text(sha + "\n")
    lock_path.write_text(json.dumps({"revision": sha, "files": files}, indent=2) + "\n")
    print(f"Imported {len(files)} native design files from {sha}")
else:
    raise SystemExit("Usage: design-sync.py check | sync <design-repo> <revision>")
