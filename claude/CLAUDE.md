# Global Claude Code Rules

## Search Hygiene

Always exclude noise directories from any search or grep:
- `node_modules/`, `**/node_modules/**`
- `dist/`, `dist-server/`, `**/dist/**`
- `__pycache__/`, `**/__pycache__/**`, `**/*.pyc`
- `.venv/`, `**/.venv/**`
- `.git/`

Pattern: `rg --glob '!node_modules/**' --glob '!dist/**' --glob '!__pycache__/**' --glob '!.venv/**'`

Before dumping content matches, use `rg -l` to identify which files are relevant, then read only those files.

Limit grep output with `-m 20` when hunting for a definition or first occurrence. Use `head`/line-range reads instead of full-file reads when you only need a section.

## Large File Reads

For config files over ~20KB (e.g. p10k.zsh at 95KB), never read the full file unless the task requires understanding the whole file. Use `Read` with `offset`/`limit` to read only the section being changed. Identify the relevant line range first with a targeted `rg -n`.

## Iterative Edits

Batch all planned changes to a file into a single pass. Do not read → edit → re-read → edit again on the same file within a session. If verification is needed after an edit, re-read only the changed section, not the whole file.

## Build / Lint Gates

Do not run full builds or linters after every code change. Gate them to natural checkpoints: before a commit, when explicitly asked, or when debugging a build error.
