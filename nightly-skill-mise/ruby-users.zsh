#!/bin/zsh
# ruby-users.zsh — which mise ruby each repo runs. Prints `version<TAB>dir<TAB>app|gem` for
# every repo, worktree and MCP server directory (repo-dirs.zsh) that pins its own ruby (`gem`
# when it has a gemspec), and `version<TAB>~<TAB>default` for the default ruby, which
# everything without a pin runs on.
#
# A directory counts only when the ruby mise resolves there comes from a file inside it, so a
# Go or PHP repo that falls back to the default ruby doesn't show up as depending on it.
# Read-only: probes never install a missing version.

emulate -L zsh
set -u
HERE="${0:A:h}"
export MISE_AUTO_INSTALL=false MISE_NOT_FOUND_AUTO_INSTALL=false

# `mise ls --current ruby` prints "ruby  <version>  <source>  <requested>", with the source
# under ~ written as "~/…".
probe='cd "$1" 2>/dev/null || exit 0
version=$(mise ls --current ruby 2>/dev/null | awk -v dir="$1" -v home="$HOME" '\''
  $1 == "ruby" { src = $3; sub(/^~/, home, src); if (index(src, dir "/") == 1) print $2 }'\'')
[[ -n $version ]] || exit 0
kind=app
[[ -n $(print -l *.gemspec(N)) ]] && kind=gem
print -- "$version\t$1\t$kind"'

"$HERE/repo-dirs.zsh" | xargs -P 8 -I{} zsh -fc "$probe" _ {} | sort

(cd "$HOME" && mise current ruby 2>/dev/null) | awk '{ print $1 "\t~\tdefault" }'
