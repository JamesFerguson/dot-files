#!/bin/zsh

if [[ $[RANDOM % 16] -eq 0 ]]; then
  echo "\n\n---------------\n  Updating Homebrew\n-----------------\n\n"
  brew update | grep "Updated Homebrew"

  # Find ruby versions actually used across all repos under $CODE_DIR.
  echo "\n\n  Scanning $CODE_DIR for ruby versions in use..."
  local -a used_versions=()
  while IFS= read -r file; do
    local v
    if [[ "$file" == *".ruby-version" ]]; then
      v=$(cat "$file" | tr -d '[:space:]')
    else
      # .tool-versions — extract the ruby line
      v=$(grep '^ruby ' "$file" | awk '{print $2}')
    fi
    v="${v#ruby-}"  # strip leading "ruby-" prefix if present
    [[ -n "$v" ]] && used_versions+=("$v")
  done < <(find "$CODE_DIR" -maxdepth 4 \( -name ".ruby-version" -o -name ".tool-versions" \) 2>/dev/null)
  used_versions=(${(u)used_versions})  # unique

  # Get all installed ruby versions and find the newest used version.
  local -a installed_versions=()
  eval "installed_versions=( $(asdf list ruby 2>/dev/null | sed 's/[* ]//g') )"

  # Sort used versions and find the newest one.
  local newest_used
  newest_used=$(printf '%s\n' "${used_versions[@]}" | sort -V | tail -1)

  # Candidate for removal: not used AND not newer than or equal to newest used version.
  local -a unused_versions=()
  for v in "${installed_versions[@]}"; do
    # Keep if it's a used version.
    [[ ${used_versions[(ie)$v]} -le ${#used_versions} ]] && continue
    # Keep if it's newer than or equal to the newest used version.
    [[ "$(printf '%s\n' "$v" "$newest_used" | sort -V | tail -1)" != "$newest_used" ]] && continue
    unused_versions+=("$v")
  done

  if [[ ${#unused_versions[@]} -gt 0 ]]; then
    echo "  The following ruby versions are installed but not used in any repo under $CODE_DIR:"
    for v in "${unused_versions[@]}"; do echo "    $v"; done
    echo -n "  Uninstall these versions? [y/N] "
    read -r uninstall_answer
    if [[ "$uninstall_answer" == "y" || "$uninstall_answer" == "Y" ]]; then
      for v in "${unused_versions[@]}"; do
        echo "  Uninstalling ruby $v"
        asdf uninstall ruby "$v"
      done
    fi
  fi

  # Check latest rubygems version once, then only update rubies that are behind.
  echo "\n\n  Updating rubygems (current ruby --->" $(asdf current ruby)")"
  local latest_rubygems
  latest_rubygems=$(curl -sf https://rubygems.org/api/v1/gems/rubygems-update.json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")
  echo "  Latest rubygems: $latest_rubygems"

  eval "ruby_versions=( $(asdf list ruby | sed 's/*/ /g') )"
  for version in "${ruby_versions[@]}"; do
    echo "\n\n-----------------\n  Updating gems for ruby $version\n-----------------\n\n"
    local current_rubygems
    current_rubygems=$(ASDF_RUBY_VERSION=$version gem --version 2>/dev/null)
    if [[ "$current_rubygems" == "$latest_rubygems" ]]; then
      echo "  ruby $version - rubygems $current_rubygems already up to date, skipping"
    else
      echo "  ruby $version - rubygems $current_rubygems -> $latest_rubygems, updating..."
      ASDF_RUBY_VERSION=$version gem update --system
    fi
  done

  echo "\n\n---------------\n  Updating ASDF plugin lists\n-----------------\n\n"
  asdf plugin update --all

  echo "  Checking ASDF installed versions against latest"
  local asdf_outdated
  asdf_outdated=$(asdf latest --all 2>&1)
  echo "$asdf_outdated"

  if echo "$asdf_outdated" | grep -q $'\tmissing$'; then
    echo -n "\n  ASDF tools have newer versions available. Install latest and update .tool-versions? [y/N] "
    read -r asdf_answer
    if [[ "$asdf_answer" == "y" || "$asdf_answer" == "Y" ]]; then
      while IFS=$'\t' read -r tool latest install_status; do
        [[ "$install_status" == "missing" ]] || continue
        echo "  Installing $tool $latest"
        if asdf install "$tool" "$latest"; then
          asdf set --home "$tool" "$latest"
          echo "  $tool updated to $latest"
        else
          echo "  $tool $latest install failed, skipping"
        fi
      done <<< "$asdf_outdated"
    fi
  fi

  echo "\n\n---------------\n  Checking for outdated Homebrew formulae\n-----------------\n\n"
  local outdated
  outdated=$(brew outdated)
  echo "$outdated"

  local outdated_count
  outdated_count=$(echo "$outdated" | grep -c '.')

  if [[ $outdated_count -gt 5 ]]; then
    echo "\n  $outdated_count outdated packages found."
    echo -n "  Run brew upgrade && brew cleanup? [y/N] "
    read -r brew_answer
    if [[ "$brew_answer" == "y" || "$brew_answer" == "Y" ]]; then
      brew upgrade && brew cleanup
    fi
  fi
fi
