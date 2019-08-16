#!/bin/zsh

if [[ $[RANDOM % 16] -eq 0 ]]; then
  echo "  Updating Homebrew"
  brew update | grep "Updated Homebrew"
  echo "  Checking for outdated formulae"
  brew outdated
  echo "  Updating rubygems"
  gem update --system
fi
