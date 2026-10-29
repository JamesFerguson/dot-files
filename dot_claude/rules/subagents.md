# Subagents: pick the cheapest agent that can do the job

Every subagent request re-reads its whole starting context, and a general-purpose one starts at about 117k tokens, almost a full session's worth. A typical run makes 20-odd requests (measured 2026-10-29), so the agent type and model matter more than the prompt.

- **Pass `model` on every Agent call that doesn't need judgment.** `"sonnet"` for search, code tracing and collection (including `Explore`); `"haiku"` for pure fetch-and-tabulate work like pulling message timestamps. Leave Opus (no override) for reviews, diagnosis and design calls.
- **Reviews of a PR, diff or draft → the `reviewer` agent.** It has read-only tools and Opus, and starts at 19k tokens of context, against general-purpose's 117k.
- **Bulk pulls from chat, email, logs or tickets → the `collector` agent**, where it's defined. It runs on Sonnet with only the read tools those pulls need, and starts at 57k. Pass `model: "opus"` when the run has to weigh what it finds (archaeology), not just gather it.
- **General-purpose only when the job needs tools neither custom agent has.**
- **Keep subagent cache TTL at the 5m default.** Outside forks, no subagent run has idled past 5 minutes, so a 1h TTL would only add the higher write rate.
