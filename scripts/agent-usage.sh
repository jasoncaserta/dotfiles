#!/usr/bin/env bash
# Usage: agent-usage.sh [claude|codex]
# Defaults to showing both bars when no argument is given.

AGENT="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${TMPDIR:-/tmp}/agent-usage-tmux"

declare -A ICONS=(
  [claude]="✻"
  [codex]=">_"
)

declare -A DEFAULTS=(
  [claude]="python3 $SCRIPT_DIR/fetch_claude_usage.py"
  [codex]="python3 $SCRIPT_DIR/fetch_codex_usage.py"
)

declare -A DEFAULT_RESETS=(
  [claude]="python3 $SCRIPT_DIR/fetch_claude_usage.py --field reset_in"
  [codex]="python3 $SCRIPT_DIR/fetch_codex_usage.py --field reset_in"
)

show_icons() {
  local value

  value="$(tmux show-option -gqv @agent_usage_show_icons 2>/dev/null)"
  if [[ -z "$value" ]]; then
    value="$(tmux show-option -gqv @agent_usage_disable_icons 2>/dev/null)"
    case "$value" in
      1|yes|true|on) return 1 ;;
    esac
    return 0
  fi

  case "$value" in
    0|no|false|off) return 1 ;;
  esac
  return 0
}

cache_seconds() {
  local value

  value="$(tmux show-option -gqv @agent_usage_cache_seconds 2>/dev/null)"
  if [[ "$value" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$value"
  else
    printf '60\n'
  fi
}

read_cached_value() {
  local agent="$1"
  local field="$2"
  local path="$CACHE_DIR/${agent}.${field}"
  local ttl now mtime value

  [[ -f "$path" ]] || return 1

  ttl="$(cache_seconds)"
  now="$(date +%s)"
  mtime="$(stat -f %m "$path" 2>/dev/null || printf '0')"

  if (( now - mtime > ttl )); then
    return 1
  fi

  value="$(<"$path")"
  [[ -n "$value" ]] || return 1
  printf '%s\n' "$value"
}

write_cached_value() {
  local agent="$1"
  local field="$2"
  local value="$3"
  local path="$CACHE_DIR/${agent}.${field}"

  mkdir -p "$CACHE_DIR"
  printf '%s\n' "$value" > "$path"
}

run_tmux_command() {
  local option_name="$1"
  local fallback="$2"
  local cmd value

  cmd="$(tmux show-option -gqv "$option_name" 2>/dev/null)"
  if [[ -z "$cmd" ]]; then
    cmd="$fallback"
  fi

  value="$(eval "$cmd" 2>/dev/null | tr -d '\r' | tail -n 1)"
  [[ -n "$value" ]] || return 1
  printf '%s\n' "$value"
}

get_percentage() {
  local agent="$1"
  local cached value option_name legacy_name

  if cached="$(read_cached_value "$agent" percent)"; then
    printf '%s\n' "$cached"
    return 0
  fi

  option_name="@agent_usage_cmd_${agent}"
  legacy_name=""
  if [[ "$agent" == "claude" ]]; then
    legacy_name="@agent_usage_cmd"
  fi

  value="$(run_tmux_command "$option_name" "${DEFAULTS[$agent]}")" || value=""
  if [[ -z "$value" && -n "$legacy_name" ]]; then
    value="$(run_tmux_command "$legacy_name" "${DEFAULTS[$agent]}")" || value=""
  fi
  [[ "$value" =~ ^[0-9]+$ ]] || value="0"
  write_cached_value "$agent" percent "$value"
  printf '%s\n' "$value"
}

get_reset_in() {
  local agent="$1"
  local cached value option_name legacy_name

  if cached="$(read_cached_value "$agent" reset_in)"; then
    printf '%s\n' "$cached"
    return 0
  fi

  option_name="@agent_usage_reset_cmd_${agent}"
  legacy_name=""
  if [[ "$agent" == "claude" ]]; then
    legacy_name="@agent_usage_reset_cmd"
  fi

  value="$(run_tmux_command "$option_name" "${DEFAULT_RESETS[$agent]}")" || value=""
  if [[ -z "$value" && -n "$legacy_name" ]]; then
    value="$(run_tmux_command "$legacy_name" "${DEFAULT_RESETS[$agent]}")" || value=""
  fi
  [[ "$value" =~ ^[0-9]+$ ]] || value="0"
  write_cached_value "$agent" reset_in "$value"
  printf '%s\n' "$value"
}

format_reset() {
  local reset_in="$1"
  local hours minutes

  [[ "$reset_in" =~ ^[0-9]+$ ]] || reset_in=0
  hours=$(( reset_in / 3600 ))
  minutes=$(( (reset_in % 3600) / 60 ))
  printf '%02d:%02d' "$hours" "$minutes"
}

render_bar() {
  local agent="$1"
  local pct="$2"
  local reset_label="$3"
  local width=6
  local empty_bg="colour236"
  local sub_chars=('▏' '▎' '▍' '▌' '▋' '▊' '▉')
  local full partial_idx color bar_on partial empty bar_off icon_prefix

  (( pct < 0 )) && pct=0
  (( pct > 100 )) && pct=100

  read -r full partial_idx <<< "$(awk -v p="$pct" -v w="$width" 'BEGIN {
    filled = p * w / 100
    full = int(filled)
    idx = int((filled - full) * 8)
    print full, idx
  }')"

  case "$agent" in
    claude) color="colour214" ;;
    codex) color="colour250" ;;
    *) color="colour250" ;;
  esac

  bar_on=""
  for (( i = 0; i < full; i++ )); do
    bar_on+="█"
  done

  partial=""
  if (( partial_idx > 0 )); then
    partial="${sub_chars[$((partial_idx - 1))]}"
    empty=$(( width - full - 1 ))
  else
    empty=$(( width - full ))
  fi

  bar_off=""
  for (( i = 0; i < empty; i++ )); do
    bar_off+=" "
  done

  icon_prefix=""
  if show_icons; then
    icon_prefix="${ICONS[$agent]} "
  fi

  printf '#[fg=%s,bold]%s%d%%#[default] #[fg=%s,bg=%s]%s%s#[fg=%s,bg=%s]%s#[default] #[fg=%s,bold]%s#[default]' \
    "$color" "$icon_prefix" "$pct" "$color" "$empty_bg" "$bar_on" "$partial" "$empty_bg" "$empty_bg" "$bar_off" "$color" "$reset_label"
}

render_agent() {
  local agent="$1"
  local pct reset_in reset_label

  pct="$(get_percentage "$agent")"
  reset_in="$(get_reset_in "$agent")"
  reset_label="$(format_reset "$reset_in")"
  render_bar "$agent" "$pct" "$reset_label"
}

case "$AGENT" in
  claude|codex)
    render_agent "$AGENT"
    ;;
  *)
    render_agent claude
    printf ' '
    render_agent codex
    ;;
esac
