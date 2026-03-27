#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── helpers ──────────────────────────────────────────────────────────────────

green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"

  # Back up real files (not existing symlinks)
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    yellow "  backing up $dst → $dst.bak"
    mv "$dst" "$dst.bak"
  fi

  # Replace stale or wrong symlinks
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

echo "Installing dotfiles from $DOTFILES"
echo

# ── symlinks ─────────────────────────────────────────────────────────────────

link "$DOTFILES/zsh/zshrc"              "$HOME/.zshrc"
link "$DOTFILES/zsh/zprofile"           "$HOME/.zprofile"
link "$DOTFILES/tmux/tmux.conf"         "$HOME/.tmux.conf"
link "$DOTFILES/ghostty/config"         "$HOME/.config/ghostty/config"
link "$DOTFILES/hammerspoon/init.lua"   "$HOME/.hammerspoon/init.lua"
link "$DOTFILES/scripts/notify.sh"      "$HOME/.notify.sh"
link "$DOTFILES/git/gitignore_global"   "$HOME/.config/git/ignore"

chmod +x "$DOTFILES/scripts/notify.sh"

# ── post-install checklist ───────────────────────────────────────────────────

echo
echo "Done. Complete these steps to finish setup:"
echo
echo "  1. Set up git identity:"
echo "       cp $DOTFILES/git/gitconfig.template ~/.gitconfig"
echo "       # then edit ~/.gitconfig and fill in your name and email"
echo
echo "  2. Grant Hammerspoon permissions (System Settings → Privacy & Security):"
echo "       - Accessibility"
echo "       - Notifications"
echo "     Then reload: Hammerspoon menu bar icon → Reload Config"
echo
echo "  3. Reload tmux config (inside an active tmux session):"
echo "       tmux source ~/.tmux.conf"
echo
echo "  4. Start a new shell (or open Ghostty) to apply zsh changes."
