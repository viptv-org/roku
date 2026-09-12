# viptv roku

Extracted from `vynxc/viptv@7d6b413`. `MIGRATION.json` records every original file and SHA-256; the original repository retains history. This repository owns the unchanged native Roku client.

The [design repository](https://github.com/viptv-org/design) is the product source of truth. Read [SPEC.md](SPEC.md), [AGENTS.md](AGENTS.md), and the pinned `DESIGN_REF` before implementation. Future platform work must inherit its interaction contracts.

## Build artifact

The installable ZIP is a runtime package, created from a BrighterScript 0.73.1 staging tree so it contains generated `source/bslib.brs`. CI runs that staging step, then invokes `python3 scripts/package.py --input <staging-directory>`; the script deliberately rejects raw source as input. Keep the source repository and its notices available separately when distributing GPL-covered source.
