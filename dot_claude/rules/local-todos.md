# Local todos: fold parked cleanups into the PR you're making

`LOCAL-TODO LT-n:` comments are uncommitted cleanups in a repo's main checkout, registered in `~/.claude/local-todos.jsonl` (`local-todo` skill). Whichever PR next touches that code does them, without James asking.

- Run `local-todo touching` before opening a PR and again before marking it ready. The register works from a worktree too.
- A todo in or next to code you're changing: do it as its own commit, `local-todo claim LT-n --repo R --pr N --session <uuid>`, and mention it in one line of the PR body. If it comes back out, `local-todo unclaim`.
- Leave it, and tell James in a line, when the PR is urgent (incident, hotfix, time-boxed release), sensitive (security, money movement, needs a narrow diff), or the todo would need testing of its own.
- Never commit the comment: stage those files with `local-todo stage <path>`, and don't `--no-verify` past the hook.
- On merge, `pr-task` runs `local-todo merged`. For any other PR it names as also claiming the todo, tell that session to drop the change.
