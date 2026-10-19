#!/bin/zsh

if [[ $[RANDOM % 16] -eq 0 ]]; then
  echo "\n\n---------------\n  Updating Homebrew\n-----------------\n\n"
  brew update | grep "Updated Homebrew"

  # Find ruby versions actually used across all repos under $CODE_DIR.
  # Note: avoid `local` inside the loop — it emits trace output for each iteration
  # when this file is sourced at top level (not inside a function).
  echo "\n\n  Scanning $CODE_DIR for ruby versions in use..."
  local -a used_versions=()
  typeset -A version_repos=()
  local _scan_file _scan_v
  while IFS= read -r _scan_file; do
    if [[ "$_scan_file" == *".ruby-version" ]]; then
      _scan_v=$(cat "$_scan_file" | tr -d '[:space:]')
    else
      # .tool-versions — extract the ruby line
      _scan_v=$(grep '^ruby ' "$_scan_file" | awk '{print $2}')
    fi
    _scan_v="${_scan_v#ruby-}"  # strip leading "ruby-" prefix if present
    if [[ -n "$_scan_v" ]]; then
      used_versions+=("$_scan_v")
      version_repos[$_scan_v]+="${_scan_file:h}"$'\n'
    fi
  done < <(find "$CODE_DIR" -maxdepth 4 \( -name ".ruby-version" -o -name ".tool-versions" \) 2>/dev/null)
  used_versions=(${(u)used_versions})  # unique
  used_versions=("${(@f)$(printf '%s\n' "${used_versions[@]}" | sort -V)}")  # sort
  echo "  Ruby versions in use:"
  printf '    %s\n' "${used_versions[@]}"

  # Get all installed ruby versions and find the newest used version.
  local -a installed_versions=()
  eval "installed_versions=( $(mise ls ruby --installed 2>/dev/null | awk '{print $2}') )"

  # used_versions is already sort -V'd: first is oldest, last is newest.
  local oldest_used="${used_versions[1]}"
  local newest_used="${used_versions[-1]}"

  # Show repos pinned to the oldest ruby in use — these are upgrade candidates.
  if [[ -n "$oldest_used" ]]; then
    echo "  Oldest ruby in use: $oldest_used — repos pinned to it:"
    printf '%s' "${version_repos[$oldest_used]}" | sort -u | sed "s|^$CODE_DIR/|    |"
  fi

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
        mise uninstall ruby@"$v"
      done
    fi
  fi

  # Check latest rubygems version once, then only update rubies that are behind.
  # Note: brew_refresh.zsh sources before z_mise.zsh, so mise shims aren't on PATH
  # yet — invoke each ruby's gem binary by absolute path to avoid hitting /usr/bin/gem.
  local current_ruby
  current_ruby=$(mise current ruby 2>/dev/null)
  echo "\n\n  Updating rubygems (current ruby ---> $current_ruby)"
  local latest_rubygems
  latest_rubygems=$(curl -sf https://rubygems.org/api/v1/gems/rubygems-update.json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")
  echo "  Latest rubygems: $latest_rubygems"

  eval "ruby_versions=( $(mise ls ruby --installed 2>/dev/null | awk '{print $2}') )"
  for version in "${ruby_versions[@]}"; do
    echo "\n\n-----------------\n  Updating gems for ruby $version\n-----------------\n\n"
    local gem_bin
    gem_bin="$(mise where ruby@"$version" 2>/dev/null)/bin/gem"
    if [[ ! -x "$gem_bin" ]]; then
      echo "  ruby $version - gem binary not found at $gem_bin, skipping"
      continue
    fi
    local current_rubygems
    current_rubygems=$("$gem_bin" --version 2>/dev/null)
    if [[ "$current_rubygems" == "$latest_rubygems" ]]; then
      echo "  ruby $version - rubygems $current_rubygems already up to date, skipping"
    else
      echo "  ruby $version - rubygems $current_rubygems -> $latest_rubygems, updating..."
      "$gem_bin" update --system
    fi
  done

  echo "\n\n---------------\n  Updating mise plugin lists\n-----------------\n\n"
  # Only asdf-backed / plugin tools have anything to update; mise core tools (ruby,
  # node, python, go, ...) resolve from the built-in registry and need no plugin update.
  # Guard so this is a no-op (and no error) when no plugins are installed.
  if [[ -n "$(mise plugins ls 2>/dev/null)" ]]; then
    mise plugins update
  else
    echo "  No mise plugins installed — core tools need no plugin update."
  fi

  echo "  Checking mise installed versions against latest"
  # `mise outdated --bump --json` keys tools by canonical name, each with a `bump`
  # field: a version string when a newer version is available, else null. Reduce to
  # <tool>\t<bump_version> lines for the tools that actually have an upgrade.
  local mise_outdated mise_upgrades
  mise_outdated=$(mise outdated --bump --json 2>/dev/null)
  mise_upgrades=$(echo "$mise_outdated" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for tool, info in data.items():
    bump = info.get('bump')
    if bump:
        print(f'{tool}\t{bump}')
")
  echo "$mise_upgrades"

  if [[ -n "$mise_upgrades" ]]; then
    echo -n "\n  mise tools have newer versions available. Install latest and update .tool-versions? [y/N] "
    read -r mise_answer
    if [[ "$mise_answer" == "y" || "$mise_answer" == "Y" ]]; then
      while IFS=$'\t' read -r tool latest; do
        [[ -n "$tool" && -n "$latest" ]] || continue
        echo "  Installing $tool $latest"
        # --path writes to ~/.tool-versions (which overrides ~/.config/mise/config.toml
        # in precedence, so `mise use -g` would be silently ignored here).
        if mise install "$tool@$latest"; then
          mise use --path ~/.tool-versions "$tool@$latest"
          echo "  $tool updated to $latest"
        else
          echo "  $tool $latest install failed, skipping"
        fi
      done <<< "$mise_upgrades"
    fi
  fi

  local _brew_cooldown=12
  echo "\n\n---------------\n  Checking for outdated Homebrew packages (${_brew_cooldown}d cooldown)\n-----------------\n\n"
  local _brew_cache="${XDG_CACHE_HOME:-$HOME/.cache}/brew_version_first_seen"
  local _brew_now _brew_name _brew_version _brew_status _brew_val _brew_answer
  local -a _brew_safe_items=()
  _brew_now=$(date +%s)
  mkdir -p "${_brew_cache:h}"

  # Python: seeds each new (name, version) with its real commit date, then ages the
  # pending upgrade by date — never by ranking version strings. brew's outdated list is
  # the sole authority on whether an upgrade exists; the cooldown only measures how long
  # the oldest release newer than the one we installed has been available. The clock is
  # anchored on the install time (receipt / keg mtime), which sidesteps two traps a
  # version comparison hits: revision suffixes like 1.12_1 that an int-parse mis-ranks,
  # and version-scheme rollbacks like openssl@3 3.6.5 → 3.5.9. Anchoring on the OLDEST
  # pending release (never the latest) keeps a fast cadence like awscli from resetting
  # the clock into eternal cooldown.
  # 3rd-party taps: local git (fast, no network). homebrew/core+cask: sequential GitHub API.
  # Output: name <TAB> current_latest <TAB> READY|COOLING <TAB> age_days|days_left
  while IFS=$'\t' read -r _brew_name _brew_version _brew_status _brew_val; do
    [[ -n "$_brew_name" && -n "$_brew_version" ]] || continue
    if [[ "$_brew_status" == READY ]]; then
      printf '  READY    %-40s %s (%dd old)\n' "$_brew_name" "$_brew_version" "$_brew_val"
      _brew_safe_items+=("$_brew_name")
    else
      printf '  COOLING  %-40s %s (%dd until ready)\n' "$_brew_name" "$_brew_version" "$_brew_val"
    fi
  done < <(brew outdated --json 2>/dev/null | python3 -c "
import sys, json, os, subprocess, urllib.request
from datetime import datetime, timezone

_taps_dir = ''
_prefix = ''
for cand in ['/opt/homebrew', '/usr/local', os.path.expanduser('~/.linuxbrew')]:
    if os.path.isdir(cand + '/Library/Taps'):
        _prefix = cand
        _taps_dir = cand + '/Library/Taps'
        break

xdg = os.environ.get('XDG_CACHE_HOME', '')
cache_path = (xdg if xdg else os.path.expanduser('~/.cache')) + '/brew_version_first_seen'
COOLDOWN = 12

cache = {}  # (name, version) -> commit_timestamp
try:
    with open(cache_path) as f:
        for line in f:
            parts = line.rstrip('\n').split('\t')
            if len(parts) == 3:
                try: cache[(parts[0], parts[1])] = int(parts[2])
                except: pass
except: pass

data = json.load(sys.stdin)
all_items = []
for kind, items in [('formula', data.get('formulae', [])), ('cask', data.get('casks', []))]:
    for item in items:
        name = item.get('name', '')
        latest = item.get('current_version', '')
        inst_list = item.get('installed_versions', [])
        installed = inst_list[0] if inst_list else ''
        if name and latest:
            all_items.append((name, latest, kind, installed))

def git_ts(repo, path):
    try:
        r = subprocess.run(['git', '-C', repo, 'log', '--follow', '--format=%ct', '-1', '--', path],
                           capture_output=True, text=True, timeout=5)
        ts = r.stdout.strip()
        return int(ts) if ts else None
    except: return None

def gh_token():
    # Unauthenticated GitHub is 60 req/hr; a full outdated list exhausts it and the
    # release dates fall back to now (first-seen), which strands the cooldown clock.
    # gh is already logged in, so borrow its token when no env token is set.
    t = os.environ.get('HOMEBREW_GITHUB_API_TOKEN') or os.environ.get('GITHUB_TOKEN', '')
    if t:
        return t
    try:
        r = subprocess.run(['gh', 'auth', 'token'], capture_output=True, text=True, timeout=5)
        return r.stdout.strip()
    except: return ''

GH_TOKEN = gh_token()

def github_ts(path, repo):
    url = f'https://api.github.com/repos/{repo}/commits?path={path}&per_page=1'
    req = urllib.request.Request(url, headers={'User-Agent': 'brew-cooldown/1.0'})
    if GH_TOKEN:
        req.add_header('Authorization', f'token {GH_TOKEN}')
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            commits = json.load(r)
            if isinstance(commits, list) and commits:
                ds = commits[0]['commit']['committer']['date']
                dt = datetime.fromisoformat(ds.replace('Z', '+00:00'))
                return int(dt.timestamp())
    except: pass
    return None

def get_ts(name, kind):
    if '/' in name:
        parts = name.split('/')
        if len(parts) == 3 and _taps_dir:
            org, tap_short, formula_name = parts
            tap_dir = os.path.join(_taps_dir, org, f'homebrew-{tap_short}')
            for fpath in [f'Formula/{formula_name}.rb',
                          f'Formula/{formula_name[0]}/{formula_name}.rb']:
                ts = git_ts(tap_dir, fpath)
                if ts: return ts
        return None
    if kind == 'formula':
        # homebrew-core shards lib* formulae under lib/, everything else by first letter
        shard = 'lib' if name.startswith('lib') else name[0]
        return github_ts(f'Formula/{shard}/{name}.rb', 'Homebrew/homebrew-core')
    if kind == 'cask':
        return github_ts(f'Casks/{name[0]}/{name}.rb', 'Homebrew/homebrew-cask')
    return None

def install_time(name, installed, kind):
    # When the version we currently run landed locally -- the cooldown clock starts here.
    # Formulae use the per-keg install receipt (never stale). Casks use the per-version
    # stamp dir Caskroom/<name>/.metadata/<version>/<YYYYMMDDHHMMSS>/ -- the cask-level
    # INSTALL_RECEIPT.json is not per-version and goes stale (it can still name an older
    # version), and the version dir's mtime gets bumped by later brew touches.
    if not installed or not _prefix:
        return None
    short = name.split('/')[-1]
    if kind == 'cask':
        meta = _prefix + '/Caskroom/' + short + '/.metadata/' + installed
        try:
            stamps = [d for d in os.listdir(meta) if d[:8].isdigit()]
            if stamps:
                # the stamp dir name is UTC; parse as UTC (naive .timestamp() reads local -> ~10h early)
                return int(datetime.strptime(max(stamps)[:14], '%Y%m%d%H%M%S').replace(tzinfo=timezone.utc).timestamp())
        except: pass
        base = _prefix + '/Caskroom/' + short + '/' + installed
    else:
        base = _prefix + '/Cellar/' + short + '/' + installed
        try:
            with open(base + '/INSTALL_RECEIPT.json') as f:
                t = json.load(f).get('time')
                if t:
                    return int(t)
        except: pass
    try:
        return int(os.path.getmtime(base))
    except: pass
    return None

now = int(datetime.now(timezone.utc).timestamp())

# Seed cache for any (name, latest_version) we haven't seen yet
new_entries = [(n, v, k) for n, v, k, _ in all_items if (n, v) not in cache]
if new_entries:
    with open(cache_path, 'a') as f:
        for name, version, kind in new_entries:
            ts = get_ts(name, kind)
            seed_ts = ts if ts else now
            cache[(name, version)] = seed_ts
            f.write(f'{name}\t{version}\t{seed_ts}\n')

for name, latest, kind, installed in all_items:
    t_install = install_time(name, installed, kind)

    # Pending upgrades = cached releases that landed after the version we run. brew
    # already flagged this item outdated, so we never rank version strings; we only
    # age the pending change. The oldest pending release anchors the clock -- newer
    # releases raise the max, never the min, so a fast cadence can't reset it.
    pending = []
    if t_install is not None:
        pending = [ts for (n, v), ts in cache.items()
                   if n == name and not v.startswith('pending:') and ts > t_install]

    if pending:
        anchor = min(pending)
    else:
        # No dated evidence (install time unknown, or installed after the newer
        # release's commit). Start the clock when we first saw this install fall
        # behind; the marker is keyed on the installed version, so it never resets
        # as new releases land and it clears COOLDOWN days later.
        marker = (name, 'pending:' + installed)
        anchor = cache.get(marker)
        if anchor is None:
            anchor = now
            with open(cache_path, 'a') as f:
                f.write(f'{name}\tpending:{installed}\t{now}\n')
            cache[marker] = now

    age = (now - anchor) // 86400
    if age >= COOLDOWN:
        print(f'{name}\t{latest}\tREADY\t{age}')
    else:
        print(f'{name}\t{latest}\tCOOLING\t{max(1, COOLDOWN - age)}')
" 2>/dev/null)

  if [[ ${#_brew_safe_items[@]} -gt 0 ]]; then
    echo "\n  ${#_brew_safe_items[@]} package(s) passed the ${_brew_cooldown}-day cooldown."
    echo -n "  Run brew upgrade for these? [y/N] "
    read -r _brew_answer
    if [[ "$_brew_answer" == "y" || "$_brew_answer" == "Y" ]]; then
      brew upgrade "${_brew_safe_items[@]}" && brew cleanup
    fi
  else
    echo "  No packages ready to upgrade (all either up to date or in ${_brew_cooldown}-day cooldown)."
  fi
fi
