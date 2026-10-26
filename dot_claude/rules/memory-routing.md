# Where new learnings go

When saving something learned mid-session, route by scope instead of defaulting to per-repo auto-memory:

- **Machine-global** — a preference, a working-style rule, or a tooling fact that holds in every repo → add it to a file in `~/.claude/rules/`. These load in every project. Rules have two homes there, each a directory symlink into a dot-files repo:
  - `general/` → the **public** dot-files repo (`dot_claude/rules/`), so it loads on every machine after a pull. **It's published**: nothing employer-specific goes here — no ticket keys, internal hosts or tools, customer or colleague names, or work incidents as examples.
  - `fz/` → the private work overlay (`work-dot-files/claude/rules/`), loaded on the work laptop only. Anything that names work systems, people or data goes here, including a mostly-general rule whose examples are work-specific.
  Edit through the `~/.claude/rules/<general|fz>/…` path: a directory link keeps the Edit tool working, where a symlinked file would be refused. Then commit and push the repo the file lives in.
- **Skills** follow the same split, one directory link per skill: `~/.claude/skills/<name>` points into the public repo's `dot_claude/skills/` or the work overlay's `claude/skills/`. A skill goes public only if it has nothing employer-specific in it, the same test as `general/`. Make a new skill in the right repo and link it (each repo's install script does the linking), then commit and push. Run output a skill writes beside itself (`data/`, `work/`) is gitignored.
- **Repo-specific** — a prod fact, this codebase's build/test quirks, its architecture, an incident → per-repo auto-memory (`~/.claude/projects/<repo>/memory/`), as normal.

If a learning could be either, ask which it is rather than defaulting to per-repo memory.
