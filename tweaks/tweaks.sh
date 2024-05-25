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



# Show full path in Finder
echo 'Show full path in Finder'
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true # show path in finder

# Show file extensions in Finder
echo "Show file extensions in Finder"
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true # show path in finder

# Make Finder changes effective now
echo "Restarting Finder"
killall Finder