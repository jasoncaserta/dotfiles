#!/bin/bash
# Shared helpers sourced by tmux-autosave.sh, tmux-manualsave.sh, and tmux-save-status.sh.

# Run a tmux plugin script with a shim that suppresses non-`-p` display-message
# banners so status feedback can be shown in the tmux status line instead.
_run_tmux_script_quiet() {
  local script="$1"
  shift
  local _tmpdir real_tmux
  _tmpdir=$(mktemp -d)
  real_tmux=$(command -v tmux)
  cat > "$_tmpdir/tmux" <<'SHIM'
#!/bin/bash
cmd=""; has_p=0
for arg in "$@"; do
  [[ -z "$cmd" && "$arg" != -* ]] && cmd="$arg"
  [[ "$arg" == "-p" ]] && has_p=1
done
[[ "$cmd" == "display-message" && "$has_p" -eq 0 ]] && exit 0
SHIM
  printf 'exec %s "$@"\n' "$real_tmux" >> "$_tmpdir/tmux"
  chmod +x "$_tmpdir/tmux"
  PATH="$_tmpdir:$PATH" "$script" "$@"
  local _status=$?
  # Defer cleanup so background processes spawned by the plugin (e.g.
  # tmux_spinner.sh) can finish using the shim before it is removed.
  ( sleep 5; rm -rf "$_tmpdir" ) &
  disown
  return "$_status"
}

_sanitize_restore_dump() {
  perl -ne 'print unless /tmux-restore-agent-session\.sh(?:["[:space:]]+)(?:codex|claude)\b|TMUX_RESTORE_KEEP_NAME=1[[:space:]]+(?:codex|claude)\b|DOTFILES_RESTORE=1[[:space:]]+(?:codex|claude)\b/'
}

_normalize_restore_dump() {
  RESTORE_BANNER_TEXT='Restored pane output above; new session starts below' perl -0pe '
    my $banner = $ENV{RESTORE_BANNER_TEXT};
    s/(?:\e\[[0-9;]*m)*[^\n]*\Q$banner\E[^\n]*\n?.*\z//s;
    s/\s*\z//s;
  '
}

_patch_alt_screen_pane_contents_archive() {
  local archive="$HOME/.tmux/resurrect/pane_contents.tar.gz"
  [[ -f "$archive" ]] || return 0
  command -v tmux >/dev/null 2>&1 || return 0
  local restore_banner=$'\033[38;5;34m──────────────── Restored pane output above; new session starts below ────────────────\033[0m'

  local tmpdir
  tmpdir=$(mktemp -d) || return 0

  if ! tar -xzf "$archive" -C "$tmpdir" 2>/dev/null; then
    rm -rf "$tmpdir"
    return 0
  fi

  local pane_id pane_cmd alt_on pane_title window_name pane_file pane_dump agent_kind
  while IFS=$'\t' read -r pane_id pane_cmd alt_on pane_title window_name; do
    pane_file="$tmpdir/pane_contents/pane-${pane_id}"
    agent_kind=''
    case "$pane_cmd:$pane_title:$window_name" in
      claude:*|*:"✳ Claude Code":*|*:*:claude*)
        agent_kind='claude'
        ;;
      codex:*|codex-aarch64-a:*|*:*:codex*)
        agent_kind='codex'
        ;;
    esac
    case "$agent_kind" in
      claude)
        mkdir -p "$(dirname "$pane_file")"
        pane_dump=''
        if [[ "$alt_on" == "1" ]]; then
          pane_dump="$(tmux capture-pane -aepJ -t "$pane_id" 2>/dev/null || printf '')"
        fi
        if [[ -z "$pane_dump" && -f "$pane_file" ]]; then
          pane_dump="$(cat "$pane_file" 2>/dev/null || printf '')"
        fi
        pane_dump="$(printf '%s' "$pane_dump" | _sanitize_restore_dump | _normalize_restore_dump)"
        [[ -n "$pane_dump" ]] || continue
        printf '%s\n\n%s\n' "$pane_dump" "$restore_banner" > "$pane_file"
        ;;
      codex)
        [[ -f "$pane_file" ]] || continue
        pane_dump="$(cat "$pane_file" 2>/dev/null || printf '')"
        pane_dump="$(printf '%s' "$pane_dump" | _sanitize_restore_dump | _normalize_restore_dump)"
        [[ -n "$pane_dump" ]] || continue
        printf '%s\n\n%s\n' "$pane_dump" "$restore_banner" > "$pane_file"
        ;;
    esac
  done < <(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}'$'\t''#{pane_current_command}'$'\t''#{alternate_on}'$'\t''#{pane_title}'$'\t''#{window_name}' 2>/dev/null)

  (
    cd "$tmpdir" &&
    tar cf - ./pane_contents | gzip > "${archive}.tmp"
  ) 2>/dev/null || {
    rm -f "${archive}.tmp"
    rm -rf "$tmpdir"
    return 0
  }

  mv "${archive}.tmp" "$archive"
  rm -rf "$tmpdir"
}

_run_save() {
  _run_tmux_script_quiet "$1"
  _patch_alt_screen_pane_contents_archive
}

# Rewrite a resurrect snapshot in place so it only contains the persistent
# session we actually restore into.
_filter_snapshot_to_main() {
  local snapshot="$1"
  local tmp

  [[ -n "$snapshot" && -f "$snapshot" ]] || return 0

  tmp="$(mktemp)"
  awk '
    BEGIN { FS = "\t"; OFS = "\t" }
    /^pane\t/ && $2 == "main" {
      if ($7 == "✳ Claude Code" || $10 == "claude" || $11 ~ /claude-preserve-scrollback\.py/) {
        $10 = "claude"
        $11 = ":claude"
      }
      print
      next
    }
    /^window\t/ && $2 == "main" { print; next }
    /^grouped_session\t/ && ($2 == "main" || $3 == "main") { print; next }
    /^state\t/ { print "state", "main", ""; next }
  ' "$snapshot" > "$tmp"
  mv "$tmp" "$snapshot"
}

# Prepend new_file to list, keeping at most the 3 most recent unique entries.
_update_save_list() {
  local new_file="$1" list="$2"
  printf '%s\n' "$new_file" > "${list}.tmp"
  [[ -f "$list" ]] && grep -v "^${new_file}$" "$list" | head -2 >> "${list}.tmp" || true
  mv "${list}.tmp" "$list"
}

# Print human-readable age for a file given its absolute path.
_file_age_str() {
  local f="$1"
  [[ -f "$f" ]] || { printf 'never'; return; }
  local now mtime diff
  now=$(date +%s)
  mtime=$(stat -f %m "$f" 2>/dev/null || printf '0')
  diff=$(( now - mtime ))
  if   (( diff < 60 ));    then printf '%ds ago' "$diff"
  elif (( diff < 3600 ));  then printf '%dm ago' "$(( diff / 60 ))"
  elif (( diff < 86400 )); then printf '%dh ago' "$(( diff / 3600 ))"
  else                          printf '%dd ago' "$(( diff / 86400 ))"
  fi
}
