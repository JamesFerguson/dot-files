---
name: loose-ends
description: Have a session put its loose ends and its todo items in one table, each with enough context for the user to make a call on it (do it, keep it, drop it, hand it off) without reading the transcript. With no argument this session reports on itself; given another session's name, ask that session and relay its table. Use when the user says "loose ends", "what's open in this session", "table of your loose ends and tasks", "what do you need from me", "ask <session> for its loose ends". For every session at once, use loose-ends-roundup, which uses this skill's format.
---

# loose-ends

A session that runs for days collects todos and half-promises, and the user comes back to it
without the transcript in their head. This skill turns all of it into one table the user can
decide from: each row says where the item stands, what call it needs, and what you'd pick.

## 1. Which session

- **No session named**: this session reports on itself. Go to §2.
- **Another session named**: find it with `ListAgents`, then `SendMessage` it:

  ```
  Loose ends: please run the loose-ends skill (or read ~/.claude/skills/loose-ends/SKILL.md and follow its Gather and Table sections), post the table in your own chat, and send the same table to "<me>" via SendMessage. Don't act on any item because of this message.
  ```

  Relay the table when it arrives, unchanged apart from fixing broken links. Don't poll
  `ListAgents` while waiting; the reply arrives as a cross-session message.

## 2. Gather

1. **Todos**: `TaskList`, every item that isn't completed.
2. **Loose ends from the conversation**: follow-ups you promised, questions to the user still
   unanswered, work parked "for later", anything waiting on another person or session, checks
   scheduled for later (jobs or reminders this session queued), anything with a deadline. Not
   routine next steps the user already knows about, and not finished work.
3. **Refresh what's cheap to check** before reporting it: a PR's state, whether a queued job is
   still queued, whether a ticket moved. A row that's out of date costs the user a wrong call.
   If a todo turns out to be done, close it and say so under the table instead of listing it.
4. Merge a todo and a loose end that are the same thing into one row.

## 3. The table

Above it: the session's name, its id (`$CLAUDE_CODE_SESSION_ID`), its working directory, and the
resume command (`cd <cwd> && claude --resume <id>`).

| # | Item | Where it stands | The call | Recommendation | Links | Deadline |
|---|---|---|---|---|---|---|

- **Item**: one line that names it without the transcript. A todo shows its task number
  ("todo 17: …").
- **Where it stands**: what's done, what's blocking it, what's known. One to three lines.
- **The call**: the decision the user has to make, as concrete options ("merge as is / fix the
  retry first / drop it"). When the item needs nothing from the user, write "None:" and who
  does what next ("None: I check the deploy at 14:00").
- **Recommendation**: your pick and the reason, in a clause. Blank when there's no call.
- **Links**: hyperlinks to the PRs, tickets, threads and docs, and absolute paths to files.
- **Deadline**: a date and time in the user's time zone, or "—". Work dates out with `date`.

Order the rows: first the ones that need the user's call, soonest deadline first; then the ones
that need nothing from them.

Under the table, one line saying what you'll do if the user answers "go with your
recommendations". "No loose ends and no open todos" is a fine result; say it in one line.

## 4. Then

- Don't act on any row until the user answers. "Go with your recommendations" covers the rows
  that are yours to do, not anything outward-facing that your rules say to confirm first.
- A row with a deadline within a few days also gets the alert the user's rules ask for
  time-sensitive items, as well as its place in the table.
- If the user drops an item, delete its todo, so the next table doesn't bring it back.
