#!/bin/sh
# Safe to re-run: each tweak only writes, and Finder only restarts, when something is different.

finder_changed=0

# set_default DOMAIN KEY TYPE VALUE READ_BACK: write it unless `defaults read` already gives READ_BACK.
set_default() {
  if [ "$(defaults read "$1" "$2" 2>/dev/null)" != "$5" ]; then
    defaults write "$1" "$2" "$3" "$4"
    [ "$1" = com.apple.finder ] && finder_changed=1
  fi
}

# Make finder show hidden files, /usr, etc.
echo "Making finder show hidden files, /usr, etc."
set_default com.apple.finder AppleShowAllFiles -boolean true 1

# Auto detect trackpad orientation when you place five fingers on it in natural position
# XXX: doesn't work
# echo 'Using sudo to turn on auto-detection of trackpad orientation'
# sudo defaults write com.apple.MultitouchSupport ForceAutoOrientation YES

# Older versions of this script appended maxfiles lines to /etc/sysctl.conf. macOS now sizes those
# limits by RAM, well above the old values, so the lines only cap them; .zshenv's ulimit covers shells.
if grep -qE '^kern\.maxfiles(perproc)?=(65536|32768)$' /etc/sysctl.conf 2>/dev/null; then
  echo 'Removing the old maxfiles caps from /etc/sysctl.conf (sudo)'
  sudo sed -i '' -E '/^kern\.maxfiles(perproc)?=(65536|32768)$/d' /etc/sysctl.conf
fi

# Make system File Save dialog expanded by default
echo 'Make system File Save dialog expanded by default'
set_default NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true 1  # expand save dialog
set_default NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true 1 # expand save dialog

# Allow touchid to be used for sudo in terminal
echo 'Allow touchid to be used for sudo in terminal'
if [ ! -f /etc/pam.d/sudo_local ]; then
  printf "# sudo_local: local config file which survives system update and is included for sudo\n# uncomment following line to enable touchid for sudo\nauth       sufficient     pam_tid.so\n" | sudo tee /etc/pam.d/sudo_local
fi


# Show full path in Finder
echo 'Show full path in Finder'
set_default com.apple.finder _FXShowPosixPathInTitle -bool true 1 # show path in finder

# Show file extensions in Finder
echo "Show file extensions in Finder"
set_default NSGlobalDomain AppleShowAllExtensions -bool true 1

# Default Finder windows to column view
echo "Default Finder to column view"
set_default com.apple.finder FXPreferredViewStyle -string clmv clmv

# Make Finder changes effective now
if [ "$finder_changed" = 1 ]; then
  echo "Restarting Finder"
  killall Finder
fi
