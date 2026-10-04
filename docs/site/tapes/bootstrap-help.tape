# docs/site/tapes/bootstrap-help.tape
#
# The bootstrap CLI surface: --help then --list. Read-only, deterministic.
# Render: vhs docs/site/tapes/bootstrap-help.tape   (from the repo root)
# Requires: vhs, ttyd, ffmpeg.

Output docs/site/public/demos/bootstrap-help.gif
Set Shell "bash"
Set FontSize 14
Set Width 1000
Set Height 640
Set Padding 12
Set Theme "Catppuccin Mocha"

Type "./bin/bootstrap.sh --help"
Enter
Sleep 2s
Type "./bin/bootstrap.sh --list"
Enter
Sleep 2s
