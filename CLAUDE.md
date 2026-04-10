# dotfiles — Claude Code Rules

## p10k.zsh Edits (95KB — read sections, not the whole file)

Never read the full `~/.p10k.zsh` / `zsh/p10k.zsh` unless the task requires understanding the entire file. Instead:

1. Find the relevant section first: `rg -n "<segment_name|POWERLEVEL9K_>" zsh/p10k.zsh | head -20`
2. Read only that line range using `Read` with `offset` + `limit`
3. Make all planned changes in one `Edit` pass
4. Verify by re-reading only the changed lines — not the full file

For prompt color/icon/segment tweaks, the relevant block is almost always under the named segment (e.g. `POWERLEVEL9K_VCS_*`, `POWERLEVEL9K_DIR_*`). One targeted read + one edit is the whole workflow.

## tmux / zsh Debugging

Instead of manually repeating `tmux source-file`, `tmux show-hooks`, `zsh -n`, and resurrection file inspections, run the diagnostic script first:

```bash
bash /Users/jasoncaserta/Projects/dotfiles/scripts/tmux-check.sh
```

This script runs the common check sequence in one pass and prints a summary. Only dig deeper into individual files if the script output points to a specific issue.

For shell syntax errors: `zsh -n <file>` is sufficient — do not source the file to check syntax.

## Install / Symlink Changes

`install.sh` manages all symlinks. When adding a new dotfile:
1. Add the symlink entry to `install.sh`
2. Run `./install.sh` once to apply
3. Do not manually `ln -sf` and also edit `install.sh` — pick one path.
