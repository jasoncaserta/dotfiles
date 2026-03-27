#!/bin/bash
set -euo pipefail

restore_file="$HOME/.tmux/resurrect/last"
restore_dir="$HOME/.tmux/resurrect"
plugin_restore="$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
tmp_restore_dir=''
original_resurrect_dir=''

if [[ -z "${TMUX:-}" ]]; then
  socket_path="$(tmux display-message -p -F "#{socket_path}" 2>/dev/null || printf '')"
  if [[ -n "$socket_path" ]]; then
    export TMUX="${socket_path},0,0"
  fi
fi

cleanup() {
  local status=$?

  if [[ -n "$original_resurrect_dir" ]]; then
    tmux set-option -gq @resurrect-dir "$original_resurrect_dir" >/dev/null 2>&1 || true
  else
    tmux set-option -guq @resurrect-dir >/dev/null 2>&1 || true
  fi

  if [[ -n "$tmp_restore_dir" && -d "$tmp_restore_dir" ]]; then
    rm -rf "$tmp_restore_dir"
  fi

  exit "$status"
}
trap cleanup EXIT

if [[ -f "$restore_file" ]]; then
  tmp_restore_dir="$(mktemp -d)"
  tmp_file="$tmp_restore_dir/last"
  awk '
    BEGIN { FS = "\t"; OFS = "\t" }
    /^(pane|window|grouped_session)\t/ { print; next }
    /^state\t/ {
      if ($2 != "" && $2 != ":" && $3 != "" && $3 != ":") {
        print
      }
      next
    }
    { print }
  ' "$restore_file" > "$tmp_file"

  if [[ -f "$restore_dir/pane_contents.tar.gz" ]]; then
    ln -sf "$restore_dir/pane_contents.tar.gz" "$tmp_restore_dir/pane_contents.tar.gz"
  fi

  original_resurrect_dir="$(tmux show-option -gqv @resurrect-dir 2>/dev/null || printf '')"
  tmux set-option -gq @resurrect-dir "$tmp_restore_dir"
fi

"$plugin_restore" "$@"
