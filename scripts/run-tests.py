"""Run the Roku client's local checks: static contracts, runtime harnesses and BrightScript tests.

The BrightScript interpreter is resolved once (see roku/tests/brs_cli.py) and exported as
VIPTV_BRS_CLI for every harness. Interpreter/compile fixtures only; this never installs on a
device or contacts a real server.
"""

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

root = Path(__file__).resolve().parents[1]
client = root / "roku"
tests = client / "tests"
sys.path.insert(0, str(tests))
from brs_cli import brs_command  # noqa: E402

STATIC = [
    "account_only_contract.py",
    "branding_contract.py",
    "design_contract.py",
    "focus_contract.py",
    "playback_static.py",
    "scenegraph_ux_contract.py",
    "sgnode_identity_contract.py",
]


def scene_scripts(xml_name):
    """Production script order of one SceneGraph component, as interpreter inputs."""
    text = (client / "components" / xml_name).read_text()
    return re.findall(r'uri="pkg:/((?:source|components)/[^"]+\.brs)"', text)


MAIN_SCENE = scene_scripts("MainScene.xml")
API_TASK = scene_scripts("ApiTask.xml")
UTIL = ["source/Util.brs", "source/SourceLabels.brs"]
PRESENTATION = UTIL + ["source/PresentationPolicy.brs"]

# test file -> (production scripts it runs against, success marker it must print)
BRS_TESTS = {
    "account-policy.brs": (API_TASK, "ROKU_ACCOUNT_POLICY_OK"),
    "audio-score.brs": (PRESENTATION, "AUDIO_SCORE_OK"),
    "browse-policy.brs": (UTIL + ["source/BrowsePolicy.brs"], "ROKU_BROWSE_POLICY_OK"),
    "caption-policy.brs": (["source/JellyfinCaptionPolicy.brs"], "ROKU_CAPTION_POLICY_OK"),
    "continuation-policy.brs": (PRESENTATION + ["source/ContinuationPolicy.brs"], "CONTINUATION_POLICY_OK"),
    "direct-policy.brs": (PRESENTATION, "DIRECT_POLICY_OK"),
    "epg_policy.brs": (UTIL + ["source/EpgPolicy.brs"], "EPG_POLICY_OK"),
    "epg_transport.brs": (["source/Util.brs", "components/EpgScene.brs"], "EPG_TRANSPORT_OK"),
    "fallback.brs": (MAIN_SCENE, "ROKU_FALLBACK_OK"),
    "family-startup.brs": (MAIN_SCENE, "ROKU_FAMILY_STARTUP_OK"),
    "image-policy.brs": (UTIL + ["source/ImagePolicy.brs"], "IMAGE_POLICY_OK"),
    "keyboard-input.brs": (["source/KeyboardInput.brs"], "KEYBOARD_INPUT_OK"),
    "lifecycle.brs": (MAIN_SCENE, "ROKU_LIFECYCLE_OK"),
    "live-ux.brs": (MAIN_SCENE, "ROKU_LIVE_UX_OK"),
    "locked-config.brs": (API_TASK, "ROKU_LOCKED_CONFIG_OK"),
    "pairing-preload.brs": (["source/Util.brs", "source/AccountPolicy.brs", "components/AccountScene.brs"], "PAIRING_PRELOAD_OK"),
    "playback_v2_contract.brs": (API_TASK, "PLAYBACK_V2_CONTRACT_OK"),
    "player-overlay.brs": (UTIL + ["components/PlayerOverlay.brs"], "PASS: player icons, explicit seeking and live focus"),
    "presentation_policy_test.brs": (PRESENTATION, "PASS: presentation metadata and backdrop adapters"),
    "profile-selection-runtime.brs": (MAIN_SCENE, "ROKU_PROFILE_SELECTION_RUNTIME_OK"),
    "request-propagation.brs": (MAIN_SCENE, "ROKU_REQUEST_PROPAGATION_OK"),
    "schema.brs": (API_TASK, "ROKU_SCHEMA_OK"),
    "sgnode-identity.brs": ([], "ROKU_SGNODE_IDENTITY_OK"),
    "smoke.brs": (UTIL, "ROKU_TEST_OK"),
    "source-cards.brs": (UTIL + ["components/SourceCard.brs"], "ROKU_SOURCE_CARDS_OK"),
    "source-policy.brs": (UTIL, "ROKU_SOURCE_POLICY_OK"),
    "transport.brs": (API_TASK, "ROKU_TRANSPORT_OK"),
}
# Inputs for preview generators and SceneGraph harnesses, not standalone tests.
BRS_FIXTURES = {
    "epg_navigation.brs": "injected into EpgGrid by epg_navigation_runtime.py",
    "epg_preview.brs": "preview scene for epg_navigation_runtime.py",
    "ux_preview.brs": "injected by make_ux_preview.py into a networkless preview copy",
    "preview_home_main.brs": "manual preview entry point for home_fixture.py on loopback:18770",
}


