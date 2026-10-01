# viptv roku

GitHub Actions builds the compiled runtime ZIP on pushes to `main` and on manual
dispatch ([build.yml](.github/workflows/build.yml)). Each run uploads a 30-day
`roku-<commit>` artifact containing the ZIP, `SHA256SUMS` and `build.json`
(revision and design pin). There are no pull-request gates, automatic releases,
tags or deployments; run the local checks below before pushing.

Extracted from `vynxc/viptv@7d6b413`. `MIGRATION.json` records every original file and SHA-256; the original repository retains history. This repository owns the native Roku client.

The [design repository](https://github.com/viptv-org/design) is the product source of truth. The native client adopts the current TV design under [ROK-044](design-contract/ROKU_DESIGN.md): bundled Onest/Bricolage fonts, Lucide controls, landscape Home/detail artwork, stable focus rings, the expanding rail and right-side panels. The 1920×1080 references map proportionally to Roku's 1280×720 logical canvas. Read [SPEC.md](SPEC.md), [AGENTS.md](AGENTS.md), and `DESIGN_REF` before implementation.

`python3 scripts/design-sync.py check` verifies the pinned native assets, fonts,
tokens and contract. To deliberately adopt a revision:
`python3 scripts/design-sync.py sync ../design <full-commit>`.
Fonts and their licenses are included in the compiled runtime package.

See [TV_AUDIT.md](TV_AUDIT.md) for the complete TV reference inventory, precedence, fixes and evidence limits.

## Local checks

From the repository root:

```sh
python3 scripts/design-sync.py check   # pinned design assets, fonts, tokens and contract
python3 scripts/verify-migration.py    # extraction inventory and recorded re-pins
python3 scripts/run-tests.py           # static contracts, runtime harnesses, BrightScript tests
(cd roku && npx --yes brighterscript@0.73.1 --project bsconfig.json)
```

`run-tests.py` needs Python 3 and a BrightScript interpreter: `VIPTV_BRS_CLI`
(a `brs-cli` executable), otherwise `brs-cli` on `PATH`, otherwise `npx` fetches
the pinned `brs-node@2.5.3`. Use `--group static|runtime|brs` and `-k <name>` to
select checks. These are interpreter and compile fixtures, not physical Roku
validation.

## Build artifact

The installable ZIP is a runtime package, created from a BrighterScript 0.73.1 staging tree so it contains generated `source/bslib.brs`. The build workflow, and a local build, run:

```sh
(cd roku && npx --yes brighterscript@0.73.1 --project bsconfig.json --copy-to-staging --staging-folder-path <staging> --retain-staging-folder)
python3 scripts/package.py --input <staging> [--public] [--output-dir <new-directory>]
```

`package.py` deliberately rejects raw source as input, refuses to overwrite an existing archive and appends to `SHA256SUMS`. Keep the source repository and its notices available separately when distributing GPL-covered source.

## License

Copyright (C) 2026 viptv contributors.

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; version 2 of the License. See [LICENSE](LICENSE). Keep this source repository available alongside any distributed runtime package, as the package alone is not the corresponding source.
