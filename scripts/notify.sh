#!/bin/bash
# notify.sh TITLE MESSAGE [TMUX_TARGET]
# Sends a macOS notification via Hammerspoon (through the hammerspoon:// URL
# scheme — hs.ipc crashes HS 1.1.1 on macOS 26) and optionally sets
# @needs_attention so the tab shows a 🔔.
TITLE="${1:-Notification}"
MESSAGE="${2:-needs attention}"
TARGET="${3:-}"

# Normalize TARGET to session:window format for tmux switch-client
if [[ -n "$TARGET" ]] && command -v tmux >/dev/null 2>&1; then
    if [[ "$TARGET" == @* ]]; then
        _session=$(tmux list-windows -a -F '#{session_name}:#{window_id}' 2>/dev/null | grep ":${TARGET}$" | cut -d: -f1)
        [[ -n "$_session" ]] && TARGET="${_session}:${TARGET}"
    elif [[ "$TARGET" == %* ]]; then
        TARGET=$(tmux display-message -p -t "$TARGET" '#{session_name}:#{window_id}' 2>/dev/null || printf '%s' "$TARGET")
    fi
    _win_name=$(tmux display-message -p -t "$TARGET" '#{window_name}' 2>/dev/null || printf '')
    [[ -n "$_win_name" ]] && TITLE="$_win_name"
fi

# Set tmux attention flag first (fast, local) so the bell shows even if
# Hammerspoon is unresponsive.
if [[ -n "$TARGET" ]] && command -v tmux >/dev/null 2>&1; then
    tmux set-option -wq -t "$TARGET" @needs_attention 1 2>/dev/null
    if tmux list-clients >/dev/null 2>&1 && [[ -n "$(tmux list-clients 2>/dev/null)" ]]; then
        tmux refresh-client -S 2>/dev/null
    fi
fi

# Base64-url-encode values so arbitrary title/message text round-trips safely
# through the URL query string. Hammerspoon URL-decodes params, then we
# base64-decode in Lua.
_b64() {
    printf '%s' "$1" | base64 | tr -d '\n' | sed 's|+|%2B|g; s|/|%2F|g; s|=|%3D|g'
}

url="hammerspoon://showNotify?title=$(_b64 "$TITLE")&message=$(_b64 "$MESSAGE")&target=$(_b64 "$TARGET")"
# Fire-and-forget; -g keeps Hammerspoon from stealing focus.
( open -g "$url" >/dev/null 2>&1 & ) >/dev/null 2>&1
exit 0
