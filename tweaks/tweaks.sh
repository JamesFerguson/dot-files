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

# raise_sysctl KEY MIN: make sure the limit is at least MIN after a reboot, and never lower it.
# Recent macOS sizes these defaults by RAM, often well above MIN, and a line in /etc/sysctl.conf
# would cap them. Older runs of this script appended a copy each time; keep only the last.
raise_sysctl() {
  if [ -f /etc/sysctl.conf ] && [ "$(grep -c "^$1=" /etc/sysctl.conf)" -gt 1 ]; then
    last=$(grep "^$1=" /etc/sysctl.conf | tail -1)
    sudo sed -i '' "/^$1=/d" /etc/sysctl.conf
    echo "$last" | sudo tee -a /etc/sysctl.conf >/dev/null
    echo "  removed duplicate $1 lines from /etc/sysctl.conf"
  fi
  if [ "$(sysctl -n "$1")" -lt "$2" ] && ! grep -q "^$1=" /etc/sysctl.conf 2>/dev/null; then
    echo "$1=$2" | sudo tee -a /etc/sysctl.conf >/dev/null
    sudo sysctl -w "$1=$2" >/dev/null
    echo "  raised $1 to $2"
  fi
}

echo 'Raising maxfiles limits where they are low (sudo if so)'
raise_sysctl kern.maxfiles 65536
raise_sysctl kern.maxfilesperproc 32768

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
