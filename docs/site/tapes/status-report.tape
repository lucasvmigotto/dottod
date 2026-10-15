# docs/site/tapes/status-report.tape
#
# The uniform status surface: bootstrap.sh --status prints every selected
# task's read-only report. Output varies by machine (versions, what is
# installed) — the tape asserts renderability, not bytes.
# Render: vhs docs/site/tapes/status-report.tape (repo root).
# Requires: vhs, ttyd, ffmpeg.

Output docs/site/public/demos/status-report.gif
Set Shell "bash"
Set FontSize 14
Set Width 1000
Set Height 470
Set Padding 12
Set Theme "Catppuccin Mocha"

Type "./bin/bootstrap.sh --status --only shell,vim,tools"
Enter
Sleep 3s
