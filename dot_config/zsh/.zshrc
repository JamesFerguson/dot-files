echo ".zshrc:"

if type brew &>/dev/null
then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

# Initialize Zsh completion system
autoload -Uz compinit bashcompinit
compinit

# Initialize Bash completion compatibility layer (so zsh can read completion files written for bash)
# Needed for asdf completions (at least)
bashcompinit

# Add Prezto's zshrc; sources .zprezto/init.zsh
if [[ -z "$ZPREZTODIR" ]]; then
  echo "Error: ZPREZTODIR is not set"
else
  source "$ZPREZTODIR/runcoms/zshrc"
fi

export INCLUDES_DIR=$DOT_FILES_DIR/dot_zshrc/includes
for include in `/bin/ls -1 $INCLUDES_DIR`
do
        echo "  Sourcing $include..."
        source "$INCLUDES_DIR/$include"
done

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/james.ferguson/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)


# Created by `pipx` on 2024-10-28 11:41:21
export PATH="$PATH:/Users/james.ferguson/.local/bin"
