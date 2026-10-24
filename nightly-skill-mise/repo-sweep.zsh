#!/bin/zsh
# repo-sweep.zsh — nightly per-repo maintenance sweep.
#
# For every git repo it finds, in isolation (one repo can never poison the run):
#   1. skip if already mid-rebase/merge (someone's WIP) — never touch it
#   2. delete local branches whose upstream is [gone] (merged PRs) — `-d` only,
#      never force; if the current branch is gone, check out the default first
#   3. run `gup` (sourced from dot-files): fetch --prune, pull --rebase --autostash,
#      fast-forward tracking branches, bundle install. Migrations run ONLY for
#      "full" repos (see classification) — "light" repos share a DB with a full clone.
#   4. abort any rebase `gup` leaves behind (conflict) — never leave a repo mid-rebase
#   5. bump Gemfile.lock BUNDLED_WITH to the latest bundler (full repos only)
#   6. minimal smoke test (bundle list / ruby -e exit, or git status for non-ruby)
#
# Classification:
#   ~/code/*                     -> FULL  (migrate + BUNDLED_WITH bump)
#   ~/code/core-payments/*       -> LIGHT (no migrate, no bump — shared/duplicate DBs)
#   ~/code/*-worktrees/*         -> LIGHT
#
# All prompts are fed EOF (stdin </dev/null) so nothing ever hangs.
# Nothing is staged or committed. Working-tree churn (lockfiles) is left for review.
#
# Env knobs:
#   CODE_DIR   (default ~/code)
#   LOGDIR     (default $PWD) — where the TSV + detail log land
#   ONLY=<substr>  restrict to repos whose path contains <substr>
#   DRY=1      classify + list only, do nothing
#   BUNDLER_LATEST  skip the `gem search` if you already know it

emulate -L zsh
set -u
setopt pipe_fail 2>/dev/null || true

CODE_DIR="${CODE_DIR:-$HOME/code}"
DOTFILES="$HOME/code/personal/dot-files"
INCLUDES="$DOTFILES/dot_zshrc/includes"
HERE="${0:A:h}"
LOGDIR="${LOGDIR:-$PWD}"
ONLY="${ONLY:-}"
DRY="${DRY:-0}"
TSV="$LOGDIR/repo-sweep.tsv"
DETAIL="$LOGDIR/repo-sweep.detail.log"
mkdir -p "$LOGDIR"

# --- source gup and its helpers (safe non-interactively) --------------------
source "$INCLUDES/auto_bundle_exec.zsh"   # run_bundler_cmd + aliases
source "$INCLUDES/z_gup.zsh"              # gup, grebase, bdl, mig

# Wrap mig so LIGHT repos skip the DB work without duplicating gup's body.
functions[__orig_mig]=$functions[mig]
mig() {
  if [[ "${SWEEP_SKIP_MIG:-0}" == 1 ]]; then
    echo "  skipping migrations (shared/duplicate DB)"
    return 0
  fi
  __orig_mig
}

BUNDLER_LATEST="${BUNDLER_LATEST:-$(gem search '^bundler$' --remote 2>/dev/null \
  | sed -n 's/^bundler (\([0-9][0-9.]*\)).*/\1/p' | head -1)}"

# BUNDLED_WITH is only bumped in repos you contribute to (your commits present) — obscure
# clones you keep for context don't need churn. CONTRIB_MATCH is a case-insensitive git
# --author regex; override for a different machine/user.
CONTRIB_MATCH="${CONTRIB_MATCH:-ferguson\\|jamesf}"
is_contributor() { [[ -n "$(git -C "$1" log --all -i --author="$CONTRIB_MATCH" --oneline -1 2>/dev/null)" ]] }

printf 'repo\tclass\tbranch\tpruned\tgup\tbundled_with\tsmoke\tnotes\n' > "$TSV"
: > "$DETAIL"

# gup's only prompt is "rebase diverged branches?" — feed it 'n' (decline; the safe
# headless choice) so gup continues to bundle/mig instead of aborting on EOF under set -e.
NFILE="$LOGDIR/.stdin-n"
printf 'n\n%.0s' {1..100} > "$NFILE"

log()  { print -r -- "$@" >> "$DETAIL"; }
line() { log "\n========== $1 =========="; }

# origin/HEAD target, else first existing of main/master/develop
default_branch() {
  local repo=$1 d
  d=$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
  if [[ -z "$d" ]]; then
    local c
    for c in main master develop; do
      git -C "$repo" show-ref --verify --quiet "refs/heads/$c" && { d=$c; break; }
    done
  fi
  print -r -- "$d"
}

