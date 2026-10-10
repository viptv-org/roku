# Shared torrent gateway client integration

Roku keeps its native Video node and authenticated gateway HLS delivery. Torrent
acquisition runs in the shared Go worker on the gateway; no BitTorrent library
is packaged into this client. The original 120-second startup budget covers
control preparation and Video startup. Pending backend leases renew every
20 seconds; cancellation and rejected authority retain existing cleanup.

Local validation passes 67 static/runtime/BrightScript checks, migration and
pinned-design verification, compilation and runtime ZIP packaging. Physical
Roku playback and production rollout have not been performed. Gateway fixtures
prove decoded HLS output and seek delivery separately from Roku presentation.
Current acquisition/seek performance is accepted for integration; see
`playback-gateway/docs/TORRENT_PERFORMANCE_FOLLOWUP.md` in the workspace.

Gateway stages now pass through a separate scoped backend progress route to the
Task's existing status line. Only the canonical peer/metadata/archive/buffering
stages are displayed, once per transition. Retired request IDs and generations
cannot overwrite current status; unknown raw text is refused. Progress reads
cannot renew authority. All 67 local checks, compilation and ZIP packaging pass.
The same backend/gateway/progress API path has actual HTTPS browser decode and
pending-metadata cancellation evidence; it is not physical Roku presentation.

Startup uses the separate decoder-aware backend route. The first Video `playing`
event reports a scoped `{}` acknowledgement, including successful managed seek
replacement. Renewal preserves its coalesced state; a stale reply cannot retire
a replacement session. A definitive acknowledgement refusal retires active media.
The request uses backend control authority and never follows a media URL.

All 67 local checks pass; the changed playback/lease/seek/transport checks were
also rerun after the final closed-response validation. BrighterScript compilation
and the runtime ZIP pass. Actual Roku frame delivery remains separately
coordinated; gateway/browser acknowledgement evidence does not qualify its Video
node on physical hardware.
