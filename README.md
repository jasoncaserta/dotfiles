# dotfiles

Ghostty + tmux + zsh setup for macOS with smart terminal notifications.

> **Tab terminology:** "tab" means a tmux window throughout — Ghostty native tabs aren't available in the quick terminal.

## What you get

**Persistent tmux session**
Ghostty always attaches to (or creates) a session named `main`. Works in the quick terminal. Set `NO_AUTO_TMUX=1` to skip.

**Smart auto-save**
Snapshots save automatically every 30 seconds via a background loop that starts with Ghostty and runs as long as tmux is alive. Only one loop runs at a time. Green text appears in the status bar for 5 seconds after each save instead of the default resurrect banner.

**Restore picker**
On a fresh Ghostty launch when tmux is not running, an interactive picker shows recent saves grouped by type:

```
Restore tmux session?

  Auto saves:
  > [1] 2m ago
    [2] 35m ago

  Manual saves:
    [3] 1h ago

    [n] New session

  ↑↓ or 1-3/n, Enter to confirm
```

If the quick terminal and a regular Ghostty window open simultaneously, both show the picker; whichever you answer first wins and the other dismisses automatically.

**Status bar save times**
The top-right of the status bar shows the age of the last auto and manual save:

```
auto: 3m ago  manual: 1h ago
```

**Long-running command notifications**
Any command taking longer than 3 seconds triggers a macOS notification when it finishes. The notification title shows the command name; clicking it focuses Ghostty and jumps to the tmux tab where it ran. Threshold is configurable via `TERMINAL_ALERT_MIN_SECONDS`.

**Claude and Codex notifications**
Both send notifications when they need attention or finish a turn.

| Trigger | Claude | Codex |
|---------|--------|-------|
| Turn done | ✓ hook | ✓ hook |
| Asks a question | ✓ hook | ✓ polling |
| Permission prompt | ✓ hook | ✓ polling |
| Elicitation / MCP | ✓ hook | ✗ |

The `codex` shell wrapper automatically passes `-c features.codex_hooks=true`. Both `claude/settings.json` and `codex/hooks.json` are included and set up by the installer. tmux-resurrect is configured to relaunch `claude` and `codex` panes after restore.

**Tab attention indicator**
When a notification fires for a background tab, a 🔔 appears in the status bar for that tab. It clears automatically when you switch to it.

**Tab auto-rename**
The tab title updates to the currently running command and resets to `zsh` when it finishes.

## Requirements

- macOS
- [Ghostty](https://ghostty.org) — terminal
- [tmux](https://github.com/tmux/tmux) — `brew install tmux`
- [Hammerspoon](https://www.hammerspoon.org) — handles notification clicks
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

**Follower** — never touches your existing config files. Appends include directives alongside your existing settings. For Claude and Codex hooks it merges only events not already defined. Re-running is safe — all steps are idempotent.

To get updates as a follower: `git pull && ./install.sh`. Behavior changes are picked up by `git pull` alone; new features require re-running `install.sh`.

## Post-install

**1. Hammerspoon permissions**

Open System Settings → Privacy & Security and grant Hammerspoon:
- Accessibility
- Notifications

Then reload: Hammerspoon menu bar icon → Reload Config.

**2. Hammerspoon notification style**

Open System Settings → Notifications → Hammerspoon and set Alert Style to **Persistent**. This keeps notifications on screen until you switch to the relevant tab (or dismiss them manually).

![Hammerspoon notification settings](docs/hammerspoon-notification-settings.png)

**3. Reload tmux** (inside an active tmux session)

```bash
tmux source ~/.tmux.conf
~/.tmux/plugins/tpm/bin/install_plugins
```

**4. Restart your shell** or open a new Ghostty window for zsh changes to take effect.

After a reboot, open Ghostty and use the restore picker to choose a snapshot or start a new session.

## Customization

| Variable | Default | Description |
|----------|---------|-------------|
| `TERMINAL_ALERT_MIN_SECONDS` | `3` | Minimum runtime before a done notification fires |
| `NO_AUTO_TMUX` | unset | Set to any value to skip auto-attach to tmux on Ghostty launch |

Export these in `~/.zprofile` to change the defaults.

## Key bindings

Run `jason help` in a shell to print these key bindings in the terminal.

### Ghostty

| Binding | Action |
|---------|--------|
| <code>Cmd+`</code> | Toggle quick terminal (global) |
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
| `prefix Ctrl-s` | Save tmux snapshot manually |
| `prefix Ctrl-r` | Restore tmux snapshot manually |
| `M-Left / M-Right` | Previous / next tab |
| `Middle-click status bar` | Kill clicked tab |
