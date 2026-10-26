---
name: plan-epic
description: Use when the user has a request larger than a single ticket and wants it broken into a plan, a Jira epic, and an ordered set of child tickets using the `acli` CLI. Triggers on "plan this out", "break this down into tickets", "make an epic for X", "scope this into tickets", "epic and tickets for Y", "decompose this". Do NOT use for single-ticket work — that's the `ticket` skill.
---

# Plan → Epic → Tickets

Break a sizeable request into a written plan, then create a Jira epic with a small set of ordered child tickets using `acli`. The plan lives in the epic description. Child tickets stay short and point back at the epic — the epic carries the detail.

## When NOT to activate

- The work fits in a single ticket → use the `ticket` skill instead.
- The user just wants to talk through approach without creating Jira artifacts → answer conversationally.
- The user is already on a feature branch → mention it; epic-level work usually starts from `main`.

## Prerequisites

- `acli` on `PATH` (`acli --version`).
- `jq` on `PATH` — used to parse `--json` output.
- OAuth session active (`acli auth status`). If `acli` errors on auth, tell the user to run `acli auth login`. Never attempt auto-setup.
- Default project key: `PAY`. Pass `--project PAY` on every `create`.

## Sizing the breakdown

**Aim for as few tickets as possible.** A typical epic is 2–5 child tickets. Each child should be a substantial unit of work — often a full PR touching several files. Larger PRs are fine if the alternative is splitting one logical change across two tickets just to make each one smaller.

Only split when:
- Two slices land on different days or in different deploys.
- One slice unblocks parallel work from someone else.
- One slice is high-risk and benefits from being reviewed and shipped on its own.

Do not split for:
- "PR size feels big" — reviewers can handle a 600-line PR if the diff is coherent.
- Tidiness — separating "tests" or "docs" into their own ticket is almost always wrong.
- Hypothetical reuse — split when a second consumer actually exists.

If the plan ends up with one ticket, stop and route the user to the `ticket` skill.

## Tone (applies to plan, epic description, and ticket bodies)

Plain, conversational. Write like you're telling a teammate what the work is, not writing a design doc.

- Short words beat long ones. "Adds/changes/moves/removes" — not "introduces/facilitates/orchestrates/encapsulates".
- No architecture jargon: avoid "seam", "boundary", "surface area", "primitive", "contract", "abstraction layer". Name the actual thing — the endpoint, the table, the job.
- No bare "this" or "that" as the subject of a sentence — say what the thing is.
- No throat-clearing ("Note that…", "It's worth mentioning…", "This ticket is responsible for…").
- Avoid heavy file references in ticket descriptions. A path or two for orientation is fine; line numbers and function names belong in the implementor's head, not the ticket. (Detailed pointers live in the epic's Work breakdown — see below.)

Frame each ticket as a requirement, not a summary of work to do. Pattern: "We need to X because Y in order to Z."

## Process

### 1. Scope check

Is this actually epic-sized? See "Sizing the breakdown" above. If it collapses to one ticket, stop.

### 2. Gather context

Read the files the request mentions. If it names a system ("refund flow", "3DS auth"), do a targeted `Grep`/`Glob` pass to orient. This is the only exploration phase — it's specifically where you gather the concrete file pointers the epic's Work breakdown will carry, so it has teeth.

### 3. Clarify — one question at a time

Ask only what's genuinely unclear:
- **Why** this work, now.
- What changes when it's done.
- Hard constraints (deadlines, ordering dependencies).
- Anything that affects how to split it.

### 4. Draft the plan

Using the template below, decide:
- Epic title, why, and approach.
- 2–5 child tickets in order.
- Which pairs have a `Blocks` relationship.
- Risks and out-of-scope items.

### 5. Write the plan file

Save to `./plans/<YYYY-MM-DD>-<slug>-plan.md`. Create `./plans/` if missing. Do not commit — the plan file is a drafting artifact. The canonical version lives in the epic description after Step 7.

### 6. Approval gate — BLOCKING

Before running any `acli` command, show the user:

1. Plan file path.
2. One-screen summary: epic title, ordered ticket list, dependency edges.
3. The `acli` commands to be run, with summaries visible and bodies elided.

Wait for affirmative approval ("yes", "go"). Edits or "looks good but…" mean iterate.

### 7. Create the epic

The epic body is the full plan from Step 5 (Why, Approach, Work breakdown, Risks, Out of scope, Provenance). At this point the Work breakdown lists placeholder keys (`[TICKET-1]`, `[TICKET-2]`, …) — those get rewritten in Step 9.

```bash
EPIC_KEY=$(acli jira workitem create \
  --project PAY \
  --type Epic \
  --summary "<short epic name>" \
  --description-file ./plans/<plan>.md \
  --json | jq -r '.key')
```

### 8. Create child tickets

For each ticket in order, build the body from the Ticket Template, then create:

```bash
CHILD_KEY=$(acli jira workitem create \
  --project PAY \
  --type Task \
  --parent "$EPIC_KEY" \
  --summary "<N>. <short title>" \
  --description-file /tmp/ticket-<N>.md \
  --json | jq -r '.key')
```

