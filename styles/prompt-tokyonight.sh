#!/usr/bin/env bash
#
# prompt-tokyonight.sh — Tokyo Night (after the starship preset): a ░▒▓ fade into a lavender
# OS block, then blue and night-blue blocks with rounded joins.
# Drawn by segments.sh (spec 018); folded segments keep their color.

# shellcheck disable=SC1090 # sibling file by design
source "$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)/segments.sh"

__DOTTOD_THEME_SEGS='os:146:16 dir:111:254 git:60:111 stack:236:111 containers:235:111 time:234:146'
__DOTTOD_THEME_HEAD='fade'
__DOTTOD_THEME_SEP='round'
__DOTTOD_THEME_TAIL='round'
__dottod_seg_register
