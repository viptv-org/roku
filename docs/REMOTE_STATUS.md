# Roku remote rebuild — implementation and qualification

Status: implementation candidate; current producer authentication/catalog/presentation
transport integration has passed in isolation. Full playback and physical-device qualification remain open. This is **not** a claim of complete 1:1 parity or of
meeting the 60 fps / p95 100 ms physical input target.

## Implemented runtime

The shipping entry point and build allowlist contain the new remote renderer
and Task/storage/player adapters. Retired scenes, source/continuation policies, adapters, tests and generators
have been physically removed. Design imports are an explicit current-only list.

Implemented surfaces: account pairing/password entry; server-authorized profiles
and edits; top navigation; billboard/portrait and landscape shelves; catalog
controls and paging; grouped search with a remote keyboard; details, seasons and
episodes; server-ranked source drawer/quality filters; Live channels and bounded
guide windows; library filters/mutations; history; calendar; settings; and native
Video controls, track/seek replacement, episode selection and manual next episode.

Server additions consumed from the web-TV agent: `viewing-action`,
`addon-activation`, named `best_match_id`, `quality_filters`, preference `controls`,
`Card.view.saved`, `HomeRow.view.card_shape`, Home `Card.view.preview`, and Live guide `view` fields. No
backend/core/gateway source was edited by this implementation.

The Task queue is bounded at 24 ordinary entries plus eight cleanup slots and
three workers; mutations serialize. Catalog/detail windows retain at most 300
cards; Home accepts the current producer bound of16 rows ×24 cards, with native
row virtualization and retained unchanged nodes; Live keeps two channel pages and twelve
cached guides with visible-row lookahead. Stale ownership checks protect account,
route, source discovery, search, playback admission and first-frame callbacks.
Rotating credential writes drain the latest snapshot across epoch changes.

No account-only kids-policy/approval editor, parent-PIN setup, per-profile PINs,
local mode, local provider/torrent execution, offline library, downloads,
unsupported email-code login, device display preferences without a server
contract, or placeholder skip-intro/frame-rate switches are exposed.

## Evidence and limits

- Latest immutable producer observation: `artifacts/backend-integration-e8e7-current/source.json`,
  including the working-tree offset fix. Its post-build source hashes match. The
  production Roku HTTP adapter passed current metadata/badges/viewing-action/source
  discovery/ranking/display over verified HTTPS through the native-HTTP simulator.
  The producer boundary regression and two presentation tests passed. This is not
  physical Roku transport/decoder qualification. Disposable processes/data cleaned up.
- Current measured limits are detailed in SCREEN_VALIDATION.md: welcome recent
  graphics FPS near60;300-card paced scrolling around58.2 in several controls;
  p95 input-to-visible-focus remains unverified because capture hardware is unavailable.
  No full performance/parity qualification is claimed.

- Current producer snapshot (`artifacts/backend-current-20261023/source.json`) compiled with `live-runtime`. The unmodified production Roku HTTP adapter passed native login, profile selection, bootstrap, Home, preferences, library, history, refresh and logout over trusted HTTPS against its disposable host. This uses the backend’s existing protocol fixture; its media gateway is mocked and does not qualify playback.
- Current login requires `Origin`. The runtime now sends the validated server origin. The pinned simulator incorrectly applies browser forbidden-header rules to native HTTP; tests permit only `Origin` in a private simulator copy, with unchanged TLS checks.
- The suite now contains only four current-client harnesses; historical test totals are retired. See the latest cleanup verification log for results.
- Design pin/import integrity are checked locally.
- BrighterScript 0.73.1 compiles the allowlisted runtime and produces compiler
  BSLib in staging. Package inspection verifies that legacy controller/policy
  scripts, tests, previews and credentials are absent.
- `remote_runtime.py` executes production SceneGraph handlers for authority,
  profile capability omission, server preference choices, opaque cursors,
  named source selection, cancellation, stale callbacks, safe restoration,
  nested Back, input masking, mutation intent, transient heartbeat handling, stale first-frame refusals and expired-lease decoder retirement.
- `remote_transport_runtime.py` exercises production HTTP against a disposable
  HTTPS server: POST/PUT/DELETE, bearer delivery, 204 responses, malformed and
  oversized responses, API-origin boundaries, cancellation, current credential preservation and unsupported storage rejection.
- Handler tests disable the dispatcher; a separate asynchronous Task fixture exercises the unchanged production dispatcher, its worker bound, mutation serialization, deduplication and completion ownership. HTTPS transport is tested separately. These fixtures do not establish end-to-end production-backend behavior.
- A regression reproduced guides disappearing when channel nodes were replaced. Cached guide data now hydrates replacement nodes using the server current-program ID and window.
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
| Entry/profiles | HTTPS/storage, cancellation and draft-retention fixtures | KMP welcome/choice/pairing captures; native welcome/choice checked | Temporary TCL build installed; spontaneous reboot under investigation |
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
navigation, cold start, frame timing and input-to-focus latency. Temporary development-channel installation on the TCL was explicitly authorized
and performed. No Store submission or production activation occurred.

