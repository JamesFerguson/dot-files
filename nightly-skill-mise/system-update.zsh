#!/bin/zsh
# system-update.zsh — the system half of the nightly refresh, automated.
# Mirrors dot_zshrc/includes/brew_refresh.zsh but non-interactive (you already
# authorized "update all the things"), and reuses that file's cooldown logic via
# brew-ready.zsh so there's one source of truth.
#
# Steps:
#   1. brew update
#   2. brew upgrade of packages past the 12-day cooldown, minus the exclusions
#      passed as args (default: firefox visual-studio-code claude), + brew cleanup
#   3. mise plugins update (only when plugin-backed tools exist; core tools need none)
#   4. mise: install any version newer than what's pinned (`bump` in `mise outdated`),
#      and pin it in ~/.tool-versions as the global default
#   5. rubygems: `gem update --system` for any installed ruby whose rubygems is behind
#
# Run this to completion BEFORE the repo sweep (repo bundles want current ruby/bundler,
# and running it first avoids swapping mise/git out from under a running sweep).
#
# Usage: system-update.zsh [exclude-pkg ...]

emulate -L zsh
set -u
HERE="${0:A:h}"
EXCLUDE=("$@"); [[ ${#EXCLUDE} -eq 0 ]] && EXCLUDE=(firefox visual-studio-code claude)

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

echo "\n===== 4. mise: install newer pinned-tool versions ====="
# `mise outdated --bump --json` keys each tool -> {requested,current,bump,latest,...};
# a non-null `bump` is a version newer than what's pinned. Install it and pin it in
# ~/.tool-versions (NOT `mise use -g`: ~/.tool-versions overrides ~/.config/mise, so a
# -g write would be silently ignored). Use the canonical JSON key (e.g. node) — mise
# rewrites the matching .tool-versions line (nodejs) in place.
mise outdated --bump --json 2>/dev/null | python3 -c '
import sys, json
raw = sys.stdin.read().strip()
data = json.loads(raw) if raw else {}
for tool, info in data.items():
    bump = info.get("bump")
    if bump:
        print(f"{tool}\t{bump}")
' | while IFS=$'\t' read -r tool bump; do
  [[ -n "$tool" ]] || continue
  echo "  installing $tool $bump"
  if mise install "$tool@$bump" 2>&1 | tail -1; then
    mise use --path "$HOME/.tool-versions" "$tool@$bump" && echo "    $tool pinned -> $bump (~/.tool-versions)"
  else
    echo "    $tool $bump install FAILED, skipping"
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
echo "\n===== system-update complete ====="
