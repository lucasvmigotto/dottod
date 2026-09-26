# 008-ghostty — as-is technical context

- Entry: `bin/ghostty.sh` (presence probe → `_DOT_GHOSTTY_INSTALLER_URL`
  piped to privileged bash → `update-alternatives` + gsettings default)
  [OBSERVED: bin/ghostty.sh:22].
- External trust: `https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh`
  executed as root — supply-chain risk, see introspec.md
  [OBSERVED: bin/ghostty.sh:22].
- Env: `_DOT_GHOSTTY_INSTALLER_URL` [OBSERVED: bin/ghostty.sh:22].
- No dedicated test suite (shellcheck/bash -n only).
