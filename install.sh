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

# Merge agent settings from $src into $dst, preserving machine-local keys.
# Applies hooks, permissions, and other dotfile settings from src into dst,
# but never overwrites any key already present in dst. Safe to re-run; existing
# local config is never clobbered.
merge_settings_json() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$DOTFILES"* ]]; then
    green "  already symlinked to repo (skipped): $dst"
    return
  fi
  if [[ ! -f "$dst" ]]; then
    cp "$src" "$dst"
    green "  created $dst"
    return
  fi
  local tmp skipped_keys skipped_hooks skipped_mcp
  tmp=$(mktemp)

  skipped_keys=$(jq -rn --slurpfile d "$dst" --slurpfile s "$src" '
    [($s[0] | keys[]) |
      select(. != "mcpServers" and . != "hooks" and . != "permissions") |
      select($d[0][.] != null and $d[0][.] != $s[0][.])
    ] | join(", ")
  ')

  skipped_hooks=$(jq -rn --slurpfile d "$dst" --slurpfile s "$src" '
    [($s[0].hooks // {}) | keys[] |
      select(. as $k | ($d[0].hooks // {})[$k] != null and ($d[0].hooks // {})[$k] != ($s[0].hooks // {})[$k])
    ] | join(", ")
  ')

  skipped_mcp=$(jq -rn --slurpfile d "$dst" --slurpfile s "$src" '
    [($s[0].mcpServers // {}) | keys[] |
      select(. as $k | ($d[0].mcpServers // {})[$k] != null and ($d[0].mcpServers // {})[$k] != ($s[0].mcpServers // {})[$k])
    ] | join(", ")
  ')

  # Deep-merge: for every top-level key in src, copy it into dst only if dst
  # doesn't already have it. Shared structured keys are merged below.
  jq -s '
    .[0] as $dst | .[1] as $src |
    reduce ($src | keys[]) as $k (
      $dst;
      if ($k == "mcpServers" or $k == "hooks" or $k == "permissions") then . else
        if .[$k] == null then .[$k] = $src[$k] else . end
      end
    ) |
    if ($src.hooks // null) != null then
      .hooks = (($dst.hooks // {}) + (($src.hooks // {}) | with_entries(select(.key as $k | ($dst.hooks // {})[$k] == null))))
    else . end |
    if ($src.mcpServers // null) != null then
      .mcpServers = (($dst.mcpServers // {}) + (($src.mcpServers // {}) | with_entries(select(.key as $k | ($dst.mcpServers // {})[$k] == null))))
    else . end |
    if (($src.permissions.allow // null) != null or ($dst.permissions.allow // null) != null) then
      .permissions.allow = ((($dst.permissions.allow // []) + ($src.permissions.allow // [])) | unique)
    else . end
  ' "$dst" "$src" > "$tmp" && mv "$tmp" "$dst"

  green "  merged $dst"
  if [[ -n "$skipped_keys" || -n "$skipped_hooks" || -n "$skipped_mcp" ]]; then
    yellow "  WARNING: $dst has local conflicts — full dotfile install not applied"
    [[ -n "$skipped_keys" ]] && yellow "    skipped keys (local differs): $skipped_keys"
    [[ -n "$skipped_hooks" ]] && yellow "    skipped hook events (already defined): $skipped_hooks"
    [[ -n "$skipped_mcp" ]] && yellow "    skipped MCP servers (already defined): $skipped_mcp"
    yellow "    To apply dotfile values, remove conflicting keys from $dst and re-run install"
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
brew_install rtk
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
  link "$DOTFILES/claude/CLAUDE.md"       "$HOME/.claude/CLAUDE.md"
  link "$DOTFILES/claude/RTK.md"          "$HOME/.claude/RTK.md"
  link "$DOTFILES/claude/skills"          "$HOME/.claude/skills"
  link "$DOTFILES/codex/hooks.json"       "$HOME/.codex/hooks.json"
  link "$DOTFILES/codex/config.toml"      "$HOME/.codex/config.toml"
  link "$DOTFILES/codex/AGENTS.md"        "$HOME/.codex/AGENTS.md"
  link "$DOTFILES/codex/RTK.md"           "$HOME/.codex/RTK.md"
  link "$DOTFILES/codex/rules"            "$HOME/.codex/rules"
  link "$DOTFILES/codex/AGENTS.md"        "$HOME/AGENTS.md"
  link "$DOTFILES/gemini/settings.json"   "$HOME/.gemini/settings.json"
  link "$DOTFILES/gemini/GEMINI.md"       "$HOME/.gemini/GEMINI.md"
  link "$DOTFILES/gemini/RTK.md"          "$HOME/.gemini/RTK.md"
  link "$DOTFILES/gemini/hooks"           "$HOME/.gemini/hooks"
  link "$DOTFILES/gemini/policies"        "$HOME/.gemini/policies"
  link "$DOTFILES/zsh/p10k.zsh"           "$HOME/.p10k.zsh"
  chmod +x "$DOTFILES/scripts/notify.sh"

# ── follower: non-destructive includes + agent config links ───────────────────

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
  merge_settings_json "$DOTFILES/claude/settings.json"   "$HOME/.claude/settings.json"
  link "$DOTFILES/claude/CLAUDE.md"       "$HOME/.claude/CLAUDE.md"
  link "$DOTFILES/claude/RTK.md"          "$HOME/.claude/RTK.md"
  merge_hooks_json "$DOTFILES/codex/hooks.json"     "$HOME/.codex/hooks.json"
  link "$DOTFILES/codex/AGENTS.md"        "$HOME/.codex/AGENTS.md"
  link "$DOTFILES/codex/RTK.md"           "$HOME/.codex/RTK.md"
  link "$DOTFILES/codex/AGENTS.md"        "$HOME/AGENTS.md"
  merge_settings_json "$DOTFILES/gemini/settings.json"   "$HOME/.gemini/settings.json"
  link "$DOTFILES/gemini/GEMINI.md"       "$HOME/.gemini/GEMINI.md"
  link "$DOTFILES/gemini/RTK.md"          "$HOME/.gemini/RTK.md"
  link "$DOTFILES/gemini/hooks"           "$HOME/.gemini/hooks"
  link "$DOTFILES/gemini/policies"        "$HOME/.gemini/policies"
  # config.toml has machine-specific paths (MCP servers, project trust levels) — skip on follower
fi

ensure_git_clone "https://github.com/tmux-plugins/tpm" "$HOME/.tmux/plugins/tpm"

# Write the resolved dotfiles path so tmux helpers can locate scripts at
# runtime regardless of where the repo was cloned.
mkdir -p "$HOME/.config/dotfiles"
printf '%s' "$DOTFILES" > "$HOME/.config/dotfiles/path"
green "  wrote dotfiles path → ~/.config/dotfiles/path"

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
# ── tmux plugins ──────────────────────────────────────────────────────────────

echo "Installing tmux plugins..."
if [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 && green "  tmux plugins installed"
else
  yellow "  TPM not found; skipped plugin install"
fi

if tmux list-sessions >/dev/null 2>&1; then
  tmux source ~/.tmux.conf 2>&1 && green "  tmux config reloaded"
else
  yellow "  no active tmux session; reload manually: tmux source ~/.tmux.conf"
fi
echo

# ── Hammerspoon permissions ───────────────────────────────────────────────────

_hs_has_accessibility() {
  local tcc_db="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
  sqlite3 "$tcc_db" \
    "SELECT allowed FROM access WHERE service='kTCCServiceAccessibility' AND client='org.hammerspoon.Hammerspoon';" \
    2>/dev/null | grep -q '^1$'
}
if _hs_has_accessibility; then
  yellow "  Hammerspoon Accessibility already enabled — skipping System Settings."
else
  echo "Hammerspoon needs Accessibility + Notifications — opening System Settings..."
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  yellow "  → Enable Hammerspoon under Accessibility, then Notifications."
  yellow "  → Then: Hammerspoon menu bar icon → Reload Config"
fi
echo

# ── remaining manual steps ────────────────────────────────────────────────────

echo "One last step:"
echo "  • Start a new shell (or open Ghostty) to apply zsh changes."
echo
echo "After reboot, reopening Ghostty will auto-attach tmux and restore your last saved layout."
