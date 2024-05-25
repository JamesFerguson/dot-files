#!/bin/zsh

# symlink all dot_config subdirs into $XDG_CONFIG_HOME
find $HOME/codez/dot-files/dot_config -d 1 -type d | while read -r dir; do
    ln -Ffs $dir $XDG_CONFIG_HOME/
done

ln -fs ~/codez/dot-files/dot_agignore/agignore ~/.agignore
ln -fs ~/codez/dot-files/dot_asdfrc/asdfrc ~/.asdfrc
ln -fs ~/codez/dot-files/dot_bash_profile/bash_profile ~/.bash_profile
ln -fs ~/codez/dot-files/dot_bashrc/bashrc ~/.bashrc
ln -fs ~/codez/dot-files/dot_bundle/ ~/.bundle
#ln -fs ~/codez/dot-files/dot_ctags/ctags ~/.ctags
ln -fs ~/codez/dot-files/dot_default-gems/default-gems ~/.default-gems
ln -fs ~/codez/dot-files/dot_editrc/editrc ~/.editrc
ln -fs ~/codez/dot-files/dot_gemrc/gemrc ~/.gemrc
ln -fs ~/codez/dot-files/dot_gitconfig/gitconfig ~/.gitconfig
ln -fs ~/codez/dot-files/dot_gitignore_global/gitignore_global ~/.gitignore_global
ln -fs ~/codez/dot-files/dot_gvimrc/gvimrc ~/.gvimrc
ln -fs ~/codez/dot-files/dot_inputrc/inputrc ~/.inputrc
ln -fs ~/codez/dot-files/dot_irbrc/irbrc ~/.irbrc
#ln -fs ~/codez/dot-files/dot_powconfig/powconfig ~/.powconfig
# powrc below \/
#ln -fs ~/codez/dot-files/dot_rdebugrc/rdebugrc ~/.rdebugrc
ln -fs ~/codez/dot-files/dot_rgignore/rgignore ~/.rgignore
ln -fs ~/codez/dot-files/dot_rubocop_dot_yml/rubocop.yml ~/.rubocop.yml
ln -fs ~/codez/dot-files/dot_ruby_version/ruby-version ~/.ruby-version
ln -fs ~/codez/dot-files/dot_rspec/rspec ~/.rspec
ln -fs ~/codez/dot-files/dot_screenrc/screenrc ~/.screenrc
ln -fs ~/codez/dot-files/dot_tmux_dot_conf/tmux.conf ~/.tmux.conf
ln -fs ~/codez/dot-files/dot_tool_versions/tool-versions ~/.tool-versions
ln -fs ~/codez/dot-files/dot_vimrc/vimrc ~/.vimrc
ln -Ffs ~/codez/dot-files/dot_vim ~/.vim
ln -fs ~/codez/dot-files/dot_zshrc/zshrc ~/.zshrc
ln -fs ~/codez/dot-files/git_repack_all/git-repack-all /usr/local/bin/git-repack-all
sudo ln -fs ~/codez/dot-files/etc_hosts/hosts /etc/hosts
sudo ln -fs ~/codez/dot-files/etc_zshenv/zshenv /etc/zshenv
sudo ln -fs ~/codez/dot-files/etc_zshenv/zshenv /etc/zsh/zshenv

# powrc
#ln -fs ~/codez/dot-files/dot_powrc/powrc ~/Blake/rex-student/.powrc
#ln -fs ~/codez/dot-files/dot_powrc/powrc ~/Blake/mathseeds/.powrc
#ln -fs ~/codez/dot-files/dot_powrc/powrc ~/codez/tv-shows/.powrc
#ln -fs ~/codez/dot-files/dot_powrc/powrc ~/Blake/blake-admin/.powrc

# tweaks
~/codez/dot-files/tweaks/install_mvimf.sh
~/codez/dot-files/tweaks/tweaks.sh
