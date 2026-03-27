#!/bin/bash
set -euo pipefail

action="${1:-}"
window_id="${2:-}"

if [[ -z "$action" ]]; then
  exit 0
fi

has_clients() {
  tmux list-clients >/dev/null 2>&1 && [[ -n "$(tmux list-clients 2>/dev/null)" ]]
}

case "$action" in
  select)
    last_active="$(tmux show-options -gv @last_active_win 2>/dev/null || printf '')"
    if [[ -n "$last_active" ]]; then
      tmux set-option -wu -t "$last_active" @needs_attention 2>/dev/null || true
    fi
    if [[ -n "$window_id" ]]; then
      tmux set-option -gq @last_active_win "$window_id" 2>/dev/null || true
      tmux set-option -wu -t "$window_id" @needs_attention 2>/dev/null || true
    fi
    if has_clients; then
      tmux refresh-client -S 2>/dev/null || true
    fi
    ;;
  bell)
    if [[ -n "$window_id" ]]; then
      tmux set-option -wq -t "$window_id" @needs_attention 1 2>/dev/null || true
    fi
    if has_clients; then
      tmux refresh-client -S 2>/dev/null || true
    fi
    ;;
  blur)
    tmux set-option -wu @needs_attention 2>/dev/null || true
    if has_clients; then
      tmux refresh-client -S 2>/dev/null || true
    fi
    ;;
esac
