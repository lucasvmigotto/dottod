# 003 — vim (vim-plug)

## Stories
- US1: As a user I run `./bin/bootstrap.sh --only vim` so that vim +
  vim-plug install, `~/.vimrc` links to the repo, and plugins install.

## Acceptance scenarios
- Given vim-plug absent, when the task runs, then `plug.vim` downloads
  (with retries) to `~/.vim/autoload/` [OBSERVED: bin/vim.sh].
- Given `~/.vimrc` exists, when the task runs, then it is backed up
  (`_link_file`) and replaced by the symlink
  [OBSERVED: bin/vim.sh, bin/utils.sh].
- Given all `Plug` entries present under `~/.vim/plugged`, when the task
  runs, then `PlugInstall` is skipped; missing entries trigger one
  headless install whose errors warn but don't fail the task
  [OBSERVED: bin/vim.sh, tests/test-vim.bats].

## Status
Implemented. Verified: no.
