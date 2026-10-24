"""Locate the off-device BrightScript interpreter shared by the Roku test harnesses.

Resolution order: ``VIPTV_BRS_CLI`` (an executable path or name), then ``brs-cli``
on ``PATH``, then the pinned brs-node release fetched through ``npx``. A missing
interpreter is a clear error instead of a machine-specific fallback path.
"""
import os
import shutil
import subprocess

PINNED_PACKAGE = 'brs-node@2.5.3'


def _from_npx():
    npx = shutil.which('npx')
    if not npx:
        return None
    result = subprocess.run([npx, '--yes', '-p', PINNED_PACKAGE, '-c', 'command -v brs-cli'],
                            capture_output=True, text=True, timeout=300)
    path = result.stdout.strip().splitlines()[-1] if result.stdout.strip() else ''
    return path if result.returncode == 0 and path and os.access(path, os.X_OK) else None


def brs_command():
    """Return the argv prefix that runs ``brs-cli``."""
    configured = os.environ.get('VIPTV_BRS_CLI', '').strip()
    if configured:
        found = shutil.which(configured)
        if not found:
            raise SystemExit(f'VIPTV_BRS_CLI={configured!r} is not an executable BrightScript interpreter.')
        return [found]
    found = shutil.which('brs-cli') or _from_npx()
    if found:
        return [found]
    raise SystemExit('No BrightScript interpreter: set VIPTV_BRS_CLI to a brs-cli executable, '
                     f'put brs-cli on PATH, or install Node.js so npx can fetch {PINNED_PACKAGE}.')


def native_http_command(directory):
    """Isolate brs-node's HTTP polyfill fix for native Roku Origin headers.

    brs-node 2.5.3 applies browser forbidden-header rules to roUrlTransfer.
    Native Roku can send Origin. Permit only that header in a private simulator
    copy; never change the installed interpreter, runtime code, or TLS checks.
    Fail explicitly if a different simulator needs a different adaptation.
    """
    from pathlib import Path
    import json
    command = Path(brs_command()[0]).resolve()
    package = command.parent.parent
    metadata = json.loads((package / 'package.json').read_text())
    if metadata.get('name') != 'brs-node' or metadata.get('version') != '2.5.3':
        raise SystemExit('Native HTTP harness requires brs-node 2.5.3; review the Origin polyfill adaptation for another version.')
    target = Path(directory) / 'native-brs-node'
    shutil.copytree(package, target)
    (Path(directory) / 'node_modules').symlink_to(package.parent, target_is_directory=True)
    bundle = target / 'bin/brs.node.js'
    source = bundle.read_text()
    before = 'isAllowedHttpHeader(e){return this._disableHeaderCheck||e&&!u.has(e.toLowerCase())}'
    after = 'isAllowedHttpHeader(e){return this._disableHeaderCheck||e&&(e.toLowerCase()==="origin"||!u.has(e.toLowerCase()))}'
    if source.count(before) != 1:
        raise SystemExit('Unexpected simulator HTTP implementation; refusing an unverified patch')
    bundle.write_text(source.replace(before, after))
    return [str(target / 'bin' / command.name)]
