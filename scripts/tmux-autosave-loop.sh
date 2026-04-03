#!/bin/bash
PIDFILE="/tmp/tmux-autosave-loop.pid"
DOTFILES_DIR="$(cat "$HOME/.config/dotfiles/path" 2>/dev/null)"
AUTOSAVE="$DOTFILES_DIR/scripts/tmux-autosave.sh"

TMUX_BIN="$(command -v tmux 2>/dev/null)"
if [[ -z "$TMUX_BIN" ]]; then
  echo "tmux-autosave-loop: tmux not found in PATH" >&2
  exit 1
fi

if [[ -z "$DOTFILES_DIR" || ! -x "$AUTOSAVE" ]]; then
  echo "tmux-autosave-loop: could not resolve autosave script (run install.sh first)" >&2
  exit 1
fi

# Prevent duplicate instances
if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  exit 0
fi
echo "$$" > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

while "$TMUX_BIN" has-session 2>/dev/null; do
  sleep 30
  "$AUTOSAVE" 30
done
