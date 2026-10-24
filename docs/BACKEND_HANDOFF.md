# Roku / web-TV shared contract handoff

The web-TV agent owns backend edits. Roku does not edit backend/core/gateway
sources. Current paging adoption: backend `1a361e4dc7923cf2909ff0be828912fb8530fa48`,
core `65add90c6a73da8743021ed0a0ff5c862d78124d` (2026-10-24). Earlier broad
presentation integration used the separately recorded e8e7b5f snapshot. Shared
producer fixtures are pinned in `PRODUCER_FIXTURE_REF.json`.
This is source/integration evidence, not production deployment evidence.

| Surface | Existing API | Required authority / remaining gap |
| --- | --- | --- |
| Startup/profiles | `/api/bootstrap`, `/api/auth/profile`, `/api/profiles` | contract_version=3, identity, management capabilities, profile-scoped revisions |
| Home | `/api/profiles/:id/home` | ordered HomeSnapshot, hero/featured, row state and opaque cursors; no client catalog fan-out |
| Browse/search | `/api/discovery-controls`, `/api/discover`, `/api/search` | scoped controls, grouped results, paging, server order |
| Detail | `/api/meta/:kind/:id` | Card, seasons/episodes/recommendations and exact metadata provenance |
| Play/resume | POST `/api/profiles/:id/viewing-action` `{card,restart}` | consume in-progress `{card,label,resume,source_selection}`; return server-selected target unchanged |
| Sources | `/api/streams`, `/api/streams/:job`, `/api/profiles/:id/source-ranking` | consume in-progress `best_match_id`, `quality_filters`, `total`; auto-start only the named source after discovery completes and server preference authorizes it |
| Continuation | `/api/profiles/:id/continue/next` | exact next Card/status; need server countdown/auto-next directive and due position, not client end thresholds |
| Player | `/api/playback` and session lifecycle | gateway delivery, resume position, timeline, track descriptors and replacement decision; Roku reports actual device facts |
| Library/history | `/api/profiles/:id/library`, `/history`, `/progress` | canonical identities, membership, watched state; no local history decisions |
| Live/calendar | profile `/live/channels`, channel `/guide` and `/sources`; `/api/calendar` | bounded server-ordered pages and canonical channel/episode identity |
| Settings | profile `/preferences`, `/integrations`, `/source-integrations`, `/simkl`; `/api/parent/status` and `/api/parent/unlock` | consume in-progress preference `controls` and `/addon-activation` intent; no local assignment construction |
| Feature visibility | bootstrap integrations + profile management + discovery capabilities | additive feature/action availability needed for unsupported auth, player actions and device display settings |
| Display preferences | missing device-scoped remote preference contract | server persistence required before exposing these KMP controls |

Add fields compatibly and include shared fixtures for missing/unsupported
capabilities, intentionally surprising source ranking/episode order, scoped
stale replies, restricted profiles, and accepted/rejected mutations. Keep the
current KMP/web-TV contracts compatible. No Roku-specific API fork, native
torrent grant, provider credentials or source URL parsing in Roku.

Integration gate: record the producer commit and consume its fixtures before
claiming the dependent feature complete. Unknown capabilities remain omitted;
transport failures remain visible retry states and must not erase credentials.

## Consumer updates during implementation

Roku now consumes the web-TV agent's `Card.view.saved`, `HomeRow.view.card_shape`,
preference `controls`, named `best_match_id` and add-on activation route. Local
membership classification, preference-choice inventories and assignment-building
have been removed from its runtime. These producer changes are currently in the
backend working tree, not the configured live QA binary.

Verified QA probe (TLS verified, isolated browser session): bootstrap HTTP 200,
contract_version=3 and expected snapshot fields; GET on the profile
`viewing-action` route returned **404**, not the 405 expected for an existing
POST-only route. No runtime was replaced or restarted.

The current producer applies supported saved audio/subtitle preferences during
admission. Roku sends intent and consumes explicit playback actions and track
eligibility. Foreign-audio subtitle policy, automatic-next countdown and device
display preferences remain unavailable and are omitted. Roku subtitle styling
is not advertised; no unsupported style action is exposed in its player.

The producer now documents these shared additions in
[`backend/TV_REMOTE_API.md`](../../backend/TV_REMOTE_API.md). Roku consumes that
contract, including named best-source selection and server-projected guide state.
This is source-level alignment; it does not change the QA 404 result or claim
producer deployment.

Synthetic request/response examples are in
[`roku/tests/fixtures/remote-v3.json`](../roku/tests/fixtures/remote-v3.json).
The production SceneGraph fixture consumes this file; it contains no credentials
or household metadata and is excluded from runtime packaging.

