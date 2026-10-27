#!/bin/zsh
# mcp-smoke.zsh — check that every stdio MCP server that starts inside a directory
# (mcp-server-dirs.zsh) still starts. For each one:
#   1. if the directory has a Gemfile, `bundle check`, and `bundle install` if that fails
#      (each mise ruby has its own gem home, so a ruby change leaves the gems behind);
#   2. start the server the way Claude does, with only HOME plus the env from its
#      ~/.claude.json entry (${VAR} values filled from ~/.fat_zebra_env.sh), send an MCP
#      `initialize` request and pass if the reply carries a "result".
# A pass fixes the repo, not a running Claude session: one that already lost the server
# still needs `/mcp` to reconnect. Prints one line per server; exits 1 if any failed.

emulate -L zsh
HERE="${0:A:h}"
CONFIG="${CLAUDE_CONFIG:-$HOME/.claude.json}"
ENV_FILE="$HOME/.fat_zebra_env.sh"
INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"mcp-smoke","version":"0"}}}'
export MISE_AUTO_INSTALL=false MISE_NOT_FOUND_AUTO_INSTALL=false

failed=0
while IFS=$'\t' read -r name dir; do
  [[ -n "$name" ]] || continue
  note=""
  if [[ -f "$dir/Gemfile" ]]; then
    if ! ( cd "$dir" && bundle check ) >/dev/null 2>&1; then
      if ( cd "$dir" && bundle install ) >/dev/null 2>&1; then note=" (ran bundle install)"
      else print -r -- "  $name: FAIL, bundle install failed in $dir"; failed=1; continue; fi
    fi
  fi

  cmd=$(jq -r --arg n "$name" '.mcpServers[$n] | [.command] + (.args // []) | map(@sh) | join(" ")' "$CONFIG")
  envs=$(jq -r --arg n "$name" '.mcpServers[$n].env // {} | to_entries[] | "\(.key)=\(.value)"' "$CONFIG")
  reply=$(print -r -- "$INIT" | timeout 30 env -i HOME="$HOME" /bin/zsh -fc '
      [[ -f "$1" ]] && source "$1" >/dev/null 2>&1
      while IFS= read -r kv; do [[ -n "$kv" ]] && export "${kv%%=*}=${(e)kv#*=}"; done <<< "$2"
      eval "exec $3"' smoke "$ENV_FILE" "$envs" "$cmd" 2>/dev/null | head -1)
  if [[ "$reply" == *'"result"'* ]]; then
    print -r -- "  $name: ok, ruby $( cd "$dir" && mise current ruby 2>/dev/null )$note"
  else
    print -r -- "  $name: FAIL, no initialize result from $dir$note"; failed=1
  fi
done < <("$HERE/mcp-server-dirs.zsh")
exit $failed
