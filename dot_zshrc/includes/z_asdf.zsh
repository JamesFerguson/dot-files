autoload -Uz bashcompinit
bashcompinit
source $HOME/.asdf/asdf.sh
BASH_SOURCE="$HOME/.asdf/completions/asdf.bash" emulate ksh -c '. $BASH_SOURCE'