def run(command, **kwargs):
    started = time.monotonic()
    result = subprocess.run(command, capture_output=True, text=True, **kwargs)
    return result, time.monotonic() - started


def report(name, ok, seconds, output, verbose):
    print(f"{'PASS' if ok else 'FAIL'}  {name}  ({seconds:.1f}s)", flush=True)
    if verbose or not ok:
        tail = output.strip().splitlines()[-25:]
        for line in tail:
            print("      " + line)


def python_check(name, verbose, env):
    result, seconds = run([sys.executable, str(tests / name)], cwd=root, env=env, timeout=600)
    report(name, result.returncode == 0, seconds, result.stdout + result.stderr, verbose)
    return result.returncode == 0


def start_mock_api():
    server = subprocess.Popen([sys.executable, str(tests / "mock_api.py")], stdout=subprocess.PIPE, text=True)
    ready = server.stdout.readline()
    if "ROKU_FIXTURE_READY" not in ready:
        server.kill()
        raise SystemExit("mock_api.py did not start on loopback:18764 (is the port in use?)")
    return server


def brs_check(name, brs, package_root, verbose):
    scripts, marker = BRS_TESTS[name]
    server = start_mock_api() if name == "transport.brs" else None
    try:
        command = [*brs, "--root", str(package_root), *scripts, f"tests/{name}"]
        result, seconds = run(command, cwd=package_root, timeout=300, stdin=subprocess.DEVNULL)
    finally:
        if server is not None:
            server.terminate()
            server.wait(timeout=10)
    output = result.stdout + result.stderr
    ok = result.returncode == 0 and marker in result.stdout and "EXIT_BRIGHTSCRIPT_CRASH" not in output
    report(name, ok, seconds, output, verbose)
    return ok


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--group", action="append", choices=("static", "runtime", "brs"),
                        help="Run only this group (repeatable); default runs every group")
    parser.add_argument("-k", "--filter", default="", help="Only run checks whose file name contains this text")
    parser.add_argument("-v", "--verbose", action="store_true", help="Show interpreter output for passing checks")
    args = parser.parse_args()
    groups = args.group or ["static", "runtime", "brs"]

    listed = set(BRS_TESTS) | set(BRS_FIXTURES)
    unlisted = sorted(p.name for p in tests.glob("*.brs") if p.name not in listed)
    if unlisted:
        raise SystemExit("BrightScript files without a runner entry: " + ", ".join(unlisted))

    env = dict(os.environ)
    brs = None
    if "runtime" in groups or "brs" in groups:
        brs = brs_command()
        env["VIPTV_BRS_CLI"] = brs[0]
        print("BrightScript interpreter:", brs[0], flush=True)

    results = []
    if "static" in groups:
        results += [python_check(n, args.verbose, env) for n in STATIC if args.filter in n]
    if "runtime" in groups:
        harnesses = sorted(p.name for p in tests.glob("*_runtime.py"))
        results += [python_check(n, args.verbose, env) for n in harnesses if args.filter in n]
    if "brs" in groups:
        # pkg:/ is a copy without data/, so no test can read the packaged origin lock.
        with tempfile.TemporaryDirectory(prefix="viptv-roku-pkg-") as package_root:
            shutil.copyfile(client / "manifest", Path(package_root) / "manifest")
            for folder in ("source", "components"):
                shutil.copytree(client / folder, Path(package_root) / folder)
            (Path(package_root) / "tests").mkdir()
            for test in tests.glob("*.brs"):
                shutil.copyfile(test, Path(package_root) / "tests" / test.name)
            results += [brs_check(n, brs, package_root, args.verbose) for n in sorted(BRS_TESTS) if args.filter in n]

    failed = results.count(False)
    print(f"{len(results) - failed} passed, {failed} failed")
    return 1 if failed or not results else 0


if __name__ == "__main__":
    sys.exit(main())
