# VIPTV for Roku

VIPTV is a native 1280×720 SceneGraph client using Roku `Video`, native keyboard input, account-scoped device sessions, and profile-specific history. It contains no static administrator key, packaged bearer, provider credentials, or local avatar artwork.

The production package is origin-locked to `https://viptv.syek.tech` with an origin-only configuration. A fresh install starts device-code sign-in. The QR image is served by VIPTV itself and opens the website with the code prefilled; no pairing secret is sent to a third-party QR service. Rotating access/refresh credentials are written only after account approval.

## Navigation and profiles

The seven-entry left rail is **Profile, Home, Discover, Live TV, My List, Search, Settings**. The profile entry uses the selected profile’s server-approved DiceBear PNG with an initials fallback; it opens the existing account chooser. The remembered profile ID is revalidated against the signed-in account before automatic selection and is cleared on revocation/sign-out.

Manage profile names and avatars from the phone dashboard. Fresh accounts start without a profile. Imported profiles complete presentation setup without changing their ID, favorites, or history.

Focus uses rounded shape cues and small bounded scale changes. Left from the first card enters the rail; Right returns to content. Back restores route, filter, page, and cursor state without allowing late responses to steal focus from the rail, a dialog, or playback.

## Home and discovery

Home is a profile/account-scoped, two-minute cache with bounded shelves:

1. Continue Watching, including progress and resume labels
2. Recently Watched Live TV
3. Trending Movies and Popular Series
4. Live Now and favorite live channels, omitted when unavailable
5. My List

The selected item drives a large remote-backdrop hero with metadata and synopsis. Empty shelves are omitted rather than replaced with duplicate filler content.

Discover exposes Movies, Series, and Live tabs. It renders bounded catalog and genre filters from normalized addon manifest capabilities, offers Search only when the active catalog advertises it, sends an encoded `genre` query, and follows authoritative `next_skip` pagination. Loading, empty, retry, and error states remain visible.

Live TV retains bounded categories/channels and debounced now/next guide requests. Search aggregates bounded movie, series, and live results through Roku’s native keyboard.

## Settings

Leaving a kids profile or signing out requires the parent PIN. Cancelling keeps the current restricted session. Parents configure age limits and approved titles on the phone; live restrictions use the curated Family Kids channels, not individual programme ratings.

Settings includes per-profile audio/subtitle language, caption appearance, quality ceiling and autoplay controls, plus account and server status. Defaults apply to subsequent playback while deliberate in-player track choices are preserved. It has no server or credential editor; household management lives in the phone dashboard.

## Sources and playback

Every ordinary movie/episode play action opens one populated source picker. Rows show addon/source name, quality/codec/size badges when reported, and informational audio-language hints. Provider filters and English/dub hints help find a suitable source while retaining focus as results arrive. Automatic continuation requests fresh candidates and matches the previously chosen provider, language and quality where possible.

Resume can reuse a stable, previously chosen source after fresh discovery. The countdown can be cancelled; holding Resume or choosing another source opens the picker. A stale source leaves explicit source selection available. History retains episode identity, position and source context.

Pause uses native `Video.control="pause"` without hiding the Video node, clearing content, or deleting the session. Server-side seeks and track replacements keep the old frame/session visible while preparing a replacement, atomically swap after replacement playback begins, and roll back to the old session on failure. Repeated seek taps are debounced, holding accelerates, release commits, and Back cancels. Single-decoder TVs reuse the primary Video when a replacement decoder is unavailable. See [PLAYBACK.md](PLAYBACK.md).

## Bounds and limitations

Lists, metadata, filters, tasks, HTTP responses, route snapshots, source rows, and profile rows are bounded. Static/simulator validation does not certify physical Roku decoder concurrency, video-plane rendering, DRM, captions, remote voice input, or real-network performance. Release notes record the physical device, observed startup/navigation and playback results, and remaining coverage limits. Testing one television is not certification across all Roku models.

## Verification

Representative DSH checks (each BrightScript test includes its source dependencies):

```text
roku_check(project="roku")
roku_test(files=["roku/source/Util.brs","roku/source/SourceLabels.brs","roku/tests/source-policy.brs"], expect_logs=["ROKU_SOURCE_POLICY_OK"])
roku_test(files=["roku/source/Util.brs","roku/components/PlayerOverlay.brs","roku/tests/player-overlay.brs"], expect_logs=["ROKU_PLAYER_OVERLAY_OK"])
roku_test(files=["roku/source/Util.brs","roku/source/BrowsePolicy.brs","roku/source/JellyfinCaptionPolicy.brs","roku/source/AccountPolicy.brs","roku/components/AccountScene.brs","roku/components/MainScene.brs","roku/components/NavigationScene.brs","roku/components/LiveScene.brs","roku/components/DiscoverScene.brs","roku/components/ResponseScene.brs","roku/components/PlaybackScene.brs","roku/components/SeekScene.brs","roku/components/HomeScene.brs","roku/components/HomeFeedScene.brs","roku/components/SourcesScene.brs","roku/components/SessionScene.brs","roku/components/SearchScene.brs","roku/tests/lifecycle.brs"], expect_logs=["ROKU_LIFECYCLE_OK"])
python3 roku/tests/branding_contract.py
python3 roku/tests/scenegraph_ux_contract.py
```

Networkless visual fixtures are created only under `artifacts/` by `tests/make_ux_preview.py`; they are never packaged. Current preview evidence includes Home, Discover, Settings, Sources, and Profiles screenshots.

## Licensing and rebuild

`source/JellyfinCaptionPolicy.brs` is a limited adaptation from Jellyfin Roku pinned to `37ecffd9a589cadaf97771be1b0423e36309182f`; see the included GPLv2 notice/license. Compiler-added BSLib retains its MIT terms. The combined Roku client is GPLv2 and binary recipients must receive corresponding source and notices.

Build a new credential-free client archive with BrighterScript 0.73.1 or `roku_build`. Never overwrite a release artifact. Production assembly adds only the locked HTTPS origin—never an access token, refresh token, administrator key, or recovery material.
