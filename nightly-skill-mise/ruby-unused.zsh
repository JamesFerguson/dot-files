#!/bin/zsh
# ruby-unused.zsh — print mise ruby versions that are safe-to-consider for uninstall:
# installed, NOT pinned by any repo, and older than the newest pinned version.
#
# Scans the WHOLE ~/code tree (not brew_refresh's maxdepth 4) so a deep pin in
# core-payments/* or a worktree never makes a version look unused when it isn't.
# Prints candidates one per line to stdout; a human-readable tally to stderr.
# It NEVER uninstalls — uninstalling ruby is destructive, so the caller decides.

emulate -L zsh
set -u
CODE_DIR="${CODE_DIR:-$HOME/code}"

# used pins (normalized: strip "ruby-", trim, keep only clean X.Y.Z)
local -a used
used=("${(@f)$(
  { find "$CODE_DIR" -name .ruby-version -not -path '*/node_modules/*' -exec cat {} \; 2>/dev/null
    find "$CODE_DIR" -name .tool-versions -not -path '*/node_modules/*' -exec grep -h '^ruby ' {} \; 2>/dev/null | awk '{print $2}'
  } | sed 's/^ruby-//' | tr -d ' ' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -u
)}")
used=(${used:#})

local -a installed
eval "installed=( $(mise ls ruby --installed 2>/dev/null | awk '{print $2}') )"

# newest pinned version (sort -V)
local newest_used
newest_used=$(printf '%s\n' "${used[@]}" | sort -V | tail -1)

echo "installed: ${installed[*]}" >&2
echo "pinned:    ${used[*]}" >&2
echo "newest pinned: $newest_used" >&2
echo "-- candidates (installed, unpinned, older than newest pinned) --" >&2

local v
for v in "${installed[@]}"; do
  [[ " ${used[*]} " == *" $v "* ]] && continue                      # keep: pinned somewhere
  [[ "$(printf '%s\n%s\n' "$v" "$newest_used" | sort -V | tail -1)" != "$newest_used" ]] && continue  # keep: newer than newest pinned
  echo "  CANDIDATE $v" >&2
  print -r -- "$v"
done
