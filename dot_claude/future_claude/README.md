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

### Prompt jobs

At the due time `future_claude run` starts a headless `claude -p` in `--cwd` (default `$HOME`):

- **Hand-back (the default from inside a session).** `add` records the caller's own messaging address,
  `uds:$CLAUDE_CODE_MESSAGING_SOCKET`, which every Claude session's Bash calls carry. (A session can't
  use its own name: `ListAgents` leaves the caller out.) The run sends the task there over `SendMessage`,
  so the session does it with its own context. If that session has gone, the send fails and the run does
  the task itself. A resumed session gets a new socket, so it counts as gone.
- **`--origin <name>`** hands back to another session by its `ListAgents` name instead.
- **`--headless`**, or `add` run outside a session, skips the hand-back: the run just does the task.

Anything other than a clean hand-back (ran headless, failed, timed out) posts a notification pointing at
`future_claude show <id>`. Other flags: `--permission-mode` (default `auto`), `--model`, `--timeout`
seconds (default 900), `--by` (who queued it, shown in the prompt).

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
