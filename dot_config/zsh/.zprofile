
eval "$(/opt/homebrew/bin/brew shellenv)"

# Prezto's zprofile
#  * sets some env vars if not already set
#  * de-dupes paths (path, fpath etc)
#  * adds some basic paths to path
#  * set default less options
if [[ -z "$ZPREZTODIR" ]]; then
  echo "Error: ZPREZTODIR is not set"
else
  source "$ZPREZTODIR/runcoms/zprofile"
fi
# Created by `pipx` on 2024-10-28 11:41:21
export PATH="$PATH:/Users/james.ferguson/.local/bin"
