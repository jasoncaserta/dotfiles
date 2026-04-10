# Global Codex Rules

## Search Hygiene

Always exclude noise directories from any search or grep:
- `node_modules/`, `**/node_modules/**`
- `dist/`, `dist-server/`, `**/dist/**`
- `__pycache__/`, `**/__pycache__/**`, `**/*.pyc`
- `.venv/`, `**/.venv/**`
- `.git/`

Pattern: `rg --glob '!node_modules/**' --glob '!dist/**' --glob '!__pycache__/**' --glob '!.venv/**'`

Use `rg -l` to identify relevant files before reading content. Limit output with `-m 20` when looking for a first occurrence.

## Large File Reads

For config files over ~20KB, never read the full file unless the task requires understanding the whole thing. Identify the relevant line range first with `rg -n`, then read only that section.

## Iterative Edits

Batch all planned changes to a file into a single pass. Do not read → edit → re-read → edit again on the same file. If verification is needed after an edit, check only the changed section.

## Build / Lint Gates

Do not run full builds or linters after every code change. Gate them to natural checkpoints: before a commit, when explicitly asked, or when debugging a build error.

## Shell Syntax Checks

`zsh -n <file>` is sufficient to check shell syntax — do not source the file to validate it.

## Long Sessions

When a task has accumulated a large amount of context and the remaining work is only PR creation, status checks, or small follow-up fixes, start a fresh session with a concise state summary instead of continuing the large context.
