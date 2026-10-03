# 002 — fonts (Nerd Fonts)

## Stories
- US1: As a user I run `./bin/bootstrap.sh --only fonts` (optionally with
  font names) so that Nerd Fonts land in `~/.local/share/fonts` (or
  system-wide with the global flag).

## Acceptance scenarios
- Given no fonts installed, when the task runs with defaults, then
  FiraCode, FiraMono, RobotoMono, NerdFontsSymbolsOnly, ZedMono install
  from the pinned `_DOT_NERDFONT_VERSION`
  [OBSERVED: bin/fonts.sh:60, README.md:25].
- Given a font present (`fc-list`), when the task runs, then it skips
  [OBSERVED: bin/fonts.sh:20].
- Given an unavailable font URL, when checked, then warn, no crash
  [OBSERVED: bin/fonts.sh:25].

## Status
Implemented. Verified: no.
