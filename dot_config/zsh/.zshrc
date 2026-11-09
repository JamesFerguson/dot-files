echo ".zshrc:"

if type brew &>/dev/null
then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

# Initialize Zsh completion system
autoload -Uz compinit bashcompinit
compinit

# Initialize Bash completion compatibility layer (so zsh can read completion files written for bash)
# Kept for bash-style completion files; mise uses native zsh completions (via `mise activate` / `mise completion zsh`)
bashcompinit

# Add Prezto's zshrc (silent no-op if Prezto isn't installed yet)
[[ -f "$ZPREZTODIR/runcoms/zshrc" ]] && source "$ZPREZTODIR/runcoms/zshrc"

export INCLUDES_DIR=$DOT_FILES_DIR/dot_zshrc/includes
# Only *.zsh fragments. Helper scripts that live here but aren't shell
# (mise-ready.py, called by brew_refresh.zsh) and __pycache__/ must not be sourced.
for include in "$INCLUDES_DIR"/*.zsh(N)
do
        echo "  Sourcing ${include:t}..."
        source "$include"
done

# Private overlay — loaded after public includes so it can override. Both contexts live in the one
# repo, so DEVICE_TYPE picks which: work/ on a work machine, personal/ on a home one, neither if unset.
case "$DEVICE_TYPE" in
  work) PRIVATE_CONTEXT=work ;;
  home) PRIVATE_CONTEXT=personal ;;
  *)    PRIVATE_CONTEXT= ;;
esac
if [[ -n "$PRIVATE_DOT_FILES_DIR" && -n "$PRIVATE_CONTEXT" ]]; then
  for include in "$PRIVATE_DOT_FILES_DIR/$PRIVATE_CONTEXT/zshrc/includes"/*.zsh(N)
  do
          echo "  Sourcing ($PRIVATE_CONTEXT) ${include:t}..."
          source "$include"
  done
fi
unset PRIVATE_CONTEXT

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/james.ferguson/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)


# Created by `pipx` on 2024-10-28 11:41:21
export PATH="$PATH:/Users/james.ferguson/.local/bin"
