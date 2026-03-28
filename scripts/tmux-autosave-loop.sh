#!/bin/bash
PIDFILE="/tmp/tmux-autosave-loop.pid"
AUTOSAVE="$HOME/Projects/dotfiles/scripts/tmux-autosave.sh"

# Prevent duplicate instances
if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  exit 0
fi
echo "$$" > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

while /opt/homebrew/bin/tmux has-session 2>/dev/null; do
  sleep 30
  "$AUTOSAVE" 30
done
