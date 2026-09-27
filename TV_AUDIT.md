# Native Roku TV design audit — ROK-043

Scope: every TV entry in the design screen index (46 states), shared components,
copy, TV-034/038/040/041, and the owner's 2026-09-27 corrections. Design pin:
`3b6e4340773b31f427f46b9ef7dd888936b381f0`. Application: 1.11.0.

## Correction to the earlier Home verdict — ROK-044

The 1.11.0 captures still lacked the episode title. The previous Home verdict
was too broad: listing and visiting all reference screens did not establish
correct metadata presentation. This defect was raised again by the owner.

1.11.1 resolves the queued episode against its series metadata (exact ID, then
verified S/E), preserves the title logo and IMDb rating through the compact cache,
and populates the same episode title in the Continue Watching subtitle. The
progress bar follows the measured context with a 12px gap, capped at340px only
for long labels. Movies and unavailable-title/duration states reserve no empty
context/progress slots. Series runtime follows the actual queued duration.

Private physical captures on the same TV verify a long episode name, a short
three-letter episode name, and a movie. Each displayed its title logo. The short
series context occupies74px from x128, with the bar starting at214; the long
label caps at340px, bar x480; the movie bar starts at128. All three have elapsed
text after the120px bar plus12px. Unavailable-title and zero/unknown-progress
geometry, specials, Up Next, cross-series identity and late/fresh episode
responses are separately covered by the executable hero regression.

This supersedes the earlier metadata-completeness implication, not every other
untested state in the inventory below.

## Precedence and corrections

The older component sheet says white Resume. TV-038 and the current owner request
supersede that: Resume stays accent yellow with dark text and a white focus ring.
The prior Roku specification incorrectly treated the white state and a separate
paged episode screen as acceptable adaptations. Both are corrected.

Home now enumerates each addon catalog by `(addon_id,type,id)` in server order.
Personal rows remain separate. Catalog data loads for the visible window plus
one row ahead, with at most two owned requests; cancellation counts active reads
until they drain. At most five nearby catalog payloads remain cached. Distant
payloads become lightweight skeletons; empty/error/required-filter states and
cursor termination are explicit. Native RowList virtualizes visible items.
The 100-catalog regression verifies inventory, no cold sweep, concurrency,
eviction, cancelled completions and repeated pages. This does not claim a
measured process-memory or GPU limit for Roku.

Lower Home uses three complete rows at 214 HD pixels per row. Hero mode retains
its original 237px spacing and one visible shelf. Artwork requests use the actual
GPU resolution (320×180 for a 213×120 card on the tested FHD graphics plane),
95-quality public artwork and logical Poster decode dimensions. Private artwork
URLs are not sent to an image proxy. Removed unrelated full-screen preloads.

TvTitle keeps its hero/actions above Season and a horizontal episode strip;
Up from every episode reaches Season. The strip keeps six item views and clamps
at either end. TvLive uses a programme header, contained channel preview artwork,
horizontal categories, channel number/logo/name column, rounded programme cells
and accent time/progress. The main rail is above all browsing content.

The audit also corrected Discover's separate type/catalog rows, source quality
badges/play icons/density and background context, the complete track list in the
right panel, More info Close, the search keypad, My List segments, bounded title
fallback and empty-state copy. Opaque playback/source identities are unchanged.

## Reference inventory and evidence

“Device” means privately inspected captures and remote traversal on TCL 50S435,
Roku OS 15.3.4. “Runtime” means executable local handlers/policies, not physical
pixel parity. Earlier profile checks remain relevant where renderer code did not
change. Destructive/account state transitions were not replayed on the household.

