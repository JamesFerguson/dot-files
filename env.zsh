setopt ALL_EXPORT

PATH="/opt/local/bin:/opt/local/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/git/bin:/usr/local/mysql/bin:/usr/local/pgsql/bin:/Users/jim/Coding/homebrew/bin:/Users/jim/Coding/git-achievements:/usr/texbin:/usr/X11/bin:$PATH"
TZ="Australia/Sydney"
HISTFILE=$HOME/.zhistory
HISTSIZE=1000
SAVEHIST=1000
HOSTNAME="`hostname`"
PAGER='less'
EDITOR='/usr/local/bin/mate -w'

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

PS1="[$PR_MAGENTA%n$PR_NO_COLOR@$PR_GREEN%U%m%u$PR_NO_COLOR:$PR_RED%2c$PR_NO_COLOR]%(!.#.$) "
RPS1="$PR_MAGENTA(%D{%m-%d %H:%M})$PR_NO_COLOR"
#LANGUAGE=
LC_ALL='en_US.UTF-8'
LANG='en_US.UTF-8'
LC_CTYPE=C
DISPLAY=:0

if [ $SSH_TTY ]; then
  MUTT_EDITOR='/usr/local/bin/mate -w'
else
  MUTT_EDITOR=emacsclient.emacs-snapshot
fi

unsetopt ALL_EXPORT
