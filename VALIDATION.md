# BE-002 retired quality preference — 2026-09-30

Roku no longer requires or publishes the retired profile `quality` preference.
Fresh backend responses without that field decode successfully; legacy responses
may include it, but it is ignored. Source compatibility hints use actual decoder
facts, not a historical profile cap. Resolution badges and source identities are
unchanged. The Maximum quality row is removed from the existing preferences
view; the remaining five rows retain their styling, options and navigation.
Stale quality-choice/save events cannot send a retired mutation.

All 32 runtime harnesses, six standalone static contracts, design/extraction
integrity, BrighterScript 0.73.1 compile/staging and both runtime ZIP flavors
passed. The focused preferences harness checks missing/legacy quality, five
rows, active language save, caption style/manual overrides and stale event
suppression. Actual source policy allows declared 2160p despite a legacy 480p
preference while still rejecting 2160p on an actual 1080p capability envelope.
These are interpreter/compile fixtures, not physical Roku or native renderer
qualification. No device install or production change occurred.

Local private/public ZIP SHA256 respectively:
`388214a61ba9c421acab343ff3f7a6fa1a7c62b2a727c18447d5cca0aed930de` /
`dc2fc86ac0a561fb52ed297cd00c19e6c1cc974bee5e1f0d6acff1780252dc46`.
Original extraction checksums remain; seven current content hashes/reasons were
mechanically updated for these owned source/test changes.

# BE-002 ordinary raw live guide — 2026-09-29

Design pin `4e153a7daca300389049e5fcfd5c3bc0af5edbee`, adopted through
design-sync without manually changing imported assets. Ordinary guide, Home
live shelves, live search, programme reads and channel playback use v2. Existing
guide geometry, programme window, hold, details and Back behavior remain.
The raw guide replaces 40-row pages with opaque next/previous tokens, including
backward refetch after eviction. Categories replace bounded 100-item pages on
existing D-pad filter boundaries, without new entries or reserved category IDs;
EPG retains at most 40 channels with at most 100 programmes each, fetching only
visible rows plus bounded lookahead with three requests in flight. Route serials
reject old page/guide responses; account/profile generation guards remain.
Provider ordering and HTTP logos survive the transport boundary; no full index,
exact count, US classification or catalog swap control is introduced.

Watch resolves the exact channel into an opaque source ID, then uses the existing
mandatory authorized gateway logical lease at position zero. Startup, renewal,
release and track replacement use v2. Duplicate source admissions are suppressed;
Back/filter cancellation clears source admission and ignores its late response.
Source sanitization rejects URL/header authority and substituted provider identity.
Page decoding rejects missing metadata, malformed tokens/scalars and duplicate IDs.
Gateway/source/cursor
failures use the existing error surfaces; partial EPG failure retains channels.

Passed locally: all 32 Python runtime harnesses; seven static contracts; standalone
EPG transport fixture; design integrity and migration inventory; BrighterScript
0.73.1 compilation/staging and both runtime ZIP flavors. The added runtime exercises
production cursor routing, 100 page replacements, 100 EPG insertions/evictions,
bounded rows/cache, backward focus and airtime, exact source routing, duplicate
admission, HTTP logos, authority rejection and opaque lease payloads. Negative
fixtures cover malformed/missing cursor metadata, duplicate rows, substituted
providers and source authority. Category boundary tests verify forward/reverse
focus and preserve a provider category named like the former reserved ID.
Interpreter: `VIPTV_BRS_CLI=/home/vynxc/.npm/_npx/a9b2b3b0ed971b66/node_modules/.bin/brs`
(`@rokucommunity/brs` cached CLI). These use mocked HTTP/device/SceneGraph boundaries.
Real backend/gateway/media integration, physical guide focus/hold, native TLS,
background/foreground expiry and 4K/tracks remain unqualified. No production,
provider subscription, device installation or Store submission occurred.

Compiled artifacts after review: `artifacts/be002-live-v2-boundary/viptv-roku.zip`
(`35f960c95c8b8003352a48d417878f922d343f20026afb3ff681e6a6a76ba2c1`)
and `viptv-roku-public.zip`
(`d568443b34f0adf0e08e3dcd6e666f20aaff479ff3a6750149aed4551aa41570`).

