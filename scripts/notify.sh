#!/bin/bash
# notify.sh TITLE MESSAGE [TMUX_TARGET]
# Shows a macOS notification, plays Glass, and optionally sets @needs_attention.
TITLE="${1:-Notification}"
MESSAGE="${2:-needs attention}"
TARGET="${3:-}"

# Normalize TARGET to session:window format for tmux switch-client
if [[ -n "$TARGET" ]] && command -v tmux >/dev/null 2>&1; then
    if [[ "$TARGET" == @* ]]; then
        # Window ID (@116) — look up its session
        _session=$(tmux list-windows -a -F '#{session_name}:#{window_id}' 2>/dev/null | grep ":${TARGET}$" | cut -d: -f1)
        [[ -n "$_session" ]] && TARGET="${_session}:${TARGET}"
    elif [[ "$TARGET" == %* ]]; then
        # Pane ID (%62) — resolve to session:window
        TARGET=$(tmux display-message -p -t "$TARGET" '#{session_name}:#{window_id}' 2>/dev/null || printf '%s' "$TARGET")
    fi
fi

if command -v hs >/dev/null 2>&1; then
    hs -c "showNotify('${TITLE//\'/\\\'}', '${MESSAGE//\'/\\\'}', '$TARGET')" >/dev/null 2>&1 &
else
    osascript - "$TITLE" "$MESSAGE" >/dev/null 2>&1 <<'EOF'
on run argv
  display notification (item 2 of argv) with title (item 1 of argv) subtitle "Ghostty" sound name "Glass"
end run
EOF
fi

if [[ -n "$TARGET" ]] && command -v tmux >/dev/null 2>&1; then
    tmux set-option -wq -t "$TARGET" @needs_attention 1 2>/dev/null
    if tmux list-clients >/dev/null 2>&1 && [[ -n "$(tmux list-clients 2>/dev/null)" ]]; then
        tmux refresh-client -S 2>/dev/null
    fi
fi
