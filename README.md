# viptv roku

Extracted from `vynxc/viptv@7d6b413`. `MIGRATION.json` records every original file and SHA-256; the original repository retains history. This repository owns the native Roku client.

The [design repository](https://github.com/viptv-org/design) is the product source of truth. The native client adopts the current TV design under [ROK-042](design-contract/ROKU_DESIGN.md): bundled Onest/Bricolage fonts, Lucide controls, landscape Home/detail artwork, stable focus rings, the expanding rail and right-side panels. The 1920×1080 references map proportionally to Roku's 1280×720 logical canvas. Read [SPEC.md](SPEC.md), [AGENTS.md](AGENTS.md), and `DESIGN_REF` before implementation.

`python3 scripts/design-sync.py check` verifies the pinned native assets, fonts,
tokens and contract. To deliberately adopt a revision:
`python3 scripts/design-sync.py sync ../design <full-commit>`.
Fonts and their licenses are included in the compiled runtime package.

## Build artifact

The installable ZIP is a runtime package, created from a BrighterScript 0.73.1 staging tree so it contains generated `source/bslib.brs`. CI runs that staging step, then invokes `python3 scripts/package.py --input <staging-directory>`; the script deliberately rejects raw source as input. Keep the source repository and its notices available separately when distributing GPL-covered source.

## License

Copyright (C) 2026 viptv contributors.

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; version 2 of the License. See [LICENSE](LICENSE). Keep this source repository available alongside any distributed runtime package, as the package alone is not the corresponding source.
