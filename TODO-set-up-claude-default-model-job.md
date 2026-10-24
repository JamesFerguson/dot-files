# TODO: set up the Claude Code default-model job on this machine

For an agent (or James) who's just pulled dot-files. Delete this file once it's done on the machine that still needs it.

## Why

The Claude Code status line (`dot_claude/statusline.rb`) shows the model in red when it isn't Claude Code's current default. It reads that default from `~/.claude/statusline-default-model.json`, which a launchd agent writes once a day. The agent is set up on one machine only. On a machine without it, the JSON file doesn't exist and the model alert stays silently off. The advisor and effort alerts work either way.

Background: `CLAUDE_convos/claude_code_status_line_alerts/`.

## Steps

1. Check whether this machine already has it. If both commands succeed, it's already set up here, so stop and leave this file for the other machine.

   ```sh
   launchctl print gui/$(id -u)/com.jamesf.claude-default-model | grep 'last exit code'
   cat ~/.claude/statusline-default-model.json
   ```

2. Link the files. These are the three lines from `install.sh`, so running the whole of `install.sh` isn't needed. `DOT_FILES_DIR` is this checkout.

   ```sh
   DOT_FILES_DIR=~/code/personal/dot-files
   mkdir -p ~/.claude
   ln -fs $DOT_FILES_DIR/dot_claude/statusline.rb ~/.claude/statusline.rb
   ln -fs $DOT_FILES_DIR/dot_claude/statusline-default-model.zsh ~/.claude/statusline-default-model.zsh
   ln -fs $DOT_FILES_DIR/plists/com.jamesf.claude-default-model.plist ~/Library/LaunchAgents/com.jamesf.claude-default-model.plist
   ```

   `~/.claude/settings.json` must have `"statusLine": {"type": "command", "command": "ruby ~/.claude/statusline.rb"}` (or similar). Check it, but don't overwrite other settings.

3. Load the agent. `RunAtLoad` makes it run straight away.

   ```sh
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.jamesf.claude-default-model.plist
   ```

4. Verify after about 30 seconds. The run starts a headless `claude -p`, which needs Claude Code logged in on this machine.
   - `launchctl print gui/$(id -u)/com.jamesf.claude-default-model | grep 'last exit code'` should show `0`.
   - `~/.claude/statusline-default-model.json` should exist, with a `default_id` and a fresh `checked_at`.
   - If either fails, read `/tmp/claude-default-model.err`. Retry with `launchctl kickstart -p gui/$(id -u)/com.jamesf.claude-default-model`. Don't test by running the script from your own shell, because that leaks your env into it.

5. Delete this file, then commit and push straight to main (`git rm TODO-set-up-claude-default-model-job.md`).
