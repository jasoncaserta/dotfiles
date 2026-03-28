#!/bin/bash
RESURRECT_DIR="$HOME/.tmux/resurrect"

_age() {
  local file="$RESURRECT_DIR/$1"
  [[ -f "$file" ]] || { printf 'never'; return; }
  local now mtime diff
  now=$(date +%s)
  mtime=$(stat -f %m "$file" 2>/dev/null || printf '0')
  diff=$(( now - mtime ))
  if   (( diff < 60 ));    then printf '%ds ago'     "$diff"
  elif (( diff < 3600 ));  then printf '%dm ago'     "$(( diff / 60 ))"
  elif (( diff < 86400 )); then printf '%dh ago'     "$(( diff / 3600 ))"
  else                          printf '%dd ago'     "$(( diff / 86400 ))"
  fi
}

auto_file="$(   head -1 "$RESURRECT_DIR/last-auto-list"   2>/dev/null || true )"
manual_file="$( head -1 "$RESURRECT_DIR/last-manual-list" 2>/dev/null || true )"

auto_age="$(   [[ -n "$auto_file"   ]] && _age "$auto_file"   || printf 'never' )"
manual_age="$( [[ -n "$manual_file" ]] && _age "$manual_file" || printf 'never' )"

printf 'auto: %s  manual: %s' "$auto_age" "$manual_age"
