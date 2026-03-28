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

# Find hs CLI installed by Hammerspoon (not always on PATH in tmux hook shells)
hs_bin=""
for _p in "$(command -v hs 2>/dev/null)" "/opt/homebrew/bin/hs" "/usr/local/bin/hs"; do
  [[ -x "$_p" ]] && hs_bin="$_p" && break
done

case "$action" in
  select)
    last_active="$(tmux show-options -gv @last_active_win 2>/dev/null || printf '')"
    if [[ -n "$last_active" ]]; then
      tmux set-option -wu -t "$last_active" @needs_attention 2>/dev/null || true
      if [[ -n "$hs_bin" ]]; then
        "$hs_bin" -c "dismissNotify('$last_active')" >/dev/null 2>&1 &
      fi
    fi
    if [[ -n "$window_id" ]]; then
      tmux set-option -gq @last_active_win "$window_id" 2>/dev/null || true
      tmux set-option -wu -t "$window_id" @needs_attention 2>/dev/null || true
      if [[ -n "$hs_bin" ]]; then
        "$hs_bin" -c "dismissNotify('$window_id')" >/dev/null 2>&1 &
      fi
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
  focus)
    if [[ -n "$window_id" ]]; then
      attention=$(tmux show-options -wqv -t "$window_id" @needs_attention 2>/dev/null || printf '')
      if [[ "$attention" == "1" ]]; then
        tmux set-option -wu -t "$window_id" @needs_attention 2>/dev/null || true
        if [[ -n "$hs_bin" ]]; then
          "$hs_bin" -c "dismissNotify('$window_id')" >/dev/null 2>&1 &
        fi
        if has_clients; then
          tmux refresh-client -S 2>/dev/null || true
        fi
      fi
    fi
    ;;
  close)
    if [[ -n "$window_id" ]]; then
      if [[ -n "$hs_bin" ]]; then
        "$hs_bin" -c "dismissNotify('$window_id')" >/dev/null 2>&1 &
      fi
    fi
    ;;
  detach)
    if [[ -n "$hs_bin" ]]; then
      "$hs_bin" -c "dismissAllNotify()" >/dev/null 2>&1 &
    fi
    tmux list-windows -a -F '#{session_name}:#{window_id}' 2>/dev/null | while read -r win; do
      tmux set-option -wu -t "$win" @needs_attention 2>/dev/null || true
    done
    if has_clients; then
      tmux refresh-client -S 2>/dev/null || true
    fi
    ;;
esac
