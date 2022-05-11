# # --------------------------------------------------------------------
# # aliases
# # --------------------------------------------------------------------
alias cd..='cd ..'
alias ..='cd ..'
alias .='pwd'
alias ls='/bin/ls -lAh@eF'
alias jobs='jobs -l'
alias pgrep='grep -P'
alias dmesg="sudo dmesg"
alias locate="locate -e" # leaves out missing files (when db is old)
alias which="which -a" # show all matching paths, not just first

# the silver searcher
alias ag="nocorrect noglob ag --smart-case -C 2"
alias ack="nocorrect noglob ag --smart-case -C 2"

# rake aliases
alias migrate='run_bundler_cmd rake db:migrate && run_bundler_cmd rake db:test:load'

# rails aliases
alias console='rails --version | grep 2.3 > /dev/null && script/console || rails console'
alias sp='spring'
alias mupiter='bx jupiter --no-questions --mdns --init-code --stash --popup=raise'
alias RET='RAILS_ENV=test'
alias RED='RAILS_ENV=development'

# global aliases
alias -g G='| grep'
alias -g L='| less'
alias -g C='| wc -l'

# disable zsh corrections for some commands
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