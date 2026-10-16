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

# Fat Zebra-specific includes from the private work-dot-files repo, if it's present.
# Loaded after the public includes so they can override (e.g. the `bk` alias).
if [[ -n "$WORK_DOT_FILES_DIR" && -d "$WORK_DOT_FILES_DIR/zshrc/includes" ]]; then
  for include in `/bin/ls -1 "$WORK_DOT_FILES_DIR/zshrc/includes"`
  do
          echo "  Sourcing (fz) $include..."
          source "$WORK_DOT_FILES_DIR/zshrc/includes/$include"
  done
fi

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/james.ferguson/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)


# Created by `pipx` on 2024-10-28 11:41:21
export PATH="$PATH:/Users/james.ferguson/.local/bin"
