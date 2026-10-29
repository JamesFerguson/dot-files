# future_claude

A durable queue of scheduled work that any Claude session, or you, can hand off to. Session-only
schedulers (`CronCreate`, `ScheduleWakeup`) die with the session, so a reminder set in one is lost on
exit or resume. `future_claude` jobs live in a file and a launchd agent runs them, so they fire whether
or not the session that queued them is open.

## Use

```sh
# A reminder: speaks --say (or the body) and posts a notification.
future_claude add --at '2026-10-27 09:47' --title 'Enrolment due' --notify 'Enrol the Mac today' --say 'Enrol the Mac today'

# Work for later. Queued from a Claude session's Bash call, it's handed back to that session.
future_claude add --at +2h --prompt 'Check whether the deploy finished and tell James'

future_claude list            # pending and running jobs (--all for finished ones)
future_claude show <id>       # the job, plus the Claude run's log for prompt jobs
future_claude rm <id>
```

`--at` takes `'YYYY-MM-DD HH:MM'` (local), ISO 8601, or relative `+90s`/`+30m`/`+2h`/`+1d`.

### Repeating jobs

```sh
# Weekdays at 09:00, 13:00 and 16:00: one job per time of day.
future_claude add --at '2026-10-27 09:00' --every 1d --weekdays --headless --prompt 'Work through the queue'
future_claude add --at '2026-10-27 13:00' --every 1d --weekdays --headless --prompt 'Work through the queue'
```

- `--every` takes `90s`, `30m`, `2h`, `1d` or `1w`. Days and weeks keep the wall-clock time across a
  daylight saving change.
- After each run the job goes back to `pending` at its next slot, counted on from the scheduled time.
  A Mac asleep through several slots fires once on wake, not once per missed slot.
- `--weekdays` moves a Saturday or Sunday slot on to Monday. `--until TIME` ends the series.
  `future_claude rm <id>` stops it.
- A failed run still reschedules, and notifies. A repeating prompt job that runs headless because its
  origin session has gone doesn't notify, since that's the usual case.
- A hand-back by socket only lasts as long as the session that queued the job. To hand back to a
  long-lived session, use `--origin <name>`, which survives a resume. Otherwise use `--headless`.
- `show` has the last run's log only; each run overwrites it.

### Prompt jobs

At the due time `future_claude run` starts a headless `claude -p` in `--cwd` (default `$HOME`):

- **Hand-back (the default from inside a session).** `add` records the caller's own messaging address,
  `uds:$CLAUDE_CODE_MESSAGING_SOCKET`, which every Claude session's Bash calls carry. (A session can't
  use its own name: `ListAgents` leaves the caller out.) The run sends the task there over `SendMessage`,
  so the session does it with its own context. If that session has gone, the send fails and the run does
  the task itself. A resumed session gets a new socket, so it counts as gone.
- **`--origin <name>`** hands back to another session by its `ListAgents` name instead.
- **`--headless`**, or `add` run outside a session, skips the hand-back: the run just does the task.

A failure or timeout posts a notification pointing at `future_claude show <id>`, and so does a one-off
run that fell back to doing the task because its origin session had gone. A `--headless` or repeating
job that succeeds stays quiet, so a headless job whose result James needs has to notify him itself
(its prompt ends with an `osascript` notification). Other flags: `--permission-mode` (default `auto`), `--model`, `--timeout` seconds (default
900), `--by` (who queued it, shown in the prompt), and `--allowed-tools` to pre-approve tools for the
run (`'ListAgents,SendMessage,Bash(some-cli *)'`).

### One job per key

`--key <text>` makes `add` idempotent: if a pending job already has that key, `add` prints that job's id
and queues nothing. The check runs under the queue lock, so callers racing to queue the same thing still
end up with one job. Once the job has run, the key is free again.

A hand-back lands only if the origin session is alive and in a mode that doesn't hold peer messages for
approval. Otherwise the message waits there or the run falls back to doing the task itself.

## How it runs

- `plists/com.jamesf.future-claude.plist` runs `~/bin/future_claude run` every 60s. launchd catches up
  after sleep, so a job due while the Mac slept runs on wake; the job records `late_by` seconds.
- launchd never starts a second `run` while one is going, so a long prompt job delays any jobs due behind it.
- The plist sets an explicit PATH and `cd "$HOME"`, then sources `~/.future_claude.env` if it exists (not
  in the repo). Put exports there that headless runs need, e.g. secrets their MCP servers read.
- It calls `/opt/homebrew/bin/claude` (the symlink), so a claude-code upgrade can't strand it on a deleted
  versioned path.
- State: `~/.claude/future_claude/queue.jsonl` (one job per line, under a file lock) and `logs/<id>.log`.
  launchd output: `/tmp/future-claude.out`, `/tmp/future-claude.err`.
- The script stays compatible with macOS's `/usr/bin/ruby` 2.6, so it works whichever ruby launchd finds.

## Install

`install.sh` links `~/bin/future_claude` and the plist. Then load it once:

```sh
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.jamesf.future-claude.plist
```

Check it with `launchctl print gui/$(id -u)/com.jamesf.future-claude | grep -E 'state|last exit'`.

## Tests

`ruby dot_claude/future_claude/future_claude_test.rb` drives the CLI against a temp queue with `say`,
`osascript` and `claude` swapped for recorders (`FUTURE_CLAUDE_HOME`, `FUTURE_CLAUDE_CLAUDE`).
