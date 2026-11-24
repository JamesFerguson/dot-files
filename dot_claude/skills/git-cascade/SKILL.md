---
name: git-cascade
description: Commit a change to one branch of a stack of branches (PRs based on each other) and carry it up every branch stacked on it, then optionally force-push them all with a lease. Checks out the right branch first, refuses anything that would rebase main or a branch held by another worktree, aborts a conflicting rebase cleanly, and verifies each branch kept its own commits and gained exactly the new one. Use when the user says "cascade", "commit to the bottom of the stack", "restack", "carry this up the stack", "rebase the stack", or when committing to a branch that other branches are based on.
---

# git-cascade

A fix to the bottom PR of a stack has to land on every PR above it. By hand that's: check out the
right branch, commit, `git rebase --update-refs --onto <new> <old> <top>`, force-push each branch.
The easy mistake is committing while the top branch is checked out: the cascade then rebuilds the
top as "bottom plus the commit" and drops every commit in between. The script does the whole
sequence and checks the result before anything is pushed.

## Commands

`git-cascade` is on `PATH` (linked from `~/bin`). Every command takes `-C DIR` for the repo or worktree.

```sh
# Commit edits to the bottom branch, carry them up, push everything that moved.
git-cascade commit PAY-1-bottom -m 'fix: …' --push app/models/x.rb spec/models/x_spec.rb

# A message file instead of -m (for a multi-line commit message).
git-cascade commit PAY-1-bottom -F msg.txt --push app/models/x.rb

# The bottom branch changed some other way (amend, rebase on main): move what sat on its old tip.
git-cascade restack PAY-1-bottom --push            # old tip defaults to PAY-1-bottom@{1}
git-cascade restack PAY-1-bottom --from 1a2b3c4d --push

# What's stacked on a branch, with commit counts.
git-cascade show PAY-1-bottom
```

- **Edit from any branch of the stack.** `commit` switches to the named branch first and the
  uncommitted edits come along. If git refuses the switch (the edits clash with that branch),
  nothing has happened yet.
- **Only the named paths are committed.** Any other file already staged makes it refuse.
- **The stack is every local branch containing the branch's old tip.** Forks work: each top is
  rebased with `--update-refs`, which moves the branches beneath it.
- **It ends on the named branch**, not where you started.

## What it refuses or checks

- Committing to, or rebasing, `main`, `master` or `develop`; more than 10 branches above (that's
  not a stack, the old tip is probably on main).
- A stacked branch checked out in another worktree (rebase can't move it). Switch that worktree off it first.
- A rebase, merge or cherry-pick already in progress.
- A rebase that stops on a conflict is aborted, so every branch is left as it was, and the
  command to resolve it by hand is printed.
- After the move, each branch must have the same number of its own commits, sit on the new
  base, and differ from its old tip by exactly the base's change (patch-id). Otherwise it stops
  before pushing and prints a `git range-diff` to look at.
- `--push` pushes each branch to its upstream with `--force-with-lease`, fetches, and checks the
  remote matches. Branches without an upstream are skipped and named.

## Files

- `git-cascade`: the tool (Ruby, stdlib only), linked as `~/bin/git-cascade`.
- `git-cascade-test.rb`: `ruby ~/.claude/skills/git-cascade/git-cascade-test.rb`. Builds
  throwaway repos with a bare origin under a temp dir.
