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
# A SwiftBar/GUI launch can start with a thin PATH; this is the shared cooldown entrypoint,
# so make brew/gh/python3/mise resolve regardless of how it was invoked.
export PATH="$HOME/.local/share/mise/shims:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
DOTFILES="$HOME/code/personal/dot-files"
SRC="$DOTFILES/dot_zshrc/includes/brew_refresh.zsh"

typeset -A excl
local x
for x in "$@"; do excl[$x]=1; done

# Pull the embedded brew-cooldown heredoc. brew_refresh.zsh also has a one-line
# `python3 -c "…"` for rubygems (content follows the quote, so a `"$`-ending anchor
# skips it); the mise cooldown now lives in its own mise-ready.py, not a heredoc here.
# Keep the brew-specific marker `brew outdated --json … python3 -c "` as the opener so
# the anchor stays unambiguous if another multi-line heredoc is ever added back.
# Grab from the line after that opener until the closing `" 2>/dev/null)`.
local py
py=$(awk '/brew outdated --json.*python3 -c "$/{grab=1; next} /^" 2>\/dev\/null\)/{grab=0} grab' "$SRC")
if [[ -z "$py" ]]; then
  echo "brew-ready: could not extract cooldown python from $SRC" >&2
  exit 1
fi

# Machine-readable mode for the SwiftBar plugin: raw `name<TAB>latest<TAB>READY|COOLING<TAB>days`
# straight from the cooldown python -- no human formatting, no exclusions applied.
if [[ -n "${BREW_READY_TSV:-}" ]]; then
  brew outdated --json 2>/dev/null | python3 -c "$py" 2>/dev/null
  exit 0
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
