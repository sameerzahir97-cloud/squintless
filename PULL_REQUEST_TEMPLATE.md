<!-- Thanks for contributing to Squintless! -->

## What changed and why

<!-- A sentence or two. Link the issue if there is one. -->

## Checklist

- [ ] If I changed colors, I edited `palettes/*.json` and regenerated with
      `python tools/gen.py` (I did **not** hand-edit anything in `config/generated/`).
- [ ] `python tools/validate.py` passes.
- [ ] `python tools/gen.py --check` passes (no stale generated files).
- [ ] If this ships a new version, I bumped `VERSION` and the five version strings
      (`install.ps1`, `install.sh`, `module/Squintless/Squintless.psd1`,
      `claude-plugin/.claude-plugin/plugin.json`).
- [ ] I tested the installer on the OS I touched (Windows `install.ps1` /
      macOS·Linux `install.sh`), if applicable.
