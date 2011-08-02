# # --------------------------------------------------------------------
# # aliases
# # --------------------------------------------------------------------
alias cd..='cd ..'
alias ..='cd ..'
alias .='pwd'
alias ls='ls -lah@eF'
alias jobs='jobs -l'
alias pgrep='grep -P'
alias dmesg="sudo dmesg"

# More specific ones
alias du_podcasts='du ~/Music/iTunes/iTunes\ Music/Podcasts | rev | sed -E s/\([^0-9]{1}\)\([0-9]{4}\)$/\\1\\2\ \ \ / | sed -E s/\([^0-9]{1}\)\([0-9]{5}\)$/\\1\\2\ \ / | sed -E s/\([^0-9]{1}\)\([0-9]{6}\)$/\\1\\2\ / | rev | sort'

# rake aliases
alias migrate='rake db:migrate db:test:prepare'
alias testsuite='rake cucumber spec'

# rails aliases
alias console='rails --version | grep 2.3 > /dev/null && script/console || rails console'
alias serve='script/server || unicorn_rails || thin start || rails server'
alias generate='rails --version | grep 2.3 > /dev/null && script/generate || rails generate'
alias bx='bundle exec'
alias cuc='bundle exec cucumber'
alias rake='bundle exec rake'

# disable zsh corrections for some commands
alias git='nocorrect git-achievements'
alias mvim='nocorrect mvim'
alias guard='nocorrect guard'

# personal project aliases
alias tv='cd ~/Coding/tv-shows'

# blake aliases
alias dbhack='cp config/database.yml.local config/database.yml'
alias regalt='cd ~/blake/readingeggs_alternate'
alias reg='cd ~/blake/readingeggs'
alias reg2='cd ~/blake/readingeggs2'
alias rexs='cd ~/blake/rex-student'
alias rexd='cd ~/blake/rex-dashboard'
