# Roku remote rebuild — implementation and qualification

Status: implementation candidate; live producer integration and physical-device
qualification remain open. This is **not** a claim of complete 1:1 parity or of
meeting the 60 fps / p95 100 ms physical input target.

## Implemented runtime

The shipping entry point and build allowlist contain the new remote renderer
and Task/storage/player adapters. Legacy scenes and source/continuation policies
remain as historical source and regression inputs, outside the installable ZIP.

Implemented surfaces: account pairing/password entry; server-authorized profiles
and edits; top navigation; billboard/portrait and landscape shelves; catalog
controls and paging; grouped search with a remote keyboard; details, seasons and
episodes; server-ranked source drawer/quality filters; Live channels and bounded
guide windows; library filters/mutations; history; calendar; settings; and native
Video controls, track/seek replacement, episode selection and manual next episode.

Server additions consumed from the web-TV agent: `viewing-action`,
`addon-activation`, named `best_match_id`, `quality_filters`, preference `controls`,
`Card.view.saved`, `HomeRow.view.card_shape`, and Live guide `view` fields. No
backend/core/gateway source was edited by this implementation.

The Task queue is bounded at 24 ordinary entries plus eight cleanup slots and
three workers; mutations serialize. Catalog/detail windows retain at most 300
cards; Home row windows at most 200; Live keeps two channel pages and twelve
cached guides with visible-row lookahead. Stale ownership checks protect account,
route, source discovery, search, playback admission and first-frame callbacks.
Rotating credential writes drain the latest snapshot across epoch changes.

No local mode, local provider/torrent execution, offline library, downloads,
unsupported email-code login, device display preferences without a server
contract, or placeholder skip-intro/frame-rate switches are exposed.

## Evidence and limits

- Final local batch: **70 passed, 0 failed** (`artifacts/remote-full-checks-release.log`). The expanded remote lease/persistence fixture was rerun successfully afterwards.
- Design pin/import integrity and extraction re-pins are checked locally.
- BrighterScript 0.73.1 compiles the allowlisted runtime and produces compiler
  BSLib in staging. Package inspection verifies that legacy controller/policy
  scripts, tests, previews and credentials are absent.
- `remote_runtime.py` executes production SceneGraph handlers for authority,
  profile capability omission, server preference choices, opaque cursors,
  named source selection, cancellation, stale callbacks, safe restoration,
  nested Back, input masking, mutation intent, transient heartbeat handling, stale first-frame refusals and expired-lease decoder retirement.
- `remote_transport_runtime.py` exercises production HTTP against a disposable
  HTTPS server: POST/PUT/DELETE, bearer delivery, 204 responses, malformed and
  oversized responses, API-origin boundaries, cancellation and registry migration.
- Historical checks are retained, but passing them does not qualify the new UI.
- Twelve production-renderer fixture states were rendered off-device: Home,
  browse, sources, settings, profiles, detail, search, Live, calendar, player,
  empty and error. Private captures are under `artifacts/remote-final-visual-*`.
  They cover a finite set of data/focus states, not every screen variant.
- KMP Home was rendered with the same input content at 1920×1080 and 1280×720
  using an external headless capture test. No KMP tracked source was changed.
  Four KMP files changed concurrently after the recorded snapshot, affecting
  focus restoration/grid focus; the Home capture's layout dimensions were
  checked against the recorded sources. The original archive remains preserved.
- Visual inspection exposed differences in old backdrop masks, Home card sizes,
  focus clipping, body wrapping and font inputs. Corrections import KMP resources,
  its Bricolage optical size, matching scrims and fixed rounded focus assets.
  KMP static font names required disambiguation to prevent native registries
  from replacing the regular face with the bold face; glyphs are preserved.
  Full screenshot equivalence, every transition/long-string state and physical
  font rasterization remain unqualified. Source inspection is not pixel proof.
- brs-node renders an FHD design canvas even when configured as 720p. A 720p
  export is explicitly marked as a scaled preview, not a native-device capture.

| Surface | Functional evidence | Visual evidence | Physical evidence |
| --- | --- | --- | --- |
| Entry/profiles | HTTPS/storage and permission fixtures | Cold launch and profile render inspection | Unverified |
| Home/browse/search | Snapshot/order/cursor/stale-owner fixtures | Native fixture renders; KMP Home comparison | Unverified |
| Details/sources | Target/resume intent, named best match, cancellation | Title and source drawer renders | Unverified |
| Live/calendar/history/library | Current API adapters and bounded renderer windows | Live/calendar/browse/empty renders | Unverified |
| Settings/forms | Server choices, activation intent, masking, nested Back | Settings render inspection | Unverified |
| Player | Admission/cleanup adapter and existing regression context | Overlay over a still fixture; no decoder evidence | Unverified |

## Integration gates

The configured QA server answered `/api/bootstrap` with HTTP 200 and contract
version 3 over verified TLS. Its profile `viewing-action` route answered HTTP
404. Therefore complete Play/Resume integration against the new producer has
not passed. `BACKEND_CONTRACT_REF.json` records working-tree producer inputs,
not a released or deployed backend revision.

The gateway must apply persisted audio/subtitle policy and provide appropriate
native caption instructions. Its existing Start contract accepts track/language
fields but does not itself read the profile preference snapshot. This dependency
is recorded in `BACKEND_HANDOFF.md`; Roku does not recreate foreign-audio policy.
Automatic next-episode countdowns and device display preferences also await
server contracts; manual next episode uses the current server resolver.

Remaining hardware gates: TCL 50S435 decoder behavior, real gateway media,
seeks/tracks/rollback, remote repeat/hold, texture/heap bounds during sustained
navigation, cold start, frame timing and input-to-focus latency. No device
installation, Store submission, runtime replacement or production deploy occurred.

The checked ZIPs are reviewable candidates. Live integration and the above
qualification gates must be completed before presenting this as a fully qualified
replacement for an installed Roku channel.
