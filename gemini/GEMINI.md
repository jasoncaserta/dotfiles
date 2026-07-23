# dotfiles — Gemini CLI Rules

## Effort Calibration

- Trivial → fast, minimal reads, no overthinking
- Mechanical → follow patterns exactly
- Complex → verify, explore, reason carefully

## Search Hygiene

Use `rtk grep` for all searches — never bare `rg` or `/opt/homebrew/bin/rg`.

Exclude noise dirs:
node_modules/, dist/, __pycache__/, .venv/, .git/

Pattern: rtk grep '<pattern>' <path> --glob '!node_modules/**' --glob '!dist/**' --glob '!__pycache__/**' --glob '!.venv/**'
For ripgrep passthrough flags such as file-only output, put them after `--`.

- List files before reading: `rtk grep '<pattern>' <path> -- --files-with-matches`
- Read only necessary files/sections
- Limit matches (e.g. -m 20)
- Avoid unrelated context

## Early Exit

Stop once sufficient information is found.

## Large File Reads

- Avoid full reads unless required
- Locate lines first: `rtk grep '<pattern>' <path>`
- Read only needed sections

## Iterative Edits

- Batch changes into one pass
- Avoid repeated read → edit cycles
- When verifying, read only modified sections

## Editing Rules

- Make the smallest possible change
- Match existing style and structure
- Do not refactor unrelated code

## Verification

If behavior is unclear:
- Search for usages
- Read definitions
- Confirm assumptions

## Build / Lint

Run only:
- Before commit
- When requested
- When debugging errors

## Shell Syntax Checks

Use `zsh -n <file>`. Do not source.

## Long Sessions

When context is large and tasks are small:
- Start a new session
- Provide a concise state summary

@RTK.md