# BE-002 v2 VOD playback — 2026-09-29

Native movie/exact-episode discovery, startup, renewal and release now use v2.
Roku always requests authorized gateway delivery; no usable original URL is
accepted. Startup/polling and independent ambiguous/cancelled cleanup are bounded;
reconciliation preserves the exact idempotency body. Gateway copy/direct mode
remains a managed timeline. Paused title time survives a sliding native window,
and Resume replaces at that anchor instead of blindly resuming stale HLS.

Logical leases cover active, paused, seek and Next transition admissions. Renewal
refusal/expiry stops media; transient network retries retain the original deadline,
and a late acknowledgement cannot recreate a released lease. V2 controls require
the configured HTTPS backend and never follow media URLs. Native decoder limits
remain measured and 2160p capability facts are not artificially capped.

Passed locally: all 31 Python runtime harnesses, seven static/contract scripts,
the new standalone v2 contract fixture, BrighterScript 0.73.1 compilation/staging,
design integrity and migration inventory. New tests exercise production Task and
Scene callbacks while mocking HTTP/device/SceneGraph boundaries, not real provider
or physical playback. Partial discovery retains healthy sources and safe provider
causes. The broader schema.brs simulator fixture could not run with this CLI's
missing roRegistrySection/roFileSystem; it is not counted as passing evidence.

Two compiled ZIP candidates: artifacts/be002-vod-final.Cdey8Q/viptv-roku.zip and
viptv-roku-public.zip (SHA256SUMS beside them). They contain bslib, fonts and
notices. No device installation, store submission or production change occurred.
Live, real backend/gateway/Roku media integration, background return, native
TLS/redirect qualification, 4K/tracks and full cutover remain open.

Four pre-existing migration-inventory mismatches were traced to committed
8e24931 font/artwork-gate/error changes. Their hashes/reasons are now recorded;
those source bytes were not changed by this pass. Original extraction hashes stay.

# ROK-044 visibility follow-up — 1.11.3 (2026-09-27)

Design `ac5ae2bad129753135aed01cb85e5a2b343f33f9`. Following the episode-title
repair, a second audit found verbose card subtitles hiding the title and a fast
playback route that could reach the player before title metadata. Compact card
copy and non-scrolling focus were inspected on the physical Roku; the fast
metadata route is covered by ownership/cancellation runtime checks. The 1.11.3
installer checksum and active-app version were confirmed independently. The latter
race was not deliberately induced on the household TV. No source preference or
playback route policy changed. See [TV_AUDIT.md](TV_AUDIT.md).

Artifacts: `artifacts/rok044-1.11.3/viptv-roku.zip` and
`artifacts/rok044-1.11.3/viptv-roku-public.zip`. SHA-256 respectively:

```
26a79fbfcb4388bbbfc8c07d7f18bcb31458ed25c0c0ccd03193f98f815c5413
6d0a7048d02691cc84db6cde764d8d252791ea88ea1995f35f09566a2de7c42c
```

Older build records follow.

# ROK-044 hero metadata correction — 1.11.1 (2026-09-27)

Design `65e2b68bb5f9c8ce32bca27241e5c893a7126d82`. Corrects the missed episode
name and fixed progress-column spacing, plus the dropped logo/rating on the same
metadata path. Title identity is verified against the owning series. Compact
metadata retains only needed episode titles; the actual asynchronous adapter is
exercised for late responses and a changed episode of the same series.

Physical TV captures verify real long-title series, short-title series and movie
heroes, all with logos. The short context and bar are adjacent; long text is
bounded; movies have no episode reservation. No playback or profile mutation
was needed for these checks. See the correction in [TV_AUDIT.md](TV_AUDIT.md).

Passed locally: seven static checks, all26 runtime harnesses including
`hero_metadata_runtime.py`, design integrity, migration hashes and BrighterScript
0.73.1 validation/staging. Both installable ZIP flavors were generated.

Artifacts: `artifacts/rok044-1.11.1/viptv-roku.zip` and
`artifacts/rok044-1.11.1/viptv-roku-public.zip`. SHA-256 respectively:

```
6bbaed7dd8783b53cef8a7245e1666fda5b26e5fa371d3d9d2dae8a3746d44e8
782f8b8b94b5177dfccee75d831c0b6c6b5e55d566f4962bcdf51dcf6d9f6e23
```