## Visual parity dependencies found in the KMP comparison (2026-10-23)

The ordered metadata, badges, source display and resume presentation requirements
are now present in the producer working tree (source hashes in
`BACKEND_CONTRACT_REF.json`). This is not deployment evidence. The Roku client
must not copy KMP's `canonicalChip`, quality aliases, capability ordering, genre
truncation, source-name parsing or completion thresholds. Current `Card.view` now projects `metadata_parts`, `hero_metadata_parts`,
`compact_metadata_parts`, `badges`, `hero_badges`, `tile_badge`, and `progress`.
Source `view` provides title/body/quality/format/addon/provider labels;
viewing-action provides `progress` and `remaining_label`. Raw `badges` mix title
state and media capability tokens and are not presentation input.
The KMP reference currently derives ordered metadata/chips locally. The shared producer now owns those
presentation decisions; matched rendering still requires per-state qualification.

| Current response | Required authoritative presentation | Fixture example |
| --- | --- | --- |
| Home/discover/detail Card | Ordered metadata parts and typed, ordered badges with label and role (`capability`, `certification`, `watched`, `new_episodes`, etc.) | Movie parts `["Movie","2026","Action, Adventure","1h 40m"]`; chips `["4K","HDR","5.1","PG-13"]` in that exact order |
| Detail/viewing-action | Resume action's remaining-time label and displayed progress; cast summary if exposed | `label:"Resume S1 E2"`, remaining `"38m left"`, progress `.3`; no client threshold or inferred episode |
| Source-ranking | Provider/add-on display label, complete display title/body, format/HDR label, named best-match ID (already present); optional server filter descriptors | `title:"LordStreams"`, body `"WEB-DL · HEVC · 5.1 · 18.4 GB"`, quality `"4K"`, format `"HDR10"`, add-on `"Add-on A"` |
| Preferences controls | KMP wording for supported control labels/descriptions; keep unavailable controls absent | Current `HDR preference`/`Any` differs from the KMP `HDR and Dolby Vision`/`No preference`; Roku must display the producer wording until agreed |

The producer may choose additive field names within the existing shared API;
these examples specify semantics and fixture content, not a separate Roku API.
`best_match_id` must remain independent of display filters. Roku will position,
wrap and focus the returned elements and preserve their ordering.


## Library reset presentation (2026-10-23)

Resolved by required `default_query` on the existing Library snapshot. Clear
copies that complete projection into the draft, including source/type/limits;
Apply remains separate. The previous extra reset GET is removed. No client
reset policy or legacy response fallback remains.

## Current producer adoption

Roku consumes ordered metadata, typed badges, source display fields and resume
labels directly. Shared fixture assertions preserve producer order without
quality aliases, capability sorting or remaining-time inference. Bootstrap
`navigation` now controls supported destination visibility/order/labels. Playback
`actions` control both visible controls and execution; source/track replacement
uses `replace_source` and lets the server resolve the observed clock. Add-on
state comes from GET `addon-activation`, never inferred from assignments.

## Direct Live action adoption

Roku now consumes the shared Live source response's action Card/label/resume/
source_selection. Channel Watch requests use shared source ranking; only the
named best ID can auto-start under the server's best preference. Explicit source
picker requests still await selection. Direct responses never produce stream-job
poll/delete requests. Missing current action is an incompatible contract, with
no local Ask/resume fallback. Producer fixture observation: `74e0ac964a88be08738704f570d53d6c43aceae4`.
This is handler/source alignment, not a claim that a running backend was replaced.

## Live page snapshot scope — producer adopted

Current producer `e8e7b5fa74a581dc6c40d6876edee9ab3f9a665d` supplies opaque `snapshot_id` on
Live pages. Roku now compares this identity before merging either direction.
Mismatch retires old guide/page requests, removes the incompatible window and
cursors, and reloads offset zero for the unchanged query. Failure leaves explicit
Retry without restoring stale channels. Missing/empty IDs are incompatible current
contracts. Shared producer fixtures are pinned in `PRODUCER_FIXTURE_REF.json`.
This closes the missing-field dependency at source/handler level; native and real
backend configuration-change qualification remain open.

## Search capability adoption

Roku consumes explicit media_search/channel_search navigation facts, including
Live-only profiles. Channel results use current profile /live/channels?search=
and snapshot_id; media keeps current grouped /api/search to match KMP's producer
rows. No client-generated suggestions/grouping. Handler alignment is verified;
real mixed-profile search and native pagination qualification remain open.

