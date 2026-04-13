#!/bin/bash
# NOTE: This script is superseded by the DOTFILES_RESTORE=1 env-var flow handled
# by the zsh wrappers (codex/claude functions in zshrc). It is kept so that old
# resurrect snapshots containing references to it can still be sanitized correctly
# by _sanitize_restore_dump in _tmux-save-common.sh.
set -euo pipefail

if [[ $# -eq 0 ]]; then
  printf 'usage: %s <command> [args...]\n' "${0##*/}" >&2
  exit 1
fi

{
  printf '%s\tpid=%s\tpane=%s\targv=%s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" \
    "$$" \
    "${TMUX_PANE:-}" \
    "$*"
} >> /tmp/tmux-restore-agent-session.log 2>/dev/null || true

restore_banner='──────────────── Restored pane output above; new session starts below ────────────────'

_wait_for_client() {
  # Wait up to 10 s for a tmux client to attach so the TUI gets terminal
  # capability responses (e.g. background-color detection from Ghostty).
  local _sess _waited=0
  _sess=$(tmux display-message -p '#{session_name}' 2>/dev/null || printf 'main')
  until tmux list-clients -t "$_sess" 2>/dev/null | grep -q .; do
    sleep 0.1
    _waited=$(( _waited + 1 ))
    if (( _waited >= 100 )); then break; fi
  done
}

agent_bin="$(basename "$1")"
case "$agent_bin" in
  codex|codex-aarch64-a)
    printf '\n'
    # Reset lingering terminal attributes, then clear only the visible viewport so
    # restored output remains available in scrollback while the new TUI starts on a
    # clean screen.
    printf '\033[0m\033[39m\033[49m\033[2J\033[H'
    printf '\033[38;5;34m%s\033[0m\n' "$restore_banner"
    printf '\n'
    export TMUX_RESTORE_KEEP_NAME=1
    _wait_for_client
    exec codex -c features.codex_hooks=true
    ;;
  claude)
    printf '\n'
    # Match the Codex restore presentation exactly.
    printf '\033[0m\033[39m\033[49m\033[2J\033[H'
    printf '\033[38;5;34m%s\033[0m\n' "$restore_banner"
    printf '\n'
    export TMUX_RESTORE_KEEP_NAME=1
    _wait_for_client
    exec claude
    ;;
esac

exec "$@"
