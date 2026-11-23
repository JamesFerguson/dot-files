# Rails migrations: real timestamps

Name a new migration with the current UTC time to the second, as `bundle exec rails generate migration` does (`date -u +%Y%m%d%H%M%S`). Never a date with the time zeroed out (`20261120000000`), and never a hand-picked sequence like `…000100`, `…000200`.

- Two migrations on one version stop Rails migrating at all, and a zeroed time clashes with anyone else who picks the same day.
- For a run of migrations that must go in order, add a second to each.
- Renaming one that hasn't merged: change the file's version and the `define(version:)` line in `db/schema.rb` (or the repo's other schema dumps), then check that Rails loads them with no duplicates.

**Why:** On 2026-11-23 two draft gateway PRs from different people both used `20261120000000`. Whichever merged second would have failed.
