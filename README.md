# VIPTV for Roku

The 2.0 client is a native, server-connected SceneGraph renderer of the current
KMP TV presentation. `RemoteScene` is the shipping entry point. Only the current implementation is retained: retired scenes, provider parsers,
ranking policies, continuation policies and API adapters have been removed.
There is no local engine, local library, torrent runtime or offline mode.

The server supplies Home rows and card shapes, catalog order, discovery controls,
saved-title state, profile permissions, preference controls, playback targets,
resume intent, source ranking and the named best match. Roku handles focus,
rendering, bounded view windows, input, credential storage and native Video.

Read [the implementation/qualification record](docs/REMOTE_STATUS.md),
[backend handoff](docs/BACKEND_HANDOFF.md), and [pinned design adoption](design-contract/ROKU_KMP_REMOTE.md).
The producer contract includes additions being implemented by the web-TV agent;
this package is a candidate, not a claim that the live backend supports them.

## Reference and backend

`docs/KMP_REFERENCE.json` records the selected KMP commit and 512 working-tree
source/resource hashes. Its source archive and private renderer captures stay
under ignored `artifacts/`. `DESIGN_REF` and `DESIGN_ASSETS.json` pin imported
fonts, masks, icons, gradients and the remote-adoption contract.

`docs/BACKEND_CONTRACT_REF.json` records the observed producer source hashes.
`/api/bootstrap` must report contract version 3. The remote presentation additions
include `HomeRow.view.card_shape`, `Card.view.saved`, preference `controls`,
source-ranking `best_match_id`/`quality_filters`, and profile `viewing-action` and
`addon-activation` endpoints. An old server gets an update/retry state; it does
not activate legacy client policy.

The normal package keeps the existing origin lock. The public package supports
another HTTPS origin and clears the previous origin's grant. Both use only the current version 3 registry format for rotating device credentials and remembered profile
IDs. Transient failures retain credentials; profile selection remains server-validated.

## Local verification

```sh
python3 scripts/design-sync.py check
python3 scripts/run-tests.py
(cd roku && npx --yes brighterscript@0.73.1 --project bsconfig.json)
```

The runner uses `VIPTV_BRS_CLI`, `brs-cli` on PATH, or pinned `brs-node@2.5.3`.
The new remote checks execute production SceneGraph handlers and Task HTTP over
disposable HTTPS. These checks do not establish device performance or visual parity.

Private, networkless renderer fixtures:

```sh
python3 scripts/remote-preview.py artifacts/new-home home
node scripts/render-remote.mjs artifacts/new-home artifacts/new-home.png
```

The simulator may render its FHD design canvas even with a 720p device setting.
A requested 720p export is then explicitly marked as a scaled preview in its
sidecar JSON. It is not a physical 720p renderer measurement.

## Runtime artifacts

Use new staging/output paths for every build:

```sh
(cd roku && npx --yes brighterscript@0.73.1 --project bsconfig.json --copy-to-staging --staging-folder-path ../artifacts/new-staging --retain-staging-folder)
python3 scripts/package.py --input artifacts/new-staging --output-dir artifacts/new-build
python3 scripts/package.py --input artifacts/new-staging --public --output-dir artifacts/new-build
```

Packages include compiler BSLib, fonts and licenses. Preview inputs and account
credentials are excluded. Actions builds on main pushes/manual dispatch remain
unchanged; there is no automatic deployment, Store submission or device install.

## License

Copyright (C) 2026 viptv contributors. GPL version 2; see [LICENSE](LICENSE).
Preserve corresponding source and the bundled third-party notices when distributing.
