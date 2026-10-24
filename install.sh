#!/bin/zsh

# Dot files dir
#   - if on the work laptop
if [[ "$(hostname)" == *"fz-"* ]]; then
  ON_WORK_LAPTOP=1
  DOT_FILES_DIR="$HOME/code/personal/dot-files"
else
  ON_WORK_LAPTOP=0
  DOT_FILES_DIR="$HOME/codez/dot-files"
fi

# symlink all dot_config subdirs into $XDG_CONFIG_HOME / .config
#   there are dirs in .config that aren't in dot_config and can't be (too big etc)
find $DOT_FILES_DIR/dot_config -d 1 -type d | while read -r dir; do
  ln -Ffs $dir $XDG_CONFIG_HOME/
done

ln -fs $DOT_FILES_DIR/dot_agignore/agignore ~/.agignore
ln -fs $DOT_FILES_DIR/dot_bash_profile/bash_profile ~/.bash_profile
ln -fs $DOT_FILES_DIR/dot_bashrc/bashrc ~/.bashrc
ln -fs $DOT_FILES_DIR/dot_claude-env/claude-env ~/.claude-env
mkdir -p ~/.claude && ln -fs $DOT_FILES_DIR/dot_claude/statusline.rb ~/.claude/statusline.rb
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
ln -fs $DOT_FILES_DIR/dot_zpreztorc/zpreztorc $XDG_CONFIG_HOME/.zprezto/.zpreztorc

ln -Ffs $DOT_FILES_DIR/dot_vim ~/.vim
ln -fs $DOT_FILES_DIR/sleepwatcher/dot_sleep/sleep ~/.sleep
ln -fs $DOT_FILES_DIR/sleepwatcher/dot_wakeup/wakeup ~/.wakeup

sudo ln -fs $DOT_FILES_DIR/etc_hosts/hosts /etc/hosts
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
./tweaks/tweaks.sh

# Work overlay: if the private work-dot-files repo is cloned, run its installer.
# It sets up the work-specific Homebrew formulae, the OpenSearch LaunchAgent, config
# symlinks, and the Claude Code MCP servers. Nothing work-specific happens without it.
WORK_DOT_FILES_DIR="${WORK_DOT_FILES_DIR:-$HOME/code/personal/work-dot-files}"
if [[ -x "$WORK_DOT_FILES_DIR/install-fz.sh" ]]; then
  "$WORK_DOT_FILES_DIR/install-fz.sh"
else
  echo "work-dot-files not found at $WORK_DOT_FILES_DIR — skipping work overlay."
  echo "  (clone git@github.com:JamesFerguson/work-dot-files.git there to enable it.)"
fi
