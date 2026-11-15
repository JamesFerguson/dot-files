#!/bin/zsh
# bump.zsh — upgrade named items of one kind, then rebuild whatever toolchain hangs off them.
# Waypoint's Updates tab runs it (and streams the output); it's as happy run by hand.
#
#   bump.zsh formula <name>...        brew upgrade, then restart any running brew service
#                                     whose version changed, then brew cleanup
#   bump.zsh cask <name>...           brew upgrade --cask. Only in a terminal you're watching:
#                                     consent and admin prompts can wedge the whole UI
#   bump.zsh mise <tool@version>...   mise install, pin in ~/.tool-versions, then that tool's
#                                     toolchain (below), and warn when the pin doesn't take
#   bump.zsh rubygems <ruby>...       gem update --system for those mise rubies
#   bump.zsh toolchain <tool@version> just the toolchain rebuild, for a re-run
#
# Toolchains:
#   elixir  Hex and rebar for the new version (with MIX_HOME/MIX_ARCHIVES unset, so a shell
#           still pointing at the old version's doesn't swallow them)
#   ruby    rubygems, bundler and ruby-lsp (when the old ruby had it) on the new ruby, a
#           reshim, bundle install in every repo that now resolves it, the MCP smoke test and
#           the fallback-prefix drift check. mise installs ~/.default-gems itself.
#   node    the old version's global npm packages, reinstalled on the new one
#
# Exits non-zero if any step failed; carries on past a failure so one bad item doesn't
# strand the rest.

emulate -L zsh
set -u
HERE="${0:A:h}"
export PATH="$HOME/bin:$HOME/.local/share/mise/shims:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin"
# Under $HOME, so mise reads ~/.tool-versions rather than wherever this was started from.
cd "$HOME" || exit 1

failed=0
step() { print; print -r -- "==> $*" }
fail() { print -r -- "  FAILED: $*"; failed=1 }

# Prints "name version" for each started brew service.
service_versions() {
  local name
  brew services list --json 2>/dev/null \
    | python3 -c 'import sys,json; [print(s["name"]) for s in json.load(sys.stdin) if s["status"] == "started"]' \
    | while read -r name; do print -r -- "$name $(brew list --versions "$name" 2>/dev/null | awk '{print $NF}')"; done
}

bump_formula() {
  local -a before after
  before=("${(@f)$(service_versions)}")
  step "brew upgrade $*"
  brew upgrade --formula "$@" || fail "brew upgrade $*"
  after=("${(@f)$(service_versions)}")
  local line
  for line in "${after[@]}"; do
    [[ -n "$line" && ${before[(Ie)$line]} -eq 0 ]] || continue
    step "brew services restart ${line%% *} (now ${line#* })"
    brew services restart "${line%% *}" || fail "restart ${line%% *}"
  done
  step "brew cleanup"
  brew cleanup || fail "brew cleanup"
}

bump_cask() {
  if [[ ! -t 0 ]]; then
    print -r -- "Casks only upgrade in a terminal you're watching: consent and admin prompts can wedge the UI."
    exit 2
  fi
  step "brew upgrade --cask $*"
  brew upgrade --cask "$@" || fail "brew upgrade --cask $*"
}

# The version mise resolves for a tool from $HOME.
current() { mise current "$1" 2>/dev/null | awk '{print $1}' }

# Where the winning pin for a tool lives, from `mise ls --current`.
pin_source() { mise ls "$1" --current 2>/dev/null | awk 'NR == 1 {print $3}' }

bump_mise() {
  local spec tool ver old
  for spec in "$@"; do
    tool=${spec%%@*} ver=${spec#*@}
    old=$(current "$tool")
    step "mise install $tool@$ver (was ${old:-none})"
    if ! mise install "$tool@$ver"; then fail "mise install $tool@$ver"; continue; fi
    mise use --path "$HOME/.tool-versions" "$tool@$ver" || { fail "pin $tool@$ver"; continue; }
    if [[ "$(current "$tool")" != "$ver" ]]; then
      print -r -- "  PIN DRIFT: pinned $tool $ver in ~/.tool-versions, but $(pin_source "$tool") still wins with $(current "$tool")"
      failed=1
    fi
    toolchain "$tool" "$ver" "$old"
  done
  step "mise reshim"
  mise reshim || fail "mise reshim"
}

toolchain() {
  local tool=$1 ver=$2 old=${3:-}
  case $tool in
    elixir) elixir_toolchain "$ver" ;;
    ruby) ruby_toolchain "$ver" "$old" ;;
    node | nodejs) node_toolchain "$ver" "$old" ;;
    *) print -r -- "  no toolchain to rebuild for $tool" ;;
  esac
}

