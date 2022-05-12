source $HOME/.asdf/asdf.sh
autoload -Uz bashcompinit
bashcompinit
BASH_SOURCE="$HOME/.asdf/completions/asdf.bash" emulate ksh -c '. $BASH_SOURCE'
