# docs/site/tapes/status-commands.tape
#
# Read-only probes: container selection report and the cargo status report.
# Output varies by machine (versions) — the tape asserts renderability, not
# bytes. Render: vhs docs/site/tapes/status-commands.tape (repo root).
# Requires: vhs, ttyd, ffmpeg.

Output docs/site/public/demos/status-commands.gif
Set Shell "bash"
Set FontSize 14
Set Width 1000
Set Height 640
Set Padding 12
Set Theme "Catppuccin Mocha"

Type "./bin/container.sh status"
Enter
Sleep 2s
Type "./bin/cargo.sh status"
Enter
Sleep 2s
