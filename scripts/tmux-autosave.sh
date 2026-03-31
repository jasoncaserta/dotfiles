#!/bin/bash
set -euo pipefail

COOLDOWN="${1:-300}"
quiet=0
for _arg in "$@"; do [[ "$_arg" == "--quiet" ]] && quiet=1; done
SAVE_SCRIPT="$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
RESURRECT_DIR="$HOME/.tmux/resurrect"
LAST="$RESURRECT_DIR/last"

# shellcheck source=_tmux-save-common.sh
source "$(dirname "$0")/_tmux-save-common.sh"

[[ -x "$SAVE_SCRIPT" ]] || exit 0

if [[ "$COOLDOWN" -gt 0 && -e "$LAST" ]]; then
  elapsed=$(( $(date +%s) - $(stat -f %m "$LAST" 2>/dev/null || printf '0') ))
  [[ "$elapsed" -lt "$COOLDOWN" ]] && exit 0
fi

_run_save "$SAVE_SCRIPT"

if (( ! quiet )); then
  tmux set -g @save-flash "✓ automatic tmux snapshot saved" 2>/dev/null || true
  ( sleep 5; tmux set -g @save-flash "" 2>/dev/null ) & disown
fi

new_file="$(readlink "$LAST" 2>/dev/null || printf '')"
if [[ -n "$new_file" && -s "$RESURRECT_DIR/$new_file" ]]; then
  _update_save_list "$new_file" "$RESURRECT_DIR/last-auto-list"
fi
