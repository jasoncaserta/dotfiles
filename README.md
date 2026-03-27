# dotfiles

Ghostty + tmux + zsh setup for macOS with smart terminal notifications.

## Features

**Notifications for long-running commands**
Any command that takes longer than 3 seconds triggers a macOS notification when it finishes. The notification title shows the command name and clicking it focuses Ghostty and jumps directly to the tmux window where it ran. Threshold is configurable via `TERMINAL_ALERT_MIN_SECONDS`.

**tmux attention indicator**
When a notification fires for a background tmux window, a 🔔 appears in the status bar for that window. It clears automatically when you switch to the window.

**Auto-attach to a persistent tmux session**
Opening Ghostty automatically attaches to (or creates) a persistent tmux session named `main`. Set `NO_AUTO_TMUX=1` to skip this.

**Window auto-rename**
The tmux window title updates to the currently running command and resets to `zsh` when it finishes.

**Codex support**
Running `codex` starts a background monitor that sends a notification whenever Codex is waiting for input ("needs attention"). The monitor cleans up on exit.

**Notification click navigation**
Clicking a notification focuses Ghostty and switches to the exact tmux window that triggered it, handled via Hammerspoon.

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

The installer symlinks each config file to its proper location. Existing files are backed up as `<file>.bak` before being replaced.

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
