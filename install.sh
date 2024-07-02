#!/bin/zsh

# Dot files dir
#   - if on FatZebra laptop
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
ln -fs $DOT_FILES_DIR/dot_bundle/ ~/.bundle
# ln -fs $DOT_FILES_DIR/dot_config/ ~/.config # handled above
#ln -fs $DOT_FILES_DIR/dot_ctags/ctags ~/.ctags
ln -fs $DOT_FILES_DIR/dot_default-gems/default-gems ~/.default-gems
ln -fs $DOT_FILES_DIR/dot_editrc/editrc ~/.editrc
ln -fs $DOT_FILES_DIR/dot_gemrc/gemrc ~/.gemrc
ln -fs $DOT_FILES_DIR/dot_gitconfig/gitconfig ~/.gitconfig
ln -fs $DOT_FILES_DIR/dot_gitignore_global/gitignore_global ~/.gitignore_global
ln -fs $DOT_FILES_DIR/dot_gvimrc/gvimrc ~/.gvimrc
ln -fs $DOT_FILES_DIR/dot_inputrc/inputrc ~/.inputrc
ln -fs $DOT_FILES_DIR/dot_irbrc/irbrc ~/.irbrc
#ln -fs $DOT_FILES_DIR/dot_powconfig/powconfig ~/.powconfig
# powrc below \/
#ln -fs $DOT_FILES_DIR/dot_rdebugrc/rdebugrc ~/.rdebugrc
ln -fs $DOT_FILES_DIR/dot_rgignore/rgignore ~/.rgignore
ln -fs $DOT_FILES_DIR/dot_rubocop_dot_yml/rubocop.yml ~/.rubocop.yml
ln -fs $DOT_FILES_DIR/dot_ruby_version/ruby-version ~/.ruby-version
ln -fs $DOT_FILES_DIR/dot_rspec/rspec ~/.rspec
ln -fs $DOT_FILES_DIR/dot_screenrc/screenrc ~/.screenrc
ln -fs $DOT_FILES_DIR/dot_tmux_dot_conf/tmux.conf ~/.tmux.conf
ln -fs $DOT_FILES_DIR/dot_tool_versions/tool-versions ~/.tool-versions
ln -fs $DOT_FILES_DIR/dot_vimrc/vimrc ~/.vimrc
ln -Ffs $DOT_FILES_DIR/dot_vim ~/.vim
ln -fs $DOT_FILES_DIR/sleepwatcher/dot_sleep/sleep ~/.sleep
ln -fs $DOT_FILES_DIR/sleepwatcher/dot_wakeup/wakeup ~/.wakeup

sudo ln -fs $DOT_FILES_DIR/etc_hosts/hosts /etc/hosts
sudo ln -fs $DOT_FILES_DIR/etc_zshenv/zshenv /etc/zshenv
sudo ln -fs $DOT_FILES_DIR/git_repack_all/git-repack-all /usr/local/bin/git-repack-all

# powrc
#ln -fs $DOT_FILES_DIR/dot_powrc/powrc ~/codez/tv-shows/.powrc

# tweaks
./tweaks/install_mvimf.sh
./tweaks/tweaks.sh
