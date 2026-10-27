#!/bin/zsh
# mise-prune-safe.zsh — uninstall the tool versions `mise prune` calls unused, minus any a
# repo still needs. mise only knows the configs it has loaded, so its list can include a
# version a repo it hasn't seen pins. A candidate is kept when:
#   - any pin file under ~/code (.tool-versions, mise.toml, .mise.toml, mise.local.toml,
#     .ruby-version, .nvmrc, .node-version, package.json) names its version, or
#   - `mise current` resolves to it in a repo root, $HOME or an MCP server's directory, or
#   - it's a ruby: rubies carry each repo's gems, so they go through ruby-unused.zsh and
#     James's approval instead.
# Removing a version a repo still uses isn't free: auto_install puts it back bare on the
# next use, without the repo's gems or global packages.
#
# Usage: mise-prune-safe.zsh [--dry]   Prints "removed"/"kept" lines.

emulate -L zsh
set -u
HERE="${0:A:h}"
CODE_DIR="${CODE_DIR:-$HOME/code}"
DRY=0; [[ "${1:-}" == "--dry" ]] && DRY=1
export MISE_AUTO_INSTALL=false MISE_NOT_FOUND_AUTO_INSTALL=false

local -a candidates
candidates=(${(f)"$(mise prune --dry-run 2>&1 | sed -nE 's/^mise ([^ ]+) is prunable:.*/\1/p')"})
(( ${#candidates} )) || { echo "  nothing to prune"; exit 0 }

# Every version string a pin file or a mise resolution names, one per line.
local pinned
pinned=$(
  find "$CODE_DIR" -name node_modules -prune -o \
    \( -name .tool-versions -o -name mise.toml -o -name .mise.toml -o -name mise.local.toml \
       -o -name .ruby-version -o -name .nvmrc -o -name .node-version -o -name package.json \) -print 2>/dev/null |
    while IFS= read -r f; do grep -oE '[0-9]+(\.[0-9]+)+[^ "'\'']*' "$f" 2>/dev/null; done
  for d in "$HOME" "${(@f)$("$HERE/repo-dirs.zsh")}"; do
    [[ -d "$d" ]] && ( cd "$d" && mise current 2>/dev/null | awk '{for (i = 2; i <= NF; i++) print $i}' )
  done
)
local -a pinned_set=(${(u)${(f)pinned}})

local c tool ver
for c in "${candidates[@]}"; do
  tool="${c%@*}"; ver="${c#*@}"
  if (( ${pinned_set[(Ie)$ver]} )); then echo "  kept $c (a repo pins or resolves it)"; continue; fi
  if [[ "$tool" == ruby ]]; then echo "  kept $c (rubies need approval: see ruby-unused.zsh)"; continue; fi
  if (( DRY )); then echo "  would remove $c"; continue; fi
  if mise uninstall "$c" >/dev/null 2>&1; then echo "  removed $c"; else echo "  FAILED to remove $c"; fi
done
