# VIPTV Roku

Native Roku viewing client. Roku requires the backend and uses the same shared Rust-engine content APIs as TV-web and remote KMP clients. Android, desktop and ordinary web live in the KMP application repository.

The experimental client reads one v3 bootstrap for Home, cached shelf cards, continuation entries and lightweight library membership. Shelf navigation uses explicit host actions. Search uses one server-ranked metadata query, with rendered Movies, TV Shows and Anime groups. Opaque media IDs and episode coordinates remain unchanged.

Discover reads host-advertised catalog/filter controls on demand, including required fields and multi-select limits. Apply sends one query; Cancel preserves the previous selections. Catalog-less metadata providers and identically named add-on catalogs retain their host identities.

Metadata automatically collects bounded episode pages. My List and Continue Watching append pages near the end of the visible collection without manual paging controls. Actual resume clocks apply only to Resume entries with matching identities; a prepared next episode starts at zero.

Live channels, groups, guide and opaque source admission use the shared profile-scoped host contract, including native M3U. Provider subtitles use viewer-scoped gateway SRT through managed replacement; unsupported Live collection controls are hidden.

Source discovery and playback retain the scoped v2 grant/gateway lifecycle. The active content adapter is selected explicitly by the application request envelope. Existing device pairing, parent controls, profile ownership and cancellation remain in place.

Current qualification is recorded in [VALIDATION.md](VALIDATION.md). The current uploaded design is the product reference; this branch does not certify full Roku design parity or physical Roku decoding. Existing native UI assets remain during that migration. No production deployment occurred.

The original extracted source and its hashes remain recorded in `MIGRATION.json`; Git history is preserved. License: GPL-2.0-only.
