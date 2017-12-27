[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow -g "!{.git,node_modules}/*" 2> /dev/null'

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

fuzzy_vim () { vim $(fzf) -; zle redisplay }
zle -N fuzzy_vim
bindkey '^p' fuzzy_vim
