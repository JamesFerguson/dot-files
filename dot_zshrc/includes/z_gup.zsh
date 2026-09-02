# gup description:
#   - Pull changes from remote.
#   - Update all local tracking branches.
#   - Run post-pull steps for Ruby projects.

# Remove any existing alias for gup, e.g. added by prezto or oh-my-zsh git plugins.
[ "$(type gup | awk '{print $4}')" = "alias" ] && unalias gup

function gup
{
  # Output the ruby version for trace.
  mise current ruby

  # subshell for `set -e`
  (
    set -e

    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)

    # Fetch all remotes (pruning stale remote tracking refs) so we know what needs updating.
    echo "Fetching all remotes"
    git fetch --all --prune

    # Rebase current branch, with autostash.
    echo "Updating current branch ($current_branch)"
    git pull --rebase --autostash

    # Collect any diverged branches for user action after doing fast-forwards.
    local -a diverged_branches=()

    # Grab the local branches and their tracking info to loop over.
    local branch_info
    branch_info=$(git branch --format='%(refname:short) %(upstream:short) %(upstream:track)')

    # Loop over all local branches and try to update.
    local c_reset='\033[0m'
    local c_green='\033[32m'
    local c_yellow='\033[33m'
    local c_red='\033[31m'
    local c_cyan='\033[36m'
    local c_dim='\033[2m'

    echo "Trying to fast-forward other local tracking branches..."
    while read -r local upstream track; do
      [[ "$local" == "$current_branch" ]] && continue
      [[ -z "$upstream" ]] && continue
      # Fast-forward other local tracking branches that are purely behind upstream.
      if [[ "$track" == *"behind"* && "$track" != *"ahead"* ]]; then
        if git fetch . "$upstream:$local" 2>/dev/null; then
          echo "  ${c_green}↓ $local${c_reset} - fast-forwarded"
        else
          echo "  ${c_red}✗ $local${c_reset} - could not fast-forward, skipping"
        fi
      elif [[ "$track" == *"ahead"* && "$track" == *"behind"* ]]; then
        echo "  ${c_yellow}⇅ $local${c_reset} - diverged"
        diverged_branches+=("$local")
      elif [[ "$track" == *"ahead"* ]]; then
        echo "  ${c_cyan}↑ $local${c_reset} - ahead of upstream, skipping"
      else
        echo "  ${c_dim}✓ $local - up to date${c_reset}"
      fi
    done <<< "$branch_info"

    # If any branches diverged, ask whether to rebase them.
    if [[ ${#diverged_branches[@]} -gt 0 ]]; then
      echo ""
      echo "The following branches have diverged from their upstream:"
      for b in "${diverged_branches[@]}"; do
        echo "  $b"
      done
      echo ""
      echo -n "Rebase these branches? [y/n] "
      read -r answer
      if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        local -a skipped_branches=()

        for b in "${diverged_branches[@]}"; do
          git checkout "$b"
          grebase || skipped_branches+=("$b")
        done

        git checkout "$current_branch"

        if [[ ${#skipped_branches[@]} -gt 0 ]]; then
          echo ""
          echo "The following branches were not rebased:"
          for b in "${skipped_branches[@]}"; do
            echo "  $b"
          done
        fi
      fi
    fi

    bdl && mig
  )
}

# Guided rebase with interactive conflict resolution.
# Usage: grebase [branch] [upstream]
#   No args: rebase current branch onto its tracking branch
#   One arg: rebase given branch onto its tracking branch (checks it out first)
#   Two args: rebase given branch onto given upstream (checks it out first)
function grebase
{
  local b="${1:-$(git rev-parse --abbrev-ref HEAD)}"
  local u="${2:-$(git rev-parse --abbrev-ref --symbolic-full-name "$b@{u}" 2>/dev/null)}"

  if [[ -z "$u" ]]; then
    echo "No upstream found for $b. Set one with: git branch --set-upstream-to=<upstream> $b"
    return 1
  fi

  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$b" != "$current_branch" ]]; then
    git checkout "$b"
  fi

  echo "Rebasing $b onto $u"

  local rebase_cmd=(git rebase "$u")
  while true; do
    if "${rebase_cmd[@]}" 2>&1; then
      echo "  $b - rebased successfully"
      if [[ "$b" != "$current_branch" ]]; then
        git checkout "$current_branch"
      fi
      return 0
    fi

    # Rebase stopped due to conflicts — show state and ask what to do.
    echo ""
    echo "Conflicting files:"
    git diff --name-only --diff-filter=U | sed 's/^/  /'
    echo ""
    echo "Commits remaining to be applied:"
    git log --oneline "$u"..REBASE_HEAD 2>/dev/null \
      || echo "  (could not determine remaining commits)"
    echo ""
    echo -n "Run git mergetool to fix conflicts? [y/n] (n aborts the rebase) "
    read -r conflict_answer
    if [[ "$conflict_answer" == "y" || "$conflict_answer" == "Y" ]]; then
      git mergetool
      rebase_cmd=(git rebase --continue)
    else
      git rebase --abort
      echo "  Rebase aborted. $b restored to its pre-rebase state."
      if [[ "$b" != "$current_branch" ]]; then
        git checkout "$current_branch"
      fi
      return 1
    fi
  done
}

# Bundle install for the current Ruby project.
function bdl
{
  if [ ! -f "Gemfile" ]; then
    echo "No Gemfile found, nothing to bundle."
    return 0
  fi
  echo "Bundling in case of Gemfile changes..."
  bundle install
}

# Run any new migrations if this looks like a Ruby project with a Rails-style schema.
# Then sync the test db from the updated schema.
function mig
{
  if [ -f "Gemfile" ] && [ -f "db/schema.rb" ] && { [ -f "bin/rails" ] || [ -f "config/application.rb" ]; }
  then
    echo "Running any new migrations..."
    run_bundler_cmd rake db:migrate
    echo "Syncing test db from schema..."
    RAILS_ENV=test RACK_ENV=test run_bundler_cmd rake db:schema:load
  else
    echo "Gemfile or db/schema.rb not found, nothing to migrate."
  fi
}
