#!/bin/zsh
# fix-ruby-pins.zsh — normalise each repo's ruby pins so they (a) point at an
# INSTALLED ruby and (b) are internally consistent.
#
# mise ignores .ruby-version here (idiomatic version files are off), so a repo with only
# a .ruby-version silently runs on the home ruby. To make repos actually run on their
# declared ruby, every ruby repo gets a .tool-versions. A repo's mise.toml / .mise.toml
# outranks its .tool-versions, though, so the ruby a repo runs is whatever
# `mise current ruby` says there. Per repo root:
#   - if .tool-versions has a ruby line: it's authoritative. Bump it to the newest
#     installed ruby in its major.minor if the pin is uninstalled (fallback
#     $FALLBACK_RUBY). Then sync .ruby-version to match.
#   - else if .ruby-version exists: CREATE .tool-versions with `ruby <that version>`
#     (bumped to installed if needed), so the repo actually uses its declared ruby.
#   - a `ruby "..."` Gemfile directive, or a mise.toml / .mise.toml ruby entry, on an
#     uninstalled version is bumped too.
#   - pins that still disagree afterwards print a RUBY PIN CONFLICT line naming each pin
#     and the ruby mise actually runs. Those are left alone: which pin is right is a call
#     for whoever owns the repo.
# Nested .ruby-version files (test fixtures etc.) just get their uninstalled pin
# bumped in place — no .tool-versions is created for non-root dirs.
#
# Idempotent — a repo already consistent + installed is untouched, so it's safe to
# re-run and safe to call every sweep. CROSS-MINOR jumps are flagged.
#
# Usage: fix-ruby-pins.zsh [--dry] [repo ...]   (no repos = whole ~/code tree)

emulate -L zsh
set -u
CODE_DIR="${CODE_DIR:-$HOME/code}"
FALLBACK_RUBY="${FALLBACK_RUBY:-3.4.9}"
DRY=0; [[ "${1:-}" == "--dry" ]] && { DRY=1; shift }

installed=("${(@f)$(mise ls ruby --installed 2>/dev/null | awk '{print $2}' | grep -E '^[0-9]')}")
is_installed() { local v; for v in "${installed[@]}"; do [[ "$v" == "$1" ]] && return 0; done; return 1 }
target_for() { local mm; mm=$(printf '%s\n' "$1" | awk -F. '{print $1"."$2}')
  printf '%s\n' "${installed[@]}" | grep -E "^${mm//./\\.}\." | sort -V | tail -1 }
rv_val() { sed 's/^ruby-//;s/[[:space:]]//g' "$1" 2>/dev/null }
tv_val() { grep '^ruby ' "$1" 2>/dev/null | awk '{print $2}' }
toml_val() { grep -E '^[[:space:]]*ruby[[:space:]]*=' "$1" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 }
mise_ruby() { ( cd "$1" && MISE_AUTO_INSTALL=false MISE_NOT_FOUND_AUTO_INSTALL=false mise current ruby 2>/dev/null ) }

changed=0
# echoes "installed-target|flag" for a pin (bumps to newest-in-minor, else fallback)
resolve() { local t; t=$(target_for "$1")
  [[ -n "$t" ]] && { print -r -- "$t|"; return; }
  print -r -- "$FALLBACK_RUBY|  ⚠ CROSS-MINOR ($1 has no installed patch)" }
write_rv() { [[ "$DRY" == 1 ]] || print -r -- "$1" > "$2" }
write_tv_line() {   # $1=version $2=.tool-versions path — set/append the ruby line
  [[ "$DRY" == 1 ]] && return
  if [[ -f "$2" ]] && grep -q '^ruby ' "$2"; then
    perl -i -pe "s/^(ruby\s+)\S+/\${1}$1/ if /^ruby\s/" "$2"
  else
    print -r -- "ruby $1" >> "$2"
  fi
}

