#!/bin/bash
RESURRECT_DIR="$HOME/.tmux/resurrect"

# shellcheck source=_tmux-save-common.sh
source "$(dirname "$0")/_tmux-save-common.sh"

auto_file="$(   head -1 "$RESURRECT_DIR/last-auto-list"   2>/dev/null || true )"
manual_file="$( head -1 "$RESURRECT_DIR/last-manual-list" 2>/dev/null || true )"

auto_age="$(   [[ -n "$auto_file"   ]] && _file_age_str "$RESURRECT_DIR/$auto_file"   || printf 'never' )"
manual_age="$( [[ -n "$manual_file" ]] && _file_age_str "$RESURRECT_DIR/$manual_file" || printf 'never' )"

printf 'auto: %s  manual: %s' "$auto_age" "$manual_age"
