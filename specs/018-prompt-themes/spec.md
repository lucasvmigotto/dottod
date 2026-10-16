# 018 — segmented prompt themes, stack and container segments

Decided 2026-10-16. Bash-native: no starship binary, no framework — the
"plain bash" rule of `styles/` holds.

## Why
The powerline style is one fixed look. Starship's presets (Pastel
Powerline, Tokyo Night, Gruvbox Rainbow, Catppuccin Powerline) show what
users expect from a segmented prompt: a palette, a separator shape, and
segments that fold to a single colored separator when they have nothing
to say. Building one renderer and expressing each look as data gives the
four themes for the cost of one, and the new stack and container segments
reach every theme at once.

## Stories
- US1: As a user I set `DOT_PROMPT_STYLE` to `pastel`, `tokyonight`,
  `gruvbox` or `catppuccin` and get that look, with the same reload
  behavior as today's styles (switching replaces, never stacks).
- US2: As a user, a segment with no information (not in a git repo, no
  stack detected, no containers) folds: its text disappears but its color
  stays as one separator, so the prompt keeps the same color rhythm.
- US3: As a user, inside a project I see its stack glyph (node, bun, deno,
  rust, go, python, ruby, php, java, dotnet), every stack found at the
  nearest directory with a marker. `DOT_PROMPT_VERSIONS=1` adds each
  toolchain's version.
- US4: As a user, when containers belonging to this project are running,
  I see a container glyph and their count. A container belongs when its
  compose working-dir label (`com.docker.compose.project.working_dir`) or
  devcontainer label (`devcontainer.local_folder`) is the current
  directory or one of its parents — never a directory below it. `DOT_PROMPT_CONTAINERS=0` turns the segment off.
- US5: As a user, themes that start with an OS glyph show the real
  distribution's (Debian, Gentoo, Arch, Fedora, Alpine, else Linux) from
  dottod's own detection.

## Rules
- The prompt never waits on a slow command. Versions and the container
  list come from a cache under `${XDG_CACHE_HOME:-~/.cache}/dottod/prompt`;
  a stale entry is refreshed by a detached background job (no job-control
  noise, at most one refresh per key at a time) and the prompt shows the
  last known value — or nothing, folded, on the very first prompt.
  - versions: keyed by stack + project root + `PATH`, 10 minutes;
  - containers: one `podman ps` for all projects, 10 seconds; skipped when
    podman isn't installed.
- One renderer (`styles/segments.sh`) draws every theme. A theme file
  (`styles/prompt-<name>.sh`) only declares: palette per segment, segment
  order, separator (arrow or rounded), optional leading/trailing caps.
- Segments: os, user, dir, git, stack, containers, time; each theme picks
  its order and colors. Last line: `❯` green on success, red on failure,
  with the duration when the command took at least `DOT_PROMPT_SLOW`
  seconds (default 2).
- `DOT_PROMPT_GLYPHS=ascii` works for every theme (no Nerd Font).
- 256-color palettes approximating each preset (no truecolor dependency).
- No new dependency at runtime; podman only for the optional segment.

## Acceptance
- Each theme renders in a git repo with a stack, outside any repo, and in
  a directory with a running compose/devcontainer container (stubbed
  `podman` in tests).
- A folded segment emits exactly one separator in its own color and no
  text.
- First prompt in a new project: no version, no container segment, and
  no wait; after the background refresh, the next prompt shows them.
- A failing `podman`, a missing toolchain or an unwritable cache never
  breaks the prompt or prints anything.
- A demo (docs/site/tapes/themes.tape) shows the four themes.

## Out of scope
- Truecolor palettes, conda/mamba environments, right-side prompts for
  the new themes (the powerline style keeps its own).

## Status
Implemented on `feat/prompt-themes` (2026-10-16).

- `styles/segments.sh` renders every theme from its declared data;
  `styles/prompt-{pastel,tokyonight,gruvbox,catppuccin}.sh` hold only that.
- Duration: PS0 stamps each command's start (`${const:$((t0 = SECONDS)):0}`
  — bash skips the offset of an unset variable, hence the constant).
- Glyph codepoints checked against Nerd Fonts v3.4.0 `glyphnames.json`
  (the version `bin/fonts.sh` installs).
- Bash before 4.2 (no `\u` in printf) falls back to ASCII glyphs; the
  renderer runs on bash 3.2 (checked in `bash:3.2`), without durations.

Deviations: the fetch demo keeps the older styles; the themes got their
own demo. Containers count when their label folder holds the current
directory (not when it is below it): the first recording showed every
compose project under `/tmp` claimed by `/tmp`.

Evidence: `tests/test-prompt-themes.bats` (13 tests: rendering, exact
folded bytes, ASCII folding, stacks, versions and containers through the
background cache with stubs, silence on failures and an unwritable cache,
PS0 duration, red prompt, hook switching, names never executed, OS glyph);
the recorded demo.

### 2.5.0 addition: `prompt-style --preview [name...]`
Renders every style (or the named ones) as it would look in the current
directory: each in a subshell — its hook runs once, `${PS1@P}` is printed
without readline markers — so nothing of the shell or `~/.prompt-style`
changes. Needs bash 4.4; refuses `--dry-run`. Tested in
`test-prompt.bats`.
