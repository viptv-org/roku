# Account-only Roku sign-in and profiles

VIPTV 1.9.1 uses revocable account/device credentials for every protected request. The optional private package contains exactly `{ "base": "https://your-origin" }` and locks only the server origin.

## Television flow

1. With no rotating device credential, Roku posts `/api/device/code` and shows the returned QR image plus the manual `user_code` and complete HTTPS activation URL.
2. The QR opens `verification_uri_complete`, which already contains the code. The website carries that code through public registration or sign-in. An authenticated person reviews the device and confirms it for their own account.
3. Roku polls `/api/device/token {device_code}`. Pending and slow-down responses use a bounded dedicated timer. Success may have zero profiles and always starts with no selected profile.
4. Roku loads `/api/auth/me`. A remembered profile is used only when it still appears in the current account response and canonical `setup_complete` is true; selection is acknowledged by `/api/auth/profile` before Home opens. Missing/revoked IDs return to the chooser.
5. A zero-profile account opens profile setup. An imported incomplete profile is edited in place so its existing ID, favorites, and history remain intact. Name entry is followed by a remote avatar-style chooser. Creation posts `{name,avatar_style}`; imported setup patches the same profile. The server creates the opaque DiceBear seed.
6. The chooser displays only people as avatar cards, with normal Add profile and Manage profiles buttons underneath. Management uses a Done button in that same action row. A separate pager exposes all twelve household profiles while rendering at most five people at once; Up/Down moves between people, actions and pager. Settings opens the same native manager. Selecting a profile there opens Edit profile with Save/Cancel and a paged avatar picker (18 tiles per page). Secondary profiles offer Delete profile with explicit confirmation; the primary profile cannot be deleted. Cancel preserves data and returns to the selected card. Deleting the selected profile returns to the chooser without unpairing the TV. Restricted kids sessions require the existing masked parent PIN before any mutation; cancelling the PIN preserves the editor draft.
7. Selecting the avatar/profile item in the navigation rail reopens the chooser. Relaunch normally restores the last validated profile. Re-pairing and revocation clear both credentials and the remembered profile.

## Closed wire contract

- `GET /api/auth/me`: account ID, `can_create_profile`, selected profile ID, and bounded own `profiles` where each profile has `id`, `name`, `avatar_url`, `avatar_style`, and `setup_complete`.
- `GET /api/profiles`: the same own-profile array. A device may `POST /api/profiles {name,avatar_style}` and `PATCH /api/profiles/:id` or `DELETE /api/profiles/:id` only inside its account. Restricted devices need a parent grant; primary deletion is rejected.
- `POST /api/auth/profile {profile_id}`: successful account-scoped selection.
- `POST /api/device/code {device_name:"VIPTV Roku"}`: `{device_code,user_code,verification_uri_complete,qr_uri,expires_in,interval}`. The QR URI must be same-origin HTTPS or a relative `/api/` URL; the complete activation link must be HTTPS.
- `POST /api/device/token {device_code}` and `/api/device/refresh {refresh_token}`: `{access_token,refresh_token,expires_in}`.
- Closed error codes: `authorization_pending`, `slow_down`, `expired_token`, `access_denied`, `invalid_grant`, `revoked`, `device_revoked`, `invalid_token`.

All account credentials are printable bounded strings and are sent only as Authorization bearers. They are never query parameters, QR contents, labels, logs, artwork URLs, or cache keys. Registry storage is not encrypted; clearing channel data requires pairing again.

## Avatar policy

The client accepts only HTTPS DiceBear 10.x PNG URLs using the server allowlist: `critters`, `pixel-art`, `pixel-art-neutral`, `moods`, `thumbs`, `lorelei`, and `notionists`. These choices are listed by DiceBear as CC0. The server generates opaque seeds; household/profile names are not sent to DiceBear. `ProfileCard` keeps a generated SceneGraph initials tile visible until the remote image reaches `ready`, and falls back to it on failure. The native catalog also contains packaged character artwork; only one bounded page is rendered at a time.

## Versioned storage

Version 3 stores only: origin, paired access/refresh credentials, credential expiry, account ID, last profile ID, and the origin-binding marker. Loading a v2 document imports `token` as a **paired device access credential only** when the document also contains a rotating refresh token and matching auth origin. Unversioned/static token fields are ignored, split token/profile/server registry fields are deleted on the first save, and packages containing a token key are rejected.

## MainScene integration hooks

The account integration is complete:

1. Runtime configuration and queue entries use `access_token` and `last_profile_id`. Coalescing, cleanup connection snapshots, source-route snapshots, and stale-response protection are scoped by the canonical access credential plus account epoch; no profile is selected until the server validates the remembered ID.
2. `pairQr` remains visible beside the manual code until token success, cancellation, or expiry.
3. `profileGrid` provides explicit profile selection and creation; a single profile is never auto-selected unless its remembered ID belongs to the authenticated account.
4. Profile-name keyboard completion and avatar selection use the account endpoints and canonical `setup_complete` response field.
5. Settings has no origin or credential editor. It provides account/profile controls and truthful player/source help rather than nonfunctional persisted playback-default toggles.
6. Home/cache keys retain origin + account ID + selected runtime profile without credentials.

## Tests

Focused test inputs:

- `account-policy.brs`, `locked-config.brs`, `schema.brs`: `Util.brs`, `AccountPolicy.brs`, `ApiTask.brs`, then the test.
- `account-flow.brs`: `Util.brs`, `AccountPolicy.brs`, `AccountScene.brs`, then the test.
- `request-propagation.brs`: run `Util.brs`, `AccountPolicy.brs`, `AccountScene.brs`, `MainScene.brs`, and the test; it executes the real queue builder, blank-bearer refresh request, and queued credential rotation.
- `transport.brs`: run the trusted loopback `mock_api.py`, then `Util.brs`, `AccountPolicy.brs`, `ApiTask.brs`, and the test; it proves `ApiTask` consumes that canonical field as the bearer credential.
- `branding_contract.py`: verifies declared Roku artwork and that `ProfileCard` has no packaged avatar dependency.

These tests establish closed serialization, MainScene-to-ApiTask access-field propagation, origin-only migration, QR/profile state behavior, and remote-avatar fallback. They do not establish backend account isolation, a real browser confirmation, DiceBear uptime, or physical Roku behavior; those require end-to-end and device validation before release.

- `profile_management_runtime.py`: real native create/edit/delete, protected primary, mutation PIN retry/cancel, and selected deletion without device sign-out.
