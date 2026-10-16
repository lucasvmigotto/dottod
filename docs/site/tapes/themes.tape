# docs/site/tapes/themes.tape
#
# The segmented prompt themes (spec 018): pastel, tokyonight, gruvbox and
# catppuccin in a small Node project with a running compose container —
# folded segments outside it, the toolchain version filled in by the
# background refresh, a slow command's duration, a red prompt after a
# failure. node and podman are stubs (a fixed version, one container
# labelled with the project), so the recording is the same everywhere.
# Render: vhs docs/site/tapes/themes.tape (repo root).
# Requires: vhs, ttyd, ffmpeg, git, and FiraCode Nerd Font
# (./bin/fonts.sh FiraCode).

Output docs/site/public/demos/themes.gif
Set Shell "bash"
Set FontFamily "FiraCode Nerd Font Mono"
Set FontSize 14
Set Width 1000
Set Height 520
Set Padding 12
Set Theme "Catppuccin Mocha"
Set TypingSpeed 35ms

Hide
Type `D=/tmp/dottod-themes; rm -rf $D; mkdir -p $D/stubs $D/shop/src $D/cache && printf '#!/bin/sh\necho v22.11.0\n' >$D/stubs/node && printf '#!/bin/sh\necho "%s"\n' "$D/shop|" >$D/stubs/podman && chmod +x $D/stubs/* && git -C $D/shop init -q -b main && touch $D/shop/package.json`
Enter
Type "export PATH=$D/stubs:$PATH XDG_CACHE_HOME=$D/cache DOT_NO_UPDATE_CHECK=1 DOT_PROMPT_VERSIONS=1 DOT_PROMPT_STYLE=pastel; R=$PWD; cd $D; source $R/config/.custom.bashrc; cd shop; true"
Enter
Sleep 1500ms
Type "cd ..; clear"
Enter
Sleep 400ms
Show

Type "cd shop && sleep 3"
Enter
Sleep 4s
Type "export DOT_PROMPT_STYLE=tokyonight; source $R/config/.custom.bashrc"
Enter
Sleep 1s
Type "false"
Enter
Sleep 1500ms
Type "export DOT_PROMPT_STYLE=gruvbox; source $R/config/.custom.bashrc; cd .."
Enter
Sleep 1500ms
Type "cd shop/src"
Enter
Sleep 1500ms
Type "export DOT_PROMPT_STYLE=catppuccin; source $R/config/.custom.bashrc"
Enter
Sleep 3s
