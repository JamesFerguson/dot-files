# Time-sensitive alerts: make noise outside the transcript

James can be away from a session for days, so a line in a reply is not an alert. A certification window was lost to a "heads-up" he read five days later.

When a reply carries something with a clock on it (an incident, a deadline, a decision needed before a cutoff, a watch that fired), put the detail in the reply **and**:
- **Emergency:** alert now with both `say "<one sentence>"` and `osascript -e 'display notification "<body>" with title "Claude: <subject>" sound name "Submarine"'`.
- **Otherwise:** schedule a delayed alert that restates the deadline, `future_claude add --at +30m --title '<subject>' --notify '<body>' [--say '<spoken>']`. If he's already back, it's harmless.

Not for routine replies or quiet monitor ticks: over-alerting trains him to ignore it.

**Anything that must happen later goes to `future_claude`**, a launchd queue that outlives the session. Not `CronCreate` or `ScheduleWakeup` (they die with the session), nor the cloud `schedule` skill (it can't reach this Mac). `--prompt '<self-contained task>'` for work; `--every 1d [--weekdays] [--until T]` to repeat; `--origin <session name>` or `--headless`. Tell James the job id and when it fires. Details: `dot_claude/future_claude/README.md` in dot-files. Session crons are fine for polling within the session.