The checked ZIPs are reviewable candidates. Live integration and the above
qualification gates must be completed before presenting this as a fully qualified
replacement for an installed Roku channel.


## Current correction evidence (2026-10-23)

The initial implementation did not match several KMP screens. The comparison
exposed a missing welcome screen, wrong choice/pairing layout, stale launcher
artwork, squashed detail logos, incorrect shelf spacing and generic Library
controls. These are being corrected against private KMP captures; the full
screen/state matrix remains incomplete.

The producer now supplies ordered metadata, typed badges, source display fields
and resume labels. Roku consumes those projections directly. Regression checks
supply conflicting raw metadata and intentionally unusual ordering to verify
that the producer display wins. `BACKEND_CONTRACT_REF.json` hashes the observed
working-tree source; this does not establish a deployed revision. The earlier
HTTPS integration run predates these additional projection fields.

The `projected-presentation-build` candidate passed all four current-client
harnesses, design integrity, BrighterScript compilation and package inspection.
Its matched movie-detail preview corrects the logo proportions and places the
recommendation artwork at y888. Remaining differences include native text
rasterization/tracking and the rightmost partially-visible shelf card. The
remote Library header now consumes server type choices and has a far-right
Filters action; the full filter surface still needs reconstruction.

TCL reboot evidence: the device rebooted spontaneously during the first revised
welcome/choice transition; the owner confirmed no manual restart. The initial
poster wall used40 MaskGroups. It now uses pre-rounded poster assets and clears
the wall on exit. Ten complete return cycles passed on the first revised build.
This mitigation is not proof of the reboot's root cause or a completed stability
qualification. The newer installed candidate passed50 complete welcome/choice/Back cycles
(100 key events), with monotonically increasing device uptime and the dev
channel active after every event. This is a transition stability result, not
frame-time qualification. Evidence is recorded separately under
`artifacts/tcl-current-20261023/projected-presentation-check/`.

Latest source changes after that hardware package add projected tile badges,
compact captions and tile progress. They require their own final package and
hardware checks. ECP response timing is transport acknowledgement, not measured
input-to-visible-focus latency. No60fps or p95 focus-performance claim is made.


Password entry now uses the combined KMP form: both fields, persistent keyboard,
mask/reveal, submit/delete/server controls and inline errors. Unsupported password
recovery is omitted. External KMP captures are retained privately at1080p/720p;
the Roku1080p preview matches the field/key coordinates, with the omitted action
collapsing the right-column spacing. Production-handler tests cover editing-target
switching, clearing submitted passwords, rejected credentials, cancellation and
revoking a late grant. A rejected login must not refresh an older session; this
regression was reproduced before correction. TCL evidence reproduced a child-focus ownership defect not caught by the
initial handler tests: after moving to a field, Select still reached the old
keyboard child. Explicit field/action Group focus fixed it; fixtures now assert
the focus chain. Native captures verify username entry, one-character password
masking, reveal and Back clearing. Reopening now resets the initial key to `q`.
No real credential was submitted during these physical UI checks. The isolated
HTTPS login integration remains a separate gate.

The final password candidate (`password-form-build-r4`) was installed on the
TCL. Reentry cleared both drafts, reset Show password and restored `q` focus.
Its heading ink bounds measured[99,149,748,200], matching the KMP reference for
that region. This does not claim whole-screen pixel identity. See
[screen qualification matrix](SCREEN_VALIDATION.md) for the remaining scope.


Browse choice filters now use KMP's full-page two-column layout instead of nested
selection drawers. Library's reference remains a separate800px sheet and is not
claimed complete. Complex query JSON serialization and JSON-based cloning were
removed from render handlers; the production HTTPS adapter now serializes query
objects in its Task. See SCREEN_VALIDATION.md for evidence and remaining states.


Library now uses the matched800px KMP sheet and current choice-menu keyboard
behavior. The query returned by the server replaces submitted values; Clear
reads normalized defaults through the existing Library API and only Apply changes
the main query. This resolves the earlier reset-presentation dependency without
backend edits. Auth refresh checks logical request ownership, and next-episode
responses are tied to the active playback session. Controlled TCL fixture checks
cover loading/error/retry/default preview, dismissal and late-response cancellation.
Current candidates and limitations are listed in SCREEN_VALIDATION.md.

Current producer d1eda1d adoption and checksummed candidates are recorded in
[SCREEN_VALIDATION.md](SCREEN_VALIDATION.md#shared-producer-adoption--d1eda1d-2026-10-23).
The shared presentation/navigation/default/action projections are consumed
without client policy fallbacks. Four harnesses, compilation/package inspection
and isolated verified-HTTPS API checks passed. Physical and visual qualification
remain incomplete; these checks do not upgrade earlier hardware evidence.
