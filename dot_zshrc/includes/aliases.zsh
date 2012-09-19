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
alias bundle='bundle && echo "Restarting Pow instance..." && touch tmp/restart.txt'

# disable zsh corrections for some commands
alias git='nocorrect git-achievements'
alias mvim='nocorrect mvim'
alias guard='nocorrect guard'
alias heroku='nocorrect heroku'
alias github='nocorrect github'
alias gh='nocorrect gh'

# personal project aliases
alias tv='cd ~/codez/tv-shows'
alias dot='cd ~/codez/dot-files'
alias todos='cd ~/codez/todos'

# blake aliases
alias reg='cd ~/Blake/re'
alias reg2='cd ~/Blake/re_alt'
alias rex='cd ~/Blake/rex-student'
alias rexd='cd ~/Blake/rex-dashboard'
alias mh='cd ~/Blake/media-hub'
alias ed='cd ~/Blake/eggspress-data'
alias fth='cd ~/Blake/fth'
alias det='cd ~/Blake/detachment'
alias adm='cd ~/Blake/blake-admin'
alias cape='cd ~/Blake/Caper'
alias caper='cd ~/Blake/Caper'
alias chefs='cd ~/Blake/Plastic-Chefs'
alias act='cd ~/Blake/caper-activities'
alias math='cd ~/Blake/mathseeds'
alias dsource='cd ~/Blake/blake-data-source'
alias hu='cd ~/Blake/hubot'
alias detgup='cd ~/Blake/detachment && git rebase -p redev/master'
alias bgup='cd ~/Blake/bootstrap && git rebase -p redev/master'
