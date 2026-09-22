# Contributing to VIPTV roku

Thanks for your interest. VIPTV is a multi-repository product; this repository owns the native Roku client. The Roku baseline is frozen during the cross-platform extraction; behavioral change requests start in [viptv-org/design](https://github.com/viptv-org/design).

## Workflow

1. Read the pinned `DESIGN_REF` commit and [SPEC.md](SPEC.md) before changing behavior. This client preserves Roku action meaning, the 700ms hold, focus restoration and the Jellyfin attribution notices.
2. Search this repository's GitHub Issues before opening a new one; use the needs-triage, needs-info, ready-for-agent, ready-for-human and wontfix labels.
3. Validate the affected interface using the repository CI commands (BrighterScript compile and the migration checks); report actual results separately from device-level checks that were not run on real hardware.
4. The installable ZIP is a runtime package only; keep this source repository available when distributing it (see [README.md](README.md)).
5. Never commit credentials, device values or screenshots; Roku device values belong in the private root `.env` of the workspace.

## License

Contributions are licensed under the GNU General Public License v2.0 only (see [LICENSE](LICENSE)). By contributing you agree your work is licensed under it.
