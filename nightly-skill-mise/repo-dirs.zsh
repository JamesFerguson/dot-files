#!/bin/zsh
# repo-dirs.zsh — print every directory whose ruby matters, one per line: each git repo
# or worktree root under ~/code (two levels deep, so ~/code/<repo>, ~/code/core-payments/<repo>
# and ~/code/<x>-worktrees/<tree>), plus the directory each stdio MCP server in
# ~/.claude.json starts in (`cd <dir> && exec …`), which may live anywhere.

emulate -L zsh
CODE_DIR="${CODE_DIR:-$HOME/code}"

{
  for d in "$CODE_DIR"/*/(N) "$CODE_DIR"/*/*/(N); do
    [[ -e "$d/.git" ]] && print -r -- "${d%/}"
  done
  "${0:A:h}/mcp-server-dirs.zsh" 2>/dev/null | cut -f2
} | sort -u