## Live directory upper-offset producer update

The prior offset>10000 counterexample is fixed in the producer working tree
observed under `artifacts/backend-integration-e8e7-current/source.json` (base
`e8e7b5fa74a581dc6c40d6876edee9ab3f9a665d`, exact dirty source hashes recorded).
The shared query accepts the unsigned32-bit offset range; native directory slicing
clamps/saturates safely. The producer handler regression passed for browsing,
search/category queries and following10040 to its final channel. Roku adopted the
shared boundary fixture and handler tests verify unchanged10040/4294967295 cursor
transport. This resolves the previous source-level inconsistency; no shared QA or
production runtime was replaced, and large-directory native qualification remains.

## Current presentation integration

The same isolated producer snapshot compiled with live-runtime and passed Roku's
production HTTP adapter in the native-HTTP simulator over peer/hostname-verified
HTTPS. Checks cover current navigation, metadata/badge projections, viewing-action
server target/resume/source decisions, source discovery/ranking/display, cleanup,
refresh and logout. The origin was explicitly pinned and a wrong-Origin login
returned403. Whitelisted synthetic response observation and all provenance/logs are
in `artifacts/backend-integration-e8e7-current/`. Mock gateway playback in this host
does not qualify real conversion/decoding. The disposable host and TLS proxy were
stopped and temporary account databases/credentials removed.

## Bounded reverse navigation bookkeeping — remaining contract need

Live/search retain only two payload pages, but their scalar cursor history grows
with traversal. The producer's expanded offset range removes the earlier incidental
query ceiling. Please project shared producer-owned previous-cursor/page-origin
metadata (or equivalent bounded bidirectional paging contract) so Roku can retain
only a bounded window of navigation metadata while preserving reverse traversal.
Roku must not invent cursor arithmetic, silently truncate the catalog, or replace
this with local catalog assembly. Until agreed/consumed, unbounded scalar history
remains a cache-qualification gap even though payload page count is bounded.

## Current device-session parental permissions verified

Real isolated HTTPS checks through Roku's production HTTP adapter confirm device
sessions may create/rename/select/delete server-authorized profiles and unlock the
account parent PIN. Restricted-profile mutations/switches return parent_required;
a valid grant restores supported profile-management authority. However
require_household_manager rejects device roles for PIN setup, kids-policy read/write,
parent search and approval management even after unlock. Roku now removes those
account-only editors, their age-choice policy, requests and dormant controllers.
It retains PIN unlock/status and account setup guidance. No backend permission
change or role-based client workaround was made. Exact native-HTTP simulator test
and browser-only disposable setup/cleanup: `artifacts/profile-parent-integration/`.

## Profile mutation outcomes after transport uncertainty

Current profile POST accepts only name/avatar fields and exposes no shared
idempotent operation receipt in the observed contract. Roku now preserves drafts
and scopes late acknowledgements; it does not infer success or duplicate identity
from a name, and only automatically replays after explicit auth/PIN rejection.
Qualification of retry after an unknown network outcome still needs a shared
producer-owned idempotency/outcome contract (or equivalent), with an accepted-but-
reply-lost fixture. This is a protocol gap to resolve before claiming safe replay
of persistent mutations; no backend source was changed by this client pass.


## Modal form eligibility — remaining presentation dependency

Current KMP Name/Add/parent-unlock dialogs disable confirmation using client name
and PIN predicates. Roku intentionally submits intents to the current producer
instead of copying those predicates. The current observed API projects mutation
capabilities and server validation errors, but no per-draft eligibility or input
constraint presentation. Please expose shared producer-owned form eligibility /
constraints (or an equivalent server validation projection) if exact initial,
unchanged, empty and invalid-draft disabled styling is required on both clients.
A client must not infer name uniqueness, permitted lengths, PIN validity, or grant
eligibility from presentation. Required fixtures: empty/unchanged/valid/rejected
name; empty/invalid/accepted PIN; current profile permissions and busy transport.
The current Roku modal only disables confirmation for its pending request. Name
and PIN rejection remain authoritative server responses; no backend edits made.


## History presentation and bounded paging — current remaining dependency

Read-only inspection2026-10-24 observed backend base
1a361e4dc7923cf2909ff0be828912fb8530fa48 and core base
65add90c6a73da8743021ed0a0ff5c862d78124d (working trees may differ). This is not
adoption/integration qualification of that newer producer revision. The current
HistoryEntry array carries Card.subtitle and landscape/poster roles plus updated/
completed timestamps. PlaybackRecord::card already projects its resume/watched
subtitle. Roku now preserves that text even when completed_at_millis would have
made the removed client rule say something else. It no longer synthesizes
“In progress”, a watched percentage, or a landscape choice from poster artwork.

