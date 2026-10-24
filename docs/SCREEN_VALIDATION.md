# Roku screen qualification matrix

Current status: **incomplete; not a release qualification**. The owner-selected
reference is the current KMP TV UI, with unsupported/local-only actions omitted.
Design pin: `50ee2ae9ee7f97d68114b4ba4e652e053502e3a7`.
KMP reference ledger: `KMP_REFERENCE.json`. Later working-tree deltas must be
reconciled before final reference adoption; a successful asset integrity check
does not prove design freshness or visual parity.

Private evidence is kept under ignored `artifacts/`; no application captures are
checked into design or runtime assets. “Handler” means production BrightScript
executed in a disposable simulator fixture. It does not establish device behavior.

| Screen/state | Verified evidence | Remaining qualification |
| --- | --- | --- |
| Startup/welcome | KMP1080/720 captures; corrected brand/poster wall; TCL native capture;50 welcome/choice return cycles with stable uptime | Cold-launch distribution, frame times during drift, sustained texture/heap bounds; spontaneous earlier reboot root cause remains unproven |
| Sign-in choice | Matching KMP artwork, geometry, supported rows; TCL render/navigation | Long-string/accessibility states; input-to-visible-focus latency |
| Phone/browser pairing | Scoped polling/cancellation handlers; revised two-column preview; server draft retained through refresh | Native QR over current isolated HTTPS host, pending/expired/denied/approved flows, final matched capture |
| Password | KMP combined-form captures1080/720; native masked/revealed/Back states; focus-chain bug reproduced and corrected; rejection/cancel/late-grant handlers | Final isolated HTTPS login through the combined form, rejection/retry on device, long drafts and repeat/hold timing |
| Profiles/edit/parental | Current-producer HTTPS profile CRUD, invalid PIN, parent challenge/unlock, denied switch and identity retention; native supported parental status states | Separate avatar reassignment, name-draft rejection/cancel, PIN-dialog parity, real device HTTPS/long-string/Back combinations |
| Home | Current preview action/background authority; canonical refresh/return focus and retained native rows; six KMP reference/simulator states; TCL hero/landscape/poster captures and Up/Down/Back path; native row-state fixture covering Pending skeletons, hidden Empty, Failed retry ownership and Ready focus | Producer caption/metadata/art roles; native typography/crop/motion differences; sustained scrolling, texture limits, physical720p and measured animation/input budget |
| Movies/Series/Anime | Current discovery contracts and stale-query regression; grid/control corrections; instrumented native poster-grid FPS/RAM samples | Focused-caption clipping corrected in the tested1080p Browse states; Library/720p/rapid-transition parity remains open. Full-page choice filters now rendered against the same KMP fixture and on TCL; inline text editor and disabled-choice focus now implemented/tested; catalog facet, long/empty/error/pagination states remain |
| Search | Scoped debouncing/stale-result handlers; current server paging; TCL short reverse/forward channel focus without idle oscillation | Same-content reference capture, boundary navigation and return focus on device |
| Details/episodes | Server viewing-action identity/resume authority; corrected movie logo/metadata/recommendation geometry | Expanded episode/season focus layout, series comparison, progress/resume native render, right-edge shelf clipping |
| Source drawer | Shared ordered presentation/ranking; current single-add-on discovery on TCL; native119x28 Best match badge and matching measured ink bounds;14px row corners | Dynamic text metrics/horizontal placement, multiline rows, filter/header states, multi-provider progressive discovery |
| Live guide | Current-program/window authority; direct Live action/ranking and stale-intent regressions; cached-guide hydration; current descriptor paging and TCL short reverse/forward focus | Native time/grid navigation, paging boundaries, actual Live decoding and recovery |
| Library | Server defaults verified over isolated HTTPS; native sheet choice/keyboard input; bounded reverse/forward paging and explicit retry on TCL fixture; error text above artwork; hydration/revision/return-state handlers | Real-network/native hydration and return-state combinations, empty states, dynamic typography, sustained scrolling/texture memory and latency |
| History | Native landscape row implementation; current API adapter and ordered rendering | Matched reference capture, clear/retry/empty states on device; day headings need producer presentation |
| Calendar | Server-ordered range paging/version guard; landscape preview correction; scoped failed-day Retry and empty-day Browse Home verified in a native fixture | Matching server day/status/watch presentation, date controls, native return navigation |
| Settings/add-ons/source integrations/Simkl | Current preference choices and capability omission; settings row renderer; activation intent handlers | Every supported group with real current responses; permitted mutations/cancellation; native matched states |
| Player/tracks/continuation | Server action/resume/continuation and lease regressions; real gateway/native MP4 completion, pause/resume, server seek admission, audio/subtitle replacements and active Back/lease cleanup | Visible picture/audio quality, end-of-stream, seek/track/replacement/recovery campaigns, sustained playback timing and memory |

## Evidence anchors

- KMP: `artifacts/kmp-all-reference-20261023/`,
  `kmp-entry-reference-20261023/`, `kmp-password-reference-20261023/`.
- Matched movie correction: `artifacts/projected-detail-check.png` and explicit
  projection fixture under `projected-detail-check/`.
- TCL transition run: `artifacts/tcl-current-20261023/projected-presentation-check/`.
- Password physical focus correction: `password-focus-*.jpg`; final candidate
  event record under `artifacts/tcl-current-20261023/password-final-check/`.
- Final native password heading ink bounds match the KMP capture at
  `[99,149,748,200]`; this measures that text region only, not full-screen parity.
  The same capture confirms empty drafts, masking reset and initial `q` focus.
- Latest password candidate: `artifacts/password-form-build-r4/packages/`.
  Normal ZIP SHA256 `51ac8f1810b53f1363289ec0785eaa9a48924ec892f868caa625e159d2ec8206`;
  public ZIP SHA256 `f670deafacb2c9375ff9f1f06b0726ab612fb6ba1cbfa89afdd908ff3e36f821`.
- Current clean producer commit `0d8da118e2282c1d7cefa4bc590004bf6a97c211` was
  compiled in isolation and passed the production Roku HTTP adapter over verified
  HTTPS: login/profile/bootstrap, navigation, Home preview fields, ordered
  metadata/badge arrays, Library defaults, preferences/history, add-on activation,
  viewing-action, source discovery/ranking/display fields, discovery cleanup,
  credential refresh and logout. Evidence:
  `artifacts/backend-integration-0d8-current/`. The dirty backend gateway module
  was excluded because it references missing `media_lab_acceptance.rs`; that
  backend worktree issue is recorded, not silently included. This is isolated
  integration evidence, not shared-QA deployment or physical decoder proof.

No app-wide60fps, p95<100ms focus, memory-ceiling, complete1080/720 parity, or real-media
playback claim is supported yet. ECP acknowledgements are not visible-frame
latency. Simulator-scaled720 output is not native720 hardware evidence.


## Browse filter / transport update

The browse filter page now has bounded pools (7 facet rows,21 choice tiles),
transient complete drafts, Show results/Clear all/Cancel and producer-driven
selection caps. Tests reach the100th server choice without growing node pools.
`artifacts/kmp-filter-reference-20261023/BrowseFilters.png` and
`browse-filter-layout-check.png` use the same explicit six-genre/three-sort
fixture. The default KMP preview has no discovery controls; the reference capture
therefore supplies an explicit current-wire fixture to the real KMP component.
TCL captures `browse-filter-native-*` verify selection/reselection and cap behavior
in a disposable network-disabled fixture, not a real catalog/backend session.

All runtime JSON parsing/serialization now occurs in RemoteTask/RemoteStore.
GET/DELETE complex query values stay structured until the Task. HTTPS tests cover
UTF-8, nested arrays, opaque metadata origin/card fields, null/boolean/number,
existing query parameters, and no GET request body. Retries retain those queries.
Draft mutation after enqueue cannot alter the submitted request snapshot. Static
checks reject JSON processing in render-thread handlers.


### TCL filter CPU/RAM sample

The network-disabled filter fixture executed100 horizontal focus moves over
18.57seconds. Roku `chanperf -r 1` produced23 samples: app RAM stayed at26528KiB
(25.9MiB), CPU median1%,maximum2%. Reporting was stopped with `chanperf -r 0`.
Raw samples and key events are in
`artifacts/tcl-current-20261023/browse-filter-fixture-check/filter-chanperf.*`.
This is a small synthetic filter workload, not media/catalog scrolling or a
sustained memory-leak test. It provides no GPU/frame timing or input-to-visible
focus measurement. Startup logs also report the fixture backdrop texture as
1935x1080 after scale-to-zoom; this is recorded, not treated as a clean image
budget qualification. The normal current-only package is restored after this
fixture test; no fixture is included in the runtime ZIP.

Normal current-only candidate after this change:
`artifacts/browse-filter-runtime-build-r2/packages/`.
ZIP SHA256 `3cdbf0f493582cbe9f585b43713f09ac199aea143c30570b3db8857007faa2a0`;
public ZIP SHA256 `fcfcaaa9391814bf89e2922766602ccf8ff723663864247fb86bc91e82616c60`.
All four current-client harnesses, BrighterScript compilation, design integrity,
package allowlist inspection and whitespace checks passed for this source state.


## Inline filter editor and focus follow-up

The text facet now keeps its value field and keyboard on the filter page. KMP
and Roku fixtures use the same Genre/Search/Sort controls. Captures live under
`artifacts/kmp-filter-reference-20261023/BrowseTextFilter.png`,
`artifacts/inline-filter-layout-check.png` and the TCL `inline-filter-native-*`
series. Native checks exercised typing, Clear, moving Up into the value field,
returning to the keyboard, Left to facets, and cancellation. No runtime errors
were logged during those scripted interactions. This fixture made no catalog
request; the complete accepted/error response flow remains an integration gate.

Focus skips choices disabled by the producer maximum_selections. An omitted
maximum imposes no invented client cap, including a regression with501 accepted
values. Label/selection lookup maps avoid repeatedly copying SceneGraph model
fields during navigation; they do not change server ordering or values. The
inline keyboard retains its64-character KMP UI draft bound.

Current-only package candidate: `artifacts/inline-filter-runtime-build-r2/packages/`.
Normal SHA256 `d7829e73c28d5c35cab10b6de8184ffb130514faefae7642edda5eca80c8a4cb`;
public SHA256 `e5acd399d35aacdfe214c70f32d02fc473bb5e6e99193a0e8a73b2af512142d0`.
Four current-client harnesses, BrighterScript compilation, design integrity and
package inspection passed. Previous CPU/RAM samples predate this inline editor;
they are not performance qualification of this new candidate.

The native/KMP scanline measurement above the first-row key glyphs (y430)
matched all ten horizontal key intervals exactly: the first four are94px wide,
the remaining six93px,with10px gaps. Raw intervals are in the private inline
fixture `geometry.json`; this supports row geometry only, not typography or
whole-screen pixel equivalence. The normal public candidate was restored with
installer success and the development channel active; its startup log contains
no runtime error matches.


## Library sheet follow-up

The current Library filter sheet replaces the retired nested filter handler.
It starts from the server-returned normalized query, keeps a complete transient
draft, omits null HTTP query fields and applies once. Query normalization is
covered with intentionally differing source/type/sort/limit values. Choice-menu
Back returns to its field; sheet dismissal leaves the accepted query untouched.
Eight field nodes and eight choice rows are reused across scrolling.

Matched KMP sheet/menu captures and resolved Compose text styles are private at
`artifacts/kmp-library-filter-reference-20261023/`; all six checked Library,
browse, entry and shared-action sources match the original reference hashes.
Roku comparison captures are `library-sheet-layout-check.png` and
`library-menu-layout-check.png`. Menu text resolves to24px weight500 in KMP;
field values are24px weight400. Baseline corrections use measured text bounds.
Clear now resolves its draft through the existing Library GET endpoint;
no hard-coded default values or new producer endpoint are required.
The current producer exposes only nonempty SingleChoice Library controls,
including the numeric episode limit as a choice. Unadvertised free-text controls
are not rendered. Complete HTTP/device mutation flows remain an integration gate.


Further authority/lifecycle checks still required before completion:
- Library hydration `refresh_after_millis` and reason/status presentation are not
  yet consumed; verify server-directed refresh without duplicating cached pages.
- Server-owned bootstrap selection and origin/account/profile cache retirement
  now have handler regressions; verify them against the current producer over HTTPS.
- Exercise repeated preference changes during authentication refresh; request-tag
  deduplication must not silently discard a later user intent.
- Episode-list HTTP failure now has a drawer-local retry and lease/content-preservation
  regressions; verify uninterrupted decoded video against the real gateway.
- Calendar date changes retire responses but still need queued-request cancellation
  qualification under rapid navigation and authentication refresh.


Library menu keyboard behavior was measured directly in KMP with129 choices:
open has no focused choice; Enter alone does nothing; Down/Up enter first/last;
movement wraps and scrolls focused rows to the top, clamped at the end. Roku now
matches those transitions. Scope and source hashes are recorded separately in
`KMP_REFERENCE_UPDATES.json`; later reference deltas are not silently attributed
to the initial snapshot.

Clear now performs a read-only Library request, preserves the existing draft
while loading, and previews exactly the server-returned query and labels.
Cancellation invalidates the request owner; error retains the draft and supports
retry. Only Apply changes the main browsing query. Auth-refresh replay now checks
logical request ownership so retired searches, catalog views, calendar days,
playback admissions and next-episode requests cannot take a newer request's slot.
Next-episode responses are bound to their playback session, and retired lease
renewals are not resurrected by authentication refresh.


## Latest Library/UI authority candidate

`artifacts/library-authority-runtime-build-r2/packages/` contains the current-only
runtime candidates. Normal ZIP SHA256:
`cc1d1c14a65f86192a91a1a56ea95323f1c103a6bc0ff97740172d9baa27b768`;
public ZIP SHA256:
`9af9fe54e26d470ec7de7d5b3bcd62f01fdecdc625776fc1c4bb584363014843`.
A per-file source manifest accompanies this build.

TCL controlled-response checks now cover Library Clear loading, recoverable
failure, retry, resolved defaults, Apply dismissal and cancellation before a late
reply. Captures are `library-reset-native-*`. The first cancellation attempt was
inconclusive because launching an active dev app resumed it; the fresh-install
run is separately recorded in `library-reset-cancel-check/result.json` and
`library-reset-native-cancelled-fresh.jpg`. After its delayed response, the frame
remained the plain dismissed-fixture background. No live backend mutation was
performed by this fixture. Actual current-producer HTTPS qualification remains
required, as do frame timing, sustained scrolling and real-media playback.

All four current-client harnesses, BrighterScript compilation, design integrity,
package allowlist inspection and whitespace checks pass for this candidate.
The latest next-episode regression additionally verifies that a current NoNext
response removes a previously offered next action.


## Bootstrap/profile ownership follow-up

Removed registry-driven automatic profile selection and the unused stored profile
selector. Existing valid rotating credentials/account ownership still survive
storage loading. A bootstrap with no selected profile renders the server's list;
an explicit server profile ID owns requests. Same-identity refresh no longer
resets navigation or dismisses a form. Identity/origin changes release cached
Home/catalog/guide models, artwork, component-owned filter drafts and pending
parent/credential form data. Reordered profile lists restore focus by server ID.
Production-handler regressions cover those cases, including identical numeric
profile IDs on different origins. These tests do not yet replace real current-
producer multi-account/profile integration qualification.


Current bootstrap/profile candidate: `artifacts/profile-authority-build-r3/packages/`.
Normal SHA256 `03565bbb64a1cd2d41355d492d3acbc9398af74c0bcffe6968de4d7a757fd776`;
public SHA256 `93cf8f21091f78727f6ac03e4c729870533bf0c2118a67edeed24fa5864b379f`.
All four harnesses, compilation, design integrity and package inspection pass.
A TCL fixture seeded old Home/draft data and a remembered profile, then delivered
a different server identity with no selected profile. Its native assertion passed
and the captured screen showed only the new server-provided profile selector.
Evidence: `artifacts/tcl-current-20261023/profile-boundary-check/` and
`profile-boundary-native.jpg`. This verifies native cleanup/selection behavior,
not real multi-account HTTP authorization. The normal public build is restored
after the fixture check.


## Episode drawer error and cancellation follow-up

Episode metadata failures no longer call the decoder failure path. Initial
failure exposes Retry; append failure keeps loaded rows, suppresses automatic
retry loops, and retains the playback lease/content. A new season retires old
requests, including queued authentication retries. Closing the drawer or stopping/
replacing playback retires metadata ownership. Tests cover exact server episode
identity/cursor, stale prior-season pages, append failure and dismissal.

Resource cleanup now uses a rotated credential only for the same origin and
identity epoch. It preserves an explicit cancelled-login grant when revoking it,
and never borrows a current credential for a foreign origin or retired identity.
These are handler/transport ownership checks; actual uninterrupted decoding,
seeking, tracks and recovery remain unqualified hardware/integration work.


Current episode-recovery candidate: `artifacts/episode-recovery-build-r2/packages/`.
Checksums:

```text
0aa609616a922503d73ce103d4f9d19f9957e87e1aa2705a3a8248302b689022  viptv-roku.zip
6e127d841ee9eff7842f1b4b1a9c121645d490595e702a25c2dd3a129d078e46  viptv-roku-public.zip
```

All four harnesses, BrighterScript compilation, design integrity and package
inspection passed. Parent-PIN cancellation during episode loading returns to a
usable retry state without retiring playback. Token refresh now rewrites queued
credentials only within the current origin/identity, preserving foreign-origin
cleanup and exact cancelled-grant revocation tokens. This closes a queued-request
credential boundary defect found during the cleanup audit. Real decoder behavior
is not inferred from these handler tests.