mid_rebase() {
  local repo=$1 gd
  gd=$(git -C "$repo" rev-parse --git-dir 2>/dev/null) || return 1
  [[ -d "$repo/$gd/rebase-merge" || -d "$repo/$gd/rebase-apply" ]] && return 0
  # absolute git-dir (worktrees)
  [[ -d "$gd/rebase-merge" || -d "$gd/rebase-apply" ]]
}

# Delete [gone] branches with -d only. Echoes: "<n> pruned | notes..."
prune_gone() {
  local repo=$1
  local -a gone kept
  gone=("${(@f)$(git -C "$repo" for-each-ref \
        --format='%(refname:short) %(upstream:track)' refs/heads 2>/dev/null \
        | awk '/\[gone\]/{print $1}')}")
  gone=(${gone:#})   # drop empties
  local n=0 notes="" cur def b
  cur=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
  for b in "${gone[@]}"; do
    if [[ "$b" == "$cur" ]]; then
      def=$(default_branch "$repo")
      if [[ -z "$def" || "$def" == "$b" ]]; then
        notes+="on-gone-branch:$b(no default to switch to); "
        continue
      fi
      if ! git -C "$repo" checkout "$def" </dev/null >>"$DETAIL" 2>&1; then
        notes+="on-gone-branch:$b(checkout $def failed); "
        continue
      fi
      cur="$def"
    fi
    if git -C "$repo" branch -d "$b" </dev/null >>"$DETAIL" 2>&1; then
      ((n++))
    else
      notes+="unmerged:$b(kept); "
    fi
  done
  print -r -- "${n}|${notes}"
}

sweep_one() {
  local repo=$1 class=$2
  local name="${repo#$CODE_DIR/}"
  local branch pruned="0" gup_res="skip" bw="-" smoke="-" notes=""

  line "$name  [$class]"
  branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")

  if mid_rebase "$repo"; then
    printf '%s\t%s\t%s\t-\tSKIP\t-\t-\tpre-existing rebase/merge state — left untouched\n' "$name" "$class" "$branch" >> "$TSV"
    log "SKIP: already mid-rebase/merge"
    return
  fi

  if [[ "$DRY" == 1 ]]; then
    printf '%s\t%s\t%s\t(dry)\t(dry)\t(dry)\t(dry)\t\n' "$name" "$class" "$branch" >> "$TSV"
    return
  fi

  # Always fetch first: even when we can't update main (dirty/diverged), fresh remote
  # refs cost nothing, make [gone] detection accurate, and keep the repo ready to pull.
  git -C "$repo" fetch --all --prune </dev/null >>"$DETAIL" 2>&1

  # Uncommitted changes: gup's `pull --rebase --autostash` reapplies them over pulled
  # changes and CONFLICTS, leaving markers (sometimes while still returning 0). Instead
  # we stash the WIP ourselves, update on a clean tree, then TRY to put the WIP back —
  # and if that reapply conflicts, we back out cleanly (reset --hard) and leave the WIP
  # safely in the stash rather than leave conflict markers. SKIP_DIRTY=1 = don't touch
  # dirty repos at all (still fetched above).
  local stashed=0
  if [[ -n "$(git -C "$repo" status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
    if [[ "${SKIP_DIRTY:-0}" == 1 ]]; then
      printf '%s\t%s\t%s\t-\tSKIP\t-\t-\tuncommitted changes — skipped (fetched, not updated)\n' "$name" "$class" "$branch" >> "$TSV"
      log "SKIP: dirty (fetched only)"
      return
    fi
    if git -C "$repo" stash push -u -m "repo-sweep WIP $name" </dev/null >>"$DETAIL" 2>&1; then
      stashed=1
    else
      printf '%s\t%s\t%s\t-\tSKIP\t-\t-\tdirty; stash failed — skipped\n' "$name" "$class" "$branch" >> "$TSV"
      return
    fi
  fi

  # 1. prune gone branches (tree is clean now)
  local pr; pr=$(prune_gone "$repo")
  pruned="${pr%%|*}"; notes+="${pr#*|}"
  branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")

  # 2. gup (in the repo dir; mig gated by SWEEP_SKIP_MIG)
  [[ "$class" == LIGHT ]] && export SWEEP_SKIP_MIG=1 || export SWEEP_SKIP_MIG=0
  if ( cd "$repo" && gup <"$NFILE" ) >>"$DETAIL" 2>&1; then
    gup_res="ok"
  else
    gup_res="ERR"
    notes+="gup-nonzero; "
  fi

  # 3. never leave a repo mid-rebase
  if mid_rebase "$repo"; then
    git -C "$repo" rebase --abort </dev/null >>"$DETAIL" 2>&1
    gup_res="ERR"
    notes+="gup-left-rebase-ABORTED; "
  fi

  # 4. put the stashed WIP back — back out to a clean state if it can't reapply
  if [[ "$stashed" == 1 ]]; then
    if git -C "$repo" stash pop </dev/null >>"$DETAIL" 2>&1; then
      notes+="WIP-restored; "
    else
      git -C "$repo" reset --hard HEAD </dev/null >>"$DETAIL" 2>&1
      notes+="WIP-left-stashed(git stash pop to reapply); "
    fi
  fi

  # 5. defensive: never leave conflict markers behind
  if [[ -n "$(git -C "$repo" ls-files -u 2>/dev/null)" ]]; then
    git -C "$repo" reset --hard HEAD </dev/null >>"$DETAIL" 2>&1
    gup_res="CONFLICT"
    notes+="markers-cleared(work in stash); "
  fi

  # 5b. self-heal ruby pins: if a pull/revert left the repo pinning an uninstalled
  # ruby, bump it to an installed one (keeps .ruby-version in sync with .tool-versions).
  local fixres
  fixres=$("$HERE/fix-ruby-pins.zsh" "$repo" 2>>"$DETAIL")
  if [[ "$fixres" != *": 0 change"* ]]; then notes+="ruby-pins-fixed; "; fi

  # 6. BUNDLED_WITH bump — FULL repos you CONTRIBUTE to, clean bundler known
  if [[ "$class" == FULL && -n "$BUNDLER_LATEST" && -f "$repo/Gemfile.lock" ]] && is_contributor "$repo"; then
    local cur_bw
    cur_bw=$(awk '/^BUNDLED WITH$/{getline; gsub(/^[ \t]+/,""); print; exit}' "$repo/Gemfile.lock")
    if [[ -n "$cur_bw" && "$cur_bw" != "$BUNDLER_LATEST" ]]; then
      # replace the version on the line after "BUNDLED WITH"
      perl -0pi -e "s/(BUNDLED WITH\n\s+)[0-9][0-9.]*/\${1}$BUNDLER_LATEST/" "$repo/Gemfile.lock"
      bw="$cur_bw->$BUNDLER_LATEST"
    elif [[ "$cur_bw" == "$BUNDLER_LATEST" ]]; then
      bw="ok"
    fi
  fi

  # 7. minimal smoke test
  if [[ -f "$repo/Gemfile" ]]; then
    if ( cd "$repo" && bundle list </dev/null ) >>"$DETAIL" 2>&1; then
      smoke="bundle-ok"
    elif ( cd "$repo" && ruby -e 'exit 0' ) >>"$DETAIL" 2>&1; then
      smoke="ruby-ok/bundle-FAIL"; notes+="bundle-list-failed; "
    else
      smoke="FAIL"; notes+="smoke-failed; "
    fi
  else
    if git -C "$repo" status --porcelain >/dev/null 2>&1; then smoke="git-ok"; else smoke="FAIL"; fi
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$class" "$branch" "$pruned" "$gup_res" "$bw" "$smoke" "$notes" >> "$TSV"
  log "RESULT: gup=$gup_res pruned=$pruned bundled_with=$bw smoke=$smoke notes=$notes"
}

# --- build classified repo list --------------------------------------------
typeset -a full light
local d
for d in "$CODE_DIR"/*/; do
  d="${d%/}"
  [[ "$d" == "$DOTFILES" ]] && continue          # never sweep the active dotfiles repo
  [[ -d "$d/.git" ]] && full+=("$d")
done
for d in "$CODE_DIR"/core-payments/*/; do
  d="${d%/}"; [[ -d "$d/.git" ]] && light+=("$d")
done
for d in "$CODE_DIR"/*-worktrees/*/; do
  d="${d%/}"; [[ -e "$d/.git" ]] && light+=("$d")
done

echo "bundler latest: ${BUNDLER_LATEST:-<unknown>}"
echo "FULL repos:  ${#full}   LIGHT repos: ${#light}"
echo "log: $TSV  (detail: $DETAIL)"

local i=0 total=$(( ${#full} + ${#light} ))
for d in "${full[@]}"; do
  [[ -n "$ONLY" && "$d" != *"$ONLY"* ]] && continue
  ((i++)); echo "[$i/$total] FULL  ${d#$CODE_DIR/}"
  sweep_one "$d" FULL
done
for d in "${light[@]}"; do
  [[ -n "$ONLY" && "$d" != *"$ONLY"* ]] && continue
  ((i++)); echo "[$i/$total] LIGHT ${d#$CODE_DIR/}"
  sweep_one "$d" LIGHT
done

echo "\n===== SWEEP COMPLETE ====="
column -t -s $'\t' "$TSV"
