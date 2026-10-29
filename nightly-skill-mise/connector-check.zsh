#!/bin/zsh
# connector-check.zsh — catch claude.ai connectors, synced plugins and account skills that the
# org turned on since James switched them off. A connector in ~/.claude/settings.json's
# deniedMcpServers never shows in `claude mcp list`, so any claude.ai connector listed here that
# isn't in ALLOWED is new. Prints one line per finding; exits 1 if there are any.

emulate -L zsh
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
# The connectors James uses. Everything else claude.ai offers goes in deniedMcpServers by URL.
ALLOWED=("Claude Docs" "Slack" "Microsoft 365" "Atlassian MCP")

found=0
claude mcp list 2>/dev/null | grep '^claude\.ai ' | while IFS= read -r line; do
  name=${${line#claude.ai }%%: *}
  url=${${line#*: }%% - *}
  (( ${ALLOWED[(Ie)$name]} )) && continue
  print -r -- "  NEW CONNECTOR: claude.ai $name ($url). Deny it with: jq '.deniedMcpServers += [{\"serverUrl\": \"$url\"}]' $SETTINGS"
  found=1
done

claude plugin list 2>/dev/null | awk '/^Synced from claude.ai:/ {s=1} s && /❯/ {p=$2} s && /Status: ✔ enabled/ {print p}' | while IFS= read -r plugin; do
  print -r -- "  SYNCED PLUGIN ENABLED: $plugin. Disable it with: claude plugin disable $plugin (refused if the org marks it required)"
  found=1
done

if [[ $(jq -r '.syncClaudeAiSkills' "$SETTINGS") != false ]]; then
  print -r -- "  ACCOUNT SKILLS SYNCING: syncClaudeAiSkills isn't false in $SETTINGS, so the anthropic-skills:* listing is back"
  found=1
fi

(( found )) && exit 1
print -r -- "  connectors, synced plugins and account skills: nothing new"
