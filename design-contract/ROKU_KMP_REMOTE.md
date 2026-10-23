# ROK-REMOTE-001 — KMP TV presentation, remote authority

Status: owner-approved implementation, 2026-10-23. This contract supersedes the
legacy Roku rail, Home composition and client-owned playback selection for the
remote rebuild. The owner selected the current KMP TV working tree, rather than
the older canvas boards, as the visual reference.

The adopting Roku repository records the KMP commit, source hashes and private
reference archive hash in `docs/KMP_REFERENCE.json`. Those source bytes define
the reference: later edits by another agent do not silently change this target.
Existing KMP source is read-only during this adoption.

`assets/roku/roku/images/design/remote-entry.jpg` is the byte-identical KMP
`composeApp/src/commonMain/composeResources/files/entry/feature.jpg`, verified
against that reference ledger before import. The `remote-*.png` scrims/masks
come from `make_kmp_assets.py`, which records their KMP component provenance.

## Presentation and input

Use the KMP 1920×1080 TV coordinate system, Onest and Bricolage fonts, 96px side
safe area, fixed-size focus treatment, top navigation and profile menu. Scale
uniformly for 720p. Match the recorded TvNavigation, TvHome, TvDetails,
TvSources, TvSearch, TvLive, TvLibrary, TvHistory, TvCalendar, TvProfiles,
TvSettings and TvPlayer sources, including loading/error/empty variants.

One remote focus target is active. Left/Right traverse a row; Up/Down change
rows; boundaries return to navigation. Back dismisses the topmost overlay,
restores its opener, then returns to the prior route/card/scroll position.
Late responses must not move focus. Source drawers use the KMP 300ms entry and
200ms exit motion. Repeated input cannot submit duplicate mutations. Text input
uses the KMP TV keyboard layout; passwords are masked and cleared on dismissal.

Supported controls retain their labels and actions. Omit local mode, local
torrent controls, downloads, unsupported authentication and controls with no
real server/platform implementation. Do not copy KMP preview-only values or
unavailable placeholder actions. Empty configured capabilities remain usable
through their supported configuration flow, rather than inventing media.

## Authority

The server owns identity, permissions, catalogs, discovery, ordering, artwork
roles, source eligibility/ranking, resume, next episode and persistent settings.
Roku owns presentation, focus, animation, transient drafts, transport and the
native decoder. It sends observed capabilities and user intent; it does not
derive business rules from titles, source names, filenames or cached history.
Use the same current API as web-TV; its agent owns backend implementation.

## Acceptance

ROK-R01: bootstrap/profile changes never expose stale account content.
ROK-R02: server source order, target episode and resume decision survive unchanged.
ROK-R03: every supported screen covers entry/success/empty/failure/Back focus.
ROK-R04: unavailable features have no selectable dead-end controls.
ROK-R05: visible-window loading bounds nodes/images/tasks during long browsing.
ROK-R06: cancellation and refresh cannot resurrect retired playback sessions.
ROK-R07: inspect equivalent reference/renderer states at 1080p and 720p.
ROK-R08: record actual TCL 50S435 frame time, input latency and memory; 60fps
and p95 focus response below 100ms are targets, not unmeasured claims.

Functional, visual and physical-device acceptance are separate. App captures
stay private; durable evidence contains measurements and source references.