Title format: **`N. Short imperative phrase`** — numbered prefix, no full sentence, under ~60 chars. The number conveys order at a glance in any Jira list view. Examples:

- `1. Add OAuth middleware`
- `2. Wire OAuth into routes`
- `3. Migrate existing tokens`

Capture each key in order.

### 9. Link dependencies and update the epic

For each `(blocker, blocked)` pair:

```bash
acli jira workitem link create --out "$BLOCKER" --in "$BLOCKED" --type Blocks --yes
```

Then rewrite the epic description to replace `[TICKET-N]` placeholders with the real keys:

```bash
acli jira workitem edit --key "$EPIC_KEY" --description-file ./plans/<plan>.md --yes
```

(Update the plan file in place first, so the file and Jira stay in sync.)

Report back: epic URL, ordered ticket list with one-line titles, dependency graph.

## Plan template

This is what you write in Step 5 and what becomes the epic body in Step 7. The epic carries the detail so child tickets can stay lean — put the per-slice acceptance rationale and concrete file pointers **here**, in the Work breakdown, not in each child ticket.

```
# <Epic Title>

## Why
<2–4 sentences. What we're solving, what changes when done, why now.
Frame as a requirement: "We need to X because Y in order to Z.">

## Approach
<3–6 sentences or a short bulleted list. Enough for a reader to see the
shape of the work. Name systems or services involved — and the key files/
modules the work touches (this is where concrete pointers live, not in the
child tickets).>

## Work breakdown
1. [TICKET-1] — <short imperative title>
   <1–2 sentences on the slice.>
   Acceptance: <testable criterion — why: brief rationale>; <criterion — why: rationale>
   Key files: `path/to/file.rb` — what changes here; `path/to/other.rb:123` — what changes
   Depends on: none
2. [TICKET-2] — <short imperative title>
   <1–2 sentences on the slice.>
   Acceptance: <criterion — why: rationale>
   Key files: `path/to/thing.rb` — what changes
   Depends on: [TICKET-1]
...

(Placeholders are replaced with real Jira keys in Step 9. Include the
Acceptance `— why:` rationale and Key files per slice when the detail helps a
fresh implementor — this is the richness that used to sit in each ticket,
centralised so the tickets stay lean and the pointers don't go stale across N
tickets.)

## Risks
- <One line per risk. Migration order, flag coupling, double-send risk, etc.>

## Out of scope
- <Things a reader might expect but aren't included. 3–6 bullets.>

## Provenance
Drafted: <YYYY-MM-DD>
From: <user's original request, verbatim, 1–3 lines>
```

Rules:
- Work breakdown is the spine — one entry per child ticket, in order.
- Each entry's `Acceptance` criteria carry a `— why:` tail. If you can't write a rationale, the criterion is probably not the right one.
- `Key files` must be concrete: real paths, real line numbers or function names. Not "the auth module somewhere". Step 2 is where you gather these.
- Risks is required, never empty.
- Out of scope is required — prevents drift during implementation.

## Ticket template

**Title:** `N. <short imperative phrase>`. Numbered prefix mandatory. Under ~60 chars.

**Body:**

```
## Goal
<One or two sentences. What "done" looks like from the outside. Plain
language — name the user-visible behaviour or system change, not the
implementation.>

## Acceptance
- <Testable criterion.>
- <Testable criterion.>

## Depends on
<PAY-N — one line on what that ticket produces that this one needs.>
(Omit the section if there are no blockers.)

## Plan
See epic <PAY-EPIC-KEY> for the full plan, approach, risks, file pointers, and
per-criterion rationale.
```

Rules:
- Keep it to the four sections above. No "Files & pointers", no "Risks", no rationale-per-criterion in the child ticket — the epic's Work breakdown carries all of that. This keeps line numbers in one place so they don't go stale across N tickets, and matches how teammates' epics read.
- Acceptance criteria are short and testable. 2–5 bullets is normal.
- The Plan link is mandatory — it's how a reviewer or fresh implementor finds the full context.

## Safety & approval gates

1. **Approval gate before Step 7 is blocking.** Silence, edits, or "looks good but…" do NOT count as approval.
2. **Stop on first failure.** If the epic is created but ticket 2 fails, do not create tickets 3..N or `Blocks` links. Report: epic key, tickets created so far, failing step, error. Ask the user: retry, abandon (they clean up Jira manually), or skip-and-continue.
3. **No silent credential handling.** If `acli` returns an auth error, stop and tell the user to run `acli auth login`.
4. **Do not read plan files you didn't write.** Existing `./plans/*.md` may belong to other work. Each invocation drafts fresh.

## Relationship to sibling skills

```
plan-epic (this skill)            ticket (existing)              land (existing)
──────────────────────            ─────────────────              ───────────────
request → plan doc →              pick up one child ticket   →   commit + PR
epic + N tickets                  check out feature branch       ship
```

This skill ends at Jira creation. When a fresh Claude picks up a child ticket, they invoke the `ticket` skill with the key to check out a branch, work through the acceptance criteria (and read the epic for full context), then invoke `/land` to commit and open the PR.
