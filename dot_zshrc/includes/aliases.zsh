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
alias migrate='run_bundler_cmd rake db:migrate db:test:prepare && DATABASE=$CUCUMBER_DATABASE rake db:test:prepare'
alias testsuite='run_bundler_cmd rake cucumber spec'

# rails aliases
alias console='rails --version | grep 2.3 > /dev/null && script/console || rails console'
alias serve='script/server || unicorn_rails || thin start || rails server'
alias generate='rails --version | grep 2.3 > /dev/null && script/generate || rails generate'
alias bx='bundle exec'
alias cuc='run_bundler_cmd cucumber'

# disable zsh corrections for some commands
alias git='nocorrect git-achievements'
alias mvim='nocorrect mvim'
alias guard='nocorrect guard'
alias heroku='nocorrect heroku'
alias github='nocorrect github'
alias gh='nocorrect gh'

# personal project aliases
alias tv='cd ~/Coding/tv-shows'
alias dot='cd ~/dot-files'
alias todos='cd ~/Coding/todos'

# blake aliases
alias reg='cd ~/blake/readingeggs'
alias reg2='cd ~/blake/readingeggs2'
alias rexs='cd ~/blake/rex-student'
alias rex='cd ~/blake/rex-student'
alias rexd='cd ~/blake/rex-dashboard'
alias mh='cd ~/blake/media-hub'
alias ed='cd ~/blake/eggspress-data'
alias fth='cd ~/blake/fth'
alias det='cd ~/blake/detachment'
alias adm='cd ~/blake/blake-admin'
alias cape= 'cd ~/blake/Caper'
alias caper= 'cd ~/blake/Caper'
alias chefs= 'cd ~/blake/Plastic-Chefs'
