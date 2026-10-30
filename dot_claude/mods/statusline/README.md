# statusline

A status line drawn above the prompt and redrawn every 20 seconds, so the countdowns keep moving while a session sits idle.

```
[gateway main] 🧠 ⚡████░░░░░░ 40% 120k ⏳ 59m ⏱️ ██░░░░░░░░ 20% 2h10m 📆 ███░░░░░░░ 30% 2d23h 💵 A$245.90/A$250 1 Nov 🤖 Opus 5.5 💪 high v2.1.308
```

| Part | Shows |
|---|---|
| `[repo branch]` | The git repo and branch of the session's directory. |
| 🧠 | How full the context window is, and its size in tokens. |
| ⏳ / 🧊 | Minutes until the prompt cache goes cold, orange under 10. 🧊 once it's cold: the next reply rewrites the whole context at the cache-write price. |
| ⏱️ / 📆 | The 5-hour and weekly quotas, with time to reset. The fill is coloured by where you'll end the window at the current rate: green at 80% or less, yellow to orange up to 100%, red past it. The green dots after the fill are the headroom left at an 80% pace. |
| 💵 | Usage credits spent against the monthly cap, and the date it resets, as `/usage` shows them. Grey normally, red while a 5-hour or weekly quota is used up, since that's when credits are being spent. |
| 🤖 | The model. It turns into a red ⚠️ badge when it isn't Claude Code's current default. |
| 🎓 | A red badge when the session runs with an advisor. |
| 💪 | The effort level, on an orange badge below `high`. |
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

## Turning parts off

Each part has an on/off option. Set them on the install screen, or later in `/config`: they're listed under the plugin's name. They're stored in `settings.json` under `pluginConfigs.statusline`.

## Where the numbers come from

- **Context, quotas, model, version:** Claude Code's own session figures (`$.session.usage()` and friends).
- **Usage credits:** `GET https://api.anthropic.com/api/oauth/usage`, the endpoint `/usage` reads, with your session's login. Fetched every 5 minutes. It's an account call, not a model call, so it uses no tokens. The reset date is the 1st of next month in local time, worked out the same way `/usage` does.
- **Cache countdown:** the end of the session's transcript. Each reply restarts the cache's clock, and the TTL is whichever the last cache write used (5 minutes or 1 hour).
- **Default model:** `bin/default_model.rb` opens a fresh `claude -p` session with no settings and records the model it starts on. Its prompt is `/cost`, which Claude Code answers itself, so it uses no tokens. A draw starts it in the background when the record (`~/.claude/statusline-default-model.json`) is over 10 minutes old, and a lock file keeps it to one at a time.
- **Advisor:** the latest reply in the session's transcript, which records the advisor in effect.

## Tests

```
cd bin && for t in *_test.rb; do ruby $t; done
claude plugin test .
```