repos=("$@")
[[ ${#repos} -eq 0 ]] && repos=("${(@f)$(for b in "$CODE_DIR" "$CODE_DIR"/core-payments; do
    for d in "$b"/*/; do [[ -d "$d/.git" ]] && print -r -- "${d%/}"; done; done)}")

for repo in "${repos[@]}"; do
  [[ -d "$repo" ]] || continue
  name="${repo#$CODE_DIR/}"
  rvf="$repo/.ruby-version"; tvf="$repo/.tool-versions"
  tv=$(tv_val "$tvf"); rv=$(rv_val "$rvf")

  if [[ -n "$tv" ]]; then
    # .tool-versions authoritative
    auth="$tv"
    if ! is_installed "$tv"; then
      r=$(resolve "$tv"); auth="${r%%|*}"
      echo "  bump $name/.tool-versions : ruby $tv -> $auth${r#*|}"; write_tv_line "$auth" "$tvf"; changed=$((changed+1))
    fi
    if [[ -f "$rvf" && "$rv" != "$auth" ]]; then
      echo "  sync $name/.ruby-version : $rv -> $auth (match .tool-versions)"; write_rv "$auth" "$rvf"; changed=$((changed+1))
    fi
  elif [[ -n "$rv" ]]; then
    # no .tool-versions ruby line — create one from .ruby-version (the point of this pass)
    val="$rv"
    if ! is_installed "$rv"; then r=$(resolve "$rv"); val="${r%%|*}"
      echo "  bump $name/.ruby-version : $rv -> $val${r#*|}"; write_rv "$val" "$rvf"; changed=$((changed+1)); fi
    echo "  create $name/.tool-versions : ruby $val (from .ruby-version)"; write_tv_line "$val" "$tvf"; changed=$((changed+1))
  fi

  # nested .ruby-version files (not repo root): bump uninstalled pins in place only
  while IFS= read -r f; do
    [[ -n "$f" && "$f" != "$rvf" ]] || continue
    v=$(rv_val "$f"); [[ -n "$v" ]] || continue
    is_installed "$v" && continue
    r=$(resolve "$v"); tgt="${r%%|*}"
    echo "  bump ${f#$CODE_DIR/} : $v -> $tgt${r#*|}"; write_rv "$tgt" "$f"; changed=$((changed+1))
  done < <(find "$repo" -mindepth 2 -name .ruby-version -not -path '*/node_modules/*' -not -path '*/vendor/bundle/*' 2>/dev/null)

  # Gemfile `ruby "x"` directive on an uninstalled version (portable extraction)
  gf="$repo/Gemfile"
  if [[ -f "$gf" ]]; then
    gpin=$(grep -E "^[[:space:]]*ruby[[:space:]]+['\"][0-9]" "$gf" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    if [[ -n "$gpin" ]] && ! is_installed "$gpin"; then
      r=$(resolve "$gpin"); tgt="${r%%|*}"
      echo "  bump $name/Gemfile ruby directive : $gpin -> $tgt"
      [[ "$DRY" == 1 ]] || perl -i -pe "s/(ruby\s+['\"])[0-9.]+(['\"])/\${1}$tgt\${2}/ if /^\s*ruby\s+['\"][0-9]/" "$gf"
      changed=$((changed+1))
    fi
  fi

  # mise.toml / .mise.toml ruby entry on an uninstalled version
  local -a toml_pins=()
  for mt in "$repo/mise.toml" "$repo/.mise.toml"; do
    mv=$(toml_val "$mt"); [[ -n "$mv" ]] || continue
    if [[ "$mv" == <->.<->.<-> ]] && ! is_installed "$mv"; then   # a prefix pin ("4.0") is deliberate
      r=$(resolve "$mv"); tgt="${r%%|*}"
      echo "  bump $name/${mt:t} : ruby $mv -> $tgt${r#*|}"
      [[ "$DRY" == 1 ]] || perl -i -pe "s/^(\s*ruby\s*=\s*\[?\s*[\"'])[0-9.]+/\${1}$tgt/" "$mt"
      changed=$((changed+1)); mv="$tgt"
    fi
    toml_pins+=("${mt:t} $mv")
  done

  # pins that still disagree: report, don't pick a winner
  local -a pins=("${toml_pins[@]}")
  tv=$(tv_val "$tvf"); rv=$(rv_val "$rvf")
  [[ -n "$tv" ]] && pins+=(".tool-versions $tv")
  [[ -n "$rv" ]] && pins+=(".ruby-version $rv")
  if (( ${#pins} > 1 )) && (( $(printf '%s\n' "${pins[@]}" | awk '{print $2}' | sort -u | wc -l) > 1 )); then
    echo "  RUBY PIN CONFLICT $name: ${(j:, :)pins} (mise runs $(mise_ruby "$repo" || echo '?'))"
  fi
done
echo "fix-ruby-pins: $changed change(s) (DRY=$DRY, fallback=$FALLBACK_RUBY)"
