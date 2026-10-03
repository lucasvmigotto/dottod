# 003 — vim (vim-plug)

## Stories
- US1: As a user I run `./bin/bootstrap.sh --only vim` so that vim +
  vim-plug install, `~/.vimrc` links to the repo, and plugins install.

## Acceptance scenarios
- Given vim-plug absent, when the task runs, then `plug.vim` downloads to
  `~/.vim/autoload/` [OBSERVED: bin/vim.sh:7].
- Given `~/.vimrc` exists, when the task runs, then it is backed up
  (`_link_file`) and replaced by the symlink
  [OBSERVED: bin/vim.sh:35, bin/utils.sh:277].
- Given the linked vimrc, when `PlugInstall` runs headless, then errors
  warn but don't fail the task [OBSERVED: bin/vim.sh:37].

## Status
Implemented. Verified: no.
