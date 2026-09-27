# ROK-042 — Native Roku design-system adoption

Status: owner authorized 2026-09-27. This replaces the extracted Roku visual
baseline with the current TV design system. Native SceneGraph, account/profile
IDs, source intent, 700 ms holds, Back restoration and playback remain owned by
the Roku implementation. Reference states: TvHome, TvMenu, TvTitle, TvSources,
TvProfiles, TvProfilesManage, TvProfileEdit, TvAvatars, TvSettings, TvSearch,
TvLive, TvMoreInfo and TvPlayer families.

Roku retains its HD logical canvas (1280×720). Design coordinates are scaled by
2/3 from 1920×1080: safe area 64×36, rail 96 wide (expanded 347), content x128,
Home cards 213×120 with 24 horizontal spacing, profile artwork 146 square,
action pills 48 tall, section headings 21 and body 17–19. Bundle Onest and
Bricolage Grotesque TrueType fonts and the design-owned Lucide PNG variants.
Use the #0B0B0C ground, #161618/#212124/#2A2A2E surfaces, #F4F2EE text,
#B6B4AF metadata and #F5C542 progress/spinners. TV action buttons use a neutral surface when unfocused and off-white when focused;
Resume has no yellow override. Pill radius is half its height. Draw a continuous
3px white focus border inside the fixed control bounds so native grid clipping
cannot trim its top/left edges; fill and border share one contour. Circular
controls remain circles at the HD canvas on both HD and FHD devices.
Focus never scales artwork,
controls or captions; it uses a white ring and the established focus fill.

Home retains its bounded native RowList and per-row cursor restoration. The
first shelf and hero fit together; lower rows remove the hero and use the
screen's safe area. No row counters or passive key legends. Each focused card
and ring must be fully visible; Left/Right stay in the same row and stop at its
ends. The hero uses landscape artwork, a soft ambient layer, left/bottom
scrims, logo-or-title, episode/progress when present, facts, two synopsis lines,
and icon-led Play/Resume and Details. Detail uses the same artwork treatment,
without the old portrait column. Missing art keeps a legible title fallback.

Native adaptations: Roku's decoded low-resolution ambient texture supplies
the soft backdrop without a custom blur shader. Episode browsing keeps the
existing four-column paged grid and season control, using the new landscape
episode cards; it preserves the established page/season focus semantics.
Roku Keyboard/MiniKeyboard remain the text and PIN input controls. These
adaptations must be recorded independently from exact reference-image parity.

Profiles retain native create/edit/avatar/delete/PIN and paging. The chooser
centres its people tiles and compact icon-led Manage/Done action. The editor
uses avatar left, name and Save/Cancel/Delete right. Selection and return focus
remain stable across mutations and cancelled PIN/delete flows. Primary profile
deletion remains unavailable. Settings and choice lists use rounded rows; modal
choices and source selection use the 547px right panel over a scrim. Source
rows retain complete details through the existing Info action.

Player uses the same fonts, Lucide transport icons, separate circular controls,
accent progress, title/status at the top, and title/episode/timeline/controls in
the lower safe area. Movies omit the episode line. Live retains its passive
programme progress and audio/captions/exit controls. Preparation and buffering
retain visible spinners; track/seek/Next cancellation and rollback are unchanged.

Acceptance: compile and package fonts/assets, validate immutable asset hashes,
run existing profile, source, seek, continuation, guide and return-focus
contracts; add checks for palette, font packaging, icon variants, no scaling,
Home row geometry, detail landscape layout and right panels. Check networkless
visual fixtures where a renderer is available. Physical Roku installation is
separate from source/package validation and requires an explicit device request.

## ROK-042 hardware close inspection corrections (2026-09-27)

The first physical install exposed a clipped ActionRow ring, inconsistent
nine-patch corner scaling, an obsolete 256×144 episode backing under 240×135
artwork, and truncated hero context/synopsis. Correct these against the existing
TV reference states. Home context separates compact S/E identity from elapsed
and total time; allow the synopsis two full lines. Keep profile actions centred,
icons aligned, and all card backgrounds, artwork, progress and rings within
the same bounds. TV card focus remains an outline without scale.

Remote press/release/hold, source choice, profile edits and cancellation retain
their established behavior. Acceptance on physical hardware: inspect Resume,
Details and icon-only focus at each grid edge; inspect profile Manage/Done,
name/Save/Cancel, avatar picker, Settings, Discover, series episodes, movie
detail, source panel, lower Home shelves and player controls. Check rightmost
Home card visibility and row boundaries, then Back focus restoration. Record
which states were actually reached; visual inspection does not authorize
destructive profile or account operations.
