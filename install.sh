#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── helpers ──────────────────────────────────────────────────────────────────

green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }

# Symlink $src → $dst. Backs up real files; replaces stale symlinks.
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

ensure_git_clone() {
  local repo="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -d "$dst/.git" ]]; then
    green "  already present (skipped): $dst"
    return
  fi
  if ! command -v git >/dev/null 2>&1; then
    yellow "  git not found; skipped clone for $repo"
    return
  fi
  git clone "$repo" "$dst"
  green "  cloned $dst"
}

# Append $line to $file only if $line is not already present.
# Skips files that are already symlinks into this repo (already "included").
append_if_missing() {
  local file="$1" line="$2"
  mkdir -p "$(dirname "$file")"
  if [[ -L "$file" && "$(readlink "$file")" == "$DOTFILES"* ]]; then
    green "  already symlinked to repo (skipped): $file"
    return
  fi
  if [[ ! -f "$file" ]]; then
    printf '%s\n' "$line" > "$file"
    green "  created $file"
  elif grep -qF "$line" "$file"; then
    green "  already present in $file (skipped)"
  else
    printf '\n%s\n' "$line" >> "$file"
    green "  appended to $file"
  fi
}

# Merge hooks from $src into $dst using jq.
# Adds hook entries for any event not already defined in $dst; skips events
# that already exist so the user's existing hooks are never overwritten.
merge_hooks_json() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ ! -f "$dst" ]]; then
    cp "$src" "$dst"
    green "  created $dst"
    return
  fi
  local tmp added skipped
  tmp=$(mktemp)
  added=$(jq -rn --slurpfile d "$dst" --slurpfile s "$src" \
    '[($s[0].hooks // {}) | keys[] | select(. as $k | ($d[0].hooks // {})[$k] == null)] | select(length > 0) | join(", ")')
  skipped=$(jq -rn --slurpfile d "$dst" --slurpfile s "$src" \
    '[($s[0].hooks // {}) | keys[] | select(. as $k | ($d[0].hooks // {})[$k] != null)] | select(length > 0) | join(", ")')
  jq -s '
    .[0] as $dst | .[1] as $src |
    $dst | .hooks = (
      ($dst.hooks // {}) +
      (($src.hooks // {}) | with_entries(select(.key as $k | ($dst.hooks // {})[$k] == null)))
    )
  ' "$dst" "$src" > "$tmp" && mv "$tmp" "$dst"
  [[ -n "$added" ]] && green "  added hooks: $added"
  [[ -n "$skipped" ]] && green "  skipped (already defined): $skipped"
  green "  merged $dst"
}

# ── guard ────────────────────────────────────────────────────────────────────

if [[ "$(uname)" != "Darwin" ]]; then
  red "This dotfiles setup is macOS-only."
  exit 1
fi

# ── dependencies ──────────────────────────────────────────────────────────────

brew_install() {
  local pkg="$1"
  if brew list "$pkg" >/dev/null 2>&1; then
    green "  already installed: $pkg"
  else
    echo "  installing $pkg..."
    brew install "$pkg"
    green "  installed $pkg"
  fi
}

brew_install_cask() {
  local pkg="$1"
  if brew list --cask "$pkg" >/dev/null 2>&1; then
    green "  already installed: $pkg"
  else
    echo "  installing $pkg..."
    brew install --cask "$pkg"
    green "  installed $pkg"
  fi
}

if ! command -v brew >/dev/null 2>&1; then
  yellow "Homebrew not found — install it from https://brew.sh then re-run."
  exit 1
fi

echo "Installing dependencies..."
brew_install tmux
brew_install powerlevel10k
brew_install eza
brew_install zoxide
brew_install fzf
brew_install jq
brew_install zsh-autosuggestions
brew_install_cask ghostty
brew_install_cask hammerspoon
brew_install_cask font-jetbrains-mono-nerd-font
echo

# ── role selection ────────────────────────────────────────────────────────────

role=follower
case "${1:-}" in
  "")
    ;;
  --leader)
    role=leader
    ;;
  *)
    red "Usage: ./install.sh [--leader]"
    exit 1
    ;;
