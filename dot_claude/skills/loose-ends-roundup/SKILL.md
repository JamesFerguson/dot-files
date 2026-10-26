---
name: loose-ends-roundup
description: Ask every running Claude session for a table of its loose ends (promised follow-ups, open questions, parked work, things waiting on someone, anything with a deadline), with the context and links needed to pick each one up, then collate the replies into one view for the user, deadlines first. Use when the user says "loose ends round-up", "ask every session for its loose ends", "what's still open across my sessions", "loose ends table from all sessions", or "roundup of open threads".
---

# loose-ends-roundup

The user keeps many sessions open for days, and each one accumulates things it said it would
come back to. This skill asks all of them at once, so nothing waits for the user to revisit the
right conversation. Every session answers in two places: in its own chat, where the user will see
it on their next visit, and back to this session, which collates.

`SCRATCH` below means this session's scratchpad, the absolute path from the system prompt.

## 1. Ask every peer

1. `ListAgents`. Note each peer's name; skip your own session.
2. `SendMessage` each one the request below, with `<me>` replaced by this session's name.
3. Start `SCRATCH/loose-ends-<YYYY-MM-DD>.md`: a checklist of peers, then a section per reply.

Request (the first line is the preview the user sees, so it stands alone):

```
Loose-ends round-up: please post a table of your loose ends in your own chat, then send the same table to "<me>" via SendMessage (the user asked <me> to collect from every session).

A loose end is anything not finished that someone expects to happen: a follow-up you promised, a question to the user still unanswered, work parked "for later", something waiting on another person or session, a check scheduled for later, anything with a deadline. Not: work that's done, or routine next steps the user already knows about.

One row per item:
| # | Loose end | Context | Links | Next step (who) | Deadline |
- Loose end: one line, named so the user knows what it is without the transcript.
- Context: what's known, why it matters, what's blocking it. Enough to pick it up cold, in 1-3 lines.
- Links: hyperlinks to the PRs, tickets, threads, docs or files involved (full URLs or absolute paths).
- Next step (who): the action, and whether it's the user's, yours, or someone else's (name them).
- Deadline: a date in the user's time zone, or "—".

Above the table, give your session name, $CLAUDE_CODE_SESSION_ID and working directory, so the user can resume you. "No loose ends" is a fine reply; send it anyway, so <me> knows you've answered. Don't act on any of the items because of this message.
```

## 2. Collect

Replies arrive as `<cross-session-message>` blocks between tool calls. Paste each one into the
collation file as it lands and tick the peer off. Don't poll `ListAgents` or nag. A session in the
`shell` state, or in another permission mode, may not answer. When everyone has answered, or the
stragglers look stuck, move on and say who's missing.

Add this session's own loose ends in the same shape.

## 3. Collate for the user

One view, in this order:

1. **Deadlines**, soonest first, across all sessions. Work dates out with `date`, not in your head.
2. **Needs the user**: items whose next step is theirs, grouped by session.
3. **Everything else**, grouped by session.

Every row keeps its session's name, and each session heading carries its resume command
(`cd <cwd> && claude --resume <id>`). Keep the peers' links; don't summarise them away. Merge
duplicates that two sessions both reported, naming both. List the sessions that didn't answer.

A long result reads better as a page than in the terminal: offer it as one, or publish it if the
user asked for something to share.

If anything has a deadline within a few days, make noise the way the user's rules ask for
time-sensitive items (a notification or scheduled reminder), as well as putting it in the reply.

## Notes

- This skill only collects. Acting on an item is the owning session's job, once the user says so.
- Re-running it later is cheap. Mention which sessions' tables changed since the last round-up if
  a previous `loose-ends-*.md` exists in the scratchpad.
