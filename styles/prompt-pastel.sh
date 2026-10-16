#!/usr/bin/env bash
#
# prompt-pastel.sh — Pastel Powerline (after the starship preset): magenta, pink, peach,
# sky and blue blocks joined by arrows, opened by a rounded cap.
# Drawn by segments.sh (spec 018); folded segments keep their color.

# shellcheck disable=SC1090 # sibling file by design
source "$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)/segments.sh"

__DOTTOD_THEME_SEGS='osuser:133:15 dir:168:15 git:216:16 stack:110:16 containers:30:15 time:25:15'
__DOTTOD_THEME_HEAD='cap'
__DOTTOD_THEME_SEP='arrow'
__DOTTOD_THEME_TAIL='arrow'
__dottod_seg_register
