# dotfiles Codex Rules

## p10k.zsh Edits

`zsh/p10k.zsh` is large. Do not read the full file unless the task requires understanding the whole file.

1. Find the relevant section first with `rg -n "<segment_name|POWERLEVEL9K_>" zsh/p10k.zsh | head -20`.
2. Read only the relevant range with `sed -n`.
3. Make all planned changes in one edit pass.
4. Verify by re-reading only the changed lines.

## tmux / zsh Debugging

Use the diagnostic script before manually repeating tmux and shell checks:

```bash
bash /Users/jasoncaserta/Projects/dotfiles/scripts/tmux-check.sh
```

This replaces repeated ad hoc runs of `tmux source-file`, `tmux show-hooks`, `zsh -n`, and resurrection-file inspections. Only dig deeper into individual files when the diagnostic output points to a specific issue.

For shell syntax checks, `zsh -n <file>` is sufficient; do not source the file just to check syntax.

## Search Hygiene

Use `rg -l` before dumping matches, cap broad searches with `-m 20` or `head`, and avoid searching dependency folders, generated files, session histories, or home-directory trees unless the task explicitly requires it.

## Install / Symlink Changes

`install.sh` manages symlinks. When adding a new dotfile:

1. Add the symlink entry to `install.sh`.
2. Run `./install.sh` once to apply it.
3. Do not both manually `ln -sf` and edit `install.sh`; use one path.
