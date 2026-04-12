#!/bin/bash
set -euo pipefail

restore_file="${1:-$HOME/.tmux/resurrect/last}"
restore_dir="$HOME/.tmux/resurrect"
plugin_restore="$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
tmp_restore_dir=''
tmp_file=''
original_resurrect_dir=''
bootstrapped_session=''
_was_running=0

# shellcheck source=_tmux-save-common.sh
source "$(dirname "$0")/_tmux-save-common.sh"

_restore_debug_log() {
  {
    printf '%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
  } >> /tmp/tmux-restore-debug.log 2>/dev/null || true
}

_restore_agent_command() {
  case "$1" in
    codex)  printf '%s\n' 'DOTFILES_RESTORE=1 codex' ;;
    claude) printf '%s\n' 'DOTFILES_RESTORE=1 claude' ;;
  esac
}

if [[ -z "${TMUX:-}" ]]; then
  # Build a valid TMUX env using any available session so tmux set-option works.
  _any_sess="$(tmux list-sessions -F '#{session_name}' 2>/dev/null | head -1 || true)"
  if [[ -z "$_any_sess" ]]; then
    bootstrapped_session="_restore_bootstrap_$$"
    tmux new-session -d -s "$bootstrapped_session"
    _any_sess="$bootstrapped_session"
  fi
  if [[ -n "$_any_sess" ]]; then
    _sock="$(tmux display-message -t "$_any_sess" -p -F "#{socket_path}" 2>/dev/null || printf '')"
    _sid="$(tmux display-message -t "$_any_sess" -p -F "#{session_id}" 2>/dev/null | tr -d '$')"
    [[ -n "$_sock" ]] && export TMUX="${_sock},0,${_sid:-0}"
  fi
fi

cleanup() {
  local status=$?

  if [[ -n "$original_resurrect_dir" ]]; then
    tmux set-option -gq @resurrect-dir "$original_resurrect_dir" >/dev/null 2>&1 || true
  else
    tmux set-option -guq @resurrect-dir >/dev/null 2>&1 || true
  fi

  if [[ -n "$tmp_restore_dir" && -d "$tmp_restore_dir" ]]; then
    rm -rf "$tmp_restore_dir"
  fi

  if [[ -n "$bootstrapped_session" ]]; then
    tmux kill-session -t "$bootstrapped_session" >/dev/null 2>&1 || true
  fi

  exit "$status"
}
trap cleanup EXIT

if [[ -f "$restore_file" ]]; then
  tmp_restore_dir="$(mktemp -d)"
  tmp_file="$tmp_restore_dir/last"
  awk '
    BEGIN { FS = "\t"; OFS = "\t" }
    /^(pane|window|grouped_session)\t/ { print; next }
    /^state\t/ {
      if ($2 != "" && $2 != ":" && $3 != "" && $3 != ":") {
        print
      }
      next
    }
    { print }
  ' "$restore_file" > "$tmp_file"

  if [[ -f "$restore_dir/pane_contents.tar.gz" ]]; then
    ln -sf "$restore_dir/pane_contents.tar.gz" "$tmp_restore_dir/pane_contents.tar.gz"
  fi

  original_resurrect_dir="$(tmux show-option -gqv @resurrect-dir 2>/dev/null || printf '')"
  tmux set-option -gq @resurrect-dir "$tmp_restore_dir" 2>/dev/null || true
fi

# Track whether the session was already running before restore.
tmux has-session -t main 2>/dev/null && _was_running=1 || true

# If the session is already up, kill any agent child processes so their pane
# shells become free to receive the restore command we'll send after resurrect.
# We intentionally leave the window/pane alive so resurrect sees >1 pane and
# doesn't enter "restore from scratch" mode (which would also overwrite the
# zsh window).
if [[ "$_was_running" -eq 1 && -n "$tmp_file" && -f "$tmp_file" ]]; then
  while IFS=$'\t' read -r _lt _sess _win _wa _wf _pi _pt _dir _pa _pcmd _pfull; do
    case "${_pfull#:}" in
      codex*|claude*)
        _pane_pid="$(tmux display-message -p -t "${_sess}:${_win}.${_pi}" '#{pane_pid}' 2>/dev/null || printf '')"
        [[ -n "$_pane_pid" ]] && pkill -P "$_pane_pid" 2>/dev/null || true
        ;;
    esac
  done < <(grep $'^pane\t' "$tmp_file")
  unset _lt _sess _win _wa _wf _pi _pt _dir _pa _pcmd _pfull _pane_pid
fi

_run_tmux_script_quiet "$plugin_restore" "$@" \
  2> >(
    while IFS= read -r line; do
      if [[ "$line" == "no current client" || "$line" == "can't find session: 0" || "$line" == *"open terminal failed"* ]]; then
        continue
      fi
      printf '%s\n' "$line" >&2
    done
  )

tmux set -g @save-flash "✓ tmux snapshot restored" 2>/dev/null || true
( sleep 5; tmux set -g @save-flash "" 2>/dev/null ) & disown

# When the session was already running, resurrect marks existing panes as
# "existing" and skips sending restore commands to them. Send them ourselves.
if [[ "$_was_running" -eq 1 && -n "$tmp_file" && -f "$tmp_file" ]]; then
  while IFS=$'\t' read -r _lt _sess _win _wa _wf _pi _pt _dir _pa _pcmd _pfull; do
    case "${_pfull#:}" in
      codex*)  _agent='codex'  ;;
      claude*) _agent='claude' ;;
      *)       continue ;;
    esac
    # Wait up to 5 s for the pane to reach a shell, then launch the restored
    # agent through the user's normal shell wrapper.
    _waited=0
    while (( _waited < 50 )); do
      _pane_cmd="$(tmux display-message -p -t "${_sess}:${_win}.${_pi}" '#{pane_current_command}' 2>/dev/null || printf '')"
      case "$_pane_cmd" in
        zsh|bash|sh|'')
          _restore_cmd="$(_restore_agent_command "$_agent")"
          [[ -n "$_restore_cmd" ]] || break
          if [[ "$_agent" == "claude" ]]; then
            _pane_target="${_sess}:${_win}.${_pi}"
            _restore_debug_log "claude-send target=${_pane_target} pane_cmd=${_pane_cmd} command=${_restore_cmd}"
            tmux capture-pane -p -S -40 -E - -t "$_pane_target" > /tmp/tmux-restore-claude-before-send.txt 2>/dev/null || true
          fi
          tmux send-keys -t "${_sess}:${_win}.${_pi}" "$_restore_cmd" Enter 2>/dev/null || true
          if [[ "$_agent" == "claude" ]]; then
            (
              sleep 0.4
              tmux capture-pane -p -S -40 -E - -t "$_pane_target" > /tmp/tmux-restore-claude-after-send.txt 2>/dev/null || true
              _restore_debug_log "claude-after-send target=${_pane_target} pane_cmd=$(tmux display-message -p -t "$_pane_target" '#{pane_current_command}' 2>/dev/null || printf '')"
            ) &
            disown
          fi
          break
          ;;
        codex*|claude*)
          break  # agent already running
          ;;
      esac
      sleep 0.1
      _waited=$(( _waited + 1 ))
    done
  done < <(grep $'^pane\t' "$tmp_file")
  unset _lt _sess _win _wa _wf _pi _pt _dir _pa _pcmd _pfull _agent _pane_cmd _restore_cmd _pane_target _waited
fi
