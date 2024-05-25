autoload -Uz bashcompinit
bashcompinit
source $HOMEBREW_PREFIX/opt/asdf/libexec/asdf.sh
BASH_SOURCE="$HOMEBREW_PREFIX/Cellar/asdf/0.14.0/etc/bash_completion.d/asdf.bash" emulate ksh -c '. $BASH_SOURCE'
