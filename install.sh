#!/bin/zsh

# Dot files dir + machine type detection
if [[ "$(hostname)" == *"fz-"* ]]; then
  DEVICE_TYPE=work
  ON_WORK_LAPTOP=1
  DOT_FILES_DIR="$HOME/code/personal/dot-files"
elif [[ -f "$HOME/.config/zsh/device-type.zsh" ]]; then
  source "$HOME/.config/zsh/device-type.zsh"
  DOT_FILES_DIR="$HOME/codez/dot-files"
else
  # First run on a new personal machine — ask once and write the file.
  echo "Is this a work or personal machine? [work/home]"
  read -r answer
  DEVICE_TYPE="${answer:-home}"
  mkdir -p "$HOME/.config/zsh"
  echo "DEVICE_TYPE=$DEVICE_TYPE" > "$HOME/.config/zsh/device-type.zsh"
  echo "Wrote DEVICE_TYPE=$DEVICE_TYPE to ~/.config/zsh/device-type.zsh"
  DOT_FILES_DIR="$HOME/codez/dot-files"
fi
[[ "$DEVICE_TYPE" == "work"  ]] && ON_WORK_LAPTOP=1 || ON_WORK_LAPTOP=0
[[ "$DEVICE_TYPE" == "home"  ]] && ON_HOME_LAPTOP=1 || ON_HOME_LAPTOP=0

# symlink all dot_config subdirs into $XDG_CONFIG_HOME / .config
#   there are dirs in .config that aren't in dot_config and can't be (too big etc)
find $DOT_FILES_DIR/dot_config -d 1 -type d | while read -r dir; do
  ln -Ffs $dir $XDG_CONFIG_HOME/
done

