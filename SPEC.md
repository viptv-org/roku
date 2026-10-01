# Current Roku TV contract — ROK-044

VIPTV 1.11.3 adopts design `ac5ae2bad129753135aed01cb85e5a2b343f33f9` under
[ROK-044](design-contract/ROKU_DESIGN.md). The hero and Continue Watching cards
show the matched episode title; the bar follows measured hero context. Direct
playback resolves the same title asynchronously when the card metadata has not
arrived, with account/profile/episode ownership guards. Physical evidence and
remaining limits are in [TV_AUDIT.md](TV_AUDIT.md) and [VALIDATION.md](VALIDATION.md).

The ROK-042 extraction/adoption record below is historical. Its original device
install and episode-grid restrictions were superseded by later owner requests.

# Native Roku TV design adoption — ROK-042

Owner request: update the Roku app to the new TV design (2026-09-27).
The immutable design pin is `e33bf664f8370aea72ef839fb6f81c9687eac9d9`;
[ROK-042](design-contract/ROKU_DESIGN.md) records geometry, assets, native
adaptations and acceptance. HD coordinates are 2/3 of the 1920×1080 TV frame.
Native keyboard/PIN entry and the four-column paged episode grid retain their
Roku interactions. Account/profile identity, saved source Resume, controlled
Next, seek rollback and return focus keep their existing behavior.

Acceptance: pinned asset verification; all existing static/runtime checks;
new design geometry and rail input checks; BrighterScript compilation and
runtime ZIPs containing fonts, Lucide assets and licenses; simulator inspection
of matching screen states. Record physical Roku evidence separately. This
source update does not authorize a device installation or Store submission.

## Historical extraction

Move all tracked roku/ files without runtime changes from vynxc/viptv@7d6b413. Keep its existing directory layout, connection origin, registry keys, manifest, packaged assets, SceneGraph components, BrightScript policies and tests. The original repository retains its full history. Design is authoritative for subsequent product changes.

## Acceptance
- All original file bytes match MIGRATION.json, especially source, components, images, data and manifest.
- Existing static/runtime suites and BrightScript compilation pass.
- CI builds a ZIP from manifest/source/components/images/data only, excluding tests and private state; each ZIP is checksummed.
- Version-tag delivery publishes the tested ZIP to a GitHub release. Device installation and Roku channel-store submission remain explicit operations using device/store credentials.
- No production deployment, device install, account/profile/provider/history mutation during this split.

## Follow-up
Validate the extracted package on a device when an installation is requested; do not confuse headless tests with physical acceptance. Preserve established single-decoder behavior and saved source semantics. Proposed UX changes must be specified in design first.
