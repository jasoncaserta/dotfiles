#!/bin/bash
RESURRECT_DIR="$HOME/.tmux/resurrect"

# shellcheck source=_tmux-save-common.sh
source "$(dirname "$0")/_tmux-save-common.sh"

# Use the mtime of the list file as the age — it's updated after every save run,
# even when resurrect deduplicates and deletes the new file.
auto_age="$(   _file_age_str "$RESURRECT_DIR/last-auto-list"   )"
manual_age="$( _file_age_str "$RESURRECT_DIR/last-manual-list" )"

printf 'auto: %s  manual: %s' "$auto_age" "$manual_age"
