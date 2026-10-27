#!/bin/zsh
# ruby-unused.zsh — print mise ruby versions that are safe-to-consider for uninstall:
# installed, NOT used by any repo, and older than the newest used version.
#
# "Used" is the union of every pin file in the WHOLE ~/code tree (.ruby-version,
# .tool-versions, and the ruby entry in mise.toml / .mise.toml / mise.local.toml) and
# what `mise current ruby` resolves to in each repo root, $HOME and each stdio MCP
# server's directory. Asking mise matters because a mise.toml outranks .tool-versions,
# and a prefix pin ("4.0") resolves to a version no file names. Uninstalling a version
# a repo still resolves to is worse than it looks: mise's auto_install brings it back
# on the next use with an empty gem home, so the repo fails with Bundler::GemNotFound.
#
# Prints candidates one per line to stdout; a human-readable tally to stderr.
# It NEVER uninstalls — uninstalling ruby is destructive, so the caller decides.

emulate -L zsh
set -u
CODE_DIR="${CODE_DIR:-$HOME/code}"
HERE="${0:A:h}"
# Never let a probe install a missing version.
export MISE_AUTO_INSTALL=false MISE_NOT_FOUND_AUTO_INSTALL=false

clean_versions() { sed 's/^ruby-//' | tr -d ' "' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' }

pin_version() {   # $1 = pin file; prints the ruby version it names
  case "${1:t}" in
    .ruby-version)  cat "$1" ;;
    .tool-versions) awk '$1 == "ruby" {print $2}' "$1" ;;
    *)              grep -E '^[[:space:]]*ruby[[:space:]]*=' "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' ;;
  esac
}

local -a used
used=("${(@f)$(
  { find "$CODE_DIR" -name node_modules -prune -o \
      \( -name .ruby-version -o -name .tool-versions -o -name mise.toml -o -name .mise.toml -o -name mise.local.toml \) \
      -print 2>/dev/null | while IFS= read -r f; do pin_version "$f" 2>/dev/null; done
    for d in "$HOME" "${(@f)$("$HERE/repo-dirs.zsh")}"; do
      [[ -d "$d" ]] && ( cd "$d" && mise current ruby 2>/dev/null )
    done
  } | clean_versions | sort -u
)}")
used=(${used:#})

local -a installed
eval "installed=( $(mise ls ruby --installed 2>/dev/null | awk '{print $2}') )"

# newest used version (sort -V)
local newest_used
newest_used=$(printf '%s\n' "${used[@]}" | sort -V | tail -1)

echo "installed: ${installed[*]}" >&2
echo "used:      ${used[*]}" >&2
echo "newest used: $newest_used" >&2
echo "-- candidates (installed, unused, older than newest used) --" >&2

local v
for v in "${installed[@]}"; do
  [[ " ${used[*]} " == *" $v "* ]] && continue                      # keep: used somewhere
  [[ "$(printf '%s\n%s\n' "$v" "$newest_used" | sort -V | tail -1)" != "$newest_used" ]] && continue  # keep: newer than newest used
  echo "  CANDIDATE $v" >&2
  print -r -- "$v"
done