| Reference states | Audit result and evidence |
| --- | --- |
| TvHome | Corrected all-catalog loader, three lower shelves, sharp artwork, yellow Resume; device Home/three-row/addon shelves and last-card traversal; catalog runtime suite |
| TvMenu | Corrected layer order; expanded rail inspected over the guide; input bounds/runtime |
| TvTitle | Corrected complete series hero/actions and horizontal episodes; device series/movie details, episode 12, Up to Season and return; episode/runtime suite |
| TvSources, TvSourceProvider | Corrected quality badge, provider/file line, play icon, five compact rows and underlying title context; device source panel/preparation; source policy fixtures |
| TvDiscover, TvDiscoverFilter | Separate type and scrollable catalog rows; device six-plus catalog movement and result grid; required-filter policy retained |
| TvFilterText | Shared full-screen input; native full Keyboard remains a platform adaptation; filter/route identity checks |
| TvLive, TvLiveSearch | Rebuilt guide composition/categories, real logos, visible timeline boundaries and rail; device guide/rail and boundary runtime; query input shares text-entry shell |
| TvLiveDetails | Right programme panel with channel/time, description, Watch and Close; same guide selection owner preserved |
| TvSearch | Custom six-column rounded keypad with Lucide utility icons; device mobile literal “naruto” input and addon result rows; keypad input/bounds runtime; removed passive result counts |
| TvLibrary | My List / Continue Watching segments, shared landscape cards and empty copy; library/queue identity and correction runtimes; device empty and populated views |
| TvMoreInfo, TvSourceDetails | Full-screen readable information and explicit Close; device title/source context; Back returns to owning page |
| TvProfiles, TvProfilesManage, TvManageCue | Stable outlined avatars, centered Manage/Done and pencil cues; device chooser/editor traversal, profile runtime |
| TvProfileEdit, TvAvatars | Shared rounded controls, curated local avatars, fixed geometry; device editor/picker cancellation; create/edit/page/primary-deletion guards in runtime |
| TvProfileName, TvPin, TvPinError | Full-screen form with native full Keyboard/PIN semantics; literal input, secret clearing, validation/cancel runtime; not a claim of matching the static keyboard illustration |
| TvProfileDelete, TvSignOut | Existing confirmation and cancellation contracts; parent/primary/delete guards in runtime; no destructive device mutation |
| TvSettings, TvPlayback, TvPlaybackChoice | Shared settings rows, icons and right choices; device Settings and preference/runtime checks |
| TvAddons, TvAddonManage, TvAddonRemove | Shared list/choice components; clear Home catalog cache after addon mutation; account-only/source-identity static checks; no production addon changes |
| TvAddonInstall | Shared full-screen native URL input, preserves punctuation/mobile keyboard entry; no production install mutation |
| TvItemMenu, TvHidden | Shared right choices and Undo behavior; library/queue runtime; hold/release semantics retained |
| TvPlayer, TvPlayerSeek | Shared circular Lucide controls, fixed outline, tabular time, no movie episode gap; prior device movie overlay and current playback/seek/rollback runtimes |
| TvPlayerSubs | One right-panel track list, current track focused, Off/back/empty states; 12-track/stale-session runtime; native TV system menus are separate |
| TvPlayerLive | Live-only controls and passive programme progress retained; live/control runtime; decoder frames excluded from screenshot claims |
| TvPlayerBuffering | Visible accent spinner and centered preparation; device preparation plus player runtime |
| TvPlayerNext, TvUpNext | Existing continuation/next-session ownership, cancel/rollback and policy tests retained; automatic end-of-episode physical transition not replayed in this visual audit |
| TvPlayerError | Existing bounded retry/source/return paths and shared controls; direct/rollback tests; error permutations not forcibly induced on the household |
| TvPairing, TvPairingLoading, TvPairingExpired | Existing account-only QR/code/expiry shell and bundled typography; auth/static guards retained; paired device was not signed out to replay these states |
| TvStates | Skeleton catalog rows, independent startup, actionable catalog retry, empty library/filter states and spinner; slow/failure/stale runtime coverage and device loaded states |

The table is a complete reference inventory, not a blanket pixel-parity or hardware
certification. Native full text/PIN entry and unexercised destructive/auth/decoder
states are explicitly distinguished. Captures remain private; no screenshots,
credentials or user catalog contents are included in source or release ZIPs.
