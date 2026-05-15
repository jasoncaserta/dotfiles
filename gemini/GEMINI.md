# dotfiles — Gemini CLI Rules

## Effort Calibration

- Trivial → fast, minimal reads, no overthinking
- Mechanical → follow patterns exactly
- Complex → verify, explore, reason carefully

## Search Hygiene

Exclude noise dirs:
node_modules/, dist/, __pycache__/, .venv/, .git/

Pattern: rg --glob '!node_modules/**' --glob '!dist/**' --glob '!__pycache__/**' --glob '!.venv/**'

- List files before reading (rg -l)
- Read only necessary files/sections
- Limit matches (e.g. -m 20)
- Avoid unrelated context

## Early Exit

Stop once sufficient information is found.

## Large File Reads

- Avoid full reads unless required
- Locate lines first (rg -n)
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
