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

# the silver searcher
alias ag="nocorrect noglob ag --smart-case -C 2"
alias ack="nocorrect noglob ag --smart-case -C 2"

# More specific ones
alias du_podcasts='du ~/Music/iTunes/iTunes\ Media/Podcasts | rev | sed -E s/\([^0-9]{1}\)\([0-9]{4}\)$/\\1\\2\ \ \ / | sed -E s/\([^0-9]{1}\)\([0-9]{5}\)$/\\1\\2\ \ / | sed -E s/\([^0-9]{1}\)\([0-9]{6}\)$/\\1\\2\ / | rev | sort'

# rake aliases
alias migrate='run_bundler_cmd rake db:migrate && run_bundler_cmd rake db:test:prepare && DATABASE=$CUCUMBER_DATABASE rake db:test:prepare'

# rails aliases
alias console='rails --version | grep 2.3 > /dev/null && script/console || rails console'
alias serve='script/server || unicorn_rails || thin start || rails server'
alias generate='rails --version | grep 2.3 > /dev/null && script/generate || rails generate'
alias cuc='run_bundler_cmd cucumber'

# disable zsh corrections for some commands
alias git='nocorrect git-achievements'
alias mvim='nocorrect mvim'
alias guard='nocorrect guard'
alias heroku='nocorrect heroku'
alias github='nocorrect github'
alias gh='nocorrect gh'
alias grb='nocorrect grb'
