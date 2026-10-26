---
name: commit
description: Use when the user wants to stage, commit, and push the current branch. Triggers on "commit this", "commit and push", "just commit".
---

# Commit and Push

Stage relevant files, write a commit message, commit, and push the branch.

## Process

1. Run `git status`, `git diff`, and `git log --oneline -5` in parallel.
2. Stage only the files relevant to the current work. Use specific file paths — never `git add -A`.
3. Write a concise commit message: 1–2 sentences focusing on the **why**. Match the repo's commit message style (e.g. `[TICKET] Description`). Ask the user to "pop the why stack" if the motivation isn't clear from the diff.
4. Commit. Never skip hooks (`--no-verify`).
5. Push the branch with `-u origin <branch>`.
6. If the push fails due to a hook, fix the issue and retry. Never force-push.

## Edge cases

- If there are no changes to commit, skip to push (if the branch hasn't been pushed yet) or skip entirely.
- Never commit `.env`, credentials, or secrets files — warn the user if any are staged.
- If the branch is behind remote, warn the user rather than force-pushing.
