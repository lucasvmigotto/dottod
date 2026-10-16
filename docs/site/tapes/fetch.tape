# docs/site/tapes/fetch.tape
#
# What dottod sees on each distribution it supports: the fetch card
# (scripts/dottod-fetch.sh, fed the os-release test fixtures) across
# Gentoo, Arch, Debian, Fedora and Alpine, with the prompt style switched
# live (DOT_PROMPT_STYLE), then a few real bootstrap commands.
# Render: vhs docs/site/tapes/fetch.tape (repo root).
# Requires: vhs, ttyd, ffmpeg, and FiraCode Nerd Font (./bin/fonts.sh FiraCode)
# for the powerline glyphs.

Output docs/site/public/demos/fetch.gif
Set Shell "bash"
Set FontFamily "FiraCode Nerd Font Mono"
Set FontSize 14
Set Width 1000
Set Height 560
Set Padding 12
Set Theme "Catppuccin Mocha"
Set TypingSpeed 35ms

Hide
Type "export DOT_FORCE_COLOR=1 DOT_NO_UPDATE_CHECK=1 DOT_PROMPT_STYLE=powerline; source config/.custom.bashrc; clear"
Enter
Sleep 400ms
Show

Type "./scripts/dottod-fetch.sh --os-release tests/fixtures/os-release/gentoo"
Enter
Sleep 3s
Hide
Type "clear"
Enter
Sleep 400ms
Show

Type "./scripts/dottod-fetch.sh --os-release tests/fixtures/os-release/arch"
Enter
Sleep 3s
Hide
Type "export DOT_PROMPT_STYLE=kali; source config/.custom.bashrc; clear"
Enter
Sleep 400ms
Show

Type "./scripts/dottod-fetch.sh --os-release tests/fixtures/os-release/debian"
Enter
Sleep 3s
Hide
Type "clear"
Enter
Sleep 400ms
Show

Type "./scripts/dottod-fetch.sh --os-release tests/fixtures/os-release/fedora"
Enter
Sleep 3s
Hide
Type "export DOT_PROMPT_STYLE=robbyrussell; source config/.custom.bashrc; clear"
Enter
Sleep 400ms
Show

Type "./scripts/dottod-fetch.sh --os-release tests/fixtures/os-release/alpine"
Enter
Sleep 3s
Hide
Type "clear"
Enter
Sleep 400ms
Show

Type "./bin/bootstrap.sh --list"
Enter
Sleep 2s
Type "./bin/bootstrap.sh --only tools --extras gh,httpie --status"
Enter
Sleep 3s