Older records below remain historical; their broad Home metadata verdict was
incorrect and is explicitly corrected above.

# ROK-043 TV audit — 1.11.0 (2026-09-27)

Design `3b6e4340773b31f427f46b9ef7dd888936b381f0`. See [TV_AUDIT.md](TV_AUDIT.md)
for all 46 TV reference states, correction precedence, device evidence and limits.

Passed: seven static scripts; 25 runtime harnesses including new 100-catalog,
virtual strip, graphics-resolution, complete track-panel and keypad tests; five
standalone BRS fixtures; BrighterScript 0.73.1 validation/staging; design import
integrity (186 files); migration inventory; both package flavors.

Physical TV: TCL 50S435 / Roku OS 15.3.4. Checked three complete Home shelves,
Cinemeta and AIOMetadata catalog rows, yellow Resume, detailed series composition,
episode 12 fully visible, guide header/categories/cells and rail above them,
Discover horizontal catalogs, custom search keys and mobile literal search,
source/title overlay context, preparation and library empty/segment presentation.
The full audit separates those checks from native-input adaptations and states
not replayed on the paired household device. Decoder pixels are not in screenshots.

Installed ZIP: `artifacts/rok043-verified/viptv-roku.zip`. Public ZIP:
`artifacts/rok043-verified/viptv-roku-public.zip`. SHA-256 respectively:

```
7e2b737dd776d17f66619de8774daa50d83973f2205ae30bf20751bef26e6ada
82db2c5408ef5d73142a6f898e84eabb7a36e2301bb771a90e39528319e9775d
```

Developer installer reports Install Success with matching package MD5; ECP reports
VIPTV 1.11.0 active. Prior records below describe historical builds.

# Physical Roku UI corrections — 1.10.1 (2026-09-27)

Design: `6e56136a698a52c87d232ed940775244e9d93d33` (ROK-042).
The 1.10.0 device screenshot revealed clipped top/left button outlines,
inconsistent nine-patch cap sizes and an incorrect yellow Resume fill.
`DesignSurface` draws a shared circular contour and 3px inset border inside
fixed bounds. Action pills, icon circles, filters, source and channel rows now
use it. Geometry never scales on focus.

Also corrected: obsolete 256×144 backing under 240×135 episode artwork;
card mask variants; two-line Home/detail synopsis; compact S/E text separated
from elapsed/total time; View all action content; explicit rail focus release
when selecting a destination. Episode-grid summaries are bounded to one line
so the second row fits its viewport; full descriptions remain in More info.

The physical profile chooser uncovered a real render-thread exception from
`roFileSystem`. Local avatar lookup now uses the validated bundled catalog,
including character asset paths, and transparent avatar backgrounds stay
stable. Removed an unsupported ScrollingLabel width field. The branding check
now validates all catalog image paths and rejects render-thread filesystem use.

## Physical evidence

TCL Roku TV 50S435, Roku OS 15.3.4, HD logical canvas, private developer captures:

| Surface/state | Inspected result |
| --- | --- |
| Home Resume / Details / plus | Continuous matching outlines; off-white focus; pill/circle geometry |
| Home final card and another Right | Complete card and ring; cursor remains in the row |
| Lower Home shelves | Hero removed; complete focused card and separated shelf headings |
| Profiles / Manage / Done | Stable square outline; compact centered management button; no avatar crash |
| Profile editor / avatar picker | Name, Save, Cancel, avatar and category focus inspected; cancelled editing |
| Settings / Search | Readable rows/icons and native keyboard; keyboard remains documented native adaptation |
| Discover / navigation rail | Landscape card geometry; selecting destination releases rail into page |
| Movie detail / More info | Landscape hero, two-line summary, icon-led actions and readable full description |
| Series episodes | Matching artwork/background/ring dimensions; no protruding backing |
| Source panel / preparation | Readable focused row, progress spinner, loading spinner |
| Movie player | Circular Lucide controls, elapsed time and `1 h 40 min` duration; no empty episode line |
| Live guide | Readable current/future programme grid and focused programme |

