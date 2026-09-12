# Roku behavior-preserving extraction

Move all tracked roku/ files without runtime changes from vynxc/viptv@7d6b413. Keep its existing directory layout, connection origin, registry keys, manifest, packaged assets, SceneGraph components, BrightScript policies and tests. The original repository retains its full history. Design is authoritative for subsequent product changes.

## Acceptance
- All original file bytes match MIGRATION.json, especially source, components, images, data and manifest.
- Existing static/runtime suites and BrightScript compilation pass.
- CI builds a ZIP from manifest/source/components/images/data only, excluding tests and private state; each ZIP is checksummed.
- Version-tag delivery publishes the tested ZIP to a GitHub release. Device installation and Roku channel-store submission remain explicit operations using device/store credentials.
- No production deployment, device install, account/profile/provider/history mutation during this split.

## Follow-up
Validate the extracted package on a device when an installation is requested; do not confuse headless tests with physical acceptance. Preserve established single-decoder behavior and saved source semantics. Proposed UX changes must be specified in design first.
