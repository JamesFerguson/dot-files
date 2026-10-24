#!/bin/zsh
# restore-sweep-stash.zsh <repo-path>: put this repo's repo-sweep stash back on the updated tree.
# Own edits (non-generated tracked files) are re-applied as a diff; generated files keep the
# freshly regenerated version; untracked files come back unless one already exists with
# different content. All or nothing: if any file won't go, everything applied is undone and
# the stash stays as the only copy. Worktrees share one stash list, so only a stash named
# for this repo is touched.
emulate -L zsh
repo=${1:A}; cd "$repo" || exit 1
name=${repo#$HOME/code/}

ref=$(git stash list --format='%gd %gs' | awk -v n="repo-sweep WIP $name" 'substr($0, length($0) - length(n) + 1) == n {print $1; exit}')
[[ -n $ref ]] || { print "$name: no repo-sweep stash for this repo"; exit 0; }

generated='^(Gemfile\.lock|db/schema\.rb|db/structure\.sql|\.ruby-version|\.tool-versions)$'
ok=1; msgs=(); applied=(); created=()

for f in ${(f)"$(git stash show --name-only $ref)"}; do
  if [[ $f =~ $generated ]]; then msgs+="$f: kept regenerated"; continue; fi
  if git diff "$ref^1" "$ref" -- $f | git apply 2>/dev/null; then
    applied+=$f; msgs+="$f: re-applied"
  elif git diff "$ref^1" "$ref" -- $f | git apply --3way 2>/dev/null && [[ -z $(git ls-files -u -- $f) ]]; then
    git restore --staged -- $f; applied+=$f; msgs+="$f: re-applied (3-way)"
  else
    git restore --staged --worktree --source=HEAD -- $f 2>/dev/null
    msgs+="$f: CONFLICTS"; ok=0
  fi
done

if git rev-parse -q --verify "$ref^3" >/dev/null; then
  for f in ${(f)"$(git show --name-only --format= "$ref^3")"}; do
    [[ -z $f ]] && continue
    if [[ ! -e $f ]]; then
      git restore --source="$ref^3" --worktree -- $f && created+=$f && msgs+="$f: restored (untracked)"
    elif git show "$ref^3:$f" | cmp -s - $f; then
      msgs+="$f: already present"
    elif [[ $f =~ $generated ]]; then
      msgs+="$f: kept regenerated (untracked)"
    else
      msgs+="$f: EXISTS WITH DIFFERENT CONTENT"; ok=0
    fi
  done
fi

print "== $name"; print -l "   "${^msgs}
if (( ok )); then
  git stash drop -q $ref && print "   stash dropped"
else
  (( $#applied )) && git restore --source=HEAD --staged --worktree -- $applied
  (( $#created )) && rm -f -- $created
  print "   stash KEPT ($ref), nothing applied"
fi
