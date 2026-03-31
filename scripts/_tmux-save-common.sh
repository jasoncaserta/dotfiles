#!/bin/bash
# Shared helpers sourced by tmux-autosave.sh, tmux-manualsave.sh, and tmux-save-status.sh.

# Run tmux-resurrect's save.sh with a shim that suppresses status-bar output.
# The shim intercepts `tmux display-message` calls without -p and silently drops them.
_run_save() {
  local save_script="$1"
  local _tmpdir
  _tmpdir=$(mktemp -d)
  cat > "$_tmpdir/tmux" <<'SHIM'
#!/bin/bash
cmd=""; has_p=0
for arg in "$@"; do
  [[ -z "$cmd" && "$arg" != -* ]] && cmd="$arg"
  [[ "$arg" == "-p" ]] && has_p=1
done
[[ "$cmd" == "display-message" && "$has_p" -eq 0 ]] && exit 0
exec /opt/homebrew/bin/tmux "$@"
SHIM
  chmod +x "$_tmpdir/tmux"
  PATH="$_tmpdir:$PATH" "$save_script"
  rm -rf "$_tmpdir"
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