This is a visual and navigation audit of the reached states, not proof of every
error, destructive action, parent-PIN or track-switch flow. Decoder video is
absent from developer screenshots; player evidence covers the UI overlay.
Profile create/delete mutations were not exercised on the household. Local
runtime fixtures cover profile mutation, PIN cancellation and playback policy.
The device log has no new script errors; oversized hero texture warnings remain
and do not establish a playback or visual failure.

Passed: seven static scripts, all 20 runtime harnesses, five standalone policy
fixtures, immutable design inputs, migration inventory, BrighterScript 0.73.1
validation/staging and both ZIP flavors. Developer installer reports success;
its package MD5 matches the local ZIP and ECP reports active VIPTV 1.10.1.

Artifacts: `artifacts/rok042-outline-release/viptv-roku.zip` and
`viptv-roku-public.zip`. SHA-256 respectively:

```
86e402503d2f94d2afef539d85c8d2baa10badf74ac5abe36a7890f635ca26fc
36f5d4a766f7c9e7e3bc6f1ac6d38cd6c4e39228da4b032be23dccf2bcb11a1e
```

The prior 1.10.0 validation below is historical.

# Native TV design adoption — 2026-09-27

Version 1.10.0 adopts design `e33bf664f8370aea72ef839fb6f81c9687eac9d9`
under ROK-042. The HD scene uses the new palette, bundled Onest/Bricolage fonts,
Lucide icon variants, rounded controls, fixed-size focus, native expanded rail,
landscape Home/detail artwork, compact profile management, and right panels.
Profile artwork uses validated persisted style/choice assets with remote/initial
fallback. Fresh movie Play still opens source selection; Resume keeps its saved
source semantics. The first Home shelf is clipped below its complete captions
so the following heading cannot peek through before navigation.

Passed locally: design input hash verification (173 files); migration inventory
(848 original entries, 84 explicitly documented divergences, one historical
removal); seven static contract scripts; all 20 Python-driven BrightScript
runtime harnesses; five standalone policy/player BRS fixtures; BrighterScript
0.73.1 compilation and staging; both deterministic runtime ZIP flavors with
fonts, Lucide licenses and generated `source/bslib.brs` present.

BrightScript simulator 2.5.3 rendered and was privately inspected at 1280×720:
Home, detail, collapsed/expanded rail, profiles, profile form, sources, Settings,
episode grid, live programme details, and player controls. Left entered the
expanded rail with icon centres unchanged. Captures are temporary evidence and
are not committed or packaged. Simulator rendering and mocked runtime tests do
not qualify physical Roku focus animation, decoder behavior or font rasterization.

Native adaptations are explicit in `design-contract/ROKU_DESIGN.md`: the native
Keyboard/MiniKeyboard, four-column paged episode grid and decoded low-resolution
ambient texture remain. This is not a claim of pixel equality with every TV
reference. No physical device installation or Store publication was performed.

Artifacts: `artifacts/rok042-20260927-final/viptv-roku.zip` and
`viptv-roku-public.zip`. SHA-256 respectively:

```
b134544ebdad056ab7233ce4eb6176f1e9137c252ecac64bf3bfc99a9a1eaae6
ea4dae9818516f322d9b4e46c98f42b68b1c4a4bb76543b943cb7fd4190a5abf
```

Reproduce the checked build using the commands in `.github/workflows/ci.yml`.
For a new local artifact directory, pass `--output-dir` to `scripts/package.py`;
the packager refuses existing archives and requires compiled staging plus fonts.

## Historical extraction validation

Baseline: vynxc/viptv@7d6b4131a44d87b58edcf12709af5851da387176. The extraction changed no runtime source, SceneGraph XML, data, image, manifest or configuration byte; MIGRATION.json records one test-only fix made at extraction time: direct_runtime.py includes the existing ContinuationPolicy.brs dependency needed by the current findStreams handler. Every entry keeps its original `source` and `sha256`.

Later dead-code cleanups diverge from those bytes, and MIGRATION.json records each divergence in place rather than dropping it. 11 entries are re-pinned against the extraction revision (the extraction-time direct_runtime.py fix plus 10 files changed by the cleanup in 14a702c), each keeping its original `sha256` and adding the current `extracted_sha256` with a `reason`. 1 entry is a recorded removal: `roku/tests/account-flow.brs`, an unreferenced and provably unpassable pre-overhaul harness. `python3 scripts/verify-migration.py` still hashes every non-removed entry and now also fails when a recorded removal reappears, when a removed entry carries a content hash, or when a re-pinned or removed entry has no reason, so the record cannot drift silently.

