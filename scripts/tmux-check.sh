#!/bin/bash
# tmux-check.sh — single-pass diagnostic for common tmux/zsh debugging
# Run this before manually inspecting individual files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESURRECT_DIR="$HOME/.tmux/resurrect"
SAVE_SCRIPT="$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
LAST="$RESURRECT_DIR/last"

ok()   { printf '  [ok]  %s\n' "$*"; }
warn() { printf '  [!!]  %s\n' "$*"; }
info() { printf '  [--]  %s\n' "$*"; }

echo "=== tmux-check ==="

# 1. tmux server running?
if tmux info &>/dev/null; then
  ok "tmux server running ($(tmux -V))"
else
  warn "tmux server NOT running"
fi

# 2. resurrect plugin present?
if [[ -x "$SAVE_SCRIPT" ]]; then
  ok "tmux-resurrect save.sh found"
else
  warn "tmux-resurrect save.sh missing: $SAVE_SCRIPT"
fi

# 3. Last save file age
if [[ -e "$LAST" ]]; then
  source "$SCRIPT_DIR/_tmux-save-common.sh"
  age=$(_file_age_str "$RESURRECT_DIR/$(readlink "$LAST" 2>/dev/null || echo '')")
  ok "Last resurrect save: $age"
else
  warn "No resurrect 'last' symlink found at $LAST"
fi

# 4. Autosave list
if [[ -f "$RESURRECT_DIR/last-auto-list" ]]; then
  info "Recent auto-saves:"
  while IFS= read -r line; do
    f="$RESURRECT_DIR/$line"
    [[ -f "$f" ]] && printf '        %s (%s)\n' "$line" "$(_file_age_str "$f")"
  done < "$RESURRECT_DIR/last-auto-list"
fi

# 5. tmux session hooks (after-new-session, etc.)
echo ""
echo "=== tmux hooks ==="
tmux show-hooks -g 2>/dev/null | grep -v '^$' || info "No global hooks set"

# 6. Syntax-check all dotfiles shell scripts
echo ""
echo "=== shell syntax ==="
for f in "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/_*.sh "$HOME"/.zshrc "$HOME"/.zprofile; do
  [[ -f "$f" ]] || continue
  case "$f" in
    *.zshrc|*.zprofile|*/.zshrc|*/.zprofile)
      if zsh -n "$f" 2>/dev/null; then
        ok "$(basename "$f")"
      else
        warn "$(basename "$f") — syntax error:"
        zsh -n "$f" 2>&1 | sed 's/^/    /'
      fi
      ;;
    *)
      if bash -n "$f" 2>/dev/null && zsh -n "$f" 2>/dev/null; then
        ok "$(basename "$f")"
      else
        warn "$(basename "$f") — syntax error:"
        bash -n "$f" 2>&1 | sed 's/^/    /'
      fi
      ;;
  esac
done

# 7. p10k.zsh symlink
echo ""
echo "=== p10k symlink ==="
p10k_target=$(readlink "$HOME/.p10k.zsh" 2>/dev/null || echo "not a symlink")
if [[ "$p10k_target" == *dotfiles* ]]; then
  ok "~/.p10k.zsh -> $p10k_target"
else
  warn "~/.p10k.zsh not linked to dotfiles: $p10k_target"
fi

echo ""
echo "Done."
