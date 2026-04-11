# Global Claude Code Rules

## Effort Calibration

- Trivial → fast, minimal reads
- Mechanical → follow patterns
- Complex → verify, explore, reason carefully

## Search Hygiene

Always exclude noise directories from any search or grep:
- `node_modules/`, `**/node_modules/**`
- `dist/`, `dist-server/`, `**/dist/**`
- `__pycache__/`, `**/__pycache__/**`, `**/*.pyc`
- `.venv/`, `**/.venv/**`
- `.git/`

Pattern: `rg --glob '!node_modules/**' --glob '!dist/**' --glob '!__pycache__/**' --glob '!.venv/**'`

List relevant files before reading contents (e.g. `rg -l`).
Limit output with `-m 20` when locating definitions.

## Minimal Context First

- Identify the smallest set of relevant files
- Read only what is necessary
- Avoid loading unrelated files

## Large File Reads

For files over ~20KB:
- Do not read full contents unless required
- Locate relevant lines with `rg -n`
- Read only the needed section

## Iterative Edits

- Batch all changes into a single pass
- Do not read → edit → re-read → edit repeatedly
- If verifying, read only the modified section

## Change Scope

- Make the smallest possible change
- Do not refactor unrelated code

## Code Style

- Match existing naming, formatting, and structure
- Do not introduce new styles unnecessarily

## Verification

- Do not assume behavior
- Search for usages and definitions before editing

## Build / Lint Gates

Run builds or linters only:
- Before commit
- When explicitly requested
- When debugging errors

## Shell Syntax Checks

Use `zsh -n <file>` to validate syntax.
Do not source files.

## Long Sessions

When context becomes large and only small tasks remain:
- Start a new session
- Provide a concise state summary