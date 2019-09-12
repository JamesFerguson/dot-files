#!/bin/sh

# Make finder show hidden files, /usr, etc.
echo "Making finder show hidden files, /usr, etc."
defaults write com.apple.Finder AppleShowAllFiles YES

# Auto detect trackpad orientation when you place five fingers on it in natural position
echo 'Using sudo to turn on auto-detection of trackpad orientation'
sudo defaults write com.apple.MultitouchSupport ForceAutoOrientation YES

# Override default maxfiles limits
echo 'Using sudo to raise maxfiles limits to large values'
sudo echo "" >> /etc/sysctl.conf
sudo echo "kern.maxfiles=65536" >> /etc/sysctl.conf
sudo echo "kern.maxfilesperproc=32768" >> /etc/sysctl.conf