esac

echo
echo "Setting up as $role from $DOTFILES"
echo

# ── leader: full symlinks ─────────────────────────────────────────────────────

if [[ "$role" == leader ]]; then
  link "$DOTFILES/zsh/zshrc"              "$HOME/.zshrc"
  link "$DOTFILES/zsh/zprofile"           "$HOME/.zprofile"
  link "$DOTFILES/tmux/tmux.conf"         "$HOME/.tmux.conf"
  link "$DOTFILES/ghostty/config"         "$HOME/.config/ghostty/config"
  link "$DOTFILES/hammerspoon/init.lua"   "$HOME/.hammerspoon/init.lua"
  link "$DOTFILES/scripts/notify.sh"      "$HOME/.notify.sh"
  link "$DOTFILES/git/gitignore_global"   "$HOME/.config/git/ignore"
  link "$DOTFILES/claude/settings.json"   "$HOME/.claude/settings.json"
  link "$DOTFILES/claude/skills"          "$HOME/.claude/skills"
  link "$DOTFILES/codex/hooks.json"       "$HOME/.codex/hooks.json"
  link "$DOTFILES/zsh/p10k.zsh"           "$HOME/.p10k.zsh"
  chmod +x "$DOTFILES/scripts/notify.sh"

# ── follower: non-destructive includes + hook merge ───────────────────────────

else
  append_if_missing "$HOME/.zshrc"    "source \"$DOTFILES/zsh/zshrc\""
  append_if_missing "$HOME/.zprofile" "export PATH=\"/opt/homebrew/bin:\$PATH\""
  append_if_missing "$HOME/.tmux.conf" "source-file \"$DOTFILES/tmux/tmux.conf\""
  append_if_missing "$HOME/.config/ghostty/config" "config-file = $DOTFILES/ghostty/config"
  append_if_missing "$HOME/.hammerspoon/init.lua" "dofile(\"$DOTFILES/hammerspoon/init.lua\")"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    append_if_missing "$HOME/.config/git/ignore" "$line"
  done < "$DOTFILES/git/gitignore_global"
  link "$DOTFILES/scripts/notify.sh"      "$HOME/.notify.sh"
  link "$DOTFILES/zsh/p10k.zsh"           "$HOME/.p10k.zsh"
  chmod +x "$DOTFILES/scripts/notify.sh"
  merge_hooks_json "$DOTFILES/claude/settings.json" "$HOME/.claude/settings.json"
  merge_hooks_json "$DOTFILES/codex/hooks.json"     "$HOME/.codex/hooks.json"
fi

ensure_git_clone "https://github.com/tmux-plugins/tpm" "$HOME/.tmux/plugins/tpm"

# ── post-install ──────────────────────────────────────────────────────────────

echo
if [[ "$role" == leader ]]; then
  echo "Done. Symlinks are live — edits to your dotfiles go directly into the repo."
  echo
  echo "Workflow:"
  echo "  1. Edit any dotfile normally (e.g. ~/.zshrc, ~/.tmux.conf)"
  echo "  2. cd $DOTFILES && git add -A && git commit -m '...' && git push"
  echo "  3. On any other machine: git pull  (changes are live immediately)"
  echo
else
  echo "Done. To get future updates: git pull && ./install.sh"
  echo
fi
echo "Complete these steps if this is a fresh machine:"
echo
echo "  1. Grant Hammerspoon permissions (System Settings → Privacy & Security):"
echo "       - Accessibility"
echo "       - Notifications"
echo "     Then reload: Hammerspoon menu bar icon → Reload Config"
echo
echo "  2. Reload tmux config (inside an active tmux session):"
echo "       tmux source ~/.tmux.conf"
echo "       ~/.tmux/plugins/tpm/bin/install_plugins"
echo
echo "  3. Start a new shell (or open Ghostty) to apply zsh changes."
echo
echo "After reboot, reopening Ghostty will auto-attach tmux and restore your last saved layout."