Missing shared presentation: ordered day headings/group identifiers, progress
label and its visibility, explicit row actions/clear permission and empty-state
presentation. Project these server-side with intentional contradictory fixtures
(server subtitle versus timestamps/progress) and artwork-role omission. Exact KMP
day/percentage parity remains unavailable until agreed fields are consumed.

The current history endpoint accepts offset/limit, rejects offset>10000, returns
an array without next/previous/completion/snapshot metadata, while the producer
can retain up to50000 records. Its client currently keeps300 entries and forward
request bookkeeping; complete bounded reverse traversal and snapshot isolation
remain unqualified. Please supply shared paging metadata / snapshot authority and
an agreed beyond10000 fixture rather than have Roku infer catalog completion,
perform local sorting/grouping or accumulate an unbounded navigation history.
No producer/core source was edited by this Roku correction.


## Bounded reverse paging dependency consumed (2026-10-24)

The new shared `paging` descriptors resolve the earlier missing server contract
for Live and channel Search. Roku now keeps only two payload pages with their
producer-owned descriptors. The growing cursor arrays/counters and use of Live
`next_cursor` are physically removed. Requests preserve cursor,limit,page_size;
same-cursor replies with changed limits/budgets are stale. Short reverse pages
retain the larger navigation budget. Applying a page preserves channel focus and
suppresses opposite-direction prefetch until actual movement, fixing a reproduced
short-window oscillation. Missing/malformed paging rejects incompatible servers.

Backend/core/current fixture revision and exact hashes are recorded in
BACKEND_CONTRACT_REF.json and PRODUCER_FIXTURE_REF.json.471 source files were
copied without mutation and remained identical after compile. The current producer
configured reverse test passed; Roku's actual HTTP/wire adapter passed against
that producer over peer/hostname-verified local HTTPS for unconfigured directions,
distinct row/navigation budgets, scoped snapshots and the unsigned cursor bound.
The owned host/TLS proxy and disposable database/credentials were removed. TCL
synthetic-controller results are recorded separately in SCREEN_VALIDATION.md;
this does not claim a real configured Live network/decoder campaign has passed.
The History paging envelope, form eligibility, mutation outcome receipt and
server display/continuation presentation requests remain open.


## Real gateway Matroska copy counterexample — producer investigation required

ROK-MEDIA-20261024-MKV-COPY is preserved under
`artifacts/roku-playback-current-20261024/mkv-copy-counterexample.json`, with input/
output full frame counts, validated generation receipt, checksummed copied HLS
payload and frozen gateway source/build provenance. Current gateway working tree
(base00b6815 plus exact dirty hashes) was copied read-only and built in an owned
target. Backend1a361e4 uses its existing real media-lab fixture, not playback mocks.
The validated90.021s,2700-frame H264/AAC Matroska with two audio tracks produced
an ENDLIST HLS output of74.013s/2192frames, starting video PTS17.534s, while the
producer response still advertised90.021s. Server-selected English input1, copy/
copy pipeline. TCL properly finished that74s output at73.863s. The Roku client did
not clip, infer completion or choose a track. The36s MP4 baseline completed and
persisted “Watched” successfully. Please investigate the missing508 video frames /
source prefix and delivery-duration consistency. Roku will keep this format/
content-timing qualification open and will not hide the discrepancy with local
completion thresholds or seek offsets. No gateway/backend runtime source edited.

## Focused Home projection adopted; remaining KMP presentation fields

Roku now consumes backend0d8da118e2282c1d7cefa4bc590004bf6a97c211's
`Card.view.preview` on Home rows. Exact producer fixture/hash is pinned in
PRODUCER_FIXTURE_REF.json; source hashes are in BACKEND_CONTRACT_REF.json.
`action` alone selects fresh viewing-action or details, including contradictory
row-ID/resume hints. `background` is kept distinct from the episode tile's
landscape. Null stays absent. Missing/malformed preview requires a server update;
there is no old-server fallback. The current producer never emits Home row
continuations, so the obsolete Home-to-discover adapter was removed. No producer
runtime source was edited. This is client fixture adoption, not a new HTTPS
integration result for0d8da118.

Six actual KMP Home captures now expose these remaining shared presentation needs:

