#!/bin/zsh
# mcp-server-dirs.zsh — list the stdio MCP servers in ~/.claude.json that start inside a
# directory (`sh -c 'cd <dir> && exec …'`), as "<name><TAB><dir>" lines. Those servers run
# on whatever ruby (or node) mise resolves in that directory, so a version change there
# breaks them on the next reconnect.

emulate -L zsh
CONFIG="${CLAUDE_CONFIG:-$HOME/.claude.json}"
[[ -f "$CONFIG" ]] || exit 0

jq -r '.mcpServers // {} | to_entries[]
  | select((.value.type // "stdio") == "stdio" and .value.command != null)
  | [.key, ([.value.command] + (.value.args // []) | join(" "))] | @tsv' "$CONFIG" |
while IFS=$'\t' read -r name cmd; do
  [[ "$cmd" =~ 'cd ([^ &;]+)' ]] || continue
  dir="${match[1]/#\~/$HOME}"
  [[ -d "$dir" ]] && print -r -- "$name"$'\t'"$dir"
done
