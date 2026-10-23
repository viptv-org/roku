# Roku / web-TV shared contract handoff

The web-TV agent owns backend edits. Roku does not edit backend/core/gateway
sources. Checked 2026-10-23 against backend 7275bce plus the in-progress
`engine_v3/viewing_action.rs` and route. This document is a consumer requirement,
not a claim that unpublished server behavior is deployed or agreed.

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
| Settings | profile `/preferences`, `/integrations`, `/source-integrations`, `/simkl`; `/api/parent/*` | consume in-progress preference `controls` and `/addon-activation` intent; no local assignment construction |
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

Additional playback requirement: the gateway must apply saved profile audio /
subtitle mode and expose decoder-facing appearance instructions. Its current
Start request accepts language/track fields but does not read saved preferences;
Roku must not recreate foreign-audio policy. Keep this dependency explicit.

The producer now documents these shared additions in
[`backend/TV_REMOTE_API.md`](../../backend/TV_REMOTE_API.md). Roku consumes that
contract, including named best-source selection and server-projected guide state.
This is source-level alignment; it does not change the QA 404 result or claim
producer deployment.

Synthetic request/response examples are in
[`roku/tests/fixtures/remote-v3.json`](../roku/tests/fixtures/remote-v3.json).
The production SceneGraph fixture consumes this file; it contains no credentials
or household metadata and is excluded from runtime packaging.
