#!/bin/zsh

if [[ $[RANDOM % 16] -eq 0 ]]; then
  echo "  Updating Homebrew"
  brew update | grep "Updated Homebrew"

  echo "  Checking for outdated formulae"
  brew outdated

  echo "\n\n  Updating rubygems\ncurrent ruby --->" $(asdf current ruby)
  eval "ruby_versions=( $(asdf list ruby | sed 's/*/ /g') )"
  for version in "${ruby_versions[@]}"; do
    asdf shell ruby $version
    echo "  Updating gems for ruby $version"
    gem update --system
  done

  echo "\n\n  Updating ASDF plugin lists"
  asdf plugin update --all

  echo "  Checking ASDF installed versions against latest"
  asdf latest --all
fi
