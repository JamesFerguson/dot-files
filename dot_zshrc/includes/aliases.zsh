# # --------------------------------------------------------------------
# # aliases
# # --------------------------------------------------------------------
alias cd..='cd ..'
alias ..='cd ..'
alias mls='/bin/ls -lAh@eF'
alias ls='/opt/homebrew/bin/gls -lAhF --color=auto --group-directories-first'
alias jobs='jobs -l'
alias pgrep='grep -P'
alias dmesg="sudo dmesg"
alias which="which -a" # show all matching paths, not just first

# fasd (autojump substitute)
alias j='fasd_cd -d'

# use rg for ag or ack
alias ag="nocorrect noglob rg --smart-case -C 2"
alias ack="nocorrect noglob rg --smart-case -C 2"

# rake aliases
alias migrate='mig'

# rails aliases
alias be="bundle exec"
alias sp='spring'
alias RET='RAILS_ENV=test'
alias RED='RAILS_ENV=development'
alias rials='run_bundler_cmd rails'

# brew aliases
alias brew-bundle="brew bundle --file=$XDG_CONFIG_HOME/brew/Brewfile"
alias bb="brew bundle --file=$XDG_CONFIG_HOME/brew/Brewfile"

# global aliases
alias -g G='| grep'
alias -g L='| less'
alias -g C='| wc -l'

# disable zsh corrections for some commands
alias g='nocorrect git-achievements'
alias git='nocorrect git-achievements'
alias mvim='nocorrect mvim'
alias guard='nocorrect guard'
alias heroku='nocorrect heroku'
alias github='nocorrect github'
alias gh='nocorrect gh'
alias grb='nocorrect grb'
alias gsm='git switch --merge'
alias rbm='grebase $(git rev-parse --abbrev-ref HEAD) origin/main'

# remove all branches that have been merged to upstream
alias gp='git push'
alias gb='git branch'
alias gre='git rebase --edit-todo'
#   git remote branch new
function grbn() {
  git checkout -b "$1"
  git push -u origin "$1"
}
alias grbd='git push origin --delete'
alias gbda='git branch --no-color --merged | command grep -vE "^(\*|\s*(main|master|develop|dev)\s*$)" | command xargs -n 1 git branch -d'
alias gst='git status'
alias bcf='bundle clean --force'
alias mdcu='mix deps.clean --unused'
alias rclose='g ch develop && gup && gbda && bcf'
alias eclose='g ch develop && gup && gbda && mdcu'
alias rgclose='(g ch master || g ch main) && gup && gbda && bcf'
alias egclose='(g ch master || g ch main) && gup && gbda && mdcu'
alias gbname='git rev-parse --abbrev-ref HEAD' # bare branch name

# open buildkite pipeline
alias bk="open https://buildkite.com/fat-zebra/$(basename $PWD | tr '_' '-')"

# overitall log viewer for all local apps
alias oita="oit -c $XDG_CONFIG_HOME/overitall/config.toml"
