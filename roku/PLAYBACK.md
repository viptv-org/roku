# Explicit sources and seamless Roku playback

## Source ownership

Movies and episodes always enter the populated `Choose a source` list. Discovery appends unique rows in arrival order; it never scores or starts a candidate on behalf of the viewer. The only automatic start is Resume with a stored `source_addon_id` (bounded to the backend's 128-byte context limit) plus `source_name`, both originating from a prior explicit choice. A newly discovered candidate must match both. Human/provider `source` text and an opaque `stream_id` alone never authorize automatic playback; absent or stale identity leaves the picker open.

A selected source error, early end, expired identifier or preparation failure never advances to another candidate. Retry repeats an explicit user action; Choose another source returns to discovery. Reported language remains visible in source/track labels but is not a consent gate and adds no `allow_unknown_audio` or audio-policy field to Roku requests.

## Pause

For VOD, Pause sets the active SceneGraph `Video.control` to `pause`. It does not stop or hide Video, clear ContentNode, delete the playback session, or stop its heartbeat. Resume sets `control` to `resume` on that same Video instance. This preserves the decoded frame and buffer.

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
- `tests/fallback.brs`: only exact stable resume source may auto-start; stale/missing preferences remain manual.
- `tests/schema.brs`: language-policy responses are not classified into client consent flows.
- `tests/playback_static.py`: production source has no automatic fallback/language-consent routines and contains both replacement Video/timer nodes and swap ordering.

Simulator/static checks establish client state transitions, not physical Roku decoder behavior. Device validation must confirm the video plane remains visible through pause and server-side seek on representative direct, remux and transcode sources.
