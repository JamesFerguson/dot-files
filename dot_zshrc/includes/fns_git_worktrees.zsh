# Workflow functions for git worktrees

# Finish and clean up a git worktree
git-finish-worktree() {
  set -euo pipefail

  worktree_path="$(git rev-parse --show-toplevel)"
  branch_name="$(git rev-parse --abbrev-ref HEAD)"
  main_repo_path="$(git -C "$worktree_path" rev-parse --git-common-dir | xargs dirname)"

  if [[ "$main_repo_path" == "$worktree_path" ]]; then
    echo "❌ Not inside a worktree — refusing to clean up main repo."
    return 1
  fi

  echo "🧹 Cleaning up worktree for branch: $branch_name"
  echo "📁 Worktree path: $worktree_path"
  echo "🗂  Main repo path: $main_repo_path"

  echo ""

  # Check if remote branch exists
  if git -C "$main_repo_path" ls-remote --exit-code --heads origin "$branch_name" > /dev/null 2>&1; then
    read "delete_remote?Do you want to delete the remote branch '$branch_name'? [y/N] "
    if [[ "$delete_remote" =~ ^[Yy]$ ]]; then
      git -C "$main_repo_path" push origin --delete "$branch_name"
    fi
  else
    echo "🚫 Remote branch '$branch_name' doesn't exist — skipping delete prompt."
  fi

  echo ""
  read "delete_local?Do you want to delete the local branch '$branch_name'? [y/N] "
  if [[ "$delete_local" =~ ^[Yy]$ ]]; then
    echo "Switching to main branch so we can delete '$branch_name'..."
    git -C "$main_repo_path" switch main
    git -C "$main_repo_path" branch -D "$branch_name"
  fi

  echo ""
  echo "🧼 Removing worktree..."
  cd "$main_repo_path"
  git worktree remove --force "$worktree_path"

  echo "✅ Worktree for '$branch_name' cleaned up."
}