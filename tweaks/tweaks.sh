#!/bin/sh

# Make finder show hidden files, /usr, etc.
echo "Making finder show hidden files, /usr, etc."
defaults write com.apple.finder AppleShowAllFiles -boolean true

# Auto detect trackpad orientation when you place five fingers on it in natural position
# XXX: doesn't work
# echo 'Using sudo to turn on auto-detection of trackpad orientation'
# sudo defaults write com.apple.MultitouchSupport ForceAutoOrientation YES

echo 'Using sudo to raise maxfiles limits to large values'
sudo echo "" >> /etc/sysctl.conf
sudo echo "kern.maxfiles=65536" >> /etc/sysctl.conf
sudo echo "kern.maxfilesperproc=32768" >> /etc/sysctl.conf

# Make system File Save dialog expanded by default
echo 'Make system File Save dialog expanded by default'
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode  -bool true # expand save dialog
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true # expand save dialog

# Allow touchid to be used for sudo in terminal
echo 'Allow touchid to be used for sudo in terminal'
if [ ! -f /etc/pam.d/sudo_local ]; then
  sudo touch /etc/pam.d/sudo_local
  sudo echo "# sudo_local: local config file which survives system update and is included for sudo" >> /etc/pam.d/sudo_local
  sudo echo "# uncomment following line to enable touchid for sudo" >> /etc/pam.d/sudo_local
  sudo echo "auth       sufficient     pam_tid.so" >> /etc/pam.d/sudo_local
fi


# Show full path in Finder
echo 'Show full path in Finder'
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true # show path in finder

# Show file extensions in Finder
echo "Show file extensions in Finder"
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true # show path in finder

# Default Finder windows to column view
echo "Default Finder to column view"
defaults write com.apple.finder FXPreferredViewStyle -string "clmv"

# Make Finder changes effective now
echo "Restarting Finder"
killall Finder