ln -fs $DOT_FILES_DIR/dot_agignore/agignore ~/.agignore
ln -fs $DOT_FILES_DIR/dot_bash_profile/bash_profile ~/.bash_profile
ln -fs $DOT_FILES_DIR/dot_bashrc/bashrc ~/.bashrc
ln -fs $DOT_FILES_DIR/dot_claude-env/claude-env ~/.claude-env
mkdir -p ~/.claude
mkdir -p ~/.claude/hooks && ln -fs $DOT_FILES_DIR/dot_claude/hooks/wfh-activity-log ~/.claude/hooks/wfh-activity-log  # UserPromptSubmit + Stop hook in settings.json
# General Claude rules. A directory link, not per-file links, so the Edit tool can still write them.
mkdir -p ~/.claude/rules && ln -sfh $DOT_FILES_DIR/dot_claude/rules ~/.claude/rules/general
# General Claude skills, one directory link each (Claude Code only finds skills one level down).
# A real directory already at the target is newer local work: leave it and say so.
mkdir -p ~/.claude/skills
for skill in $DOT_FILES_DIR/dot_claude/skills/*(/N); do
  [[ -f $skill/SKILL.md ]] || continue
  target=~/.claude/skills/${skill:t}
  if [[ -d $target && ! -L $target ]]; then echo "dot-files: $target is a real directory — reconcile it with the repo copy by hand"; continue; fi
  ln -sfh $skill $target
done
# General Claude subagents, one file link each so the work overlay can add its own beside them.
mkdir -p ~/.claude/agents
for agent in $DOT_FILES_DIR/dot_claude/agents/*.md(.N); do ln -sf $agent ~/.claude/agents/${agent:t}; done
# ln -fs $DOT_FILES_DIR/dot_config/ ~/.config # handled above
#ln -fs $DOT_FILES_DIR/dot_ctags/ctags ~/.ctags
ln -fs $DOT_FILES_DIR/dot_default-gems/default-gems ~/.default-gems
ln -fs $DOT_FILES_DIR/dot_editrc/editrc ~/.editrc
ln -fs $DOT_FILES_DIR/dot_gemrc/gemrc ~/.gemrc
ln -fs $DOT_FILES_DIR/dot_gitignore_global/gitignore_global ~/.gitignore_global
ln -fs $DOT_FILES_DIR/dot_gvimrc/gvimrc ~/.gvimrc
ln -fs $DOT_FILES_DIR/dot_inputrc/inputrc ~/.inputrc
ln -fs $DOT_FILES_DIR/dot_irbrc/irbrc ~/.irbrc
#ln -fs $DOT_FILES_DIR/dot_powconfig/powconfig ~/.powconfig
# powrc below \/
#ln -fs $DOT_FILES_DIR/dot_rdebugrc/rdebugrc ~/.rdebugrc
ln -fs $DOT_FILES_DIR/dot_rgignore/rgignore ~/.rgignore
ln -fs $DOT_FILES_DIR/dot_rspec/rspec ~/.rspec
ln -fs $DOT_FILES_DIR/dot_tmux_dot_conf/tmux.conf ~/.tmux.conf
ln -fs $DOT_FILES_DIR/dot_tool_versions/tool-versions ~/.tool-versions
ln -fs $DOT_FILES_DIR/dot_vimrc/vimrc ~/.vimrc
ln -fs $DOT_FILES_DIR/dot_yarnrc/yarnrc ~/.yarnrc
mkdir -p $XDG_CONFIG_HOME/.zprezto && ln -fs $DOT_FILES_DIR/dot_zpreztorc/zpreztorc $XDG_CONFIG_HOME/.zprezto/.zpreztorc

ln -Ffs $DOT_FILES_DIR/dot_vim ~/.vim
ln -fs $DOT_FILES_DIR/sleepwatcher/dot_sleep/sleep ~/.sleep
ln -fs $DOT_FILES_DIR/sleepwatcher/dot_wakeup/wakeup ~/.wakeup

# A generic /etc/hosts, unless one is linked already: the private overlay links its own per context.
[[ -L /etc/hosts ]] || sudo ln -fs $DOT_FILES_DIR/etc_hosts/hosts /etc/hosts
sudo ln -fs $DOT_FILES_DIR/etc_zshenv/zshenv /etc/zshenv
sudo ln -fs $DOT_FILES_DIR/git_repack_all/git-repack-all /usr/local/bin/git-repack-all
chmod +x $DOT_FILES_DIR/usr_local_bin/wrapped_code
sudo ln -fs $DOT_FILES_DIR/usr_local_bin/wrapped_code /usr/local/bin/wrapped_code
chmod +x $DOT_FILES_DIR/usr_local_bin/mvimf
sudo ln -fs $DOT_FILES_DIR/usr_local_bin/mvimf /usr/local/bin/mvimf

# plists
ln -fs $DOT_FILES_DIR/sleepwatcher/homebrew.mxcl.sleepwatcher.plist $HOME/Library/LaunchAgents/homebrew.mxcl.sleepwatcher.plist
ln -fs $DOT_FILES_DIR/plists/set-gui-path.plist $HOME/Library/LaunchAgents/set-gui-path.plist
ln -fs $DOT_FILES_DIR/plists/com.jamesf.nightly-reminder.plist $HOME/Library/LaunchAgents/com.jamesf.nightly-reminder.plist
ln -fs $DOT_FILES_DIR/plists/com.jamesf.nightly-run.plist $HOME/Library/LaunchAgents/com.jamesf.nightly-run.plist
ln -fs $DOT_FILES_DIR/plists/com.jamesf.wfh-heartbeat.plist $HOME/Library/LaunchAgents/com.jamesf.wfh-heartbeat.plist
if (( ON_WORK_LAPTOP )); then
  ln -fs $DOT_FILES_DIR/plists/com.jamesf.keep-awake-at-home.plist $HOME/Library/LaunchAgents/com.jamesf.keep-awake-at-home.plist
fi
# future_claude: durable scheduled reminders/prompts that Claude sessions hand off to (dot_claude/future_claude/README.md)
mkdir -p ~/bin && ln -fs $DOT_FILES_DIR/dot_claude/future_claude/future_claude ~/bin/future_claude
# rules-changes: register of instruction edits, sent to every session as a twice-daily digest via future_claude
ln -fs $DOT_FILES_DIR/dot_claude/rules_changes/rules-changes ~/bin/rules-changes
# claude-bg: hands a script's last step (publishing an Artifact, an investigation) to a background Claude session
ln -fs $DOT_FILES_DIR/dot_claude/claude_bg/claude-bg ~/bin/claude-bg
ln -fs $DOT_FILES_DIR/plists/com.jamesf.future-claude.plist $HOME/Library/LaunchAgents/com.jamesf.future-claude.plist

# VS Code user settings — path has spaces + capitals and lives outside ~/.config,
# so it needs its own explicit symlink (the dot_config loop can't reach it).
# Pins Ruby LSP at mise (rubyLsp.rubyVersionManager). Backs up the live copy once.
VSCODE_SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
if [[ -e "$VSCODE_SETTINGS" && ! -L "$VSCODE_SETTINGS" ]]; then
  cp "$VSCODE_SETTINGS" "$VSCODE_SETTINGS.bak.$(date +%Y%m%d)"
fi
mkdir -p "$(dirname "$VSCODE_SETTINGS")"
ln -fs "$DOT_FILES_DIR/vscode/settings.json" "$VSCODE_SETTINGS"

# powrc
#ln -fs $DOT_FILES_DIR/dot_powrc/powrc ~/codez/tv-shows/.powrc

# tweaks
$DOT_FILES_DIR/tweaks/tweaks.sh

# Personal LaunchAgents (home mac only — polaris-specific services)
if (( ON_HOME_LAPTOP )); then
  for plist in \
    me.fergusons.backup-claude-sessions.plist \
    me.fergusons.device-backups.plist \
    me.fergusons.mobilesync-guard.plist \
    me.fergusons.mount-external.plist \
    me.fergusons.relay-sync.plist \
    me.fergusons.relay-sync-on-mount.plist \
    me.fergusons.screensaver-reaper.plist; do
    src="$DOT_FILES_DIR/launch_agents/$plist"
    [[ -f "$src" ]] && ln -fs "$src" "$HOME/Library/LaunchAgents/$plist"
  done
fi

# Private overlay: if the private repo (dot-files-private) is cloned,
# run its installer. It routes internally by DEVICE_TYPE — work/ for work machines,
# personal/ for home machines. Nothing machine-specific happens without it.
if (( ON_WORK_LAPTOP )); then
  PRIVATE_DOT_FILES_DIR="${PRIVATE_DOT_FILES_DIR:-$HOME/code/personal/dot-files-private}"
elif (( ON_HOME_LAPTOP )); then
  PRIVATE_DOT_FILES_DIR="${PRIVATE_DOT_FILES_DIR:-$HOME/codez/dot-files-private}"
fi
if [[ -n "$PRIVATE_DOT_FILES_DIR" ]]; then
  if [[ -x "$PRIVATE_DOT_FILES_DIR/install.sh" ]]; then
    "$PRIVATE_DOT_FILES_DIR/install.sh"
  else
    echo "dot-files-private not found at $PRIVATE_DOT_FILES_DIR — skipping private overlay."
    echo "  (clone git@github.com:JamesFerguson/dot-files-private.git there to enable it.)"
  fi
fi
