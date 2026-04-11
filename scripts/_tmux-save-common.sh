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
  rm -rf "$_tmpdir"
}

_run_save() {
  _run_tmux_script_quiet "$1"
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
    /^pane\t/ && $2 == "main" { print; next }
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
