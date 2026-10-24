# Local todos: fold parked cleanups into the PR you're already making

James parks minor cleanups as `LOCAL-TODO LT-n:` comments: uncommitted, in a repo's main
checkout, registered in `~/.claude/local-todos.jsonl` (the `local-todo` skill adds them).
He expects them to get done without him asking again, by whichever PR next touches that code.
(James, 2026-10-20.)

## When you're working on a PR

1. **Check for todos in what you touch.** Run `local-todo touching` in the checkout you're
   working in (a worktree is fine) before you open the PR, and again before marking it ready.
   It lists open todos in files the branch changes. The comment itself only exists in the
   main checkout, so a worktree won't show it to you; the register is the reliable source.
2. **Fold it in** when the todo sits in or next to code the PR changes. Make the change as its
   own commit, then `local-todo claim LT-n --repo <repo> --pr <N> --session <uuid>`. Mention it
   in the PR description in a line, as the small rider it is.
3. **Leave it out**, and say so in a line to James, when the PR is high priority (an incident
   fix, a hotfix, a time-boxed release) or sensitive (security, money movement, a change that
   needs a narrow diff to review safely). Leave it out if the change would need its own
   testing or review beyond what the PR already gets, too. The todo stays open for the next PR.
4. **Never commit the comment.** In the main checkout, stage files that carry one with
   `local-todo stage <path>`, never `git add`. The repo's `pre-commit` hook refuses a staged
   `LOCAL-TODO` line. Don't bypass it with `--no-verify`.
5. **If the change comes back out of the PR** (review pushback, a split), `local-todo unclaim`.

## When the PR merges

`pr-task` runs `local-todo merged --repo <repo> --pr <N>` when the PR reaches `deploy`. Run it
yourself if the PR has no `pr-task` row. It closes the todo, deletes the comment from the main
checkout, and prints any other PR that also claimed it. For each one, `SendMessage` the named
session (look it up in `ListAgents`, or `pr-task find <N>`): "LT-n landed in <repo>#<N>; drop
it from <repo>#<M>." That session takes the change back out, or rebases it away, and runs
`local-todo unclaim`.

## Housekeeping

- `local-todo list` flags a repo with more than five open todos. When it does, suggest to
  James a dedicated PR that clears them.
- `local-todo check` finds comments lost to git mishaps (a `checkout --`, a dropped stash).
  Run it during nightly maintenance or whenever `list` shows `COMMENT MISSING`, and restore
  with `--restore`.
- **Anchor a new todo on a line that's both on disk and in `git show origin/main:<file>`.** The main checkout is often behind and can't always fast-forward (someone's half-finished merge, uncommitted work). An anchor on both survives the catch-up, and `check --restore` still finds it. Don't fast-forward or touch someone else's conflicted checkout to get a fresher anchor. (LT-4, 2026-10-24.)

Related: `pr-tasks.md` (PR stages; `deploy` triggers the close), `git-and-prs.md` (staging named
files only; `local-todo stage` is the exception for files carrying a todo comment).