The normal public candidate installed successfully on the TCL and remained the
active development channel. Its startup console had no runtime-error matches.
This is startup evidence only, not decoded-playback qualification.

## Shared producer adoption — d1eda1d (2026-10-23)

Producer fixture pinned to `d1eda1d96d860a436e1d93a69cb4acbd5f9a1b01` with
SHA-256 in `PRODUCER_FIXTURE_REF.json`. Design pin:
`a7b50f357376c7a5bfcf01caf4a653c088faf748`. The producer source snapshot and its
hash inventory are private in `artifacts/backend-qualification-d1eda1d/`.
Backend checkout was read/copied only; its agent-owned changes were not edited.

Roku directly consumes ordered metadata, typed badges, source title/body/chips
and resume labels/progress. Handler regressions use the shared producer fixture
and contradictory raw fields. Navigation now preserves server order/labels and
omits unavailable/unknown routes; focus survives by destination identity. Library
Clear uses the entire required `default_query`; the previous reset GET workflow
is removed. Add-on enabled state comes from its GET activation projection.

Player controls and execution require explicit server actions. Source/track
changes send `replace_source` with the active opaque lease and observed clock;
position remains zero for server resolution. Rejection, timeout and Back retire
pending admission without stopping the prior player. Tests cover denied actions,
track eligibility, replacement intent and cancellation. Calendar changes retire
old requests/auth retries and clear stale rows while loading.

Validation: all four harnesses passed (static, production SceneGraph handlers,
verified-HTTPS transport, dispatcher). Design integrity verifies209 imported
files; full design validation passed1106 assets/653 references/516tokens.
BrighterScript0.73.1 compilation and both runtime package inspections passed.

Isolated current backend lib-test build passed in51.09s (26warnings). The native
Roku HTTP adapter passed login, profile selection, bootstrap navigation, filtered
Library/default query equality, preferences/history, add-on installation and
activation confirmation, navigation refresh after activation, Home scope,
credential refresh preserving profile and logout. TLS verification stayed enabled.
Evidence: `artifacts/backend-qualification-d1eda1d/native-check.log`, ending
`CURRENT_PRODUCER_NATIVE_HTTP_OK`. Disposable accounts only. Owned fixture and
TLS proxy were stopped; shared QA18445 and production were not changed.

Candidate packages: `artifacts/producer-d1eda1d-build/packages/`:

```text
95eb7d846db04b5292e013e039aa637fb92ced4a2d5ffd47d518f82148840ef9  viptv-roku.zip
d93713ea21e46ea0bb34e0497dcee9b07547e8d9bda9aac31afac51d38e2a612  viptv-roku-public.zip
```

This candidate was not installed on TCL in this pass. Existing physical startup
evidence belongs to the earlier episode-recovery candidate. Current API checks
are not decoded playback, visual parity, native720, frame-time/input-latency or
memory-soak qualification. The per-screen/hardware gaps above remain open.

## Source best-match row — native check (2026-10-23)

The source drawer now marks only the exact server `best_match_id`. Tests prove
that a later row can be best, that filtering out the best row does not transfer
its badge, and that reused nodes remove it. The tag uses a pinned five-pixel
corner asset. Row height is108px, add-on width is measured/capped at170px, and
quality is vertically centered when the format is absent. Source order and
server display labels remain untouched.

All four harnesses and BrighterScript compilation passed. Design integrity:
210 imports; design validation1108 assets/653 reference files/516 tokens.
Network-disabled production-renderer fixture installed on TCL50S435 successfully.
Native captures verify full add-on labels, visible best-match tag, Down focus to
the next row and inverted badge colors while preserving the named source.
No fixture networking or registry access was enabled; this proves rendering and
remote focus only. Startup log reported no runtime crash. Its backdrop scaled
to1935x1080 before crop despite1920x1080 load bounds; this is recorded, not hidden
as a performance pass.

Measured dark badge bounds (exclusive right/bottom): KMP[1554,340,1673,368],
TCL[1561,270,1676,298]. Both are28px high; native width115px vs reference119px.
Rows begin at different Y because the fixture lacks filter rows. Remaining
source parity gaps include typography/placement,14px row corners, full multiline
body, producer-supported filter/header states and progressive discovery with a
real backend. This is not whole-drawer parity or a frame-time measurement.

Evidence: `artifacts/source-badge-measurements.json`,
`artifacts/tcl-current-20261023/source-badge-native-first.jpg`,
`source-badge-native-second.jpg`, and `source-badge-device-check/`.
KMP source hashes recorded in `KMP_REFERENCE_UPDATES.json`.

Normal runtime packages (fixture code excluded):
`artifacts/source-badge-build/packages/`:

```text
fd9d21ae95cd5900cbcb22f5f66a4dddf4be0a9c57d64083c1870b3df239e523  viptv-roku-public.zip
f0bd42430c185154a77b7644698f71d1153715fe97f382f91fe3e2b044dab8e8  viptv-roku.zip
```

Library refresh_after_millis/reason consumption, mutation busy handling, broad
visual parity and decoded playback/performance qualification remain open.

The normal public runtime was restored successfully on the TCL after the fixture.
`source-badge-runtime-check/` records Install Success and active dev channel.
The new launch logged compile233ms and AppLaunchChainComplete979ms; these are
single Roku lifecycle beacons, not time-to-first-content or a latency distribution.
No runtime-error/crash match appeared in the captured startup log.

## Preference mutation ownership (2026-10-23)

Preference input is now visibly busy while its PUT, auth retry, parent prompt or
revision-conflict read is outstanding. It retains the confirmed server model and
does not silently replace the submitted intent with another local snapshot.
Cancelling Parent PIN clears the pending intent and reports changes not saved.
Late success updates confirmed preferences but cannot reopen a route that was
left or close a different drawer. Late failure from a retired route cannot open
Parent PIN or overwrite the new screen's status.

Production handler regressions cover repeated input producing one PUT, exact
submitted intent, unchanged confirmed values, auth retry, Parent PIN busy/cancel,
conflict-read exclusion, late acceptance and late parent-required failure. All
four harnesses passed; BrighterScript compilation, design validation and package
inspection passed. Evidence: `artifacts/preference-ownership-r2-tests.log` and
`artifacts/preference-ownership-r2-compile.log`. This pass did not install on TCL;
the previously verified source-badge runtime remains its development channel.

Packages: `artifacts/preference-ownership-r2-build/packages/`:

```text
53976f86dc4514ef667231a63b0d146f6258cbf4a9b0a144f4b034950bc1d821  viptv-roku-public.zip
e58c583f4f7eae344c2e4bbd92ec09e4890f5d466dcb16493e7585b4149fb560  viptv-roku.zip
```

This closes the preference-save ownership gap, not all settings mutation flows.
Library hydration refresh, broad visual parity and real-media/performance
qualification remain open.

## Server-directed Library hydration (2026-10-23)

Roku now consumes Library `reason` and positive `refresh_after_millis`. Deadlines
are rounded up to the poll timer's next second; no deadline is invented when the
server omits it. Refresh waits for open overlays/auth retries and dispatcher
capacity. It reads the retained window from its accepted starting query and uses
returned cursors for subsequent pages. Visible rows remain intact until the
replacement is complete; canonical identity restores focus. Unchanged card data
keeps the existing grid ContentNode. No quality/order/metadata inference occurs.

The window retains at most three pages (current producer maximum100 cards/page).
A later page without a refresh directive does not erase an earlier page's due
refresh. Error retains the visible list and partial replacement with explicit
retry; polling cannot silently retry a failed page. Filter/route/profile changes
retire the refresh state. Back snapshots include the page window/deadline and
restore Library header geometry.

All four harnesses passed. New production-handler cases cover server delay and
reason, overlay deferral, multi-page atomic replacement, exact query/cursor,
unchanged visible data during staging,503 retry ownership, no automatic retry
loop, no duplicate cards, focus identity, absent directive, filter/profile
retirement, three-page cache bound and full-dispatcher deferral. BrighterScript,
package inspection, design integrity and full design validation passed.
Evidence: `artifacts/library-hydration-tests.log` and
`artifacts/library-hydration-compile.log`. This is handler evidence, not a new
physical-device or live producer hydration test.

Packages: `artifacts/library-hydration-build/packages/`:

```text
62d479c197a53809589de435ddee311970d950dc9dadcf359462c9f4aaa835e1  viptv-roku-public.zip
d456bbeb148d2d0e13912aa5918f62c0e69659074f58bcdae399396e8391898d  viptv-roku.zip
```

Remaining Library work includes reverse traversal of discarded pages, current
route refresh on unrelated server revision changes, and native matched states.
The broad visual/playback/performance gates remain open. TCL still runs the
previously installed source-badge candidate; these new packages were not installed.

## Cross-client Library revision invalidation (2026-10-23)

Changed profile revisions now request bootstrap so navigation/membership/profile
facts can update, and invalidate the visible Library window independently of the
hydration timer. An open drawer/filter sheet/keyboard defers its replacement.
Once unblocked, prior catalog ownership is retired and the retained accepted
window is refreshed. Unchanged revisions do not reschedule work. Query/route/
profile changes clear obsolete invalidation. Retired auth-retry requests do not
block the current Library refresh.

Four harnesses, BrighterScript compilation, runtime package inspection, design
integrity and full design validation passed. New production-handler assertions
cover changed/unchanged revisions, bootstrap scheduling, preserved filter draft,
new catalog ownership after the overlay closes and query invalidation cleanup.
Logs: `artifacts/library-revisions-tests.log`,
`artifacts/library-revisions-compile.log`. This is not physical cross-client
or real-producer event qualification; no backend files or live service changed.

Packages: `artifacts/library-revisions-build/packages/`:

```text
cd55cdd328f0842bf6b8bec3d6cf728be52d24cf7e8c041ba4edcfdf8bf9091b  viptv-roku-public.zip
2f1391b647b6104782c456abc6e22b8febc4979ecd1ed42c632185c7d958a200  viptv-roku.zip
```

Not installed this pass. TCL remains on the source-badge candidate. Other visible
routes still need a complete revision-invalidation audit. Reverse catalog paging,
full visual parity and decoded playback/performance gates remain open.

## First real gateway/TCL playback path (2026-10-23)

An owned network-isolated gateway, disposable backend fixture/account and trusted
HTTPS ingress exercised the production Roku transport, catalog/detail/viewing
requests, progressive source discovery/ranking, admission and Video adapter.
The private package used a separate `VIPTV_RokuMediaQA_20261023` registry, an
embedded QA CA, seeded disposable credentials and limited HTTP/Video diagnostics.
Video received its own CA-bearing roHttpAgent. No product API response was mocked.
Backend QA seams seeded the account/add-on and routed control to the real owned
gateway; this is not production deployment or production-network routing evidence.

Source: generated CC0 1280x720 H264/AAC MP4,36seconds. Server-selected delivery:
HLS. Device returned player state `play`, error `false`, video `mpeg4_10b`, audio
`aac_adts`; sampled position advanced4202→9380→18623ms of36069ms. Admission
returned202, ready poll200, first-frame acknowledgement200; progress and heartbeat
returned200. These are native playback telemetry, not a physical picture/audio
quality observation. Device screenshot was black and does not establish visible
video. A later sample remained `play` at35938ms; end-of-stream handling is **not
qualified** and needs investigation, rather than being counted as completion.

Back then returned player state `close`, error `false`; gateway capacity recovered
to8 inputs/8 outputs/64 viewers. Owned services/container stopped and TCL-only
firewall rule removed. Normal public runtime restored successfully and active.

The device test exposed and corrected three production defects:

- Empty Home could focus an empty action list; Select dereferenced invalid content.
  Empty Home now focuses navigation, and retired/empty action selection is a no-op.
- Custom navigation had native `focusable=false`; explicitly enabling it makes
  actual remote navigation work. Simulator focus acceptance had missed this.
- Timestamp-derived playback request IDs produced400 for admission and cancellation.
  Platform-generated UUIDv4 IDs now satisfy the producer grammar and admission
  succeeds. A retry keeps the existing request body/ID; new intent gets a UUID.

Four harnesses passed including the added empty-Home/native-focus/identifier
regressions. BrighterScript compilation, design validation and package inspection
passed. An intermediate private harness-copy error was corrected before the
successful run; it was not present in production source.

Evidence: `artifacts/roku-media-qualification/qualification-result.json`, frozen
`provenance.json`, `playback-r4-console.log`, `player-r4-*.xml`,
`cleanup-capacity.json`, `host-stopped.json`; native captures under
`artifacts/tcl-current-20261023/media-qa-*`; restore record `media-normal-restored/`.
Gateway binary SHA256: `a8ca35354f2c5477b6866c7caabb662248dda16207baceee280f1e3d7b15a95a`.
Gateway declared revision: `00b6815dd459cc783f03646f274f5169c9fb6400`.
Backend snapshot: `d1eda1d96d860a436e1d93a69cb4acbd5f9a1b01`.

Normal packages: `artifacts/media-admission-build/packages/`:

```text
fc6c77c83990de665390e6a0cad2659e34d92aca972a78a2c89c42b7939796ca  viptv-roku-public.zip
7584606effc768092b6ad84b89d676122aaa111225638b3526b6be6e25bb89cb  viptv-roku.zip
```

Seek/track/source replacement/recovery, sustained playback, visible/audio quality,
end-of-stream and full performance gates remain open. Other custom focus targets
also need a native audit. No full playback or release qualification is claimed.

## Native custom-input focus audit (2026-10-23)

Following the device-only navigation failure, all custom input Groups receiving
setFocus were audited. Keyboard, Library header/sheet, filter/password roots,
password fields/buttons, and filter facets/buttons/text-field/Clear now explicitly
set `focusable=true`. Decorative groups retain their default. Regression checks
assert the platform focus contract for each intended target.

TCL tests used private production-renderer fixtures with networking and registry
access disabled. Physical ECP remote input produced observable state changes:

- Password: Right→Select moved q→w and entered `w` in Username.
- Library sheet: Select→Down→Select changed the fixture draft from Title to Last
  watched, then restored field focus.
- Browse filters: Down→Right→Select entered Search and typed `q`. Four Down presses
  reached Clear; Select removed the draft text and returned keyboard focus.

Private captures: `artifacts/tcl-current-20261023/native-focus-password-w.jpg`,
`native-focus-library-selected.jpg`, `native-focus-filter-text.jpg`, and
`native-focus-filter-clear.jpg`. Install logs are in matching
`native-focus-*-install/` directories. These prove the exercised remote actions,
not every focus route, backend mutation or whole-screen design parity.

All four harnesses, BrighterScript compilation, design integrity/full validation,
and package inspection passed. Logs: `artifacts/native-focus-targets-tests.log`,
`artifacts/native-focus-compile.log`. Packages:
`artifacts/native-focus-build/packages/`:

```text
e33521a2f168548176f66f29a754a6004fcd6d46347f677658048910a8bb15d1  viptv-roku-public.zip
d6aa466d20dc36b03405610426a47bfc57cb1094194148f0b81db894977e00ad  viptv-roku.zip
```

The larger design/playback/performance qualification remains incomplete.

Normal public build restored on TCL successfully after the focus fixtures;
`native-focus-normal-restored/` records installation and active development channel.

## Decoder completion reporting (2026-10-23)

The explicit Video finished handler is now one-shot per attempt. It sends stop
and progress with ended=true, then requests continuation only under the supplied
server action. Repeated finished events cannot duplicate completion/continuation.
Periodic progress and late pause/start calls cannot write ended=false after that
attempt has finished. No position/duration threshold was added.

All four harnesses passed. The new production-handler regression verifies exact
completion request count/flags, repeated finished notifications, subsequent poll,
and direct late unfinished-progress/pause calls. BrighterScript compilation,
package inspection, design integrity and full design validation passed. Logs:
`artifacts/decoder-completion-tests.log`, `decoder-completion-compile.log`.

This fixes completion reporting only. It does not establish that the physical
Video node emits finished for the gateway fixture, or qualify end-of-stream lease
release. The earlier near-end playback observation and finished-overlay resource
lifetime remain open. No device install occurred in this pass; TCL remains on the
native-focus candidate.

Packages: `artifacts/decoder-completion-build/packages/`:

```text
4d46e8f716b8c875ea8c8bf039cbf80823ad7b2ca46da78581f690ba50360fe2  viptv-roku-public.zip
6b198c133ace453d4ed5b00770a4c377118942b2eaba45712e2eefd5fdcc230f  viptv-roku.zip
```

## Playback permission revocation (2026-10-23)

Track replacement now requires the independent tracks permission, rather than
also requiring change_source. Pending replacements record their invoking lease
and required track/seek/source action. Withdrawal in heartbeat cancels admission
without stopping current playback; late replies fall through existing retired
request cleanup. Next-episode replies are discarded when their permission was
withdrawn, including authentication replay, so an old target cannot reappear
upon later re-enablement. Empty player-control selection is guarded as a no-op.

All four harnesses passed. New production-handler cases use contradictory
permissions (tracks=true/change_source=false), revoke tracks and seek while
admission is queued, prove the old lease survives and request ownership retires,
and reject late continuation. BrighterScript compilation, package inspection,
design integrity and full design validation passed. Receipt/source hashes:
`artifacts/playback-revocation-build/checks.json`; compiler log:
`artifacts/playback-revocation-compile.log`. No physical revocation test or device
installation occurred; TCL remains on the native-focus candidate.

