# dotfiles

Ghostty + tmux + zsh setup for macOS with smart terminal notifications.

## Features

**Notifications for long-running commands**
Any command that takes longer than 3 seconds triggers a macOS notification when it finishes. The notification title shows the command name and clicking it focuses Ghostty and jumps directly to the tmux tab where it ran. Threshold is configurable via `TERMINAL_ALERT_MIN_SECONDS`.

**Claude and Codex support**
Both Claude and Codex send notifications when they need attention or finish a turn. Claude uses hooks; Codex uses pane-content polling where no hook is available (hooks for codex are limited and currently in beta).

| Trigger | Claude | Codex |
|---------|--------|-------|
| Turn done | ✓ hook → "done!" | ✓ hook → "done!" |
| Asks a question | ✓ hook → "needs attention" | ✓ polling → "needs attention" |
| Permission prompt | ✓ hook → "needs attention" | ✓ polling → "needs attention" |
| Elicitation / MCP | ✓ hook → "needs attention" | ✗ not available |

The `codex` shell wrapper automatically passes `-c features.codex_hooks=true` to enable hook support. Both `claude/settings.json` and `codex/hooks.json` are included in the repo and set up by the installer.

**tmux attention indicator**
When a notification fires for a background tmux tab, a 🔔 appears in the status bar for that tab. It clears automatically when you switch to it.

**Notification click navigation**
Clicking a notification focuses Ghostty and switches to the exact tmux tab that triggered it, handled via Hammerspoon.

**Auto-attach to a persistent tmux session**
Opening Ghostty automatically attaches to (or creates) a persistent tmux session named `main`. Set `NO_AUTO_TMUX=1` to skip this.

**Window auto-rename**
The tmux tab title updates to the currently running command and resets to `zsh` when it finishes.

## Requirements

- macOS
- [Ghostty](https://ghostty.org) — terminal
- [tmux](https://github.com/tmux/tmux) — `brew install tmux`
- [Hammerspoon](https://www.hammerspoon.org) — macOS automation (handles notification clicks)
- [Homebrew](https://brew.sh)
- zsh (macOS default)

## Install

```bash
git clone https://github.com/jasoncaserta/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
./install.sh
```

`./install.sh` installs the **follower** setup by default.

Use leader mode explicitly:

```bash
./install.sh --leader
```

**Leader** — sets up full symlinks so edits to your dotfiles (e.g. `~/.zshrc`) write directly into the repo. Just commit and push. `git pull` on any other machine picks up changes immediately.

**Follower** — never touches your existing config files. Appends include directives (`source`, `source-file`, `config-file`, `dofile`) alongside your existing settings. For Claude and Codex hooks it merges only events not already defined. Re-running is safe — all steps are idempotent.

To get updates as a follower: `git pull && ./install.sh`. Behavior changes to existing features are picked up by `git pull` alone; new features require re-running `install.sh`.

## Post-install

**1. Hammerspoon permissions**

Open System Settings → Privacy & Security and grant Hammerspoon:
- Accessibility
- Notifications

Then reload: Hammerspoon menu bar icon → Reload Config.

**2. Reload tmux** (inside an active tmux session)

```bash
tmux source ~/.tmux.conf
```

**3. Restart your shell** or open a new Ghostty window for zsh changes to take effect.

## Customization

| Variable | Default | Description |
|----------|---------|-------------|
| `TERMINAL_ALERT_MIN_SECONDS` | `3` | Minimum runtime before a done notification fires |
| `NO_AUTO_TMUX` | unset | Set to any value to skip auto-attach to tmux on Ghostty launch |

Export these in `~/.zprofile` to change the defaults.

## Key bindings

### Ghostty

These bindings work at the Ghostty level. The tmux ones send key sequences directly to tmux.

| Binding | Action |
|---------|--------|
| ``Cmd+``` | Toggle quick terminal (global) |
| `Ctrl+Tab` | Next tmux tab |
| `Ctrl+Shift+Tab` | Previous tmux tab |
| `Cmd+T` | New tmux tab |
| `Cmd+W` | Close tmux tab |
| `Cmd+Enter` | Toggle fullscreen |
| `Cmd+Shift+Enter` | Zoom current split |
| `Cmd+D` | New split right |
| `Cmd+Shift+D` | New split down |
| `Cmd+[` | Previous split |
| `Cmd+]` | Next split |
| `Cmd+F` | Search scrollback |
| `Cmd+K` | Clear screen |

### tmux

tmux prefix is `Ctrl-A`.

| Binding | Action |
|---------|--------|
| `prefix \|` | Split horizontal |
| `prefix -` | Split vertical |
| `prefix h/j/k/l` | Navigate panes (vim-style) |
| `prefix r` | Reload tmux config |
| `prefix 0` | Jump to window 10 |
| `M-Left / M-Right` | Previous / next window |
| `Middle-click status bar` | Kill clicked window |
