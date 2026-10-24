# Contributing to VIPTV roku

Thanks for your interest. VIPTV is a multi-repository product; this repository owns the native Roku client. Behavioral change requests start in [viptv-org/design](https://github.com/viptv-org/design). Only the current backend and pinned KMP TV design are supported.

## Workflow

1. Read the pinned `DESIGN_REF` commit and [SPEC.md](SPEC.md) before changing behavior. Preserve the current remote actions and focus restoration.
2. Search this repository's GitHub Issues before opening a new one; use the needs-triage, needs-info, ready-for-agent, ready-for-human and wontfix labels.
3. Validate the affected interface with the local checks in [README.md](README.md#local-verification) (`python3 scripts/run-tests.py`, the BrighterScript compile, design integrity checks); report actual results separately from device-level checks that were not run on real hardware. Pull requests have no CI gate; the build workflow runs only on `main` pushes and manual dispatch.
4. The installable ZIP is a runtime package only; keep this source repository available when distributing it (see [README.md](README.md)).
5. Never commit credentials, device values or screenshots; Roku device values belong in the private root `.env` of the workspace.

## License

Contributions are licensed under the GNU General Public License v2.0 only (see [LICENSE](LICENSE)). By contributing you agree your work is licensed under it.
