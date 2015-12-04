setopt ALL_EXPORT

export PATH=\
$HOME/bin:\
$HOME/.rvm/gems/ruby-2.0.0-p247/bin:\
$HOME/.rvm/gems/ruby-2.0.0-p2470@global/bin:\
$HOME/.rvm/rubies/ruby-2.0.0-p247/bin:\
$HOME/.rvm/bin:\
$HOME/codez/git-achievements:\
$HOME/Dropbox/Blake/sync/bin:\
/usr/local/share/npm/bin:\
/usr/local/bin:\
/usr/local/sbin:\
/usr/bin:\
/bin:\
/usr/sbin:\
/sbin:\
$PATH

# RE setting
RETRIES=1

# Locale
LC_ALL='en_US.UTF-8'
LANG='en_US.UTF-8'
LC_CTYPE=C
TZ="Australia/Sydney"

HISTFILE=$HOME/.zhistory
HISTSIZE=1000
SAVEHIST=1000

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
RPS1="$PR_MAGENTA(%D{%m-%d %H:%M})$PR_NO_COLOR"
DISPLAY=:0

# Tell PostgreSQL where to find its data
PGDATA=/Library/PostgreSQL/8.4/data/

# Ensure node finds npm modules
NODE_PATH=/usr/local/lib/node_modules

# Can't set redis up in pow
REDIS_URL="redis://127.0.0.1:6379/"

unsetopt ALL_EXPORT
