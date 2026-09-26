# 011-tools — as-is technical context

- Entry: `bin/tools.sh` (apt CLI set → 4 GitHub installs: 2 tarballs,
  1 binary, 1 tarball) [OBSERVED: bin/tools.sh:70,83].
- Helpers `_github_binary_install` / `_github_tarball_install` resolve
  latest-release assets via the GitHub API (`_github_asset_url`), retry
  downloads (`curl --retry 3`), `install -m 0755` into `~/.local/bin`
  [OBSERVED: bin/tools.sh:7, bin/utils.sh:251].
- Arch mapping via `_go_arch`/`_rust_arch` (`x86_64`/`arm64`)
  [OBSERVED: bin/utils.sh:310, bin/tools.sh:71].
- bat→batcat alias when only `bat` exists
  [OBSERVED: bin/tools.sh:78].
- No dedicated test suite (shellcheck/bash -n only).