- Role-specific tile subtitle/caption and ordered certification badges. KMP
  landscape cards show Card.subtitle when supplied (e.g. `S1 E2 · 38m left`),
  otherwise year/runtime/up-to-three genres joined ` / `/rating, then a compact
  certification badge. Current `compact_metadata_parts` gives year/runtime/rating;
  `preview.caption` prefixes `Resume` and is a different summary role. Please
  project the complete tile display facts so Roku does not infer resume labels or
  choose formatting rules from raw metadata. No extra caption panel belongs in
  TvBrowseSummary merely because the new preview has a caption/progress field.
- Hero/browse summary ordering matching current KMP: year, runtime, up-to-three
  genres joined ` / `, rating `★ n`; current hero projection is year, up-to-two
  comma-separated genres, runtime, with no rating. Roku preserves supplied order.
- Poster soft-art role: KMP uses poster imagery blurred70px on a1920x620 plane,
  scaled1.2,opacity.45. Roku renders the sharp280x420 poster but keeps the soft
  background neutral pending a producer-owned URL. Do not require a client
  provider-host allowlist, arbitrary third-party proxy construction, or render-
  thread full-image processing. Shared public image delivery policy belongs on
  the producer. A pretrimmed logo role also avoids a client alpha-pixel scan.
- A complete, cache-enriched focused summary (description/logo/metadata where
  available). KMP currently enriches missing fields via its detail controller;
  Roku must consume producer enrichment without per-card metadata network calls.

Reference/renderer comparison is recorded separately in SCREEN_VALIDATION.md.
History presentation/paging is still unresolved; the Home preview does not alter
the HistoryEntry envelope. Existing form-eligibility, mutation-receipt and
server-display/continuation dependencies remain open.

## Current producer integration checkpoint (2026-10-24)

Clean backend commit `0d8da118e2282c1d7cefa4bc590004bf6a97c211` compiled in an
isolated Roku artifact snapshot and passed the production Roku HTTP adapter over
peer/hostname-verified HTTPS. Verified surfaces include bootstrap navigation,
Home preview projection, ordered metadata/badge arrays, Library default_query,
add-on activation, viewing-action, source discovery/ranking/display fields,
credential refresh and logout. Evidence: `artifacts/backend-integration-0d8-current/`.
The current backend working tree also contains a gateway change that references
untracked `server/src/gateway/media_lab_acceptance.rs` and does not compile when
included. Roku excluded that dirty gateway module from the integration snapshot
and did not edit backend sources. Shared QA/production runtime state is unchanged.

## ROK-MEDIA-20261024-MKV-COPY resolved — gateway `11cd610` (2026-10-24)

Root cause confirmed from the archived payload: the 90s remux finished inside
one throttle tick, so the 60-entry rolling playlist (sized for 2s segments)
had already slid to media sequence 16 before the reader's first fetch. The
segment files held all 2,700 frames; only the playlist listing was truncated,
which also produced the advertised-90s/listed-74s inconsistency. The gateway
reproduction (engine `tests::remux::a_completed_fast_copy_keeps_its_whole_playlist`,
real FFmpeg, mirrored fixture with two audio tracks and one-second keyframes)
failed at exactly `MEDIA-SEQUENCE:16` before the fix.

Fix in playback-gateway `11cd610` (on top of the `7273ab1` startup/output
batch): on-demand VOD sessions pass `-hls_list_size 0` and no longer use
producer-side `delete_segments`; the complete produced playlist is listed from
segment zero during and after production, so a late or paused reader always
sees the full advertised duration. The consumption-paced throttle still bounds
production ahead of the viewer, and prefix segment files are now reclaimed by
the gateway once their media ends a full grace period behind the viewer's
furthest fetched segment — including after the producer has exited — keeping
disk bounded during long viewing. The per-segment timeline is retained whole
so deep seeks in long completed features still resolve deletion watermarks.
Fragmented-MP4 segment names now count toward throttle/cleanup accounting,
and the shared-caption playlist reader accepts feature-length VOD playlists.
Live sessions are unchanged: rolling window, producer-side deletion, GOP-aligned
joins.

Verification on the final tree: workspace 247 passed / 0 failed; 24
real-FFmpeg gates pass including the mirrored reproduction (playlist now
starts at sequence 0, listed duration within 3s of the probe, prefix
fetchable, prefix reclaimed behind a deep fetch with the tail retained),
the 46s consumption-paced throttle end-to-end, remux/browser/selection/
disguised/joinable/direct/recovery/HDR/VAAPI sets. No client compensation is
needed or wanted; the delivered playlist duration now matches the admission
response. Remaining open on the producer side: requalifying long-form (2h+)
VOD disk/playlist behavior on hardware and the media-lab campaign.
