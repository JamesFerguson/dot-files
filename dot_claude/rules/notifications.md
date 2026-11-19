# Time-sensitive alerts: make noise outside the transcript

James can be away from a session for days, so a line in a reply is not an alert. A certification window was lost to a "heads-up" he read five days later.

When a reply carries something with a clock on it (an incident, a deadline, a decision needed before a cutoff, a watch that fired), put the detail in the reply **and**:
- **Emergency:** alert now with `claude-notify --title '<subject>' --message '<body>' --open '<url>' --say '<spoken>'`.
- **Otherwise:** schedule a delayed alert that restates the deadline, `future_claude add --at +30m --title '<subject>' --notify '<body>' [--open '<url>'] [--say '<spoken>']`. If he's already back, it's harmless.

- **`--say` is two to four words:** how serious it is, then the topic. "Urgent: gateway incident", "Deadline: eftpos cert", "New Relic MCP down". No names, numbers or sentences; the detail goes in the notification and the reply.
- **`--open` is where he'd act:** the PR, ticket, artifact, Slack thread or dashboard. Without one, a click brings iTerm forward. Never raw `osascript` for these: its notifications open Script Editor when clicked.

Not for routine replies or quiet monitor ticks: over-alerting trains him to ignore it.

**Anything that must happen later goes to `future_claude`**, a launchd queue that outlives the session. Not `CronCreate` or `ScheduleWakeup` (they die with the session), nor the cloud `schedule` skill (it can't reach this Mac). `--prompt '<self-contained task>'` for work; `--every 1d [--weekdays] [--until T]` to repeat; `--origin <session name>` or `--headless`. Tell James the job id and when it fires. Details: `dot_claude/future_claude/README.md` in dot-files. Session crons are fine for polling within the session.
