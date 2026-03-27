#!/bin/bash
# creator.sh — leader setup. Sets up full symlinks so edits to your dotfiles
# go directly into the repo. After setup, just edit normally, commit, and push
# — followers run install.sh to get the features non-destructively.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── helpers ──────────────────────────────────────────────────────────────────

green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    yellow "  backing up $dst → $dst.bak"
    mv "$dst" "$dst.bak"
  fi
  if [[ -L "$dst" ]]; then
    rm "$dst"
  fi
  ln -s "$src" "$dst"
  green "  linked $dst"
}

# ── guard ────────────────────────────────────────────────────────────────────

if [[ "$(uname)" != "Darwin" ]]; then
  red "This dotfiles setup is macOS-only."
  exit 1
fi

echo "Setting up creator symlinks from $DOTFILES"
echo

# ── symlinks ─────────────────────────────────────────────────────────────────

link "$DOTFILES/zsh/zshrc"              "$HOME/.zshrc"
link "$DOTFILES/zsh/zprofile"           "$HOME/.zprofile"
link "$DOTFILES/tmux/tmux.conf"         "$HOME/.tmux.conf"
link "$DOTFILES/ghostty/config"         "$HOME/.config/ghostty/config"
link "$DOTFILES/hammerspoon/init.lua"   "$HOME/.hammerspoon/init.lua"
link "$DOTFILES/scripts/notify.sh"      "$HOME/.notify.sh"
link "$DOTFILES/git/gitignore_global"   "$HOME/.config/git/ignore"
link "$DOTFILES/claude/settings.json"   "$HOME/.claude/settings.json"
link "$DOTFILES/codex/hooks.json"       "$HOME/.codex/hooks.json"

chmod +x "$DOTFILES/scripts/notify.sh"

# ── post-install checklist ───────────────────────────────────────────────────

echo
echo "Done. Symlinks are live — edits to your dotfiles go directly into the repo."
echo
echo "Workflow:"
echo "  1. Edit any dotfile normally (e.g. ~/.zshrc, ~/.tmux.conf)"
echo "  2. cd $DOTFILES && git add -A && git commit -m '...' && git push"
echo "  3. On any other machine: git pull  (changes are live immediately)"
echo
echo "Complete these steps if this is a fresh machine:"
echo
echo "  1. Grant Hammerspoon permissions (System Settings → Privacy & Security):"
echo "       - Accessibility"
echo "       - Notifications"
echo "     Then reload: Hammerspoon menu bar icon → Reload Config"
echo
echo "  2. Reload tmux config (inside an active tmux session):"
echo "       tmux source ~/.tmux.conf"
echo
echo "  3. Start a new shell (or open Ghostty) to apply zsh changes."
