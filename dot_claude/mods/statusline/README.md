# statusline

A status line drawn above the prompt and redrawn every 20 seconds, so the countdowns keep moving while a session sits idle.

```
[gateway main] 🧠 ████░░░░░░ 40% 120k ⏳ 59m ⏱️ ██░░░░░░░░ 20% 2h10m 📆 ███░░░░░░░ 30% 2d23h 💵 A$245.90/A$250.00 1 Nov 🤖 Opus 5.5 💪 high v2.1.308
```

| Part | Shows |
|---|---|
| `[repo branch]` | The git repo and branch of the session's directory, or just the folder's name outside a repo. |
| 🧠 | How full the context window is, and its size in tokens. The 🧠 turns into 🔥 at 70% and 🚨 at 90%. |
| ⏳ / 🧊 | Minutes until the prompt cache goes cold, orange under 10. 🧊 once it's cold: the next reply rewrites the whole context at the cache-write price. |
| ⏱️ / 📆 | The 5-hour and weekly quotas, with time to reset, paced against a target (80% by default). The fill is green while usage is on or under the target pace, red once it's past a steady pace to 100%, and yellow to orange in between. In the last fifth of the window the target climbs to 100%, since quota left at the reset is wasted. The green dots after the fill are the headroom left at the target pace. |
| 💵 | Usage credits spent against the monthly cap, and the date it resets, as `/usage` shows them. Grey normally, red while a 5-hour or weekly quota is used up, since that's when credits are being spent. |
| 🤖 | The model. It turns into a red ⚠️ badge when it isn't the one you expect, by default Claude Code's current default. |
| 🎓 | The advisor, on a red badge when it isn't the one you expect. By default you expect none, so any advisor is flagged. Expecting one and having none shows a red `🎓 no advisor`. |
| 💪 | The effort level, on an orange badge below the lowest you expect, by default `high`. |
| `v2.1.308` | The running Claude Code version. When Homebrew has installed a newer one, the running version turns red with the new one after it in green: a restart picks it up. |

If something breaks, the band shows a red `statusline: …` line saying what, rather than going blank.

## Install

It's a [Claude Code mod](https://code.claude.com/docs/en/plugins/mods/overview). From a clone of the repo that holds it:

```
claude plugin marketplace add <path to the mods folder>
claude plugin install statusline@james-mods
```

Then `/reload-plugins` in any open session.

### Ruby

The line is drawn by Ruby scripts in `bin/`. The mod looks for Ruby in this order: mise, asdf and rbenv shims, then Homebrew Ruby. It runs them from `bin/`, where `.tool-versions` and `.ruby-version` pin 3.4.5, the version gateway and Jabberwocky use, so you probably have it already. If not, install it with your version manager (`mise install ruby@3.4.5`, `asdf install ruby 3.4.5`, `rbenv install 3.4.5`). chruby and rvm have no shims the mod can find, so use Homebrew Ruby there.

## Options

Set these on the install screen, or later in `/config`, where they're listed under the plugin's name. They're stored in `settings.json` under `pluginConfigs.statusline.options`.

- Each part has an on/off switch.
- **Expected model:** `default` (Claude Code's default), a family (`fable`, `opus`, `sonnet`, `haiku`), or `any` to never warn.
- **Expected advisor:** `none`, a family, or `any` to never warn.
- **Lowest expected effort:** `low` to `max`.
- **Quota target:** the percentage of each window to aim for by its reset.

## Where the numbers come from

- **Context, quotas, model, version:** Claude Code's own session figures (`$.session.usage()` and friends).
- **Usage credits:** `GET https://api.anthropic.com/api/oauth/usage`, the endpoint `/usage` reads, with your session's login. Fetched every 5 minutes. It's an account call, not a model call, so it uses no tokens. The reset date is the 1st of next month in local time, worked out the same way `/usage` does.
- **Cache countdown:** the end of the session's transcript. Each reply restarts the cache's clock, and the TTL is whichever the last cache write used (5 minutes or 1 hour).
- **Default model:** `bin/default_model.rb` opens a fresh `claude -p` session with no settings and records the model it starts on. Its prompt is `/cost`, which Claude Code answers itself, so it uses no tokens. A draw starts it in the background when the record (`~/.claude/statusline-default-model.json`) is over 10 minutes old, and a lock file keeps it to one at a time.
- **Advisor:** the `advisorModel` setting in `~/.claude/settings.json`, which is what `/advisor` reports. A session keeps the advisor it started with until `/clear` or `/compact`, so for a while after you change it the badge is ahead of the session. The transcript's `advisorModel` field doesn't help: replies carry it whether or not the advisor is on.

## Tests

```
cd bin && for t in *_test.rb; do ruby $t; done
claude plugin test .
```
