#!/bin/bash
set -euo pipefail

restore_file="$HOME/.tmux/resurrect/last"
plugin_restore="$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh"

if [[ -f "$restore_file" ]]; then
  tmp_file="$(mktemp)"
  awk -F '\t' '$1 != "state" { print }' "$restore_file" > "$tmp_file"
  cat "$tmp_file" > "$restore_file"
  rm -f "$tmp_file"
fi

exec "$plugin_restore" "$@"
