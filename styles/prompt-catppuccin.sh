#!/usr/bin/env bash
#
# prompt-catppuccin.sh — Catppuccin Powerline, Mocha (after the starship preset): red, peach,
# yellow, green, sapphire and lavender blocks between rounded caps.
# Drawn by segments.sh (spec 018); folded segments keep their color.

# shellcheck disable=SC1090 # sibling file by design
source "$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)/segments.sh"

__DOTTOD_THEME_SEGS='osuser:211:233 dir:216:233 git:223:233 stack:151:233 containers:117:233 time:147:233'
__DOTTOD_THEME_HEAD='cap'
__DOTTOD_THEME_SEP='arrow'
__DOTTOD_THEME_TAIL='round'
__dottod_seg_register
