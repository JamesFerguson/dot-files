#!/bin/sh

# Make finder show hidden files, /usr, etc.
defaults write com.apple.Finder AppleShowAllFiles YES

# Auto detect trackpad orientation when you place five fingers on it in natural position
echo 'Using sudo to turn on auto-detection of trackpad orientation'
sudo defaults write com.apple.MultitouchSupport ForceAutoOrientation YES