Packages: `artifacts/playback-revocation-build/packages/`:

```text
0e93fab51f1ed8911d4aad22beb066a32f2ff5e91a87e1fd6e94a078bafd028c  viptv-roku-public.zip
39f78d152d9785c531b29ada993111db36e8b0ac3b30358022531bfc24ddb5e6  viptv-roku.zip
```

End-of-stream/lease lifecycle, native seek/track/recovery, full design parity,
reverse paging and sustained performance qualification remain open.

## Recovery lease ownership (2026-10-23)

Replacement admission cannot overwrite a retained recovery lease while waiting
for first-frame acknowledgement. Additional attempts show a starting status.
Recovery heartbeat rejection/invalid delivery/expiry now releases only the
retained lease; it does not roll back the current candidate to that failed lease.
Transient renewal failures retain recovery only while its server lease is valid.
Preparation heartbeat failure cancels admission without stopping active playback.
The failure handler also rechecks recovery expiry immediately before rollback.
Release retires recovery heartbeat workers, queued requests and auth retries.

New production-handler regressions cover third-admission exclusion, transient
renewal,403 recovery rejection, invalid recovery response, timer expiry,
preparation-heartbeat rejection and current-candidate failure with an already
expired recovery lease. All four harnesses, BrighterScript compilation, package
inspection, design integrity and full design validation passed. Evidence:
`artifacts/recovery-ownership-tests.log`, `recovery-ownership-compile.log`.
No physical replacement/recovery campaign ran in this pass; these checks do not
qualify the single-decoder behavior of the TCL under actual playback failure.

Packages: `artifacts/recovery-ownership-build/packages/`:

```text
39bc969a4e04229fb45ec302d3b801c099af0d953571f61702623b33af1cf00e  viptv-roku-public.zip
3ec57309d25c94ed1bc82848bf26beef592526c49885bba37e67642022a65773  viptv-roku.zip
```

Not installed this pass. TCL remains on the native-focus candidate. End-of-stream,
real seek/track/recovery, full design parity, reverse paging and sustained timing/
memory qualification remain open.

## Direct Live viewing authority and intent retirement (2026-10-23)

Shared producer fixture now pinned to `74e0ac964a88be08738704f570d53d6c43aceae4`, including
live_source_action. Roku no longer forces Live into local Ask/resume=false state.
The server action owns its canonical card and resume/selection facts. Direct
Live streams are ranked through the common endpoint, without inventing a
stream-job ID, poll or delete URL. Watch honors the server's named best candidate;
explicit source picker remains manual. Missing action is update-required.

Live/channel and ordinary Play requests now share source-intent generation.
Changing intent retires queued requests, auth retries and superseded admission;
late same-route viewing responses cannot overwrite a newer selection. Existing
retired-admission cleanup handles ambiguous late success.

All four harnesses passed, including shared Live action validation, deliberately
contrarian resume preservation, non-first best source, explicit picker omission,
no fabricated stream-job cleanup, stale direct/viewing reply rejection, auth
retry retirement and newer Play cancelling queued admission. Compilation,
package inspection, design integrity and full validation passed. Evidence:
`artifacts/live-viewing-intent-tests.log`, `live-viewing-intent-compile.log`.
No backend source edits, device installation or physical Live test occurred.

Packages: `artifacts/live-viewing-intent-build/packages/`:

```text
4bcd743bed428d0514f3581b80585ca590ec0ccea82f1683f226dd4629b1bfe6  viptv-roku-public.zip
d560cea2ac3e00b5d08c7cb49b5b72c2d5d3324b65c63463d8ca0626e65b03bc  viptv-roku.zip
```

TCL remains on the native-focus candidate. Real Live/seek/track/recovery,
end-of-stream, full design parity, reverse paging and sustained performance
qualification remain open.

## Source row geometry comparison (2026-10-23)

Source rows now use a pinned14px corner asset and #222222 unfocused fill. Best
match is vertically centered within the34px title line, moving its28px box from
row-relative y20 to y23. Runtime tests assert the source-specific asset and tag
placement; generic row reuse still resets its asset before applying source style.

The production-renderer fixture installed successfully on TCL. Measured native
badge bounds relative to the source row: [537,23,652,51]; KMP:[530,23,649,51].
Vertical position/height now match; native width remains115px vs119px and left
edge7px farther right. Typography/horizontal placement are **not** qualified.
At y offsets[0,1,2,4,7,13], the first light corner pixels were native
[12,9,7,4,2,0] versus KMP[13,9,7,4,2,0], threshold min(R,G,B)>220. Five scanlines
match, with a one-pixel difference on the top line. KMP PNG and TCL JPEG capture
formats differ; this is sampled geometry evidence, not exact raster equality.

Evidence: `artifacts/source-geometry-measurements.json`,
`artifacts/tcl-current-20261023/source-geometry-native.jpg`, and
`source-geometry-native-install/`. Reference remains private
`artifacts/kmp-all-reference-20261023/Sources-Movie.png`. The fixture intentionally
lacks the reference filter rows, so measurements are row-relative rather than
whole-screen parity claims.

All four harnesses, BrighterScript compilation, runtime package inspection,
design integrity211 imports and full design validation1109 assets passed.
Logs: `artifacts/source-geometry-tests.log`, `source-geometry-compile.log`.
Normal packages: `artifacts/source-geometry-build/packages/`:

```text
c7dd32e370d4ce12bfdd6cd90ec1ccd6b9d77c0dae0fdeefd6c1dc52048b942b  viptv-roku-public.zip
6c98efbf7272c5b7d524ee068e6d64b4611525719f50f710604972730497facb  viptv-roku.zip
```

Full source-drawer typography/multiline/filter parity and broader design,
playback/performance qualification remain open.

Normal public source-geometry candidate restored successfully on TCL after the
fixture; `source-geometry-normal-restored/` records Install Success and active dev.

## Source typography investigation (2026-10-23)

A private KMP ImageComposeScene test extracted unmerged TextLayoutResult data
from the actual Sources preview. Relevant TvSourceRow/SourceFactBadges/theme
hashes still match the initial reference. Resolved Best match:18px/700,20px line
height,0sp letter spacing,99px layout width and98.60339px advance. Both t glyph
advances are7.59595px, matching Onest t2.alt422 units/em rather than base t366.
Add-on label:[Add-on A],20px/400,0sp spacing,103px layout width/102.079926px advance.
Thus adding arbitrary tracking would contradict the reference.

A private static-font substitution experiment compiled and passed Roku's four
harnesses, but native badge bounds remained115x28, not KMP119x28. It was reverted
and its font/generator/runtime import removed; no ineffective adapter ships.
A debugger-driven late-render probe paused within animation and is excluded from
measurement evidence. Current source badge metrics are still unqualified.

KMP render test completed successfully in an isolated Gradle build directory;
`buildDesktopTorrent` was excluded after its unrelated Go1.25 prerequisite failed.
This is a render test, not a complete KMP build gate. Evidence:
`artifacts/kmp-source-style/gradle-r5.log`, `source.json`,
`output/source-styles.txt`, `resolved-style-summary.json`, and private current
Sources capture. Context7 lookup exhausted its monthly quota; the numerical
findings above come from the compiled local KMP component, not recalled defaults.

Design pin b776e07 reverts the unverified font experiment; asset integrity remains
211 imports. The existing source-geometry public candidate was restored successfully;
its checksums and prior physical evidence remain in the preceding entry.

Restore evidence: `artifacts/tcl-current-20261023/source-style-normal-restored/`
records Install Success and active development channel.

## Fixed source-badge shaping — native measurement (2026-10-23)

