# 002-fonts — as-is technical context

- Entry: `bin/fonts.sh` (args override the default font list)
  [OBSERVED: bin/fonts.sh:66].
- Downloads `https://github.com/ryanoasis/nerd-fonts/releases/download/<ver>/<font>.zip`,
  unzips `*.[ot]tf`, `fc-cache -f` [OBSERVED: bin/fonts.sh:32,51].
- Env: `_DOT_NERDFONT_VERSION` (default v3.4.0), `_DOT_NERDFONT_BASE`,
  `_DOT_NERDFONT_GLOBAL_INSTALL`, `_DOT_NERDFONT_DIE_IF_FAIL_ONCE`,
  `_DOT_NERDFONT_TEMP_DESTINATION` [OBSERVED: bin/fonts.sh:60].
- No dedicated test suite (covered only by shellcheck/bash -n in CI)
  [OBSERVED: tests/run.sh glob; no test-fonts file].
