ulimit -n 8192

setopt ALL_EXPORT

# XDG base dir spec - mac dir spec sucks for cli tools
XDG_CONFIG_HOME="$HOME/.config"
XDG_DATA_HOME=$HOME/.local/share
XDG_STATE_HOME=$HOME/.local/state
XDG_CACHE_HOME=$HOME/.cache
XDG_RUNTIME_DIR=/run/user/$UID

# Make tools comply with XDG
ACKRC="$XDG_CONFIG_HOME/ack/ackrc"
ASDF_CONFIG_FILE="$XDG_CONFIG_HOME"/asdf/asdfrc
ASDF_DATA_DIR="$XDG_DATA_HOME"/asdf
BUNDLE_USER_CONFIG="$XDG_CONFIG_HOME"/bundle/config
INPUTRC="$XDG_CONFIG_HOME"/readline/inputrc

# Go-lang setup
export GOPATH=$HOME/go
# ${VAR//PATTERN/REPLACE} -> find ':' replace w '/bin:'
GOPATHS=${GOPATH//://bin:}/bin

export PATH=\
$HOME/bin:\
$HOME/codez/git-achievements:\
/usr/local/bin:\
/opt/homebrew/bin:\
/opt/homebrew/sbin:\
/opt/homebrew/opt/libpq/bin:\
/usr/local/sbin:\
/usr/bin:\
/bin:\
/usr/sbin:\
/sbin:\
/usr/local/opt/mysql@5.6/bin/mysql:\
$GOPATHS:\
$HOME/Blake/bs/bin:\
$HOME/Blake/bk8s/bin:\
$HOME/.yarn/bin:\
$HOME/.yarn/dist/bin:\
$HOME/.config/yarn/global/node_modules/.bin:\
$PATH

# RE setting
RETRIES=1

# Locale
LC_ALL='en_US.UTF-8'
LANG='en_US.UTF-8'
LC_CTYPE=C
TZ="Australia/Sydney"

HISTFILE=$HOME/.zhistory
HISTSIZE=10000
SAVEHIST=10000

HOSTNAME="`hostname`"

PAGER='less'
EDITOR='/usr/local/bin/mvimf' # '/Users/jim/bin/mate_wait'

# Colour vars
autoload colors zsh/terminfo
if [[ "$terminfo[colors]" -ge 8 ]]; then
  colors
fi
for color in RED GREEN YELLOW BLUE MAGENTA CYAN WHITE; do
  eval PR_$color='%{$terminfo[bold]$fg[${(L)color}]%}'
  eval PR_LIGHT_$color='%{$fg[${(L)color}]%}'
  (( count = $count + 1 ))
done
PR_NO_COLOR="%{$terminfo[sgr0]%}"
CLICOLOR=1 # colorize ls and others

# Terminal prompt
#PS1="[$PR_MAGENTA%n$PR_NO_COLOR@$PR_GREEN%U%m%u$PR_NO_COLOR:$PR_RED%2c$PR_NO_COLOR]%(!.#.$) "
#RPS1="$PR_MAGENTA(%D{%m-%d %H:%M})$PR_NO_COLOR"
#DISPLAY=:0

# Tell PostgreSQL where to find its data
#PGDATA=/Library/PostgreSQL/8.4/data/

# Ensure node finds npm modules
NODE_PATH=/usr/local/lib/node_modules

# Can't set redis up in pow
REDIS_URL="redis://127.0.0.1:6379/"

# Enable shell history in IEx
# ERL_AFLAGS"=" +pc unicode -kernel shell_history_file_bytes 1024000"
ERL_AFLAGS="-kernel shell_history enabled"

# Configure less
LESS='--quit-if-one-screen --ignore-case --status-column --LONG-PROMPT --RAW-CONTROL-CHARS --HILITE-UNREAD --tabs=2 --no-init --window=-2'

# should be provided by prezto environment module
# Set colors for less. Borrowed from https://wiki.archlinux.org/index.php/Color_output_in_console#less .
#LESS_TERMCAP_mb=$'\E[1;31m'     # begin bold
#LESS_TERMCAP_md=$'\E[1;36m'     # begin blink
#LESS_TERMCAP_me=$'\E[0m'        # reset bold/blink
#LESS_TERMCAP_so=$'\E[01;44;33m' # begin reverse video
#LESS_TERMCAP_se=$'\E[0m'        # reset reverse video
#LESS_TERMCAP_us=$'\E[1;32m'     # begin underline
#LESS_TERMCAP_ue=$'\E[0m'        # reset underline

# editor used by bundle open
BUNDLER_EDITOR=code

unsetopt ALL_EXPORT
