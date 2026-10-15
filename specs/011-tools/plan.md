# 011-tools — technical context

- Entry: `bin/tools.sh`: the core set from native packages
  (`_install_packages`, logical names), then the opt-in extras.
- Extras (`DOT_TOOLS_EXTRA` / bootstrap `--extras`): `httpie`, `chafa`
  (native packages) and `gh` (the distro package; on Debian/Ubuntu the
  official GitHub CLI apt repository, signed keyring, download-then-install).
- `bat`/`batcat` and `fd`/`fdfind`: whichever spelling the distro installs,
  the missing one is linked in `~/.local/bin`.
- No upstream release downloads: lazygit, lazydocker, k9s and resterm were
  dropped on 2026-10-15.
