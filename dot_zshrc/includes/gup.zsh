unalias gup # added by oh-my-zsh git plugin

function gup
{
  # subshell for `set -e` and `trap`
  (
    set -e # fail immediately if there's a problem

    echo "Fetching upstream changes"
    git fetch --prune
    BRANCH=$(git describe --contains --all HEAD)
    if [ -z "$(git config branch.$BRANCH.remote)" -o -z "$(git config branch.$BRANCH.merge)" ]
    then
      echo "\"$BRANCH\" is not a tracking branch." >&2
      exit 1
    else
      echo "\"$BRANCH\" is a tracking branch, using it."
    fi

    TEMPFILE=$(mktemp -u -t "gup.XXXXXX")
    echo "Created a temp file, \"$TEMPFILE\", for capturing command output, will delete on exit."
    trap '{ rm -f "$TEMPFILE"; echo "Deleted $TEMPFILE" }' EXIT

    if git status | grep "# Your branch" > "$TEMPFILE"
    then
      # extract tracking branch from message
      UPSTREAM=$(cat "$TEMPFILE" | cut -d "'" -f 2)
      echo "We're behind upstream, \"$UPSTREAM\", we need to update."

      if [ -z "$UPSTREAM" ]
      then
        echo Could not detect upstream branch >&2
        exit 1
      fi

      # stash any uncommitted changes
      git stash | tee "$TEMPFILE"
      [ "${PIPESTATUS[0]}" -eq 0 ] || exit 1

      # take note if anything was stashed
      HAVE_STASH=0
      grep -q "No local changes" "$TEMPFILE" || HAVE_STASH=1

      echo "Rebasing our changes on top of upstream, but keeping any merges."
      echo "git rebase -p \"$UPSTREAM\""
      git rebase -p "$UPSTREAM"

      # restore any stashed changed
      if [ "$HAVE_STASH" -ne 0 ]
      then
        echo "Popping stash."
        git stash pop
      else
        echo "Nothing stashed."
      fi

      if [ -f "Gemfile" ]
      then
        echo "Bundling in case of Gemfile changes"
        bundle
        echo "Cleaning bundle"
        bundle clean --force
      fi

      if [ -d "db" ]
      then
        echo "Running any new migrations and updating test db..."
        rake db:abort_if_pending_migrations 

        if [ $? -eq 0]
        then
          echo "No new migrations."
        else
          echo "Migrations found, migrating and preparing test..." 
          rake db:migrate
          rake db:test:prepare
          #echo "Migrating cucumber env..."
          #DATABASE=$CUCUMBER_DATABASE rake db:test:prepare
        fi
      fi

    else
      echo "Nothing to update, no need to stash/rebase."
    fi
  )
}
