# Host-driven discovery

Discover loads `/api/v3/discovery-controls?type=…` when opened or when the media
type changes. Home keeps its single bootstrap. Advertised media types, catalog
connection identity, friendly names, labels, required inputs and selection limits
drive presentation. The client never builds a provider endpoint. A catalog-less
provider uses its aggregate without sending an invented catalog ID.

Two identically named catalogs retain separate connection and numeric add-on
identities. Duplicate friendly labels receive a display number. Changing a
catalog or type clears its previous query. Scalar search/genre/extra inputs remain
compatible; multiple choices use one JSON `values` parameter on the existing
host request. Paging and saved navigation retain those arrays.

The shared choice sheet keeps a private draft. Required fields and selection caps
are checked before catalog IO. Apply publishes once, while Back/Cancel preserve
the query. Its native MarkupList scrolls through every supplied choice; Right
reaches the footer, and Up restores the last choice. Existing Lucide check assets
mark selections without moving the text when checked.

The multi-select footer, selection-limit message, required/empty states and
host-driven filter chips are provisional UI pending a matched supplied design.
This change does not establish full Roku visual parity. BrightScript interaction
fixtures exercise actual handlers and transport; physical Roku focus, animation
and decoding remain unqualified without a device.
