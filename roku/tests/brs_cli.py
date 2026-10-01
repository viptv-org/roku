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
