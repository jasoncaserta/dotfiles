#!/bin/bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  printf 'usage: %s <command> [args...]\n' "${0##*/}" >&2
  exit 1
fi

printf '\n'
# Reset lingering terminal attributes, then clear only the visible viewport so
# restored output remains available in scrollback while the new TUI starts on a
# clean screen.
printf '\033[0m\033[39m\033[49m\033[2J\033[H'
printf '%s\n' 'Restored pane output above; new session starts below'
printf '\n'

agent_bin="$(basename "$1")"
case "$agent_bin" in
  codex|codex-aarch64-a)
    export TMUX_RESTORE_KEEP_NAME=1
    exec zsh -ic 'printf "\033[0m\033[39m\033[49m"; exec codex'
    ;;
  claude)
    export TMUX_RESTORE_KEEP_NAME=1
    exec zsh -ic 'printf "\033[0m\033[39m\033[49m"; exec claude'
    ;;
esac

exec "$@"
