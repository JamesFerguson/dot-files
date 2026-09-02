ulimit -n 8192

setopt ALL_EXPORT

# XDG base dir spec - mac dir spec sucks for cli tools
XDG_CONFIG_HOME="$HOME/.config"
XDG_DATA_HOME=$HOME/.local/share
XDG_STATE_HOME=$HOME/.local/state
XDG_CACHE_HOME=$HOME/.cache
# XDG_RUNTIME_DIR=/run/user/$UID # doesn't make sense on mac

# Make tools comply with XDG
ACKRC="$XDG_CONFIG_HOME/ack/ackrc"
AWS_SHARED_CREDENTIALS_FILE="$XDG_CONFIG_HOME"/aws/credentials
AWS_CONFIG_FILE="$XDG_CONFIG_HOME"/aws/config
AZURE_CONFIG_DIR="$XDG_DATA_HOME"/azure
BUNDLE_USER_CONFIG="$XDG_CONFIG_HOME"/bundle/config
BUNDLE_USER_CACHE="$XDG_CACHE_HOME"/bundle
BUNDLE_USER_PLUGIN="$XDG_DATA_HOME"/bundle
DOCKER_CONFIG="$XDG_CONFIG_HOME"/docker
# GEM_HOME="$XDG_DATA_HOME"/gem # might conflict with mise's per-version gem setup
GEM_SPEC_CACHE="$XDG_CACHE_HOME"/gem
INPUTRC="$XDG_CONFIG_HOME"/readline/inputrc
LESSHISTFILE="$XDG_STATE_HOME"/less/history
MYSQL_HISTFILE="$XDG_DATA_HOME"/mysql_history
NODE_REPL_HISTORY="$XDG_DATA_HOME"/node_repl_history
NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME"/npm/npmrc
PSQL_HISTORY="$XDG_DATA_HOME/psql_history"
RUBOCOP_CONFIG="$XDG_CONFIG_HOME"/rubocop/config.yml
SCREENRC="$XDG_CONFIG_HOME"/screen/screenrc
TLDR_CACHE_DIR="$XDG_CACHE_HOME"/tldr
ZPREZTODIR="$XDG_CONFIG_HOME/.zprezto"

# Claude environment file for VSCode
CLAUDE_ENV_FILE="$HOME/.claude-env"

# Dot files dir
#   - if on FatZebra laptop
if [[ "$HOST" == *"fz-"* ]]; then
  ON_WORK_LAPTOP=1
  CODE_DIR="$HOME/code"
  DOT_FILES_DIR="$CODE_DIR/personal/dot-files"
  source ~/.fat_zebra_env.sh
  setopt ALL_EXPORT # above line unsets ALL_EXPORT
else
  ON_WORK_LAPTOP=0
  CODE_DIR="$HOME/codez"
  DOT_FILES_DIR="$CODE_DIR/dot-files"
fi

# FZ root dir
FZ_ROOT_DIR="$CODE_DIR"
FZ_UTIL_BIN_DIR="$FZ_ROOT_DIR/utils/fz/bin"

# Go-lang setup
export GOPATH=$HOME/go
# ${VAR//PATTERN/REPLACE} -> find ':' replace w '/bin:'
GOPATHS=${GOPATH//://bin:}/bin

# Path
export PATH=\
$XDG_DATA_HOME/mise/shims:\
$HOME/bin:\
$CODE_DIR/git-achievements:\
/usr/local/bin:\
$HOME/.local/bin:\
/opt/homebrew/bin:\
/opt/homebrew/sbin:\
/opt/homebrew/opt/libpq/bin:\
/usr/local/sbin:\
/usr/bin:\
/bin:\
/usr/sbin:\
/sbin:\
$XDG_DATA_HOME/gem/bin:\
/usr/local/opt/mysql@5.6/bin/mysql:\
$GOPATHS:\
$HOME/.yarn/bin:\
$HOME/.yarn/dist/bin:\
$XDG_CONFIG_HOME/yarn/global/node_modules/.bin:\
$PATH

# $FZ_UTIL_BIN_DIR:\ # fat zebra utils


# Locale
LC_ALL='en_US.UTF-8'
LANG='en_US.UTF-8'
LC_CTYPE=C
TZ="Australia/Sydney"

# History
HISTFILE="$XDG_STATE_HOME"/zsh/history
HISTSIZE=10000
SAVEHIST=10000

# Put hostname in the env
HOSTNAME="`hostname`"

# Some standard zsh config
PAGER='less'
EDITOR="code --wait" #'/usr/local/bin/mvimf'
VISUAL="code --wait"

# Colour vars
autoload colors zsh/terminfo
if [[ "$terminfo[colors]" -ge 8 ]]; then
  colors
fi
for color in RED GREEN YELLOW BLUE MAGENTA CYAN WHITE; do
  eval PR_$color='%{$terminfo[bold]$fg[${(L)color}]%}'
  eval PR_LIGHT_$color='%{$fg[${(L)color}]%}'
done
PR_NO_COLOR="%{$terminfo[sgr0]%}"
CLICOLOR=1 # colorize ls and others

# Terminal prompt
#PS1="[$PR_MAGENTA%n$PR_NO_COLOR@$PR_GREEN%U%m%u$PR_NO_COLOR:$PR_RED%2c$PR_NO_COLOR]%(!.#.$) "
#RPS1="$PR_MAGENTA(%D{%m-%d %H:%M})$PR_NO_COLOR"
#DISPLAY=:0

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

# API tokens and other machine-local secrets live in ~/.claude-env.local (uncommitted)
[[ -f "$HOME/.claude-env.local" ]] && source "$HOME/.claude-env.local"

# Ruby
RUBY_CONFIGURE_OPTS="--enable-yjit"
SIMPLECOV_ONLY_FULL_SUITE=true

# editor used by bundle open
BUNDLER_EDITOR="code --wait"

# Brew env var init
HOMEBREW_PREFIX=$(brew --prefix)
HOMEBREW_NO_ANALYTICS=1

unsetopt ALL_EXPORT

# Source Prezto's zshenv
if [[ -z "$ZPREZTODIR" ]]; then
  echo "Error: ZPREZTODIR is not set"
else
  source "$ZPREZTODIR/runcoms/zshenv"
fi