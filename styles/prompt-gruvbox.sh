#!/usr/bin/env bash
#
# prompt-gruvbox.sh — Gruvbox Rainbow (after the starship preset): orange, yellow, aqua,
# blue and grey blocks joined by arrows, between rounded caps.
# Drawn by segments.sh (spec 018); folded segments keep their color.

# shellcheck disable=SC1090 # sibling file by design
source "$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)/segments.sh"

__DOTTOD_THEME_SEGS='osuser:166:230 dir:172:230 git:72:230 stack:66:230 containers:241:109 time:237:230'
__DOTTOD_THEME_HEAD='cap'
__DOTTOD_THEME_SEP='arrow'
__DOTTOD_THEME_TAIL='round'
__dottod_seg_register
