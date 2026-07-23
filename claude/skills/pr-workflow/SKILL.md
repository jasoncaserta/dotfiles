---
name: pr-create-review
description: Full PR workflow — create a branch, commit staged changes, push, open a PR, review the diff, and post the review as a GitHub comment. Use whenever the user says "open a PR", "make a PR and review it", "branch PR and review", or any variation of wanting to publish and review changes.
disable-model-invocation: true
---

# PR Create & Review

Full end-to-end workflow: branch → commit → push → open PR → review → post review as GitHub comment.

## Current Context
- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Diff: !`git diff HEAD`

## Steps

### 1. Branch

If already on a feature branch (not `main`/`master`/`dev`), skip. Otherwise create one:

```
git checkout -b <type>/<short-description>
```

Name the branch from the nature of the changes (e.g. `fix/`, `feat/`, `chore/`).

### 2. Commit

Stage all modified tracked files and commit with a conventional commit message:

```
git add <changed files>
git commit -m "<type>: <summary>\n\n<bullet details>\n\nCo-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### 3. Push & open PR

```
git push -u origin <branch>
gh pr create --title "<type>: <summary>" --body "<body>"
```

PR body template:
```markdown
## Summary
- <bullet points>

## Test plan
- [ ] <test steps>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### 4. Review the PR

Fetch the diff and PR metadata:
```
gh pr diff <number>
gh pr view <number> --json title,body,files,commits
```

Analyze every changed file. Structure the review as:

```markdown
## Code Review

### <file or section>
<observations — correctness, edge cases, performance, style>

### Overall
<verdict: Approved / Needs changes, and why>
```

Be specific: call out line-level issues with the surrounding context. If something is correct and non-obvious, say so. Flag anything that could silently fail or cause a regression.

### 5. Post review as comment

```
gh pr comment <number> --body "<review markdown>"
```

Return the comment URL to the user.
