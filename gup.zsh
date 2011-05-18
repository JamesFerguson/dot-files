unalias gup # added by oh-my-zsh git plugin

function git_current_branch() {
  git symbolic-ref HEAD 2> /dev/null | sed -e 's/refs\/heads\///'
}

function gup() {
  echo "git fetch origin && git rebase -p origin/$(git_current_branch)"
  git fetch origin && git rebase -p origin/$(git_current_branch)
}