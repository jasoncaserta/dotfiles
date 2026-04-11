#!/bin/bash
set -euo pipefail

restore_file="${1:-$HOME/.tmux/resurrect/last}"
restore_dir="$HOME/.tmux/resurrect"
plugin_restore="$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
tmp_restore_dir=''
original_resurrect_dir=''
bootstrapped_session=''

# shellcheck source=_tmux-save-common.sh
source "$(dirname "$0")/_tmux-save-common.sh"

if [[ -z "${TMUX:-}" ]]; then
  # Build a valid TMUX env using any available session so tmux set-option works.
  _any_sess="$(tmux list-sessions -F '#{session_name}' 2>/dev/null | head -1 || true)"
  if [[ -z "$_any_sess" ]]; then
    bootstrapped_session="_restore_bootstrap_$$"
    tmux new-session -d -s "$bootstrapped_session"
    _any_sess="$bootstrapped_session"
  fi
  if [[ -n "$_any_sess" ]]; then
    _sock="$(tmux display-message -t "$_any_sess" -p -F "#{socket_path}" 2>/dev/null || printf '')"
    _sid="$(tmux display-message -t "$_any_sess" -p -F "#{session_id}" 2>/dev/null | tr -d '$')"
    [[ -n "$_sock" ]] && export TMUX="${_sock},0,${_sid:-0}"
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

  if [[ -n "$bootstrapped_session" ]]; then
    tmux kill-session -t "$bootstrapped_session" >/dev/null 2>&1 || true
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

_run_tmux_script_quiet "$plugin_restore" "$@" \
  2> >(
    while IFS= read -r line; do
      if [[ "$line" == "no current client" || "$line" == "can't find session: 0" ]]; then
        continue
      fi
      printf '%s\n' "$line" >&2
    done
  )

tmux set -g @save-flash "✓ tmux snapshot restored" 2>/dev/null || true
( sleep 5; tmux set -g @save-flash "" 2>/dev/null ) & disown
