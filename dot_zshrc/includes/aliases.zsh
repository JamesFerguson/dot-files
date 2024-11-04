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

# the silver searcher
alias ag="nocorrect noglob ag --smart-case -C 2"
alias ack="nocorrect noglob ag --smart-case -C 2"

# rake aliases
alias migrate='run_bundler_cmd rake db:migrate && run_bundler_cmd rake db:test:load'

# rails aliases
alias sp='spring'
alias mupiter='bx jupiter --no-questions --mdns --init-code --stash --popup=raise'
alias RET='RAILS_ENV=test'
alias RED='RAILS_ENV=development'

# brew aliases
alias brew-bundle="brew bundle --file=$XDG_CONFIG_HOME/brew/Brewfile"

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

# remove all branches that have been merged to upstream
alias gbda='git branch --no-color --merged | command grep -vE "^(\*|\s*(master|develop|dev)\s*$)" | command xargs -n 1 git branch -d'
alias gst='git status'
alias bcnf='bundle clean --force'
alias mdcu='mix deps.clean --unused'
alias rclose='g ch develop && gup && gbda && bcnf'
alias eclose='g ch develop && gup && gbda && mdcu'

# open buildkite pipeline
alias bk="open https://buildkite.com/blake-education/$(basename $PWD | tr '_' '-')"