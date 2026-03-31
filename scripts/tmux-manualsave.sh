#!/bin/bash
set -euo pipefail

SAVE_SCRIPT="$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
RESURRECT_DIR="$HOME/.tmux/resurrect"
LAST="$RESURRECT_DIR/last"

# shellcheck source=_tmux-save-common.sh
source "$(dirname "$0")/_tmux-save-common.sh"

[[ -x "$SAVE_SCRIPT" ]] || exit 0

_run_save "$SAVE_SCRIPT"

tmux set -g @save-flash "✓ manual tmux snapshot saved" 2>/dev/null || true
( sleep 5; tmux set -g @save-flash "" 2>/dev/null ) & disown

new_file="$(readlink "$LAST" 2>/dev/null || printf '')"
if [[ -n "$new_file" && -s "$RESURRECT_DIR/$new_file" ]]; then
  _update_save_list "$new_file" "$RESURRECT_DIR/last-manual-list"
fi
