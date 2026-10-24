# Alerting James out-of-band — be noisy for time-sensitive things

James may not return to a session for **days** after prompting. A quiet line in the transcript
(a "Heads-up…") is invisible until he happens to read it — which is how a
certification window was lost: flagged "window closes tomorrow" as plain text on 1 Oct, he saw it 6 Oct, the window
had closed 2 Oct. A text response is **not** a reliable alert.

So: whenever a response carries **time-sensitive** information, get his attention **outside the text
response** — don't assume he'll read the transcript soon. Put the detail in the text reply *and* make
noise.

## When to make noise (time-sensitive = there's a clock on it)
- An active incident, or anything with a clear deadline / timeline / "needs X by <time>".
- A monitor/watch he asked for has fired, or reached a point that deserves attention in the near term.
- A decision or action is needed from him before some cutoff.

NOT for ordinary responses, quiet monitor ticks ("still no reply"), or work with no clock on it.
Over-alerting trains him to ignore the noise — reserve it for genuine time pressure.

## How to make noise
- **`say`** (macOS TTS) — audible spoken alert, one short sentence:
  `say "the cert window closes tomorrow and needs a nudge to the vendor"`
- **System notification** — persists in Notification Center if he's away from the keyboard:
  `osascript -e 'display notification "<body>" with title "Claude: <subject>" sound name "Submarine"'`
- Genuinely urgent → use **both**. Milder heads-up → either. Always also write the detail in the reply.
  (`say`/`osascript` are on PATH for the Bash tool; both are used by the launchd jobs already.)

## Minimise disruption if he came straight back
If it's not an emergency, **schedule** the noise for a short delay after the initial response rather than
blaring immediately — a `ScheduleWakeup`/`CronCreate` a few minutes to a couple of hours later that fires
`say` + the notification. If he came right back, he's already dealt with it in-session and the delayed
noise is harmless; if he didn't, it ensures the item doesn't get buried. Have the delayed fire restate
the deadline so the alert is self-contained.

For a **true emergency**, make noise immediately AND on the text response — don't wait.

## Related
- `working-style.md` — flag-before-you-act and shared-record rules.
- `tooling.md` § launchd — the headless jobs already post `osascript` notifications + `say`; same mechanism.
