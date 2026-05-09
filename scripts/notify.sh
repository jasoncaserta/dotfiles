#!/bin/bash
# notify.sh TITLE MESSAGE [TMUX_TARGET]
# Sends a macOS notification via Hammerspoon (through the hammerspoon:// URL
# scheme — hs.ipc crashes HS 1.1.1 on macOS 26) and optionally sets
# @needs_attention so the tab shows a 🔔.
TITLE="${1:-Notification}"
MESSAGE="${2:-needs attention}"
TARGET="${3:-}"
PANE_ID="${3:-}"   # saved before TARGET is rewritten to session:window form

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

    # Arm input watcher: clears @needs_attention the moment the user presses
    # any key (which causes the TUI to produce output that pipe-pane detects).
    # The 0.8s delay lets the TUI finish its own post-completion rendering so
    # we don't trigger on the agent's output rather than the user's keypress.
    _dotfiles_dir=$(cat "$HOME/.config/dotfiles/path" 2>/dev/null || echo '')
    _clear_script="$_dotfiles_dir/scripts/tmux-clear-on-input.sh"
    _tmux_socket="${TMUX%%,*}"   # extract socket path from $TMUX env var
    if [[ -x "$_clear_script" && -n "$_tmux_socket" ]]; then
        # Resolve pane ID and window ID — caller may pass %pane or @window.
        _pane_id=""
        _win_id=""
        if [[ "$PANE_ID" == %* ]]; then
            _pane_id="$PANE_ID"
            _win_id=$(tmux display-message -p -t "$PANE_ID" '#{window_id}' 2>/dev/null || echo '')
        elif [[ -n "$TARGET" ]]; then
            _win_id=$(tmux display-message -p -t "$TARGET" '#{window_id}' 2>/dev/null || echo '')
            _pane_id=$(tmux display-message -p -t "$TARGET" '#{pane_id}' 2>/dev/null || echo '')
        fi
        if [[ -n "$_pane_id" && -n "$_win_id" ]]; then
            (sleep 0.8
             tmux -S "$_tmux_socket" pipe-pane -t "$_pane_id" 2>/dev/null
             tmux -S "$_tmux_socket" pipe-pane -t "$_pane_id" \
               "\"$_clear_script\" \"$_win_id\" \"$_tmux_socket\"" 2>/dev/null
            ) >/dev/null 2>&1 &
        fi
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