A private native probe registered the pinned font through roFontRegistry and
measured GetOneLineWidth at18px (both bold flag settings), then read the SceneGraph
label after a one-second Timer. All returned95px. This rules out the proposed
font-readiness/ink-bounds explanations for this label. API references used:
[ifFont](https://github.com/rokudev/dev-doc/blob/v2.0/docs/REFERENCES/brightscript/interfaces/iffont.md)
and [ifFontRegistry](https://github.com/rokudev/dev-doc/blob/v2.0/docs/REFERENCES/brightscript/interfaces/iffontregistry.md).
Context7 remained quota-limited; official documentation and actual device output
were used. KMP's measured advance98.60339px,99px layout and baseline15.985001px
are recorded by the updated isolated render test.

The fixed Best match text is now a99x20 transparent glyph asset generated directly
from pinned OFL Onest with RAQM shaping, zero added tracking and baseline16px.
It is not derived from an application capture and does not rasterize arbitrary
provider text. Its inverse foreground tint follows focus. Layout uses explicit
asset width, avoiding the initial unloaded-Poster bounding-box regression caught
by the runtime test. The failed initial package is not the delivery candidate.

TCL corrected candidate: badge119x28 and thresholded ink bounds[11,7,108,20]
relative to its box, both matching KMP. Row-relative badge bounds are native
[533,23,652,51], KMP[530,23,649,51]. The remaining3px horizontal shift comes from
adjacent dynamic-label layout and remains open. Matching these bounds does not
claim identical antialiasing or whole-drawer parity.

Evidence: `artifacts/source-shaped-text-measurements.json`,
`artifacts/tcl-current-20261023/source-shaped-text-native-r2.jpg`,
`source-shaped-text-native-unfocused.jpg`, `source-metrics-probe-install/`, and
`source-shaped-text-native-r2-install/`. KMP evidence:
`artifacts/kmp-source-style/gradle-baseline.log` and `output/source-styles.txt`.
All four harnesses, compilation, package inspection, design integrity212 imports
and full design validation1111 assets passed. Logs:
`artifacts/source-shaped-text-r2-tests.log`, `source-shaped-text-r2-compile.log`.

Packages: `artifacts/source-shaped-text-r2-build/packages/`:

```text
688014a99da87192f28e34716da9a080beb5becda8b03681e26898b44f13ec3f  viptv-roku-public.zip
f04488acd08eda373b62613e8db645589ed3f9fab3676010a3d8b7512b7683d5  viptv-roku.zip
```

Dynamic typography, multiline/filter states, broad visual parity, reverse paging,
and remaining physical playback/performance gates are still open.

The normal public r2 candidate restored successfully on TCL; installation and
active development-channel evidence: `source-shaped-text-normal-restored/`.
The second-row focus capture verifies the badge's inverse tint on an unfocused
source while preserving its server-selected row identity.

## Library reverse page traversal (2026-10-23)

Library now records visited normalized server offsets independently of its
three-page card cache. Approaching the first retained row requests the preceding
accepted offset with the accepted query, prepends the returned page and evicts
the tail payload when required. Focus returns to the same canonical card. The
tail's next cursor survives prepending, so forward traversal works again after
backtracking. No previous offset is calculated from card count or guessed page
size. Cursor metadata is bounded to10001 scalar offsets, matching the current
producer offset ceiling10000/minimum limit1; cards remain at three pages.

Up at a noninitial window requests the prior page; Up at the initial window can
reach the header. Detail-return snapshots retain history/window index. Hydration
commit updates retained accepted offsets, revision refresh preserves preceding
history, and query/profile retirement clears it. A next cursor that points into
the retained window cannot append duplicate pages indefinitely.

Four harnesses passed. New production-handler tests cover deliberately uneven
accepted offsets17/43/88/120, three-page eviction, exact reverse request, focus
shift2→12 by identity, tail next-cursor preservation, resumed forward traversal,
detail-return history and duplicate-cursor suppression. BrighterScript compilation,
package inspection, design integrity and full validation passed. Evidence:
`artifacts/library-reverse-build/checks.json`, `library-reverse-compile.log`.
No physical reverse-scroll, input-latency or memory-soak test ran in this pass.

Packages: `artifacts/library-reverse-build/packages/`:

```text
e0bd652c343ee479d444452f99f03e6f036e8e669907896ebd2c434ec8532940  viptv-roku-public.zip
060f0953a2cf4583770bcde3d48650d7830794f8014859547570ebdd83439961  viptv-roku.zip
```

Not installed this pass; TCL remains on the source-shaped-text r2 candidate.
Browse/Home reverse traversal still needs its own audit. Full design parity,
remaining physical playback lifecycle and sustained performance remain open.

## Explicit Library page retry (2026-10-23)

A failed current Library page now blocks automatic lookahead, reverse fetch and
hydration until explicit retry. Visible cards remain in place. Grid-boundary Down
reaches Retry; Up from Retry returns to the grid, and Up at a noninitial reverse
boundary reaches Retry instead of resubmitting the failed page. Accepted Retry
preserves query/context, clears failure ownership, and restores card focus.
A full request queue retains the visible retry state. Options uses the same
retry path. Focus-driven pagination waits while a current page is queued for
authentication replay, preventing it from occupying the same request tag.

All four harnesses passed. New production-handler cases cover503 reverse-page
failure with retained cards, no implicit retry from focus/reverse/hydration,
remote Retry focus transitions,24-slot dispatcher saturation, exact query/context
replay, no duplicate activation and authentication-replay exclusion. Compilation,
package inspection, design integrity and full validation passed. Evidence:
`artifacts/library-retry-r2-tests.log`, `library-retry-r2-compile.log`.
No physical scrolling/retry or latency/memory test ran in this pass.

Packages: `artifacts/library-retry-r2-build/packages/`:

```text
827dbb3742db03e641b0bdefb14584803b76eb9dc99fa80aa13337fa35214bf5  viptv-roku-public.zip
f62e291f5728657f45380f432a420a6278f7ac53d011feac54e032c447e78c6a  viptv-roku.zip
```

Not installed this pass; TCL remains on source-shaped-text r2. Broad visual,
playback lifecycle and sustained performance qualification remain incomplete.

## Physical Library paging/retry and focus restoration (2026-10-23)

TCL testing used production handlers/rendering with a private Timer-delivered
synthetic page producer, no network or registry. Four28-title pages initialized
a three-page84-card window at offset28. The previous-page fixture returned503
once, then200 on explicit Retry. This is native UI/handler evidence, not real
backend transport, distinct-image texture pressure or sustained performance.

The first physical run exposed two failures not covered by simulator defaults:
implicit grid wrapping bypassed Up-boundary handlers, and content replacement's
transient index0 triggered alternating forward/reverse fetches. Production now
explicitly selects vertical floatingFocus and makes RemoteActionBar focusable.
Catalog replacement suppresses pagination until the restored target notification,
ignores stale focus events, and does not treat restoration as user navigation.
Roku's [ArrayGrid documentation](https://developer.roku.com/dev/docs/arraygrid)
was consulted for focus styles; device observations establish the fixes here.

Final physical sequence: six Up presses reached Retry; Select refetched offset0,
kept84 cards and restored Title28 at index28. Seven Down presses requested offset84,
kept84 cards and restored the window at first=1/index42; the final capture shows
Title77 after the remaining movement. Exactly three response records occurred:
503/offset0,200/offset0,200/offset84. No alternating requests appeared during the
six-second idle observation after input stopped. The earlier r2 oscillation is
preserved as failure evidence, not counted as qualification.

Private evidence: `artifacts/library-device-paging-results.json`,
`library-device-paging-r3-console.log`, and captures under
`artifacts/tcl-current-20261023/library-device-paging-r2-retry.jpg`,
`library-device-paging-r2-recovered.jpg`, `library-device-paging-r3-forward.jpg`.
The screenshot also exposes error copy overlaying poster artwork; footer
readability/geometry remains an explicit visual issue.

A further handler regression fixes empty accepted queries leaving old rendered
cards after the model had already been cleared: content reuse now checks rendered
card count. That final guard has handler/build evidence, not a separate native
empty-result capture. All four harnesses, compilation, package inspection,
design integrity and full validation passed. Logs:
`artifacts/library-focus-restore-r3-tests.log`, `library-focus-restore-r3-compile.log`.

Final normal packages: `artifacts/library-focus-restore-r3-build/packages/`:

```text
3d10ea5fe0306e1873caf939c8f5abdc6cdce5ecfdc7165b9ac5530ee1da7f52  viptv-roku-public.zip
f4a179d9ae29a1b8de81abf2fcde4ae5aa9c2a4b3137f6ab57ea8f12a8e0f13a  viptv-roku.zip
```

No FPS, input-latency or memory-soak conclusion follows from this sequence.
Full design parity, remaining real playback lifecycle and broader paging
qualification remain open.

Final normal public r3 candidate installed successfully and remains active on TCL;
restore evidence is `library-focus-final-normal-restored/`. All disposable paging
fixture collectors have finished; no fixture backend service was used or left running.

## Library status readability and KMP placement (2026-10-23)

A private KMP TvLibraryScreen render measured the actual error text at[96,236],
31px one-line layout, baseline23.68px,24px font and danger#FF7A6E. The current
source differs from the initial pin only by tvGridItem focus annotations; its
status layout is unchanged. Hash and delta evidence are recorded in
KMP_REFERENCE_UPDATES.json and `artifacts/kmp-library-error/reference-delta.diff`.
The render test used isolated Gradle output and excluded the unused torrent task.

Roku now positions Library errors/reasons above retained cards, reserving31px for
one line or62px for two bounded lines. Errors use danger color; reasons use
secondary. Empty status restores grid y236. Native wrapped Labels required a
62px transparent drawing area even for the one-line case; layout reservation is
computed separately from an unwrapped measurement. Earlier two-line-overreserve
and invisible-text candidates are excluded from final evidence.

TCL r3 shows one-line error text above posters and grid y267. Explicit Up/Select
Retry succeeds; the next capture shows status removed and grid y236 with Title28
focus restored. Thresholded red ink bounds: KMP[97,242,536,265],
TCL[98,243,514,266]. Placement/readability improved; native glyph width/baseline
still differ and exact typography parity remains open. The supported native Retry
button remains at its existing opaque footer position; it is not claimed as a
KMP visual match. Long two-line device states remain to be compared.

Evidence: `artifacts/kmp-library-error/gradle.log`, `library-error-style.txt`,
`artifacts/library-status-measurements.json`, and private TCL captures
`library-status-native-r3-error.jpg`/`library-status-native-r3-recovered.jpg`.
All four harnesses, compilation and package inspection passed; an additional
production-handler check verifies two-line reservation and clearing. Logs:
`artifacts/library-status-r3-tests.log`, `library-status-multiline-test.log`,
`library-status-r3-compile.log`. Design integrity/full validation also passed.

Final packages: `artifacts/library-status-r3-build/packages/`:

```text
90650779c73565aac0af3717b6bd4c916630958e4a06ba1a50d6281fd31e78ed  viptv-roku-public.zip
02c964b9f5958a9d2df579c5251b0392a37ac76875cb00f054ba9adcbce1e4da  viptv-roku.zip
```

This does not qualify full Library empty states, dynamic typography, broad design
parity, remaining playback lifecycle or sustained performance.

Normal public Library-status r3 package restored successfully and active on TCL;
restore evidence: `artifacts/tcl-current-20261023/library-status-normal-restored/`.

## Library status and retry on return (2026-10-23)

Returning from details now restores Library controls, normalized defaults, server
reason and status-row geometry without accidentally rendering stale Browse
controls. Pending revision invalidation survives the round trip. Failed page
requests retain their visible Retry state; return snapshots store only intent
fields/message and any failed hydration staging, not access-token/base copies.
Restored retry binds to the current epoch/route/catalog generation before replay.
Explicit Retry consumes prior revision invalidation because the new read obtains
current server state. Unfinished nonfailed hydration restarts from accepted pages.

All four harnesses passed, covering server reason/defaults, unrelated Browse
control exclusion, pending revision restoration, credential-free failure intent,
new route ownership, failed hydration staging and successful replacement commit
following return/retry. An initial test compared defaults before intentional null
omission; its expectation was corrected to the existing normalized wire-query
contract. Compilation, package inspection, design integrity and full validation
passed. Evidence: `artifacts/library-return-state-r2-tests.log`,
`library-return-state-r2-compile.log`. This pass added no physical return-state
qualification and did not install a device package.

Packages: `artifacts/library-return-state-r2-build/packages/`:

```text
9c70bc3d55b4035dde936a4ed265ffc74cd498c8cda6e86cd32709bc758e685f  viptv-roku-public.zip
f409f96d22f1a88e5e9255055d93ed37c9f1b94539f6de75456dd0c3af4e0457  viptv-roku.zip
```

TCL remains on Library-status r3. The current screen matrix above has been
reconciled with the accumulated evidence; its remaining gates are still open.

## Mutation-safe return cache invalidation (2026-10-23)

Accepted mutations and changed server revisions now invalidate return-view data
without deleting the navigation path. Cached cards, Home models, Library pages/
cursors/failed hydration and stale controls are cleared; route/query intent stays
so Back refetches the correct destination. Progress/event acceptance also retires
return models. Profile/origin changes continue to clear the entire stack.
The obsolete membership invalidation loop after stack deletion was removed.

Library membership acceptance marks a currently visible Library for refresh.
Invalidated Browse return preserves catalog/facet intent, resets pagination, and
resolves its selected catalog label/control data from fresh server descriptors.
No local membership or progress mutation was introduced.

All four harnesses passed. New production-handler cases verify membership writes
preserve a Library return route while retiring card payload, Back refetches its
saved genre query, progress/revision updates retain the navigation path, and
Browse refetch uses its saved filter with current server control labels.
Compilation, package inspection, design integrity and full validation passed.
Evidence: `artifacts/return-cache-invalidation-tests.log`,
`return-cache-invalidation-compile.log`. No native mutation/Back campaign ran.
Fresh-refetch focus identity/deep-scroll restoration still needs its own audit.

Packages: `artifacts/return-cache-invalidation-build/packages/`:

```text
bf8672e36ce3030026936fc215eb8e4f263663d742da5aef2c8711b41cf0b3f4  viptv-roku-public.zip
10ec3177039be512874ff60c47604ebcfed5cc04b4b6e5e8e8ef37b6fcc3e147  viptv-roku.zip
```

Not installed this pass; TCL remains on Library-status r3. Full design parity,
remaining native lifecycle states and sustained performance gates remain open.

## Selection identity after refetch (2026-10-23)

Invalidated catalog return now retains the selected canonical key, including
metadata origin. On refetch, selection follows that key in the current server
result instead of overriding it with an obsolete numeric index. No results are
reordered. If the target is absent, the first returned card is selected and the
pending restoration is cleared. New query/route/profile ownership clears it.
Known indexes are still used only when restoring an unchanged cached window.

All four harnesses passed. New cases reorder two cards with the same ID but
different metadata origins, verify the exact selected origin at its new index,
cover absent target and query retirement. The refetch restoreIndex path was
removed. Compilation, package inspection, design integrity and full validation
passed. Receipt and source hashes: `artifacts/refetch-selection-build/checks.json`;
compiler log: `artifacts/refetch-selection-compile.log`.

This is selection-within-returned-results evidence. It does not locate a target
outside the refetched page or qualify physical focus ownership while a refetch
is pending; deep-window relocation and native return states remain open.
No device install occurred; TCL remains on Library-status r3.

Packages: `artifacts/refetch-selection-build/packages/`:

```text
fd2a2bae54b6c055dd81942bd954cc0f29e279f79320dc73578b39e47dc8830f  viptv-roku-public.zip
532da40169d7f5a699322979625aadfc15e5529e9d86a7d9d128905aa186f569  viptv-roku.zip
```

Full design parity, remaining playback lifecycle and sustained performance
qualification are still incomplete.

## Live group response ownership (2026-10-23)

Live group changes now retire channel-list/page/guide workers, queued requests,
pending tags and authentication retries before submitting the new group. Old
channel rows and hero preview are hidden while Loading channels… is shown; group
controls remain available. Responses/failures must match the Live generation and
query. Paging also checks its current next/previous cursor before replay. Direct
Live sources retain their independent source-intent scope.

All four harnesses passed. New production-handler cases exercise50 rapid groups
leaving one latest request, worker cancellation, guide auth retirement, rejection
of stale parent-required failure without consuming new pending ownership, ignored
old guide data, latest server reason replacing loading, and outdated page-cursor
rejection. Compilation, package inspection, design integrity and full validation
passed. Evidence: `artifacts/live-group-ownership-tests.log`,
`live-group-ownership-compile.log`. No native Live group/paging campaign ran.

Packages: `artifacts/live-group-ownership-build/packages/`:

```text
ab125739101b5923a971c77dad21f9ffaeda140f4baef3db816a30fcd977dcc5  viptv-roku-public.zip
279b3654db193357395973667a66d8a2b1c21bac084fe7df84b7b14a391524ea  viptv-roku.zip
```

Not installed this pass; TCL remains on Library-status r3. Native Live rendering,
selection/paging, actual Live playback, broad parity and sustained performance
qualification remain open.

## Live guide retry and overlay isolation (2026-10-23)

A current Live data failure now pauses automatic guide/page reads while keeping
cached preview navigation. Authentication replay also blocks competing metadata
requests. Errors arriving behind a drawer or active player are retained without
rewriting that foreground status; returning focus to Live exposes the deferred
failure. Repeated focus movement does not rebuild the same Retry UI or resubmit
its request. Explicit Retry returns focus to rows and successful retry clears
its old message without hiding a different current failure. New group/profile
ownership clears deferred failure state. The shared Retry action now rejects
retired request scopes before sending anything.

All four harnesses passed. Production-handler cases verify a guide503 cannot
overwrite Finding sources…, deferred status appears on return, no focus-driven
retry loop, exact path/method/context replay, restored row focus, success clearing,
auth replay exclusion and stale Retry rejection. Compilation, package inspection,
design integrity and full validation passed. Evidence:
`artifacts/live-error-recovery-tests.log`, `live-error-recovery-compile.log`.
No physical guide-error/retry campaign or live-network fault test ran here.

Packages: `artifacts/live-error-recovery-build/packages/`:

```text
a24a259dbfe0aee5d1feaad95d88e26ce97ee0688a55dd2dd3776dce9b644109  viptv-roku-public.zip
f42c9a271875d43913fafbb278e18e9385178b105efe7b90527e67ae732448f3  viptv-roku.zip
```

Not installed this pass; TCL remains on Library-status r3. Native Live states,
full visual parity, remaining playback lifecycle and sustained performance gates
remain open.

## Unique guide cache slots (2026-10-23)

Replacing a channel guide now removes its old cache-order entry before appending
the refreshed slot. Duplicate order entries can no longer evict that channel's
newest payload. Channel/program order and source selection are unchanged.

All four harnesses passed. New production-handler cases exercise20 refreshes of
one channel retaining one slot/latest payload, no redundant focus-driven fetch,
12-distinct-channel eviction, attached-row cleanup and one refetch after eviction.
Compilation, package inspection, design integrity and full validation passed.
Evidence: `artifacts/guide-cache-slots-tests.log`, `guide-cache-slots-compile.log`.
This is bounded cache/handler evidence, not native heap or sustained guide-scroll
performance qualification. No device install occurred.

Packages: `artifacts/guide-cache-slots-build/packages/`:

```text
05a96545307715c91c4075351c62f515f2daef3419cb3c9d1fecfa20b94d7cfc  viptv-roku-public.zip
27f010348f6701fcf89c491d7c7b0294e3b96e6ecb726a2ff8452a5d17b9dd8e  viptv-roku.zip
```

TCL remains on Library-status r3. Remaining native Live, visual parity, playback
lifecycle and sustained performance gates remain open.

## Live programme selection across refresh (2026-10-23)

Initial selection still follows the server current_program_id/window. Explicit
Left/Right browsing now records programme identity, preserving it through guide
reordering and retained channel-page replacement. Its viewport follows the
selected programme. If the ID disappears, manual selection clears and the
producer's current programme/window is used. The server current marker is never
rewritten and no current-programme decision uses the local clock.

All four harnesses passed, including initial server selection, manual browse,
reordered data, retained-row replacement and missing-ID fallback. Compilation,
package inspection, design integrity and full validation passed. Evidence:
`artifacts/guide-selection-tests.log`, `guide-selection-compile.log`.

TCL test used a disposable production-renderer fixture with no network/registry.
Right selected B. A fixture-only Info hook delivered reordered programme data
with server current=C; native output and capture show manual=b,selected=0,
current=c,window=1800 and Selected B highlighted. A second injected response
removed B; output shows manual empty,selected=1,current=c,window=3600 and Current C
highlighted. The special Info injection is excluded from normal packages.
This verifies native selection/render transitions, not real guide transport,
full guide geometry, Live decoding or performance.

Private evidence: `artifacts/guide-selection-native.log`,
`guide-selection-native-removed.log`, TCL captures
`guide-selection-native-preserved.jpg`/`guide-selection-native-removed.jpg`, and
`guide-selection-device-install/` under `artifacts/tcl-current-20261023/`.

Normal packages: `artifacts/guide-selection-build/packages/`:

```text
e5100189a11e9268992795d5f89db729d819343e3e2d5991cb49c2376b700a2a  viptv-roku-public.zip
9072d0112b79b8f9a0b6b57b299b0599c0d1f95ff186a741d7e172ef565be53b  viptv-roku.zip
```

Remaining native Live groups/paging/error states, real Live playback, full design
parity and sustained performance gates remain open.

Normal guide-selection public runtime restored successfully and active on TCL;
restore record: `artifacts/tcl-current-20261023/guide-selection-normal-restored/`.

## Live page metadata and unavailable windows (2026-10-23)

Channel-page merging now takes group/connection/reason/availability metadata from
the latest accepted response while preserving server page order and the retained
tail's cursor/completion. A non-Available response retires prior Live data work
and replaces the cache instead of merging old channels into the unavailable
state. Empty data hides old rows/preview, omits the inert All-only group control,
and focuses available top navigation when no overlay/player owns focus.

Transport validation now requires current Live channel-page arrays, completion,
availability and channel identities/cards, with the requested100-channel bound.
Missing availability is update-required, not a local unavailable fallback.
All four harnesses passed, including changed labels/reason, page ordering,
current-next-page unavailable replacement, retired guide auth work, empty focus,
overlay focus isolation and missing-field rejection. Compilation, package
inspection, design integrity and full validation passed. Evidence:
`artifacts/live-page-metadata-final-tests.log`, `live-page-metadata-final-compile.log`.

Current producer LivePage lacks snapshot scope/revision. Concurrent server
configuration changes across retained pages therefore remain an explicit
integration dependency in BACKEND_HANDOFF.md, with source hash/commit recorded
in BACKEND_CONTRACT_REF.json. Local generation/cursor checks do not prove server
snapshot coherence. No backend code changed and no physical page-metadata test
ran in this pass; native page-focus restoration remains unqualified.

Packages: `artifacts/live-page-metadata-final-build/packages/`:

```text
908192d5ee9252f429cec18b6da25b39c44e1820d2424afefe3240296e5c0dc2  viptv-roku-public.zip
ada36c2971e0d6f8047f61d82b1a4632e0401ee16dd5a7e9418b8e31f8320369  viptv-roku.zip
```

Not installed this pass; TCL remains on guide-selection. Full Live/native
lifecycle, design parity and sustained performance gates remain open.

## Native Live page focus restoration (2026-10-23)

Live channel-window replacement now sets its intended channel index before
assigning row content. Transient focus notifications are ignored until the target
is acknowledged; stale notifications afterward are ignored. Guide/page reads
and hero preview wait, then resume through the existing settle timer. New
routes/groups retire the guard. This prevents index0 during native content
replacement from initiating previous-page lookahead.

All four harnesses passed, including a three-page/two-page-cache case restoring
channel35 from index35 to15, rejected transient0, restored-focus acknowledgement
and no page request from the middle of the retained window. Compilation, package
inspection, design integrity and full validation passed. Logs:
`artifacts/live-page-focus-tests.log`, `live-page-focus-compile.log`.

Physical TCL fixture used synthetic Timer-delivered pages/guides and no network or
registry. Starting with40 channels at index31, four Down presses requested offset40.
Exactly one page response was recorded: first=1,channels=40,focused=15. Native
capture shows Channel35 and its programme still highlighted/previewed. No reverse
page request appeared during the six-second idle observation. This is a bounded
forward-boundary smoke test, not latency/FPS/memory or real-provider qualification.
Private evidence: `artifacts/live-page-focus-native.log`,
`artifacts/tcl-current-20261023/live-page-focus-native-forward.jpg`, and
`live-page-focus-device-install/`.

Normal packages: `artifacts/live-page-focus-build/packages/`:

```text
d6c88ecb410d9c9e4cd139454669c77287d9d5ac4408f27c15ae6f56afa478d5  viptv-roku-public.zip
94a60faab1344ea6bde927a6d663832b5ea5401de2a91283721098af8c6f30d7  viptv-roku.zip
```

Native group/backward/error combinations, producer snapshot coherence, actual
Live decoding, complete design parity and sustained performance remain open.

Normal public live-page-focus runtime restored successfully and active on TCL;
restore evidence: `artifacts/tcl-current-20261023/live-page-focus-normal-restored/`.

## Current guide wire validation (2026-10-23)

The Task boundary now validates Live guide identity, availability, programme
array and server view fields before renderer arithmetic. Window/current-marker
fields cannot be missing; timestamps must be numeric/nonnegative, window end
must exceed start and programme intervals cannot run backward. Wrong-channel
replies are rejected when request context identifies the channel. Programme
order and supplied current ID remain unchanged. Renderer window initialization
no longer supplies an epoch-zero default for a missing server window.

All four harnesses passed. New cases cover current empty guide, surprising
programme order, numeric strings, missing/invalid windows, reversed intervals
and wrong-channel data. Verified-HTTPS production Task tests accept large epoch
milliseconds and reject a malformed guide with contract_error before rendering.
Compilation, package inspection, design integrity and full validation passed.
Evidence: `artifacts/guide-wire-validation-tests.log`,
`guide-wire-validation-compile.log`. The local guide fixture now includes the
current availability/reason fields; this is not legacy-response compatibility.

These tests establish wire handling, not native viewport precision with real
large epoch values. The physical guide fixtures used small synthetic times;
timestamp-to-viewport precision remains a required native check. No device
installation occurred in this pass.

Packages: `artifacts/guide-wire-validation-build/packages/`:

```text
8c869b44b7ef91cb74695cc4c2fa496d9503095bdc107554425dd2e52968a1f9  viptv-roku-public.zip
938d46dcfedb5802cf488a69434a1cd197053f2f1f24c74f8dd0961da68fbbd9  viptv-roku.zip
```

TCL remains on live-page-focus. Full native Live, producer snapshot coherence,
visual parity, remaining playback lifecycle and sustained performance remain open.

## Native guide epoch precision (2026-10-23)

The TCL probe reproduced an8-second error storing1800001800 epoch seconds in
the row's inferred roFloat windowStart field. Production now keeps viewport epoch
milliseconds in an associative record, subtracts that origin before projecting
programme offsets into the1400px/two-hour timeline, and materializes manual
30-minute alignment as LongInteger. The old scalar windowStart path was removed.
[Roku numeric type documentation](https://developer.roku.com/dev/docs/expressions-variables-types)
was consulted for explicit64-bit integer storage.

A private native Task parsed current-shaped guide JSON with integer timestamps.
The fixed initial viewport reported wire_delta_ms=0, viewport_delta_ms=0 and
LongInteger type. A programme starting1000ms after the window projected x=
0.19444444444444 and width341.80555555556 as expected. Manual Right browsing in
r3 reported LongInteger value1800003600000 and delta_ms=0. An earlier manual probe
reported roFloat; its mixed-type zero subtraction was insufficient and is not
counted as precision proof. This qualifies the exercised native JSON/viewport
arithmetic, not real-provider guide transport or every timestamp range.

Evidence: private `guide-time-probe-install/`, `guide-time-fixed-r3-install/`
under `artifacts/tcl-current-20261023/`, plus
`artifacts/guide-time-manual-r3-native.log`. The Task/diagnostic fixture is excluded
from normal packages. All four harnesses, BrighterScript compilation, package
inspection, design integrity and full validation passed. New regressions cover
large epoch preservation, fractional pixel projection and exact integer manual
alignment. Logs: `artifacts/guide-time-precision-r3-tests.log`,
`guide-time-precision-r3-compile.log`.

Packages: `artifacts/guide-time-precision-r3-build/packages/`:

```text
69f381f3ac69cfe67264f4f234a42b6c59a263eb64d25070cb02475aefffc8e4  viptv-roku-public.zip
cc66ea0e30c0a3faab03c08a63466382afbc067d8c61d15af42c8716b814bd09  viptv-roku.zip
```

Guide freshness during long sessions, full Live layout/network states, producer
snapshot coherence, actual Live decoding, remaining playback lifecycle and
sustained performance remain open.

Normal guide-time-precision r3 public runtime restored successfully and active
on TCL; restore evidence: `guide-time-normal-restored/` under the private TCL artifacts.

## Visible guide freshness and parent authorization (2026-10-23)

Live now refreshes its focused/nearby guide working set on a30-second transport
cadence, bounded to10 rows (four before focus through five after). It leaves
cached rows visible and consumes current-programme decisions from each server
response; no programme is advanced from the client clock. Refresh pauses for
overlays, playback, restoration, explicit Retry, auth replay and parent approval.
Queue-capacity preflight defers the batch without creating a background busy error.

Background guide parent-required responses are deferred as Retry rather than
opening PIN over another operation. Explicit retry can request PIN; cancellation
restores a paused failure state and clears retry authorization intent. Pending
parent authorization owns its request slot even after the keyboard closes.

Four harnesses passed, plus an additional queue-capacity handler test. Cases cover
cadence,10-row bound, overlay deferral, no per-tick multiplication, background PIN
isolation, explicit authorization/cancel, and capacity return. Compilation,
package inspection, design integrity and full validation passed. Evidence:
`artifacts/guide-freshness-tests.log`, `guide-freshness-capacity-test.log`,
`guide-freshness-compile.log`.

Native TCL fixture used Timer-delivered synthetic guide/revision responses with
no networking/registry. It recorded the initial guide at196ms, refreshes at30143ms
and60143ms: intervals29947ms and30000ms. The producer fixture changed its current
marker A→B; capture shows Server programme B selected afterward. Evidence:
`artifacts/guide-freshness-native-results.json`, `guide-freshness-native.log`,
`artifacts/tcl-current-20261023/guide-freshness-native-updated.jpg` and
`guide-freshness-device-install/`. This is a short one-channel native cadence
check, not a provider/network or sustained FPS/memory measurement.

Packages: `artifacts/guide-freshness-build/packages/`:

```text
8b0715c9f67d04854e1666b88919e5b348c3c602eb7c78947cbbfcabd39e5b1a  viptv-roku-public.zip
8bef9360f3c16e58ffa71a4ba66829e131ee01bf1c67912bad2fe90d2ec09aa5  viptv-roku.zip
```

Real-provider guide freshness, native permission/error combinations, producer
snapshot coherence, full visual parity, remaining playback lifecycle and sustained
performance remain open.

Normal guide-freshness public runtime restored successfully and active on TCL;
restore evidence: `artifacts/tcl-current-20261023/guide-freshness-normal-restored/`.

## Bounded guide tile reuse (2026-10-23)

Guide rows now project a bounded visible display model and retain up to32 tile
groups. Unchanged visual data repaints selection without destroying programme
nodes. Changed titles/geometry update existing groups; unused groups hide and
release text. One dedicated empty label displays the server reason. Retiring
itemContent clears cached text/model references. Programme labels narrower than
their padding are hidden with nonnegative width. Programme font nodes are shared
within each row. Guide application computes final selection before publishing it,
avoiding the previous intermediate index=-1 update.

All four harnesses passed. New tests prove node identity survives clock-only and
title updates, pool ceiling32, safe narrow cells, empty-status behavior and text
cleanup on retirement. Compilation, package inspection, design integrity and full
validation passed. Logs: `artifacts/guide-tile-reuse-tests.log`,
`guide-tile-reuse-compile.log`.

Native TCL fixture retained3 constructed tile groups while visible entries changed
3→2→1 and through subsequent unchanged updates. Instrumentation counted createChild
Group operations, not all allocations. Capture shows correct final Current C
selection. The fixture had no network/registry and its diagnostics are excluded
from normal packages. Evidence: `artifacts/guide-tile-reuse-native.log`,
`guide-tile-reuse-native-results.json`, TCL `guide-tile-reuse-native.jpg` and
`guide-tile-reuse-device-install/`. This proves the tested native reuse path;
full dense-guide frame time, input latency and memory soak remain unmeasured.

Packages: `artifacts/guide-tile-reuse-build/packages/`:

```text
0dd5ffbf2735c2d3e994bc78f7b357acd64635d2a563ea2a68b866bc650bf24f  viptv-roku-public.zip
1e5d4f51ccb6cec80d36873365ad8a033d89793077a7aba8164a4e0d05b5e6bf  viptv-roku.zip
```

Producer snapshot coherence, full design parity, remaining real playback lifecycle
and sustained performance qualification remain open.

Normal guide-tile-reuse public runtime restored successfully and active on TCL;
restore evidence: `artifacts/tcl-current-20261023/guide-tile-reuse-normal-restored/`.

## Current producer adoption and backdrop reload (2026-10-23)

Producer fixture refreshed to backend `e8e7b5fa74a581dc6c40d6876edee9ab3f9a665d`;
exact file hash in `PRODUCER_FIXTURE_REF.json`. Ordered metadata, typed badges,
source display and resume labels remain direct producer projections. No backend
files were edited. Newly supplied Live `snapshot_id` closes the previous missing
producer-field dependency. Equal IDs preserve page order; mismatched forward or
backward pages discard old content/cursors, retire guide requests and reload the
unchanged query at offset zero. Missing/empty IDs are incompatible responses.
Production-handler tests cover failed reload and explicit Retry without reviving
the incompatible directory. This is not real-backend/native configuration-change
qualification. New navigation search flags in the fixture have not been qualified
in this pass.

All four harnesses passed (`artifacts/producer-snapshot-final-tests.log`).
BrighterScript compilation, design integrity, design validation and package
inspection passed. Design pin is `998eae0c456040aeaf7311652581d6a6c6419f78`.

TCL native image probe: a774x432 source displayed in Live's640x360 box previously
decoded to1935x1080 (requested1920x1080). Bounding the request to640x360 produced
645x360. Exact target texture allocation fell from8495104 to1032192 bytes; this
is per-image allocation, not total RAM or frame-time evidence. Baseline and sized
texture records: `artifacts/live-image-baseline-bitmaps.xml`,
`artifacts/live-image-sized-bitmaps.xml`, `artifacts/live-image-allocation.json`.

Changing load bounds alone retained the small bitmap for the same URI. Runtime
now clears that unchanged URI when decode bounds change, then requests the new
size. Native transition evidence (`artifacts/live-image-reload-transitions.log`)
reports645x360 Live →1935x1080 full Home →1160x647 compact Home, with unchanged
source bytes and crop mode. Native aspect-preserving decode exceeds one dimension
slightly. Flash-free transition, sustained texture reuse and frame timing remain
unqualified; this test proves actual resized decoding, not animation performance.

Packages: `artifacts/producer-snapshot-build/packages/`:

```text
121f09f883b1db7ade5ee5186a4d4aab6341dce16249ddd7a2fd55b388390740  viptv-roku.zip
7dd3c2ead00d08a8aef80c694a77044d878e6061c194bf67ced4ce5ee082c845  viptv-roku-public.zip
```

Full per-screen KMP parity, native720p qualification, remaining playback lifecycle
and sustained hardware performance remain open. The prior spontaneous reboot's
root cause is still unproven.

Normal public runtime installed successfully and active on the TCL after removing
the temporary image fixture. Restore evidence:
`artifacts/tcl-current-20261023/producer-snapshot-normal-restored/`.

## Capability-scoped search and channel row (2026-10-23)

Roku now consumes explicit bootstrap media_search/channel_search flags. Live-only
profiles request only profile-scoped channel search. Mixed profiles retain current
shared grouped /api/search for the KMP media rows and separately request channels.
This endpoint remains in the current producer; it is not a legacy fallback. Query
edits retire workers, pending/queued requests and authentication replays before
debounce. Missing flags grant no authority. Channel rows preserve server ordering,
Card identity and connection ID; activation uses the existing Live source action.
Two channel pages are retained, with opaque cursor history for backward refetch.
Snapshot mismatch clears incompatible channel results and reloads offset zero.
Successful media results remain independent from channel failures and vice versa.
Both request failures remain available for serial Retry rather than overwriting one.

All four harnesses passed (`artifacts/search-channel-geometry-tests.log`). Added
handler cases cover capability omission/revocation, both result sets, query
retirement, independent failures and snapshot replacement. Additional bounded-page
and unset-query regressions are recorded in `search-channel-expanded-runtime.log`.
Compilation/package inspection passed; design inventory initially failed because
new generated assets were not inventoried, then passed after explicit provenance
and hash inventory commit30b56fa. No backend source was changed.

The first native fixture exposed an unset searchTerm crash during capability
refresh before typing. rSearchSubmit now guards the value and init initializes it.
Native r2/r3 installed and launched successfully. r2 physical Right/Right/Left
focus trace is0→1→2→1 (`artifacts/search-channel-native-r2-focus.log`). This fixture
uses empty credentials/example.test and has registry loading disabled; later audit
found dispatch was enabled in the derived r2/r3 fixture. It is not backend
integration or network-isolation evidence. Native
pagination/retry/selection and Back still require a dedicated device campaign.

Private r3 capture: `artifacts/tcl-current-20261023/search-channel-native-r3.jpg`.
Measured channel image box origin700,196, size356x200; next origin1076,196 yields
20px gap. Dedicated generated masks use radius10, focus3, gradient#1D2230→#121318;
logo140x140 centered, absent-logo full server title Bricolage800 size56, red LIVE
pill60x28/radius6 at12,12. Initial r2 reused the generic movie mask/solid ground
and imagey208; r3 corrects those differences. KMP source hashes and geometry are
in KMP_REFERENCE_UPDATES.json. Matched same-content KMP capture, native720p,
font ink/letter spacing,120ms focus animation and long-title wrapping remain open.
Provider-group empty/error messages and media/channel mixed-state focus restoration
still need qualification/correction; do not treat this as full Search parity.

Packages: `artifacts/search-channel-final-build/packages/`:

```text
191c8e3ac44c2695c147008f2f19e611d87209415a391c4e5ab8cb913f07c312  viptv-roku.zip
ef96df9246c7e9b6b0e7c581b911b704b5f128c47c293e49ee3b285642c7b55e  viptv-roku-public.zip
```

Updated normal public runtime installed successfully and active on the TCL;
restore evidence: `artifacts/tcl-current-20261023/search-channel-normal-restored/`.
No runtime error appeared in its captured startup log. This is a short startup
check, not a crash-free soak claim.

## Search empty/provider-error states and focus identity (2026-10-23)

Server groups now retain their headings and exact message even with zero cards.
Empty groups without a message display “No matches.”; no selectable placeholder
cards are created. Current shared complete=false responses retain usable cards
and offer an explicit retry of that request. Complete retry clears that failure
without hiding an independent channel failure. Channel NeedsConfiguration/reason
is displayed as a channel status row, not collapsed into a generic no-match state.
Search-results entry and Retry return skip groups without actual results.

Focus now resolves server group ID plus canonical card identity (including metadata
origin), instead of restoring a numeric item index. Missing target falls back to
the first actual card; no cards restores keyboard/Retry and clears the focus guard.

All four harnesses passed (`artifacts/search-status-final-tests.log`). Added cases
cover exact provider messages, empty focus, title/message geometry, reordered and
removed cards/groups, partial-result retry, complete retry and channel unavailability.
BrighterScript compilation, package inspection, design integrity and design
validation passed. Compilation: `artifacts/search-status-compile.log`.

Native TCL fixture with registry loading removed rendered both empty group headings
and messages with zero card children. Private capture:
`artifacts/tcl-current-20261023/search-status-native.jpg`. First logical heading
origin700,140; message700,200; second heading700,292 and message700,352. These are
source-box geometry confirmed by native layout; glyph ink differs from box origin.
Keyboard remains focused. This proves RowList displays the zero-card status rows;
long/many-group scrolling, clipping and same-content KMP ink comparison remain open.

Separate native fixture staged focus on B at row0/item1, then exercised production
rSearchRender on Info: B moved to row1/item0 and stayed selected; removing B selected
A at row0/item0; replacing results with an empty group restored keyboard focus.
The pending guard cleared on each tested replacement. Evidence:
`artifacts/search-focus-native-transitions.log`,
`tcl-current-20261023/search-focus-native-install/`. The initial B selection was
fixture-staged, not a physical initial-navigation test; no network/backend
integration or focus-latency claim follows from this trace.

Packages: `artifacts/search-status-build/packages/`:

```text
7ab1c27e0da9f182936c88787b71782cf2e51a573cdc995893a24c3ecdf237d5  viptv-roku.zip
b1c3f533b256adfcbaff47f1e672f565c9c588d5f3326bfae818918612fd40c9  viptv-roku-public.zip
```

Still open: mixed media/channel late-response focus on hardware; large status-only
sets; long provider messages; real backend partial-provider retry; native720p;
font metrics/motion parity; sustained memory, frame times and input latency.

Normal public runtime restored successfully and active on TCL, with no runtime
error in the captured short startup log. Restore evidence:
`artifacts/tcl-current-20261023/search-status-normal-restored/`.

## Search channel pagination ownership (2026-10-23)

Channel search now owns a generation independent from the media search/query
version. Snapshot replacement cancels channel workers and retires queued requests,
authentication replays, pending ownership and channel failures before reloading.
Media requests/replays/results remain intact. Current-response validation also
requires exact retained next/previous cursor; initial replies are accepted only
while the channel window is empty. Duplicate initial replies and old cursors cannot
replace a populated window. This removes the same-query stale-page hole.

All four harnesses passed (`artifacts/search-page-ownership-final-tests.log`).
Regression cases include stale initial/next cursors, snapshot generation change,
media auth replay surviving channel reset, and an actual production rResponse
invocation delivering an old page while a new initial request owns the pending tag.
It cannot populate the cleared window or clear the new request's ownership.
Compilation (`search-page-ownership-compile.log`), design integrity/validation and
package inspection passed. No new native/device evidence is claimed for this pass.

Payload retention remains two channel pages. Current requests use limit40; transport
shape validation admits at most100 channels/page, so the renderer's accepted
retained window is at most200 channels, normally80 under the current producer.
Cursor history remains separate scalar state, not retained page payloads. This
pass does not claim measured heap/texture bounds or sustained frame timing.

Source audit found an upper-offset producer inconsistency: stored-catalog pages
can emit next_cursor10040 when the next request's LiveQuery validator rejects
anything above10000. Exact counterexample and source hashes are recorded in
`artifacts/live-offset-bound-observation.json`; BACKEND_HANDOFF.md requests producer
resolution and a boundary fixture. No server revision was edited or deployed, and
Roku does not parse/replace that cursor or silently truncate the catalog.

Packages: `artifacts/search-page-ownership-build/packages/`:

```text
1cd43434933ec3479a96e7ed02eb5e47e09bf0192fbc7c62bebde8ef4e9f1d9c  viptv-roku.zip
e075c401b3e738f975b7e9f83a6e797c103126d33bf0b4c98156918807cacfe4  viptv-roku-public.zip
```

The TCL remains on the previous normally restored search-status runtime; this
transport-ownership build has not been installed. Real-backend paging at the
upper boundary and native delayed-response scrolling remain unqualified.

## Search fixture isolation correction (2026-10-23)

Audit of derived search-channel r2/r3, search-status and search-focus private
fixtures found that RemoteTransport.brs had been copied from production after the
preview builder disabled dispatch. Those derived fixtures therefore retained real
dispatch, contrary to the previous network-disabled description. Their explicit
config used example.test and an empty access token and registry loading was removed;
no real authenticated backend was configured. The render/focus traces remain
native observations, but do not prove network isolation or backend integration.
The new search-paging-isolated fixture asserts dispatch returns before platform
effects and asserts registry-load removal before zipping. Its synthetic delayed
responses exercise production request ownership without network transport.

## Native delayed search paging and reverse boundary (2026-10-23)

A fresh fixture was generated with scripts/remote-preview.py and its transport
isolation checked before ZIP creation: rDispatch returns before any effect, and
CONFIG_LOAD is removed. It uses four synthetic eight-channel pages with opaque
cursors and a400ms timer: requests queue on one tick and reply on the next. These
are delayed synthetic responses through production rResponse, not HTTP timings.
Production focus observers remain installed; logging is inserted after validation.

Initial native run exposed a reverse-boundary defect: while a previous page was
pending, repeated Left at the first retained item could move focus to the keyboard
although earlier pages existed. The corrected renderer consumes that boundary
Left while earlier pages exist, with reverse lookahead at three items. Failed
reads still allow keyboard/Retry access. Reads awaiting authentication replay or
parent authorization are not duplicated. Keyboard-to-results now restores the
current valid result instead of always selecting the first result.

All four harnesses passed (`artifacts/search-reverse-boundary-final-tests.log`).
New cases cover repeated boundary Left, true first page, failed-page escape,
auth/parent waits and return focus. Compilation, design integrity/validation and
package inspection passed (`search-reverse-boundary-compile.log`).

Corrected native run:80 ECP keypresses (40 Right,40 Left),32 synthetic channels;
reached channel31 and returned to channel0. Accepted focus trace67 entries, max2
retained pages and4 cursor entries. Requests: initial, next opaque-1/2/3,
previous opaque-1, previous empty cursor. No extra page request during the final
5-second idle interval. Earlier channels remained reachable through delayed
reverse loads. Full trace: `artifacts/search-paging-isolated-r2-navigation.log`;
results: `artifacts/search-paging-isolated-r2-results.json`.

During this narrow no-artwork/no-network test, chanperf produced38 samples:
RAM26468–27264KiB; CPU median15%, max16%. Duration approximately38.5seconds including idle. These include fixture diagnostics and native scrolling;
they do not establish a memory leak, a long-soak bound, GPU frame times,60fps,
input-to-visible-focus p95, real network behavior or artwork decode pressure.
ECP keypress count is not a frame or accepted-focus-event count.

Packages: `artifacts/search-reverse-boundary-build/packages/`:

```text
2bd32b137260a4bf6e9b61918a19b121aee40f7f3e0cd1f234660329691dd6ff  viptv-roku.zip
93ca6a134c6917751881f3c1857b3502848a9e35d6ae96cc44f8e874c1caa44b  viptv-roku-public.zip
```

Upper-offset backend inconsistency remains in the handoff. Broad visual parity,
real backend mixed-result/search authorization,720p and sustained performance
qualification remain open. The fixture isolation correction above supersedes
older derived-search-fixture isolation claims.

Current normal public runtime installed successfully and active on the TCL.
Restore evidence: `artifacts/tcl-current-20261023/search-reverse-boundary-normal-restored/`.
No runtime error appeared in the captured startup segment.

## Native graphics FPS — normal welcome animation (2026-10-23)

Current official Roku documentation was fetched via Context7 (quota was available
again), resolving `/rokudev/dev-doc`. The documented ECP endpoint
[`query/graphics-frame-rate`](https://github.com/rokudev/dev-doc/blob/v2.0/docs/DEVELOPER/dev-tools/external-control-api.md)
returns recent rendered graphics FPS, separately from video FPS. It does not
provide individual frame times or input-to-visible-focus latency. Percentiles
below describe the sampled recent-FPS readings, not individual-frame statistics.

The normal public runtime remained installed from search-reverse-boundary-normal-
restored. Private before/after captures confirm the Welcome screen. No fixture,
remote input, sign-in or runtime replacement was used during this sample. Native
welcome drift uses a120-second repeating translation animation.

Device: TCL50S435/C157X, OS15.3.4 build2402. Thirty1Hz readings, all statusOK and
all30 device timestamps distinct; timestamp span approximately29seconds.
Recent graphics FPS: minimum59.634083, 5th percentile59.870026,
median59.9393295, maximum60.007397. This supports near60FPS for the sampled
welcome animation only. It does not establish absence of individual long frames,
other screens' animation rate, or the p95<100ms focus target.

Evidence: `artifacts/tcl-welcome-graphics-fps.json` includes exact package hash,
device fields, raw readings and restore evidence. Private captures:
`tcl-current-20261023/fps-welcome-before.jpg`, `fps-welcome-after.jpg`.
A reusable read-only collector, `scripts/measure-graphics-fps.py`, records package
provenance, private workload label, device fields and raw endpoint samples; it
refuses artifact overwrite and retains partial evidence on errors. CLI and a
separate two-sample collector smoke check passed. The endpoint cannot attest the
installed package hash; that is tied to the recorded successful installation.

No production runtime or design change was needed for this measurement. The TCL
remains on the normal current runtime. Remaining performance work includes
artwork-heavy scrolling, guide transitions, dense drawers, real playback,
individual frame-time evidence and input-to-visible-focus measurement.

## Poster-grid scrolling performance and caption clipping (2026-10-23)

Verified isolated fixture uses the current Browse controls and catalog response
handlers,100 synthetic cards and100 distinct pkg poster URIs copied from14 KMP
preview images. Provenance/hashes: `artifacts/poster-grid-performance-artwork.json`.
Dispatch return and registry-load removal are asserted before ZIP creation. The
r2 fixture includes normal top navigation/catalog control and uses grid origin96,244.
An earlier r1 fixture omitted Browse's controls-layout step (origin96,360); its
results are not representative Browse-layout evidence. Initial console parsing
also split records across socket chunks; r2 reassembles complete lines. Raw r1
trace/correction are retained rather than silently discarded.

TCL r2 campaign:144 ECP keypresses (six12-Down/12-Up cycles), with0.8-second
settling pauses after each direction. Approximately45seconds of campaign plus
warmup/final idle. Native settled focus reached7→91→7; thirteen settled-focus
records are not144 input latency measurements. Recent graphics FPS during the
campaign:79 samples, median59.839115, minimum1.812689, maximum60.723465. The minimum
occurred at39.568s during a deliberate pause (previous key acknowledgement38.529s,
next key39.777s). These recent-FPS samples include on-demand idle rendering; they
cannot establish a minimum animation frame rate or per-frame p95. Values slightly
over60 reflect the endpoint's measurement interval, not a claimed higher display
refresh rate. All sample status values and errors remain in the raw JSON.

RAM during campaign34012–34736KiB; CPU median14%, maximum16%. Packaged images remove
HTTP latency, and steady scrolling follows installation/startup warmup. Fixture
focus logging is enabled. No whole-app, cold-decode, leak-free or long-soak claim.

The native graphics bitmap inventory already contained84 target poster bitmaps
before the first campaign (30277632bytes), and r2 ended with100 (36044800bytes).
These are exact perf-poster URI allocations, separate from app RAM and unrelated
textures. Thus this is mostly warm artwork scrolling; the native grid preloads
far more than the14 visible items. Longer300-card/texture-pressure qualification
and tighter decoder lookahead investigation remain required. Do not infer the
texture delta solely from the r2 interval because it reused URIs from r1.

Evidence: `artifacts/poster-grid-performance-r2-results.json`,
`poster-grid-performance-r2-console.log`, `poster-grid-performance-r2-texture-summary.json`,
`poster-grid-performance-r2-textures-before.xml` and `-after.xml`. Private captures:
`tcl-current-20261023/poster-grid-performance-r2-before.jpg` and `-after.jpg`.

**Design failure discovered:** with native floatingFocus and two rows, focused
item7's image box is704..1052, and its title begins below1066 and clips at1080;
remaining caption content is off-screen. KMP TvBrowseScreen gives the full card
(including76px caption slot) to its lazy-grid visibility/focus machinery. The
native grid must keep the focused caption in the viewport while preserving the
KMP scroll behavior. Switching blindly to fixedFocus would alter navigation and
is not approved parity. Official Roku ArrayGrid docs confirm fixedFocus pins the
upper-left item while floatingFocus travels to the last visible row; a correct
viewport/focus solution still needs implementation and matched native validation.
Performance measurements do not waive this failed visual state.

No production runtime code changed during this measurement pass. Full qualification
remains incomplete: this new clipping failure, texture pressure, real network,
720p, frame-time distributions and input-to-visible-focus measurement remain open.

Normal public runtime restored successfully and active on TCL after the performance
fixture. Evidence: `artifacts/tcl-current-20261023/poster-grid-performance-normal-restored/`.

## Focused catalog-card viewport correction (2026-10-23)

Current runtime keeps native floatingFocus and uses sceneSubBoundingRect("focusItem")
to measure the full232x424 focused card after focus/layout notification. A one-shot
10ms timer defers measurement; this duration is scheduling, not measured input
latency. Only the necessary vertical offset is applied. A parent clipping region
stays anchored at the original content top so shifted items cannot paint over
filters/navigation. Top-row focus restores the original origin. Scene focus return
also schedules measurement, covering geometry changes behind a drawer. Drawer
opener records the actual grid rather than its new clipping container. No server
order, card identity or persistent state is altered.

Official API documentation fetched via Context7:
[ifSGNodeBoundingRect](https://github.com/rokudev/dev-doc/blob/v2.0/docs/REFERENCES/brightscript/interfaces/ifsgnodeboundingrect.md).
Missing subparts can return whole-node bounds, so the runtime rejects a measured
rectangle whose dimensions do not match an item. Noncatalog routes, absent content,
pending restoration, lost focus and overlays do not apply a correction.

All four harnesses passed (`artifacts/catalog-viewport-release-tests.log`). Cases
cover second-row caption inclusion, top-row restoration, idempotent correction,
Library status-height geometry, protected clipping, route retirement and drawer
return to the grid. Compilation, package inspection, design integrity and design
validation passed (`catalog-viewport-release-compile.log`). Source geometry hashes
are recorded under catalog_focus_viewport in KMP_REFERENCE_UPDATES.json.

Native isolated fixture retained production focus handlers and verified dispatch
return/registry-load removal before packaging. TCL measurements:

| State | Focused card bounds | Original top | Applied offset |
| --- | --- | --- | --- |
| Browse item7 | y656,height424,width232 |244|−48|
| Up to item0 | y244,height424,width232 |244|0|
| Down to item7, then item14 | y656,height424,width232 |244|−48|
| Origin changed while drawer open | y710,height424; grid unfocused |298|−48 retained|
| Back closes drawer | y656,height424; grid focused |298|−102|
| Up after drawer return | y298,height424; grid focused |298|0|

The card bottom is1080 in corrected lower-row states. Inspected private capture
`artifacts/tcl-current-20261023/catalog-viewport-second-row.jpg` shows both caption
lines fully visible, with the prior row clipped at the content top and controls
unobscured. Logs: `artifacts/catalog-viewport-native-focus.log` and
`catalog-viewport-native-overlay.log`. The changed-origin drawer test is a geometry
fixture, not full Library/backend integration. Static native visibility is proven
for these states; smooth rapid scrolling, exact KMP bring-into-view animation,
long captions, pagination restoration and720p are still separate gates.

Packages: `artifacts/catalog-viewport-release-build/packages/`:

```text
1a917c9d675fb37e99c1ff0cdcbec09daadbee4847eb2f8124973e6b7a98dbb3  viptv-roku.zip
8b6d86e3a3330cb1f011ae62f87466dc273361e4fab8bbb60ecd50273bf1160e  viptv-roku-public.zip
```

This corrects the prior observed1080p clipping failure for the tested Browse
states; it does not establish complete catalog parity or change the remaining
texture-pressure/input-latency/per-frame qualification gaps.

Current normal public runtime installed successfully and active on TCL after the
viewport tests. Restore evidence: `artifacts/tcl-current-20261023/catalog-viewport-normal-restored/`.
No runtime error appeared in the captured startup segment.

## 300-card native texture-pressure campaign (2026-10-23)

Fresh verified isolated fixture uses current production Browse/control/rendering
and focused-card viewport correction. It supplies300 synthetic cards, the current
retained catalog-window ceiling, and300 new stress300-poster URIs copied from14 KMP
preview images. This removes reuse of the earlier100-poster URI namespace, but
still uses local packaged JPEGs rather than real network artwork. Provenance:
`artifacts/poster-pressure-300-artwork.json`. Registry loading and dispatch effects
were explicitly disabled and checked before fixture ZIP creation.

TCL workload:164 ECP keypresses, two41-Down/41-Up cycles with settling pauses,
approximately43.95seconds plus warmup/final idle. Settled focus reached item294
and returned to7. The final private capture shows the selected card and both
caption lines fully visible. This extends the viewport fix's settled-state evidence
to a long traversal; it does not prove every intermediate animation frame.

Recent graphics FPS:77 campaign readings, median58.223835, min0, max60.620289.
The campaign includes deliberate pauses, so its minimum is not an animation
throughput measurement. Using the recorded input-burst intervals (excluding the
first second of each burst) gives medians58.4431,58.1375,58.2956,58.2638; lowest
burst reading54.4041. All raw readings and input timestamps are retained. These
results do **not** qualify the60FPS target under300-card texture pressure. They
also do not reveal per-frame timing or input-to-visible-focus latency.

App RAM34660–35580KiB; CPU median17%, max18%. No probe errors or runtime-error text
were recorded during this short instrumented run. This is not crash-free soak
qualification, nor a resolution of the older spontaneous reboot.

Exact target bitmap snapshots:

| Point | Poster bitmaps | Poster allocation bytes | Replacement evidence |
| --- | --- | --- | --- |
| Before traversal |84|30277632|Fresh URI namespace already prefetched84 posters|
| First Down |200|72089600|199 newly present,83 prior URIs absent|
| First Up |200|72089600|100 newly present,100 prior URIs absent|
| Second Down |200|72089600|100 newly present,100 prior URIs absent|
| Second Up |200|72089600|100 newly present,100 prior URIs absent|

The union of snapshots contains all300 URIs, so old poster textures were replaced
rather than all300 retained together.200 is an observed plateau for this workload,
not a portable/cache-policy guarantee. The containing graphics instance reports
max83886080bytes and used75698176 after traversal, but includes other textures;
only the URI-filtered allocation above is attributable to fixture posters. The
remaining instance headroom was8187904bytes. Native preload/texture replacement
and the lower FPS warrant further profiling before changing cache policy.

Evidence: `artifacts/poster-pressure-300-results.json`, `poster-pressure-300-console.log`,
`poster-pressure-300-texture-summary.json` and phase-specific texture XMLs. Inspected
private capture: `tcl-current-20261023/poster-pressure-300-final.jpg`.
No production runtime change was made in this measurement pass. The next performance
work must distinguish decode/replacement cost, viewport correction and diagnostics
instead of attributing the FPS difference to one cause without a controlled test.

Normal public runtime restored successfully and active on TCL after this campaign.
Restore evidence: `artifacts/tcl-current-20261023/poster-pressure-300-normal-restored/`.
No runtime error appeared in the captured startup segment.

## Texture/viewport diagnostic comparisons and latency hardware (2026-10-23)

The user confirmed no HDMI capture or high-frame-rate camera is available. This
host exposes no /sys/class/video4linux capture surface. The p95<100ms
input-to-visible-focus gate remains **unverified**; ECP acknowledgements, focus
callbacks and recent graphics FPS cannot substitute for that measurement. This
limits that gate, while other implementation/integration work continues.

Ordered diagnostic comparisons kept300 cards and the164-key navigation workload:

| Variant | Median recent graphics FPS | Artwork/viewport change |
| --- | --- | --- |
| Initial distinct300 |58.223835|300 fresh URIs, viewport correction enabled|
| Shared14 control |58.160294|Same cards and image bytes;14 shared URIs; viewport enabled|
| Fresh distinct300 repeat |58.153767|Fresh repeat URI namespace; viewport enabled|
| Viewport-disabled control |58.237427|Shared14 URIs; clip wrapper/correction disabled for diagnosis|

All reached settled focus7→294→7 and recorded no probe errors. Shared-artwork
snapshots retain14 poster textures/5046272bytes throughout; distinct-artwork
campaigns exercise replacement of the larger cache. Both moving-burst and whole
campaign readings are in `artifacts/poster-pressure-comparison.json`. These are
short ordered runs, not randomized per-frame measurements. They show no material
median improvement for either intervention, so neither texture churn nor the
viewport correction is established as the cause of the58.2FPS result. The100-card
and300-card workloads also differ in burst length; their medians are not an
isolated card-count comparison.

The viewport-disabled fixture deliberately reintroduced the known caption defect
and is not a product candidate. Its early return and wrapper removal are absent
from production source. Variant file hashes and scope are recorded in private
artifacts. No production runtime change resulted from these experiments.

Normal public runtime restored successfully after the comparisons:
`artifacts/tcl-current-20261023/poster-pressure-comparison-normal-restored/`.
The60FPS target under this workload remains unqualified. Further performance work
must also account for input cadence, native scroll scheduling and measurement
observer effects, without assuming those explanations are proven.

## Current producer HTTPS integration refresh (2026-10-23)

A stable read-only snapshot of the producer working tree was copied to
`artifacts/backend-integration-e8e7-current/`, basee8e7b5fa with exact dirty-file
hashes in source.json. It includes the producer's large-offset fix and current
presentation/navigation/snapshot fields. Before/copy/after inventories matched;
all470 recorded source files still match after compilation. Build cache was
reflink-copied to an independent target directory; shared backend source/targets,
QA/production serving paths and household databases were not modified.

The snapshot compiled with live-runtime. Existing producer regression
engine_v3::live_tests::live_browsing_and_search_follow_cursors_past_ten_thousand
passed, including the10041-channel boundary, search/category behavior and past-end
handling. Both viewing_presentation producer tests passed. Logs: compile.log,
offset-boundary-test.log, presentation-tests.log under the snapshot directory.
Roku adopted the additive shared boundary fixture; all four client harnesses passed
(`artifacts/current-producer-integration-client-tests.log`), including unchanged
10040 cursors in Live/search and4294967295 string transport.

The producer's existing disposable remote-addon fixture ran on owned loopback
ports with Origin pinned to https://viptv.local.test:18443. A separate owned Caddy
process terminated TLS using the existing QA CA. Health returned200 with peer and
hostname verification; a wrong-Origin login using the disposable credentials
returned403. TLS/origin evidence: tls-and-origin-check.json. No -k/TLS bypass,
shared data import, production origin change or shared runtime replacement occurred.

The current production RemoteTask/rHttp and RemoteWire code ran through the
native-HTTP BrightScript simulator adapter, with only the QA certificate path
selected in its private copy. It passed login/profile selection/bootstrap,
Library defaults/preferences/history, add-on activation/navigation, scoped Home,
current metadata/badge array projections, viewing-action target/label/resume/source
selection/progress/remaining fields, progressive discovery, named best ranking,
complete source display-field projection, discovery deletion, refresh and logout.
Full whitelisted synthetic observation: presentation-observation.json; logs:
native-check.log and native-check-with-observation.log. The observation has one
metadata part and no hero badges, so nonempty multi-badge ordering is supported
by the shared producer/client fixture regressions, not this empty-badge API sample.
No real decoder or physical Roku network path is established by this harness.
The host's gateway is mocked; it cannot qualify real conversion/track/EOS behavior.

All owned backend/TLS processes were terminated after the checks and both temporary
fixture databases/credential directories removed. cleanup.json records the verified
owned process identities and removal. Both owned listener ports are free. TCL
remains on the normal catalog-viewport public runtime restored before this host ran.

This supersedes the old source-snapshot gap for current presentation transport.
It does not deploy the producer or replace the historical shared-QA404 observation
with a new shared-QA probe. Full profile/parental/integration mutation campaigns,
physical HTTPS flows, real playback, native720p, comprehensive parity and the
unavailable p95 visual-latency measurement remain open. Expanded cursor range also
makes bounded scalar reverse-history bookkeeping a documented contract dependency
in BACKEND_HANDOFF.md; two bounded payload pages alone do not close that cache gate.

## Device-supported profiles and parental controls (2026-10-23)

Current-producer integration exposed a permission mismatch: device sessions are
forbidden by require_household_manager from kids-policy/approval/PIN-setup APIs,
even with an accepted parent grant. The earlier client exposed those account-only
editors. The current runtime physically removes those menus, local0..17 age choices,
search/approval requests and controllers. A static shipping guard prevents those
endpoints/controllers returning. This is the approved omission of unavailable
features, not a new permission model or compatibility fallback. Parent PIN status,
unlock, parent-required profile selection and permitted profile management remain.

The existing immutable producer test binary was reused with a new disposable
account/database and explicitly pinned HTTPS origin. A browser-only API session
(with CSRF, Origin, peer/hostname verification) seeded the PIN/restricted profile;
no SQL or shared household mutation was used. Through current production Roku
RemoteTask/rHttp/RemoteWire in the native-HTTP simulator,40 PASS checks cover:
profile creation using an advertised avatar, rename preserving ID, rejected empty
name, active identity retention, invalid PIN classification, valid unlock, account-
only API403s after unlock, restricted mutation/switch parent_required responses,
capability change after grant, return to original viewer and temporary-profile
deletion/logout. Logs and explicit scope: `artifacts/profile-parent-integration/`,
particularly native-supported-check.log and result.json. The initial probe expected
policy access and failed on403; that evidence led to removing unsupported controls,
not changing the server or bypassing its role checks. No physical device HTTP path,
nonempty existing-history migration, avatar reassignment or decoder claim follows.

All four client harnesses passed (`artifacts/parent-supported-layout-tests.log`),
including locked/unlocked/unconfigured visibility and section focus. Final shipping
static guard passed (`parent-supported-static-final.log`). Compilation, package
inspection, design integrity and design validation passed. Latest compiler log:
`artifacts/parent-supported-final-compile.log`.

Native isolated fixtures verified dispatch/registry isolation before packaging.
Locked status renders exactly one Unlock row; unlocked/unconfigured statuses render
zero editor rows. A first capture revealed status hidden behind the left sidebar
and fallback focus on Account. The corrected build places read-only status at
[640,220],width1184; errors use[640,940] with870px beside Retry. Rebuilt sections
restore their matching sidebar index. Inspected r2 unlocked capture shows readable
“Parent PIN unlocked” and focus on Parental controls. Private captures:
`tcl-current-20261023/parent-supported-r2-unlocked.jpg`, `-unconfigured.jpg`;
state trace: `artifacts/parent-supported-native-states.log`. Static native states
are proven; exact KMP PIN-dialog rendering, submitted-PIN rejection/cancellation on
hardware and fast remote transitions remain open.

All owned backend/TLS processes were stopped and the disposable database,
credentials and PIN seed removed (result.json cleanup record); both listener ports
are free. Shared QA/production runtimes and household identities were untouched.

Packages: `artifacts/parent-supported-final-build/packages/`:

```text
fa471d6e8140be8275936451fa624b7a9e09463fc02f9b6c415d14053d144cb0  viptv-roku.zip
a03f2d4c9cbee2196a8584686ad55739c44581cb413e644ff6f7603155c11118  viptv-roku-public.zip
```

Remaining profile work includes preserving transient name drafts through rejection
and cancellation/late acknowledgements, separate avatar updates and complete native
profile/PIN visual flows. Global720p, playback, performance and unavailable visual
latency gates remain open.

Current normal public runtime installed successfully and active on TCL after the
supported-parental tests. Restore evidence:
`artifacts/tcl-current-20261023/parent-supported-normal-restored/`. No runtime error
appeared in the captured startup segment; fixture diagnostics are absent from source.

## Profile-name drafts, cancelled replies and PIN retry (2026-10-24)

Profile create/rename now retains its complete transient name while waiting for
the server. Busy input consumes edits/duplicate submit and keeps Back available;
“Saving…” is secondary text. Rejection returns the same editable draft and error.
Back retires its editor version and unissued queued work. Already-issued work is
not rolled back: late acceptance invalidates profile/return models and refreshes
the current unobscured profile/status view when appropriate, but cannot replace
a newer editor or navigate to an old route. Avatar/delete also capture the original
profile editor/target. Current success clears drafts/overlays and refetches profiles;
it never inserts a locally fabricated profile or selects the submitted target.

Parent authorization preserves the original name behind secret PIN entry. Invalid
PIN remains retryable with an empty secret field; the producer parent_pin_invalid
code maps to the KMP prompt wording. Completed/retired PIN payloads are scrubbed.
Cancelling authorization returns to the original unsaved name; late grants cannot
replay a cancelled save. Current accepted grants resume the original current
intent. Transient refresh failures release form retries into editable error states,
retain credentials and submit the user's current draft on the next explicit attempt.
Retired failed profile selection cannot open a PIN or replay through refresh;
accepted selection still clears profile views and re-resolves bootstrap identity.

All four harnesses passed (`artifacts/profile-form-final-tests.log`). Added cases
cover rejected nonempty name, edit/duplicate blocking, cancellation before dispatch,
in-flight/route/target changes, accepted mutation cache invalidation, invalid and
cancelled PIN, accepted authorization, transient refresh, avatar/delete replies,
late-grant status refresh and accepted/rejected selection authority. Compilation,
package inspection, design integrity and design validation passed. Compiler log:
`artifacts/profile-form-release-compile.log`. No backend source was changed.

Native TCL isolated fixtures asserted registry-load removal and dispatch return
before packaging, then delivered synthesized results through production rResponse.
Rejected26-character draft remained visible/editable. In a second fixture, Back
retired an in-flight save; opening a new20-character draft and delivering the old
success left that current form visible and nonbusy. Logs:
`tcl-current-20261023/profile-draft-native-install/` and
`artifacts/profile-late-native-events.log`. Inspected private captures:
`tcl-current-20261023/profile-draft-rejected.jpg`, `profile-draft-busy.jpg`, and
`profile-draft-after-late-success.jpg`. These establish native state/render behavior
for the synthesized callback cases, not real network timing, accepted backend
mutations or complete KMP dialog geometry. The current full-page entry remains a
visual-comparison gate against the KMP dialog forms.

Packages: `artifacts/profile-form-release-build/packages/`:

```text
7bf8492054dbb577c5b6a37b7c183fabc38ca23b79f656f6f56254bc3e530042  viptv-roku.zip
78bc5dde05545355d3d38f2464ef51f0ca570ca4db160bf610ce23b41343299a  viptv-roku-public.zip
```

`artifacts/profile-form-release-build/source-record.json` records260 runtime input
hashes, base commit/working-tree status, design/compiler pins, package hashes and
exact test/compiler evidence hashes. Production source contains no fixture diagnostics.

Unknown-outcome replay remains a producer contract dependency: profile creation
has no observed idempotent operation receipt. Roku does not infer duplicate identity
from a name or automatically replay after a transport failure. Real delayed HTTP
mutation/authorization combinations, complete modal visuals, avatar persistence,
720p, playback and performance/visual-latency gates remain open.

Current normal public runtime installed successfully and active on TCL after this
pass. Restore evidence: `artifacts/tcl-current-20261023/profile-form-normal-restored/`.
No runtime error appeared in the captured startup segment.

## Profile identity-read and credential-owner race (2026-10-24)

The new unknown-selection reconciliation regression exposed an old bootstrap
pending-slot race: a pre-switch read could prevent the fresh post-selection read,
then become stale itself and leave no current owner. Identity replacement now
cancels old bootstrap workers/queued reads and releases that slot before bootstrap
is requested. Old read callbacks cannot clear the replacement's pending owner.
Profile-scoped auth replays retire with the old view epoch.

Credential rotation has separate ownership: exact origin and opaque refresh-token
generation. A valid rotation for the same credential owner survives a profile
epoch change. Changed credentials cannot adopt a retired rotation; its returned
session token is cleaned up without touching the current token. Forgetting auth
retires unissued refresh/identity work. This is platform request ownership only;
active profile identity still comes exclusively from bootstrap.

All four harnesses passed (`artifacts/profile-credential-scope-tests.log`), including
existing refresh/dedup/cleanup regressions updated to use complete real refresh
request envelopes plus the new profile/credential race cases. Compilation, design
integrity/validation and package inspection passed; compiler log is
`profile-credential-scope-compile.log`.

A fresh native fixture explicitly removed registry loading and made dispatch return
before effects. Real SceneGraph Task request/cancel fields and production callbacks
reported: old_cancelled=true, fresh_epoch=true, fresh_owner=true;
old_reply_kept_slot=true; rotated_current=true; queued_boot_token=true. Only synthetic
credential strings were used, and no credential payload was printed. Evidence:
`artifacts/tcl-current-20261023/profile-owner-native-install/startup-console.log`.
This proves the tested native ownership/copy behavior, not real concurrent HTTPS
rotation or a full authentication soak. Earlier profile-draft native captures prove
name rejection and cancelled-save state retention for their callback variants.

Latest packages: `artifacts/profile-credential-scope-build/packages/`:

```text
b5f8286d87cf376fef4e806e3d2ec4d36199038a85d2be544ac4d2135be43282  viptv-roku.zip
03ead962213475792b8429c9962ed85cd85573d350ccc59d353dd429120f9aea  viptv-roku-public.zip
```

source-record.json beside those packages records the260 runtime inputs, design and
compiler pins, package/test/compiler hashes and current TCL model/OS fields.
This supersedes earlier package pointers for the profile-form pass. Real concurrent
network flows, unknown-outcome mutation receipts, complete modal/KMP parity,720p,
playback and performance/visual-latency gates remain open.

Latest normal public runtime installed successfully and active on TCL after the
credential-owner probe. Restore evidence:
`artifacts/tcl-current-20261023/profile-credential-scope-normal-restored/`. No runtime
error appeared in the captured startup segment; fixture diagnostics are absent.


## Current KMP modal implementation and first native comparison (2026-10-24)

Design adoption d90985bcc9b87833cf8d066a0f7976e732c3c5a6 records the measured
Name/Add/parent-unlock dialog shell and four procedural native assets. Private
reference captures (26 modal +2 baseline at1080/720), semantics and text styles:
`artifacts/kmp-modal-reference-20261024/output-final/`. The eight recorded KMP
source/build hashes stayed unchanged through the isolated desktop reference test.
Roku now opens centered dialogs; field activation opens the separate input-method
step. Done returns the draft; Save/Unlock alone submits. Back from text entry
returns the prior draft. Name permits busy cancellation; parent unlock blocks it.
PIN stays only in the masked transient form until dismissal/success; completed
HTTP payloads remain scrubbed. Account-only parental editors remain absent.

Native TCL initial geometry: Name[796,424,328,232], parent error[680,407,560,266],
parent busy[680,424,560,232]. These match the measured1080 shell geometry. Evidence
under `artifacts/tcl-current-20261023/modal-native-*/` and adjacent JPEGs. First
font-measurement implementation failed on native because roFontRegistry is not
render-thread safe; it was removed. The implementation uses SceneGraph Label
bounding rectangles for wrapping, with a native20px one-line metric. Simulator
checks alone had not caught the platform restriction. The rejected diagnostic
package is not a deliverable. Native compile has one existing unused parameter
warning; fixture-only Home artwork warns about its1935px image and is not packaged.

The first native Name comparison, recorded in `modal-native-name-r2-metrics.json`,
found title ink2px narrower, value ink5px narrower/1px shorter, Cancel1px shorter,
Save1px shifted/shorter at threshold110 against the lossless KMP reference. JPEG
compression and platform glyph rasterization differ. The title renderer was then
changed to pinned glyph advances; final native comparison is recorded separately.
These are region measurements, not a whole-screen pixel-parity assertion. Values
and arbitrary server text still use the native Unicode renderer; tracking parity
and font rasterization remain open. Source-level KMP form eligibility, Name busy
interaction/dismissal differences, and fixed-density HD versus proportional Roku
scaling are explicit remaining comparisons/dependencies.

Production-handler regression checks now include modal/input-method draft
ownership, focus trap, background focus protection, cancellation, pending PIN Back,
late replies, parent-resumed name intents, token refresh failure, and a PIN-over-
Search privacy case. A modal PIN cannot become a search draft/query, and cancelling
restores the underlying search keyboard/draft. Latest passing intermediate suite:
`artifacts/modal-tests-r7.log` (4/4). Final candidate checks are recorded below.

The owner confirmed no capture hardware is available. The p95<100ms remote-input-
to-visible-focus target remains unmeasured; ECP ACK, simulator callbacks and the
recent-graphics-FPS samples do not qualify it. No further capture-hardware request
is pending. This does not close other available device/visual/playback checks.


Final modal-region comparison and native input evidence:
`artifacts/modal-native-name-r3-metrics.json`: title[822,455,883,472] versus KMP
[822,455,884,472] at threshold110 (1px narrower); value remains5px narrower/1px
shorter, Cancel1px shorter, Save1px right/shorter. No adjustment stretches arbitrary
Unicode text or changes its font weight to hide the platform difference.
`pin-modal-keyboard.jpg`, `pin-modal-return.jpg`, `pin-modal-cancel.jpg` plus
`modal-native-interaction.json` verify actual field activation, Back to dialog,
then dismissal to the opener on TCL. Busy parent capture after Back/Select/Right/
Select remains masked/disabled (`modal-native-pin-busy-blocked.jpg`). Long server
error fixture wraps6 lines; panel[796,356,328,368], error120px, all actions remain
visible. Those synthetic fixtures perform no registry/network work and never ship.

The first final build (`artifacts/modal-final-build/`) passed4/4 checks, compilation
and allowlist package inspection; its normal public flavor restored the TCL with
no startup runtime error. Device compilation reported the two pre-existing unused
variables (main scene, settings request). A following candidate explicitly marks
its modal Group focusable and carries its own complete verification/provenance.
Neither archive is a release qualification of the remaining screen/playback gates.


Modal cycle campaign: `artifacts/modal-cycle-evidence/results.json` and console
record50 completed open/field/type-q/input-Back/modal-Back cycles (250 ECP keys),
all dismissals with queue0/keyboard hidden. Synthetic packaged profiles; no backend
traffic. During44 recent-FPS samples RAM26720–26916KiB; CPU median3%,max4%.
The first/last active RAM samples26916/26864KiB and late samples26864KiB show no
monotonic growth in this short run; this is not a long soak or leak-freedom proof.
Recent-FPS min0.939932,median8.6533395,max11.541728 reflects the sparse redraws of
static dialogs and keyboard transitions; no animation60fps/per-frame qualification
is inferred. The memory/CPU command is the documented chanperf -r1; it was stopped.
Texture snapshots at cycles1/10/25/50 separately attribute only matching form asset
URIs; global texture totals contain unrelated system/app artwork. Final clean
candidate `artifacts/modal-qualified-build/` passed4/4, compilation, design checks
and ZIP allowlist/unique-entry inspection.266 runtime-input hashes and package,
compiler/test, modal-ledger hashes are in source-record.json. Public ZIP SHA256
3e43802871dbd9f03beded00d98bfad2fcc48ae5d681576dbe34be716f14f35f;
locked ZIP49af67f3207b90dcd2b555b08abdca67ad9a9f2ce4036804e551c8a8861e0eeb.
The diagnostic fixtures are separate and cannot pass runtime packaging. Native
normal-app restoration evidence: `modal-qualified-normal-restored/` (installer,
active app, console); no production activation or Store action performed.


## History authority correction (2026-10-24)

Design ed830a85cc681d59a2791f198a6e89452c46797f removes remaining Roku History
classification: completed timestamps no longer overwrite the producer subtitle,
missing subtitle no longer becomes “In progress”, numeric progress no longer
becomes a “% watched” label, and poster artwork no longer substitutes for the
landscape role. The unsupported percentage Label/controller is physically removed;
the text column fills its vacated space. Producer day/progress/action/paging fields
remain explicit handoff dependencies, not inferred UI. Current server can already
project resume/watched text in Card.subtitle. Production-handler counterexamples
verify subtitle omission, contradictory completion/progress values, server order
and missing landscape while poster exists. This is an authority correction, not
complete KMP History parity. Current/new producer source bases were observed read-
only; prior immutable HTTPS qualification does not automatically qualify newer
working-tree commits. No backend/core files were edited.


History correction verification: `artifacts/history-authority-final-tests.log`
4/4, BrighterScript0.73.1 compile, design integrity/validation and clean diff check
passed. Native current renderer captured under `history-server-status-native-r2/`
and adjacent JPEG confirms two rows in server order, supplied resume text despite
completion timestamp, and absent caption/landscape when not supplied. The first
private fixture bypassed rPageResponse and left loading placeholders visible;
only r2, which enters that production handler, is representative of the accepted
response state. A regression now asserts the history loading presentation clears.
No real account/backend was contacted by the visual fixture. The screenshot only
qualifies those row states; navigation, day headings, paging and full KMP comparison
remain open. Latest runtime: `artifacts/history-authority-build/`,266 source hashes
and test/compiler/package hashes in source-record.json. ZIP SHA256:
public6b6147909252fbc3222da61072bfc5542d6a2d6d09a58b30b7db3cd8a406141a;
locked1c2614b6dcc82ede69a00c7dd0da6beccabb63111ccfc05e5a61ec39be448c9f.
Normal public app restoration: `history-authority-final-normal-restored/`; installer,
active app and startup console are recorded separately from synthetic fixtures.


## Current shared bidirectional paging adoption (2026-10-24)

The prior Live/channel Search scalar cursor-history gap now has a current producer
contract. Design b971c475d82cb3ff4af9323ece189b749c5120f8 adopts backend1a361e4 /
core65add90 `paging` descriptors. Runtime physically removes all growing cursor
arrays/page counters and stops consuming Live next_cursor. At most two payload
pages and their server descriptors are retained; cursor/limit/page_size are sent
unchanged. Wire validation requires current paging and bounds row/navigation
budgets1..200. A descriptor, route/query/profile/snapshot generation owns replay;
same cursor with a changed limit/page_size is stale. Legacy/malformed fields have
no fallback. The copied shared fixture is pinned by exact SHA256; older partial
snapshot samples are completed with explicit current descriptors in the harness,
while the shared full reverse fixture drives the production-handler assertions.

Evidence: `artifacts/backend-integration-bidirectional/` contains471 immutable
producer source hashes, post-build/current-checkout comparison, the configured
producer reverse test (one test actually executed/passed), and production Roku
HTTP/wire adapter checks over verified local HTTPS. The first cargo --exact filter
matched zero tests; only reverse-producer-test-executed.log proves the test ran.
HTTPS checks cover explicit null directions for an unconfigured directory, row
limit2/navigation budget3, separate search snapshot and unsigned cursor4294967295
with200-row budget. These do not qualify a configured Live catalog over device
HTTPS. The disposable fixture, credentials/database, TLS/API processes were removed
and ports18183/18443 confirmed closed. Shared QA and production were not touched.

The short reverse fixture exposed a real focus bug, captured failing in
bidirectional-short-restore-counterexample.log: restored focus triggered immediate
opposite prefetch in overlapping edge lookahead regions. The implementation now
uses actual focus movement to choose paging direction; applying a page clears
that intent, while guide hydration remains allowed. An overlapping media/channel
failure also previously let channel paging bypass its explicit Retry gate when
the media error was shown first; the separate failing counterexample is recorded
and the channel failure map now gates automatic fetches. Production checks cover
100 forward/reverse cycles per controller, unchanged ordering, short-page budget
restoration, bounded pages, stale limits, snapshot/cancellation/auth/retry and
wire omissions. Full app parity, per-frame timing and playback gates remain open.


TCL bidirectional controller checks passed for channel Search and Live. Evidence:
`artifacts/bidirectional-native-search-evidence/`,
`artifacts/bidirectional-native-live-r2-evidence/`; adjacent native captures show
Channel2 remains selected after reverse0(limit2,page_size3) produces pages[0,2],
then Channel3 remains selected after forward5(limit3,page_size3) produces[2,5].
Each trace has exactly those two paging requests; counts stay1→1 and2→2 during
idle waits. No runtime error. These are production renderer/response/wire paths
with controlled synthetic replies, no registry/HTTP, and no input-latency claim.
The first Live fixture omitted guide availability; the strict wire adapter rejected
it and the test failed with zero paging requests. Only corrected Live-r2 counts
as successful native evidence. Search's later error-map Retry guard is separately
covered by final handler tests; its successful no-error native paging path predates
that small guard addition. No blanket binary/device qualification is inferred.

Latest candidate `artifacts/bidirectional-final-build/` passes4/4 checks,
BrighterScript0.73.1 compile, design integrity/validation and package allowlist/
unique-entry inspection.266 source input hashes and all test/compiler/producer/
contract/package hashes are recorded in source-record.json. Public ZIP SHA256
e407cca327717d29624da6becf291c150c8872f75b202343e86bc1f97cce8d6b;
locked ZIP84c8fb2b58833a03c6eff8d5c495a1f1ea6678a2295e1f27c9ff778cb1c2f5e5.
Normal app restore evidence: `artifacts/tcl-current-20261023/bidirectional-normal-restored/`.
Configured Live over real device HTTPS, large-directory soak/artwork memory,
full KMP guide/search comparisons, native720, playback/track/recovery and real
frame/input timing remain open. No production activation or Store submission.


## Real gateway/native player controller campaign (2026-10-24)

Evidence root: `artifacts/roku-playback-current-20261024/`, summarized in
qualification-summary.json. A read-only snapshot of1165 current gateway files
(base00b6815 plus exact working-tree hashes) built in an owned release target;
its binary SHA2564d7a435abaebaea948163b3511afcedf521cdbad365498949483b6c823d9dfde.
Backend used the immutable1a361e4 snapshot's existing real media-lab fixture, not
playback mocks. The gateway ran software-only with2CPU/3GiB, no network egress in
its owned namespace; private HTTPS source and TCL ingress used explicit test CAs.
All three generated720p H264/AAC inputs passed metadata validation and full decode.
No production/server/gateway runtime source was modified by this Roku work.
Context7 quota was exhausted; SDK semantics were checked against official Roku
Video/content-metadata docs. Failed TLS setup was corrected with a constrained CA
key-usage extension; verification was never disabled.

Native36s MP4: state playing, first-frame acknowledgement200, one explicit
Video.finished callback at35.937s, accepted stop/completion progress, producer
History subtitle“Watched”. ECP/query/media-player misleadingly remained“play” at
35937ms after SceneGraph.finished; it is not the completion authority. No client
end threshold was added. The first2s capacity check found viewers released but
input/output cache retained; later observation verified full8/8/64 reclamation.

The real key path exposed controller defects absent from simulator-only checks:
Video focus enabled native transport behavior without a seek admission; Scene
focus requests left the action row active; dedicated Fwd was incorrectly treated
like a horizontal button arrow; raising drawers after focusing detached their
native focus. Current code keeps Video non-focusable, uses an explicit empty input
component forwarding captured press/repeat payloads, separates transport keys from
arrows, and raises player drawers before opening/focusing them. Release events do
not submit intents; queued event data is not replaced by the component's newer key.

Native pause/resume held position8.291s across two paused observations. Dedicated
Fwd/OK generated the real playback admission; a returned19.819s timeline offset
was consumed (new native local0.105s mapped to19.924s). First-frame ack200 preceded
prior-lease cleanup200. With the final input bridge, Up→controls→Audio→Down→OK
selected server Spanish input2; another Up path selected English subtitle input2.
Both replacements reached native playing, received first-frame ack200 and released
the previous lease. These prove selection/admission/control routing, not audible
language, caption pixels, continuous source timing or full KMP player parity.
Options/ECP Info sequences did not reach the intended app path; they failed with
both raw/custom input targets and remain unqualified. Do not infer the raw Group
alone caused that Options result. No confirmed picture/audio observation arrived.

Active Back was rerun with a fresh app launch and observed playing1113ms; it
closed playback, sent three ended=false start/stop/progress facts, accepted stop/
progress and cleanup200, with zero finish callbacks. Earlier late/identical-ZIP
probes were not valid active-exit evidence. Check active-back-result.json and
active-back-r3-run.log. A same-archive install can leave an existing app running;
this check explicitly exited/launched dev and required a fresh low position.

Format failure remains open: the validated90.021s Matroska multi-audio input has
2700video frames; gateway copy/copy output had74.013s/2192frames, video starting
PTS17.534s, although delivery still advertised90.021s. Native ended that output
correctly at73.863s. Source/output probes and a checksummed HLS archive are handed
off as ROK-MEDIA-20261024-MKV-COPY in BACKEND_HANDOFF.md. No Roku offset, duration
heuristic or local remux hides the missing508frames. Content-accurate seeking,
quality, visual/audio output, live, failure rollback,720p and sustained timing/
memory therefore remain open despite controller improvements.

All owned resources were reclaimed before shutdown. Only the recorded container
and API/bridge/TLS jobs were stopped; four owned ports closed and the TCL-only
firewall rule removed. The private test registry was cleared with explicit native
confirmation; normal VIPTV registry/identity was untouched.34 credential/private
package/key files were removed; exact private-source hashes and evidence remain.
The normal public app was restored under player-controller-normal-restored/ with
no startup runtime error (two existing unused-variable warnings).

Current candidate: `artifacts/player-controller-release-build/`;4/4 current checks,
BrighterScript0.73.1 compile, design integrity/validation and package inspection
passed.268 runtime input hashes, design pin, compiler/test/package provenance are
in source-record.json. Public ZIP0a75f802ba529dd62ed103cde97ba20790dc9d824b36a3d87d20ff5084510b6d;
locked ZIP95f910da74a6b0cd1a7d459e9d17b56dcfe5a86a2198289156117e9134d52e93.
The later design-pin clarification changes no packaged runtime bytes. This is an
incomplete qualification, not a release/Store/production activation.


## Measured Home focus correction — 2026-10-24

Design50ee2ae9ee7f97d68114b4ba4e652e053502e3a7 adopts the focused Home
measurements before implementation. Six actual KMP TvHomeScreen renders were
rerun at1920x1080/1280x720, with544 commonMain/desktopMain source/resource inputs
hashed before/after and no drift. Private record:
`artifacts/kmp-home-focus-reference-20261024/reference-record-r2.json`.
The original twelve component hashes and the full rerun record are linked from
KMP_REFERENCE_UPDATES.json. This is a scoped Home reference, not whole-app freshness.

Roku consumes the current0d8da118 Home preview fixture, requiring explicit
background/caption/progress/action fields on row cards. Server play versus details
wins over a contradictory row ID or resume hint. Play still requests fresh viewing
authority. Tile landscape remains unchanged when summary background differs.
No Home-to-discover adapter remains. Current producer bounds16rows ×24cards are
validated before native content creation. Unchanged rows retain native children;
changed/reordered responses preserve canonical row/card identity, with a surviving
neighbor after removal. Pending focus restores, current event data, route/profile/
epoch/render-version checks prevent transient/retired previews from being shown.
Back from browsing returns to the billboard before popping an older route.

TCL50S435/C157X, OS15.3.4 build2402, rendered hero/landscape/poster at1080p.
`artifacts/home-preview-native-r3-20261024/` owns the disposable fixture recipes,
logs, six off-device renders and navigation-result.json. All credentials, registry
and networking are disabled in these visual fixtures. Static fixture display
projections isolate the renderer and are not producer metadata-formatter evidence.
Roku's720p images are scaled simulator previews, not physical720p qualification.

Native-only failure found and corrected: an invisible message's60px offset/26px
height still enlarged its custom title Group. With16px label spacing this placed
landscape artwork at792 instead of the intended742/743. Home now collapses that
hidden geometry, uses40px title plus12px gap, and lets trailing tiles reach the
right display edge. Sharp portrait preview is[1520,96,280,420],radius12. Shared
catalog corners/stroke are now12px/3px. The focused title and description use
1000px/700px widths; navigation fades out over200ms and cannot own browse focus.
The native Right×2→Up→Down→Back→Down check retained[0,2], restored navigation
opacity1 on the billboard, and returned to opacity0 while browsing. No runtime
error occurred in that check. This is ECP path/state evidence, not remote latency.

Measured JPEG/reference border rows in the matched landscape state: KMP top
743–745,bottom977–979; native top742–744,bottom978–979 under the recorded light-
pixel threshold. Remaining native typography differs: description wraps at
different words and the reported native block is117px versus KMP114px. Metadata
spacing/ink widths, artwork crop/quality and motion still need correction or
explicit qualification. The native image loader also reported a1935x1080 hero texture
for the774x432 fixture with1920x1080 decode bounds; texture/performance tuning is
not closed. No full-screen parity or60fps claim follows from these captures.

Missing producer presentation remains explicit in BACKEND_HANDOFF.md: role-specific
tile captions/certification, KMP hero metadata ordering, poster soft-art and trimmed
logos/enriched summaries. The sharp poster is present, but the soft background
stays neutral. History day/progress/paging is not resolved by Home's new fields.
Row pending/failed/Retry shells, long strings, rapid scroll and empty-to-content
transitions remain open. Source-accurate gateway Matroska timing, negative decoder
recovery and actual Live media qualification also remain open. The owner cannot
currently observe the TV; visible motion/audible output remain unconfirmed. No
capture hardware is available, so physical p95 input latency remains unverified.

Final source checks:4/4 production-boundary, SceneGraph handler, HTTPS transport
and asynchronous-dispatch checks passed; BrighterScript0.73.1 compile, immutable
design integrity, design validation and diff whitespace checks passed. Final
runtime source record has269 input hashes at
`artifacts/home-preview-release-r2-20261024/source-record.json`. Packager inspection
found no QA hooks/captured images/fixtures/retired API/Home paging path. Checksums:
public303f2d3821b58c9e25a53760bab50072f83a1dd6662c8495d7b0baf422c19e70;
locked2dd38f2bd5bab485ae0c17f5f5182a6627df79833d5ad0fe0e9d75307d82355d.
Both ZIPs are in that build's packages directory. The normal public package was
restored after fixtures; installation/startup evidence is in
`artifacts/tcl-current-20261023/home-focus-normal-restored/`. Production activation
and Store submission were not performed. Overall qualification remains incomplete.

## Home row-state correction follow-up

Home now consumes explicit `Pending`, `Ready`, `Empty` and `Failed` row states.
Pending rows render six bounded placeholder cards in the server-provided card
shape; Empty rows remain hidden; Failed rows render the producer message with a
retry action that re-requests the current Home snapshot. A complete Home with no
rows exposes the supported Settings recovery action instead of a dead footer.
Contract validation rejects unknown states, cards on non-ready rows, and failed
rows without a message. Handler regressions cover ordering, retry request
ownership, empty recovery and native focus expectations.

All four current-client harnesses and BrighterScript compilation passed. The
private network-disabled TCL fixture ran the production Home handler and passed:
3 rendered rows from Pending/Failed/Ready input, Empty omitted, six pending
cards, failed retry marker, ready card identity and shelf focus. Evidence:
`artifacts/tcl-current-20261023/home-state-check-r6/` and
`home-state-fixture-r6.jpg`. The earlier fixture attempts exposed invocation
issues only; the final run had no runtime error after the marker. Normal public
package was restored afterward.

Current candidate: `artifacts/home-row-states-build/packages-equivalent/` is
not separately retained; package archives are in
`artifacts/home-row-states-build/`. Normal ZIP SHA256
`21da0d14ce9763e1433a414ff88f08dce9ff6225e09becae02e03d4db46d9412`; public ZIP
SHA256 `574056ba80fd571a461e99a91a6b832e7957b7f5c0d8b78f32f0a8d78ae62f4e`.
This closes the Home loading/failed-row shell gap, not full Home parity,
sustained scrolling, picture/audio quality or app-wide timing budgets.

## Calendar failed/empty state follow-up

Calendar day responses now clear retained entries on an accepted first page for
that selected day, preventing a stale day from making an empty server response
look populated. Failed day loads retain request ownership and expose a focused
Try again action; stale failures are ignored. Empty days expose a focused Browse
Home action. The malformed request/context guard was corrected after a TCL
fixture reproduced a crash. All four harnesses and BrighterScript compilation
passed. Native fixture evidence:
`artifacts/tcl-current-20261023/calendar-state-check-r2/result.json` and
`calendar-state-fixture-r2.jpg`. Normal public package restored from
`artifacts/calendar-state-build/`; SHA256 values are in that directory. This
closes the tested failure/empty states, not producer day-label presentation,
native return navigation, or full Calendar parity.
