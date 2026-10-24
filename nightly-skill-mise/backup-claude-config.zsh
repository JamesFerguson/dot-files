#!/bin/zsh
# Nightly refresh of the private claude-config backup: ~/.claude/{skills,rules,CLAUDE.md}
# → ~/code/personal/claude-config. Uses the repo's own sync.sh (rsync + gitleaks scan),
# then commits + pushes only if something changed. No-op otherwise. Never fails the nightly.

REPO="$HOME/code/personal/claude-config"

if [[ ! -d "$REPO/.git" ]]; then
  echo "claude-config: repo not found at $REPO — skipping backup."
  exit 0
fi

cd "$REPO" || { echo "claude-config: cannot cd $REPO — skipping."; exit 0; }

# sync.sh mirrors ~/.claude in and runs gitleaks; it exits non-zero if gitleaks flags.
if ! ./sync.sh; then
  echo "claude-config: sync.sh failed (gitleaks flagged, or rsync error) — NOT committing."
  exit 0
fi

if [[ -z "$(git status --porcelain)" ]]; then
  echo "claude-config: no changes."
  exit 0
fi

git add -A
git commit -q -m "nightly sync from ~/.claude"

# push.sh is a plain git push over the SSH remote (gh only holds the work account).
if ./push.sh >/dev/null 2>&1; then
  echo "claude-config: backup updated + pushed ($(git rev-parse --short HEAD))."
else
  echo "claude-config: committed locally ($(git rev-parse --short HEAD)) but push failed — run ./push.sh manually."
fi
