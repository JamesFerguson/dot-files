#!/bin/zsh
# system-update.zsh — the system half of the nightly refresh, automated.
# Mirrors dot_zshrc/includes/brew_refresh.zsh but non-interactive (you already
# authorized "update all the things"), and reuses that file's cooldown logic via
# brew-ready.zsh so there's one source of truth.
#
# Steps:
#   1. brew update
#   2. brew upgrade of packages past the 12-day cooldown, minus the exclusions
#      passed as args (default: firefox visual-studio-code claude claude-code), + brew cleanup
#   3. mise plugins update (only when plugin-backed tools exist; core tools need none)
#   4. mise: install any version newer than what's pinned (`bump` in `mise outdated`),
#      and pin it in ~/.tool-versions as the global default
#   5. rubygems: `gem update --system` for any installed ruby whose rubygems is behind
#   6. mise: remove the installs `mise prune` calls unused unless a repo still pins or
#      resolves them (mise-prune-safe.zsh), and report drift between the global config's
#      ruby fallback prefix and the ~/.tool-versions ruby
#   7. stdio MCP servers that start in a repo: re-bundle if needed and check each starts
#
# Run this to completion BEFORE the repo sweep (repo bundles want current ruby/bundler,
# and running it first avoids swapping mise/git out from under a running sweep).
#
# Usage: system-update.zsh [exclude-pkg ...]

emulate -L zsh
set -u
HERE="${0:A:h}"
EXCLUDE=("$@"); [[ ${#EXCLUDE} -eq 0 ]] && EXCLUDE=(firefox visual-studio-code claude claude-code)

echo "===== 1. brew update ====="
brew update 2>&1 | tail -3

echo "\n===== 2. brew upgrade (past 12-day cooldown, excluding: ${EXCLUDE[*]}) ====="
local -a ready
ready=("${(@f)$("$HERE/brew-ready.zsh" "${EXCLUDE[@]}")}")
ready=(${ready:#})
if [[ ${#ready} -gt 0 ]]; then
  echo "upgrading: ${ready[*]}"
  echo "(note: brew may also pull in outdated *dependencies* of these, cooldown or not)"
  brew upgrade "${ready[@]}" && brew cleanup
else
  echo "nothing past cooldown to upgrade."
fi

echo "\n===== 3. mise plugins update ====="
# mise's core backends (node, ruby, python, go, ...) have no git plugin to update —
# `plugins update` only applies to asdf/vfox-backed plugins. Skip cleanly when none.
if [[ -n "$(mise plugins ls 2>/dev/null)" ]]; then
  mise plugins update 2>&1 | tail -20
else
  echo "no plugins installed — mise core tools need no plugin update"
fi

echo "\n===== 4. mise: install cooled tool versions (${MISE_COOLDOWN_DAYS:-10}d cooldown) ====="
# mise-ready.py picks, per outdated tool, the newest version that has soaked the cooldown
# within the same major and build variant (the mise-side twin of brew-ready.zsh). It prints
# <tool>\t<version> for ready tools and a READY/COOLING/UNDATED/HELD table to stderr; tools
# that are undated (ruby) or would cross a major/variant (python, yarn) stay manual. mise maps
# the canonical key (node) to the matching .tool-versions line (nodejs) on `use --path`.
python3 "$HOME/code/personal/dot-files/dot_zshrc/includes/mise-ready.py" | while IFS=$'\t' read -r tool ver; do
  [[ -n "$tool" && -n "$ver" ]] || continue
  echo "  installing $tool $ver"
  if mise install "$tool@$ver" 2>&1 | tail -1; then
    mise use --path "$HOME/.tool-versions" "$tool@$ver" && echo "    $tool pinned -> $ver (~/.tool-versions)"
  else
    echo "    $tool $ver install FAILED, skipping"
  fi
done

echo "\n===== 5. rubygems: update rubies behind latest ====="
local latest_rg
latest_rg=$(curl -sf https://rubygems.org/api/v1/gems/rubygems-update.json 2>/dev/null \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['version'])" 2>/dev/null)
echo "latest rubygems: ${latest_rg:-<unknown>}"
local v gem_bin cur
eval "rubies=( $(mise ls ruby --installed 2>/dev/null | awk '{print $2}') )"
for v in "${rubies[@]}"; do
  gem_bin="$(mise where ruby@"$v" 2>/dev/null)/bin/gem"
  [[ -x "$gem_bin" ]] || { echo "  ruby $v: no gem bin, skip"; continue; }
  cur=$("$gem_bin" --version 2>/dev/null)
  if [[ -n "$latest_rg" && "$cur" == "$latest_rg" ]]; then
    echo "  ruby $v: rubygems $cur up to date"
  else
    echo "  ruby $v: rubygems $cur -> updating"
    "$gem_bin" update --system 2>&1 | tail -1
  fi
done
echo "\n===== 6. mise: prune unused installs, and ruby fallback drift ====="
"$HERE/mise-prune-safe.zsh"
# The global config's ruby prefix is the fallback outside $HOME; it should follow ~/.tool-versions.
local home_ruby fallback_ruby
home_ruby=$(awk '$1 == "ruby" {print $2}' "$HOME/.tool-versions")
fallback_ruby=$(sed -nE 's/^ruby *= *"([^"]+)".*/\1/p' "$HOME/.config/mise/config.toml")
if [[ -n "$home_ruby" && -n "$fallback_ruby" && "$home_ruby" != "$fallback_ruby"* ]]; then
  echo "  RUBY FALLBACK DRIFT: ~/.config/mise/config.toml has ruby = \"$fallback_ruby\" but ~/.tool-versions pins $home_ruby; bump the prefix to \"${home_ruby%.*}\""
else
  echo "  ruby fallback \"$fallback_ruby\" matches ~/.tool-versions ($home_ruby)"
fi
echo "\n===== 7. MCP servers that run from a repo ====="
"$HERE/mcp-smoke.zsh" || echo "  (a failed server needs a look before the next /mcp reconnect)"
echo "\n===== 8. claude.ai connectors, synced plugins and account skills ====="
"$HERE/connector-check.zsh" || echo "  (the org turned something back on: deny or disable it, or add it to ALLOWED)"
echo "\n===== system-update complete ====="
