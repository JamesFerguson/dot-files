# Activate mise for interactive zsh: manages PATH and picks up per-directory
# .tool-versions via a chpwd hook. Re-asserts its managed paths after anything
# that clobbers PATH (the reason the old asdf line re-prepended shims).
eval "$(mise activate zsh)"
