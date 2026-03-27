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

# Merge hooks from $src into $dst using Python.
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
  python3 - "$dst" "$src" <<'EOF'
import json, sys

with open(sys.argv[1]) as f:
    existing = json.load(f)
with open(sys.argv[2]) as f:
    incoming = json.load(f)

existing_hooks = existing.setdefault("hooks", {})
added = []
skipped = []

for event, entries in incoming.get("hooks", {}).items():
    if event in existing_hooks:
        skipped.append(event)
    else:
        existing_hooks[event] = entries
        added.append(event)

with open(sys.argv[1], "w") as f:
    json.dump(existing, f, indent=2)
    f.write("\n")

if added:
    print(f"  added hooks: {', '.join(added)}")
if skipped:
    print(f"  skipped (already defined): {', '.join(skipped)}")
EOF
  green "  merged $dst"
}

# ── guard ────────────────────────────────────────────────────────────────────

if [[ "$(uname)" != "Darwin" ]]; then
  red "This dotfiles setup is macOS-only."
  exit 1
fi

# ── role selection ────────────────────────────────────────────────────────────

echo
echo "Are you a leader or a follower?"
echo
echo "  leader   — your machine, edits go directly into the repo (full symlinks)"
echo "  follower — adds features non-destructively alongside your existing config"
echo
printf 'Enter role [leader/follower]: '
read -r role

case "$role" in
  leader|Leader|LEADER)     role=leader ;;
  follower|Follower|FOLLOWER) role=follower ;;
  *)
    red "Unknown role '$role'. Please enter 'leader' or 'follower'."
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
  link "$DOTFILES/codex/hooks.json"       "$HOME/.codex/hooks.json"
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
  link "$DOTFILES/scripts/notify.sh" "$HOME/.notify.sh"
  chmod +x "$DOTFILES/scripts/notify.sh"
  merge_hooks_json "$DOTFILES/claude/settings.json" "$HOME/.claude/settings.json"
  merge_hooks_json "$DOTFILES/codex/hooks.json"     "$HOME/.codex/hooks.json"
fi

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
echo
echo "  3. Start a new shell (or open Ghostty) to apply zsh changes."
