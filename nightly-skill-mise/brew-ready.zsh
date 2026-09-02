#!/bin/zsh
# brew-ready.zsh — list Homebrew packages that have cleared the 12-day cooldown,
# using the EXACT cooldown python embedded in brew_refresh.zsh (single source of
# truth — no duplicated logic to drift). Running it re-seeds the version cache,
# same side effect as brew_refresh itself.
#
# Args: package names to EXCLUDE from the ready list (e.g. firefox visual-studio-code claude).
# stdout: one ready-to-upgrade package name per line (exclusions removed).
# stderr: the full READY/COOLING table for the human.

emulate -L zsh
set -u
DOTFILES="$HOME/code/personal/dot-files"
SRC="$DOTFILES/dot_zshrc/includes/brew_refresh.zsh"

typeset -A excl
local x
for x in "$@"; do excl[$x]=1; done

# Pull the embedded heredoc: the cooldown block's opener line ENDS with `python3 -c "`
# (the other `python3 -c "…"` in the file, for rubygems, has content after the quote).
# Grab from the line after that opener until the closing `" 2>/dev/null)`.
local py
py=$(awk '/python3 -c "$/{grab=1; next} /^" 2>\/dev\/null\)/{grab=0} grab' "$SRC")
if [[ -z "$py" ]]; then
  echo "brew-ready: could not extract cooldown python from $SRC" >&2
  exit 1
fi

local name latest st val
brew outdated --json 2>/dev/null | python3 -c "$py" 2>/dev/null \
| while IFS=$'\t' read -r name latest st val; do
  [[ -n "$name" ]] || continue
  if [[ "$st" == READY ]]; then
    if [[ -n "${excl[$name]:-}" ]]; then
      printf '  READY(excluded) %-32s %s\n' "$name" "$latest" >&2
    else
      printf '  READY           %-32s %s (%sd old)\n' "$name" "$latest" "$val" >&2
      print -r -- "$name"
    fi
  else
    printf '  COOLING         %-32s %s (%sd left)\n' "$name" "$latest" "$val" >&2
  fi
done
