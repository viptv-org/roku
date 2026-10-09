# BE-002 current VOD transport — 2026-09-29

Movies/exact episodes use account-scoped v2 discovery and playback leases. Roku
requires authorized HTTPS gateway delivery regardless of its direct-file codec
support; no gateway yields an actionable error rather than a native attempt.
The first start uses a unique idempotency body, polls under a 45-second bound,
and reconciles ambiguous/cancelled admissions before release under an independent
five-second bound. V2 control stays on the configured HTTPS backend.

Delivery kind and processing mode are separate: gateway `mode: direct` still
starts at native zero with its title offset. Managed Pause freezes title time;
Resume first continues the same Video node and delivery, retaining its buffer
and processing mode. Only native resume failure or eight seconds without clock
progress requests same-source recovery at the frozen anchor. Seek/track replacements retain the
single decoder, old lease and rollback position until success. Active/paused/
transition leases renew individually. Refusal/expiry stops playback; network
retries cannot extend expiry and late renewals cannot restore released leases.
Transport failures, 408/429 and HTTP 5xx renewal responses retry while the existing
lease remains valid; explicit authorization refusal and actual expiry stop playback.

Healthy provider sources survive another provider's failure. Empty discovery
shows its safe cause; raw provider messages never become displayed error text.
Profiles, history, exact-source selection and viewing geometry are unchanged.
Live remains on the legacy path until raw catalog migration. Device/network/
codec qualification and retired-path cleanup remain required; host tests alone
do not establish them.

# Historical explicit sources and playback record

## Source ownership

Movies and episodes always enter the populated `Choose a source` list. Discovery appends unique rows in arrival order; it never scores or starts a candidate on behalf of the viewer. The only automatic start is Resume with a stored `source_addon_id` (bounded to the backend's 128-byte context limit) plus `source_name`, both originating from a prior explicit choice. A newly discovered candidate must match both. Human/provider `source` text and an opaque `stream_id` alone never authorize automatic playback; absent or stale identity leaves the picker open.

A selected source error, early end, expired identifier or preparation failure never advances to another candidate. Retry repeats an explicit user action; Choose another source returns to discovery. Reported language remains visible in source/track labels but is not a consent gate and adds no `allow_unknown_audio` or audio-policy field to Roku requests.

## Pause

For VOD, Pause sets the active SceneGraph `Video.control` to `pause`. It does not stop or hide Video, clear ContentNode, delete the playback session, or stop its heartbeat. Resume sets `control` to `resume` on that same Video instance. This preserves the decoded frame and buffer.

## Buffering and buffer bars

Roku's SceneGraph `Video` node exposes no buffered TimeRanges: `bufferingStatus`
is valid only while a re-buffer is in progress and the `pauseBuffer*` fields
apply to live pause only. A seekbar buffer bar (as drawn on tv-web) is
therefore not implementable without fabricating data, and the client does not
fabricate it. The player overlay reports an honest state cue instead:
mid-playback stalls show a spinner plus a `REBUFFERING` status, initial
preparation shows `LOADING`.

## Seek and track replacement

Direct media uses native `Video.seek`. Server remux/transcode outputs require a replacement playback URL:

1. Clamp the absolute target and pause the current visible Video.
2. Keep its session and frame alive while requesting the replacement.
3. Start a second hidden Video and retain the old one until the replacement reaches `playing`.
4. Make the replacement visible, then hide/stop the old Video and delete only its session.
5. On secondary-decoder failure/timeout after successful preparation, release the secondary decoder and reuse the visible primary with the validated new content/session. Keep the old backend session until primary playback succeeds; preserve the original pause/play intent.
6. If primary fallback fails, restore the old content/session/full timeline. If restoration also fails, clean both sessions and show truthful source retry UI rather than leaving a stalled player.
7. If preparation itself fails (including provider connection-budget 429), keep the original session and restore its pause/play intent. Never bypass provider limits or choose another source.

The overlay remains visible with `Seeking…` and the absolute target. One OK commits one request. Repeated Left/Right or FF/Rewind presses accelerate from short steps to long jumps and clamp within the title duration.

## Regression evidence

- `tests/player-overlay.brs`: scrub preview, acceleration, clamping, single commit, visible seeking status, options and pause controls.
- `tests/lifecycle.brs`: native pause identity; old-frame retention; failed replacement rollback; successful atomic swap and old-session cleanup; direct seek; explicit track preservation.
- `tests/fallback.brs`: only the exact stable (addon + fingerprint) resume source may auto-start through v2 playback; `tests/explicit_resume_runtime.py` covers stale preferences reopening the explicit picker.
- `tests/schema.brs`: language-policy responses are not classified into client consent flows.
- `tests/playback_static.py`: production source has no automatic fallback/language-consent routines and contains both replacement Video/timer nodes and swap ordering.

Simulator/static checks establish client state transitions, not physical Roku decoder behavior. Device validation must confirm the video plane remains visible through pause and server-side seek on representative direct, remux and transcode sources.
