#!/bin/bash
set -euo pipefail

SAVE_SCRIPT="$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
RESURRECT_DIR="$HOME/.tmux/resurrect"
LAST="$RESURRECT_DIR/last"

[[ -x "$SAVE_SCRIPT" ]] || exit 0

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
PATH="$_tmpdir:$PATH" "$SAVE_SCRIPT"
rm -rf "$_tmpdir"
tmux set -g @save-flash "✓ manual tmux snapshot saved" 2>/dev/null || true
( sleep 5; tmux set -g @save-flash "" 2>/dev/null ) & disown

new_file="$(readlink "$LAST" 2>/dev/null || printf '')"
if [[ -n "$new_file" && -s "$RESURRECT_DIR/$new_file" ]]; then
  list="$RESURRECT_DIR/last-manual-list"
  printf '%s\n' "$new_file" > "${list}.tmp"
  [[ -f "$list" ]] && grep -v "^${new_file}$" "$list" | head -2 >> "${list}.tmp" || true
  mv "${list}.tmp" "$list"
fi
