"""Run current Roku contract and production-handler fixture checks (no device install)."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[1]
tests = root / 'roku/tests'
sys.path.insert(0, str(tests))
from brs_cli import brs_command

CHECKS = {
    'static': ['remote_contract.py'],
    'runtime': ['remote_runtime.py', 'remote_transport_runtime.py', 'remote_dispatch_runtime.py'],
}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--group', action='append', choices=tuple(CHECKS))
    parser.add_argument('-k', '--filter', default='')
    parser.add_argument('-v', '--verbose', action='store_true')
    args = parser.parse_args()
    groups = args.group or list(CHECKS)
    env = dict(os.environ)
    if 'runtime' in groups:
        env['VIPTV_BRS_CLI'] = brs_command()[0]
    results = []
    for group in groups:
        for name in CHECKS[group]:
            if args.filter not in name:
                continue
            start = time.monotonic()
            result = subprocess.run([sys.executable, str(tests / name)], cwd=root,
                                    env=env, capture_output=True, text=True, timeout=600)
            ok = result.returncode == 0
            results.append(ok)
            print(f"{'PASS' if ok else 'FAIL'} {name} ({time.monotonic()-start:.1f}s)", flush=True)
            if not ok or args.verbose:
                print(result.stdout + result.stderr)
    print(f'{results.count(True)} passed, {results.count(False)} failed')
    return 0 if results and all(results) else 1

if __name__ == '__main__':
    sys.exit(main())
