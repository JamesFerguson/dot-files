# Where new learnings go

- **Every repo, any machine, nothing employer-specific** → `~/.claude/rules/general/` (the public dot-files repo).
- **Names work systems, people, data or incidents**, even only as examples → `~/.claude/rules/fz/` (the private work overlay). Put long detail in `~/.claude/reference/fz/` and point to it from the rule.
- **One repo** (prod facts, build quirks, architecture, incidents) → that repo's auto-memory.
- Skills split the same way (`dot_claude/skills/` vs `claude/skills/`, linked one per skill).

Edit through `~/.claude/rules/<general|fz>/` (Edit refuses symlinked files), then commit and push that repo. If the scope is unclear, ask.