elixir_toolchain() {
  step "Hex and rebar for elixir $1"
  env -u MIX_HOME -u MIX_ARCHIVES mise exec "elixir@$1" -- mix local.hex --force || fail "mix local.hex"
  env -u MIX_HOME -u MIX_ARCHIVES mise exec "elixir@$1" -- mix local.rebar --force || fail "mix local.rebar"
}

ruby_toolchain() {
  local ver=$1 old=$2 dir resolved
  local -a on=(mise exec "ruby@$ver" --)
  step "rubygems and bundler on ruby $ver"
  "${on[@]}" gem update --system || fail "gem update --system"
  "${on[@]}" gem install bundler || fail "gem install bundler"
  if [[ -n "$old" ]] && mise exec "ruby@$old" -- gem list -i ruby-lsp >/dev/null 2>&1; then
    step "ruby-lsp, which ruby $old had"
    "${on[@]}" gem install ruby-lsp || fail "gem install ruby-lsp"
  fi
  mise reshim || fail "mise reshim"

  step "bundle install in repos that now resolve ruby $ver"
  export MISE_AUTO_INSTALL=false MISE_NOT_FOUND_AUTO_INSTALL=false
  "$HERE/repo-dirs.zsh" | while read -r dir; do
    [[ -f "$dir/Gemfile" ]] || continue
    resolved=$(cd "$dir" && mise current ruby 2>/dev/null)
    [[ "$resolved" == "$ver" ]] || continue
    if (cd "$dir" && bundle check >/dev/null 2>&1); then
      print -r -- "  $dir: already bundled"
    elif (cd "$dir" && bundle install --quiet); then
      print -r -- "  $dir: bundled"
    else
      fail "bundle install in $dir"
    fi
  done

  step "MCP servers that run from a repo"
  "$HERE/mcp-smoke.zsh" || fail "mcp-smoke"

  local home_ruby fallback_ruby
  home_ruby=$(awk '$1 == "ruby" {print $2}' "$HOME/.tool-versions")
  fallback_ruby=$(sed -nE 's/^ruby *= *"([^"]+)".*/\1/p' "$HOME/.config/mise/config.toml")
  if [[ -n "$home_ruby" && -n "$fallback_ruby" && "$home_ruby" != "$fallback_ruby"* ]]; then
    print -r -- "  RUBY FALLBACK DRIFT: ~/.config/mise/config.toml has ruby = \"$fallback_ruby\" but ~/.tool-versions pins $home_ruby; bump the prefix to \"${home_ruby%.*}\""
  fi
}

node_toolchain() {
  local ver=$1 old=$2
  [[ -n "$old" ]] || return 0
  local -a globals
  globals=("${(@f)$(mise exec "node@$old" -- npm ls -g --depth=0 --json 2>/dev/null \
    | python3 -c 'import sys,json; [print(n) for n in json.load(sys.stdin).get("dependencies", {}) if n not in ("npm", "corepack")]')}")
  globals=(${globals:#})
  if [[ ${#globals} -eq 0 ]]; then
    print -r -- "  node $old had no global npm packages to carry over"
    return 0
  fi
  step "global npm packages from node $old: ${globals[*]}"
  mise exec "node@$ver" -- npm install -g "${globals[@]}" || fail "npm install -g"
}

bump_rubygems() {
  local ver gem_bin
  for ver in "$@"; do
    gem_bin="$(mise where "ruby@$ver" 2>/dev/null)/bin/gem"
    [[ -x "$gem_bin" ]] || { fail "ruby $ver has no gem bin"; continue; }
    step "ruby $ver: rubygems $("$gem_bin" --version) -> latest"
    "$gem_bin" update --system || fail "gem update --system on ruby $ver"
  done
}

kind=${1:-}
(( $# )) && shift
if [[ -z "$kind" || $# -eq 0 ]]; then
  print -r -- "usage: bump.zsh formula|cask|mise|rubygems|toolchain <item>..." >&2
  exit 64
fi

case $kind in
  formula) bump_formula "$@" ;;
  cask) bump_cask "$@" ;;
  mise) bump_mise "$@" ;;
  rubygems) bump_rubygems "$@" ;;
  toolchain) toolchain "${1%%@*}" "${1#*@}" ;;
  *) print -r -- "bump.zsh: unknown kind $kind" >&2; exit 64 ;;
esac

if (( failed )); then
  print; print -r -- "==> Finished with failures (see FAILED above)"
  exit 1
fi
print; print -r -- "==> Done"
