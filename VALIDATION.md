# Experimental shared-host checkpoint

Engine contract: core `47b85b5386617f455ade8b294a7a844b54f537c0`. Backend library acknowledgements include complete lightweight saved-title membership, including canonical aliases.

The off-device BrightScript runtime authenticated against the real local HTTPS backend, read twelve continuation entries and three discoverable shelves from one bootstrap, and collected all 1,184 real One Piece episodes automatically. Credentials stayed in a private temporary fixture. This was a content-transport check, not physical Roku playback qualification.

Focused checks cover opaque identity/parent preservation, Resume versus Next clocks, explicit shelf actions, 1,242-episode paging, repeated-cursor and parent-replacement rejection, cancellation, append deduplication, one in-flight collection page, focus restoration and retained content after append failure. The lifecycle fixture now exercises one global server query and server-category rendering.

The shared Live adapter retains opaque M3U connection/channel/group IDs and exact guide clocks. Live collection controls are hidden where the typed host does not support them. Provider subtitle discovery submits an opaque candidate to the server, validates its viewer-scoped SRT URL, and applies it through managed replacement before the decoder opens. The caption is already rebased by the gateway. Embedded/off selections clear the provider preference; source ownership fences prevent reuse on a different source. Physical Roku subtitle rendering and updated design parity remain unqualified. A decoder frame-rate claim requires actual Roku hardware.

Current full local suite: 73 passed, zero failures. BrighterScript 0.73.1 compile/staging passed. The public runtime ZIP was packaged from that staging tree; its checksum is stored beside the private workspace artifact. This is an experimental package, not a production release.

The compatible timeline contract retains the explicit gateway offset, keeping resumed HLS seek and title clocks separate. Backend integration pin: `91ecda58179ffa9fde4f19264c49b52c8dd4386c`; gateway `c85cd279c68e9fbc46530fb2e39bfc5de45ee7cd`. The current real HTTPS metadata probe again collected all 1,184 One Piece episodes.

Provider subtitle discovery is hidden unless the selected profile bootstrap advertises an enabled subtitle provider. Old hosts default to unavailable; no extra startup request is added. The full gate includes the bootstrap availability projection and current compiler pass.

Discovery now uses canonical host controls rather than Home-derived empty schemas.
The added transport fixture checks catalog ownership, friendly labels, selection
limits, unavailable and catalog-less providers, percent-decoded custom types and
lossless arrays. The actual scene/sheet handler fixture checks 40 available options,
required-input preflight, selection cap, Cancel isolation, one-request Apply,
footer focus return and paged query retention. These fixtures replace external IO
and SceneGraph nodes; physical Roku presentation remains unqualified. UI variants
without matched supplied design are recorded in `docs/DISCOVERY_V3.md`.

The updated 73-check gate passed with zero failures. BrighterScript 0.73.1
compiled and staged the runtime. Public ZIP SHA-256:
`f9f5b37babe0d59e3fb59e7a1735a96163c144ce92898572f389176443de8519`.
Archive inspection confirmed the compiled discovery components and runtime library,
with the private origin lock and test fixtures omitted. The current Android TV
installation and its API/gateway services were not changed.
