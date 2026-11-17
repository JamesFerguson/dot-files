# Flag uncommitted changes, don't auto-commit

If a task looks otherwise complete but a repo has uncommitted changes — mine or pre-existing — say so in the text response instead of letting it pass silently. Don't commit it myself; just flag it so James can decide.

**Why:** James wants control over what lands in a commit and when a repo's state gets changed. A silent pass risks losing track of changes, and an auto-commit risks sweeping in someone else's in-progress edits.

**How to apply:** This is the default for every repo. A repo can override it for itself in its own `CLAUDE.md` — `ai_chats` does, asking for an auto-commit at the end of any turn that changed files there, since that repo's workflow wants it.
