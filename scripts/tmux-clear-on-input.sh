#!/bin/bash
# tmux-clear-on-input.sh <window-id> <socket-path>
# Run via `tmux pipe-pane`. Waits for the first byte of pane output
# (any keypress causes TUI output), then clears @needs_attention.
WIN_ID="${1:-}"
SOCKET="${2:-}"

[[ -z "$WIN_ID" || -z "$SOCKET" ]] && exit 0

# Background timer: exit after 10 minutes if user never interacts.
(sleep 600 && kill $$ 2>/dev/null) &
TIMER_PID=$!

# stdin = piped pane output via pipe-pane
if IFS= read -rn1 2>/dev/null; then
    tmux -S "$SOCKET" set-option -wu -t "$WIN_ID" @needs_attention 2>/dev/null || true
    tmux -S "$SOCKET" refresh-client -S 2>/dev/null || true
    open -g "hammerspoon://dismissNotify?winKey=${WIN_ID}" >/dev/null 2>&1 || true
    open -g "hammerspoon://dismissVisiblePending" >/dev/null 2>&1 || true
fi

kill "$TIMER_PID" 2>/dev/null || true
