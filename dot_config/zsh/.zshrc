echo "Sourcing ~/.zshrc"

if type brew &>/dev/null
then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"

  autoload -Uz compinit
  compinit -d "$XDG_CACHE_HOME"/zsh/zcompdump-"$ZSH_VERSION"
fi


export INCLUDES_DIR=$DOT_FILES_DIR/dot_zshrc/includes
for include in `/bin/ls -1 $INCLUDES_DIR`
do
        echo "Sourcing $include..."
        source "$INCLUDES_DIR/$include"
done

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/james.ferguson/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)