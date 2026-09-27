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
#B6B4AF metadata and #F5C542 progress/spinners. Focus never scales artwork,
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
