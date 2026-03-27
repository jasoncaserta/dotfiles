# dotfiles

Ghostty + tmux + zsh setup for macOS with smart terminal notifications.

## Features

**Notifications for long-running commands**
Any command that takes longer than 3 seconds triggers a macOS notification when it finishes. The notification title shows the command name and clicking it focuses Ghostty and jumps directly to the tmux window where it ran. Threshold is configurable via `TERMINAL_ALERT_MIN_SECONDS`.

**Claude and Codex support**
Both Claude and Codex send notifications when they need attention or finish a turn. Claude uses hooks; Codex uses pane-content polling where no hook is available (hooks for codex are limited and currently in beta).

| Trigger | Claude | Codex |
|---------|--------|-------|
| Turn done | ✓ hook → "done!" | ✓ hook → "done!" |
| Asks a question | ✓ hook → "needs attention" | ✓ polling → "needs attention" |
| Permission prompt | ✓ hook → "needs attention" | ✓ polling → "needs attention" |
| Elicitation / MCP | ✓ hook → "needs attention" | ✗ not available |

The `codex` shell wrapper automatically passes `-c features.codex_hooks=true` to enable hook support. Both `claude/settings.json` and `codex/hooks.json` are included and symlinked by the installer.

**tmux attention indicator**
When a notification fires for a background tmux window, a 🔔 appears in the status bar for that window. It clears automatically when you switch to the window.

**Notification click navigation**
Clicking a notification focuses Ghostty and switches to the exact tmux window that triggered it, handled via Hammerspoon.

**Auto-attach to a persistent tmux session**
Opening Ghostty automatically attaches to (or creates) a persistent tmux session named `main`. Set `NO_AUTO_TMUX=1` to skip this.

**Window auto-rename**
The tmux window title updates to the currently running command and resets to `zsh` when it finishes.

## Requirements

- macOS
- [Ghostty](https://ghostty.org) — terminal
- [tmux](https://github.com/tmux/tmux) — `brew install tmux`
- [Hammerspoon](https://www.hammerspoon.org) — macOS automation (handles notification clicks)
- [Homebrew](https://brew.sh)
- zsh (macOS default)

## Install

There are two scripts depending on your use case.

### Your own machine (`creator.sh`)

Sets up full symlinks so edits to your dotfiles go directly into the repo. Edit normally, commit, and push — `git pull` on any other machine picks up changes instantly.

```bash
git clone https://github.com/jasoncaserta/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
./creator.sh
```

### Someone else's machine (`install.sh`)

Non-destructive — never replaces existing config files. Instead it appends an include directive to each one (`source`, `source-file`, `config-file`, `dofile`) so existing settings are preserved. For Claude and Codex it merges only the hook events that aren't already defined. Re-running is safe — all steps are idempotent.

```bash
git clone https://github.com/jasoncaserta/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
./install.sh
```

Since the include directives point at the repo files, `git pull` is all you need to pick up changes — no need to re-run `install.sh` unless new files are added.

## Post-install

**1. Git identity**

```bash
cp ~/Projects/dotfiles/git/gitconfig.template ~/.gitconfig
# edit ~/.gitconfig and fill in your name and email
```

**2. Hammerspoon permissions**

Open System Settings → Privacy & Security and grant Hammerspoon:
- Accessibility
- Notifications

Then reload: Hammerspoon menu bar icon → Reload Config.

**3. Reload tmux** (inside an active tmux session)

```bash
tmux source ~/.tmux.conf
```

**4. Restart your shell** or open a new Ghostty window for zsh changes to take effect.

## Customization

| Variable | Default | Description |
|----------|---------|-------------|
| `TERMINAL_ALERT_MIN_SECONDS` | `3` | Minimum runtime before a done notification fires |
| `NO_AUTO_TMUX` | unset | Set to any value to skip auto-attach to tmux on Ghostty launch |

Export these in `~/.zprofile` to change the defaults.

## Key bindings

tmux prefix is `Ctrl-A`.

| Binding | Action |
|---------|--------|
| `prefix c` | New window (inherits current path) |
| `prefix W` | Kill window |
| `prefix \|` | Split horizontal |
| `prefix -` | Split vertical |
| `prefix h/j/k/l` | Navigate panes (vim-style) |
| `prefix r` | Reload tmux config |
| `M-Left / M-Right` | Previous / next window |
| `Middle-click status bar` | Kill clicked window |
| `prefix 0` | Jump to window 10 |

Ghostty quick terminal is toggled with `Cmd+\`` (global shortcut).
