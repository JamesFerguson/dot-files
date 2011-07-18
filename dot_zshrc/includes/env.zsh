setopt ALL_EXPORT

PATH="/opt/local/bin:/opt/local/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/git/bin:/usr/local/mysql/bin:/usr/local/pgsql/bin:/Users/jim/Coding/homebrew/bin:/Users/jim/Coding/git-achievements:/usr/texbin:/usr/X11/bin:/usr/local/lib/node:$PATH"

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
EDITOR='/Users/jim/bin/mate_wait'

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

unsetopt ALL_EXPORT