Local checks passed: migration checksums; account, branding, playback, focus, scenegraph and node-identity static contracts; all 19 *_runtime.py harnesses (18 initially passed and the corrected direct harness then passed); BrighterScript 0.73.1 validation/staging; generated runtime ZIP layout with 749 entries including generated source/bslib.brs. CI also exercises the explicit BRS policy fixtures.

ZIP packaging uses compiled staging, not raw source; artifact creation refuses to overwrite an existing archive. GitHub CI uploads the checksummed archive, and validated version-tag builds publish it as a release asset. This split did not install a device package, submit a Roku Store build or perform physical TV validation.
# REL-001 — 2026-09-28

Removed the Home metadata/image readiness cover and timer entirely. Account
connection status remains separate. Production startup handlers now pass the
updated runtime check: absent rows/loading artwork, repeat Home entry and stale
artwork responses never raise that cover. Error decoding preserves safe reasons
and stable codes without ParseJSON logging malformed error bodies; discovery,
catalog, preparation and seek failures carry them through the UI. The numeric
player labels no longer enable monospacedDigits; bundled regular/tabular glyphs
were inspected and the player-overlay runtime still reports correct time text.

Passed: BrighterScript 0.73.1 validation/staging, design contract and pin checks,
startup_ready_runtime.py, isolated production api_error_runtime.py, and the
player-overlay BRS fixture. A compiled ZIP includes runtime helpers and fonts.
The full schema harness cannot run under the available off-device interpreter
because roRegistrySection/roFileSystem are unsupported; no full-schema or physical
Roku acceptance is claimed. Real firmware must confirm the font rendering fix.

# Live v2 wire bounds — 2026-09-30

Baseline `d46fe668995e6fe2c924d65ba98c722027390cb3`. The shared live-page
sanitizer now accepts opaque base64url next/previous cursors through 4096
characters, matching the backend decoder. Live catalog/generation metadata uses
a dedicated integer/LongInteger validator rather than the signed-32-bit generic
matching helper. Exact native integer values are retained; Float/Double and string
identity encodings fail closed. Generic `MatchInteger` and other numeric fields
are unchanged. No client request/response schema or UI layout changed.

`live_v2_runtime.py` covers both page routes and cursor directions at
2048/2049/4096/4097, JSON metadata at 2147483647/2147483648, typed LongInteger
9007199254740993 and 9223372036854775807, zero/sign semantics, malformed scalars,
fractional/unsafe floating-point identities and preserved exact metadata strings.
The >2^53 cases are typed native LongInteger fixtures, not a claim that arbitrary
JavaScript JSON parsing preserves every i64 value. Actual device decoding remains
unqualified. Baseline temporary probes rejected valid >32-bit metadata and a
2049-character cursor; the expanded production runtime fixture passes now.

Passed: all 32 runtime harnesses, six Python static contracts, design/inventory
checks, BrighterScript 0.73.1 validation/staging and both locked/public runtime
ZIP builds. Interpreter:
`/home/vynxc/.npm/_npx/a9b2b3b0ed971b66/node_modules/.bin/brs`.
Local packages: `/tmp/roku-wire-final-packages.pvpJ0E/`; no device install, CI dispatch,
production operation or Android/backend source change was performed.
Locked/public ZIP SHA-256 respectively:
`4ee62f6c055a37ee2aec4375506098a0703b328ffc20766986c7fbac7e65e088` /
`b20f82cd002ebff7429bf4881db7d91031cf05b8993d5113886360737b6893a7`.

The audited backend encoder had a separate unbounded pivot issue: its live
cursor included provider category ID verbatim. A 3000-character ASCII category
ID plus a second row, requested with categories/default filters/limit1,
reconstructs a 4276-character cursor which the 4096-character decoder refused
with `invalid_cursor`. Raising the Roku cap cannot repair this. The backend owner
is separately bounding emitted live/VOD tokens with safe
`catalog_cursor_too_large` refusal, preserving raw IDs/data rather than truncating,
filtering or changing import policy. That fix and its tests are not part of this
Roku checkpoint. This is source-derived diagnostic evidence, not a production-
provider observation.
