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

Installed ZIP: `artifacts/rok043-1.11.0/viptv-roku.zip`. Public ZIP:
`artifacts/rok043-1.11.0/viptv-roku-public.zip`. SHA-256 respectively:

```
386630574ec91fba4c2f155e5649a2f32ef377654408be7d76719e580199bb62
7f17e5660bb50a5a983c6ec874c6b3b65bda4d23a9a0d76f0d1c304d8d7ce7f9
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
