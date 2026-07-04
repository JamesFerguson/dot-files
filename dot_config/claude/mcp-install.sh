#!/bin/zsh
#
# Register Claude Code MCP servers from dot-files.
#
# Idempotent: skips any server already registered, so it's safe to re-run.
# Called from install.sh, but also runnable on its own:
#   ~/.config/claude/mcp-install.sh
#
# What it does NOT do:
#   - claude.ai connectors (Atlassian, Slack, etc.) come from your Claude
#     account over OAuth — nothing to install here, just log in.
#   - OAuth logins for http servers can't be scripted; we print the command
#     to run by hand (e.g. `claude mcp login pganalyze`).
#
# Secrets: the New Relic key is registered as ${NEW_RELIC_API_KEY} and expanded
# by Claude Code at launch. The real key lives in the uncommitted
# ~/.claude-env.local (never in this repo). See the template this script writes.

# ── setup ────────────────────────────────────────────────────────────────────

# Work out CODE_DIR the same way .zshenv does, in case we're run standalone
# (install.sh / a login shell will already have these exported).
if [[ "$(hostname)" == *"fz-"* ]]; then
  ON_WORK_LAPTOP=1
  : "${CODE_DIR:=$HOME/code}"
else
  ON_WORK_LAPTOP=0
  : "${CODE_DIR:=$HOME/codez}"
fi

SECRETS_FILE="$HOME/.claude-env.local"
ROLLBAR_CONFIG="$HOME/.rollbar-mcp.json"  # multi-project tokens, uncommitted

if ! command -v claude >/dev/null 2>&1; then
  echo "mcp-install: 'claude' CLI not on PATH — skipping MCP setup." >&2
  return 0 2>/dev/null || exit 0
fi

# already_registered <name> — true if the server exists in any scope
already_registered() {
  claude mcp get "$1" >/dev/null 2>&1
}

# ── uncommitted secrets sidecar ────────────────────────────────────────────────

if [[ ! -f "$SECRETS_FILE" ]]; then
  cat > "$SECRETS_FILE" <<'EOF'
#!/bin/sh
# Machine-local secrets for Claude / MCP servers. NOT committed to dot-files.
# Sourced by ~/.claude-env and ~/.zshenv (via .config/zsh/.zshenv).
#
# Fill in real values below, then restart Claude Code.

# New Relic user API key (https://one.newrelic.com > API keys).
# Used by the `new-relic` MCP server.
# export NEW_RELIC_API_KEY="***REMOVED***"

# Rollbar tokens are NOT here — they live in ~/.rollbar-mcp.json (one per project).
EOF
  chmod 600 "$SECRETS_FILE"
  echo "mcp-install: wrote secrets template $SECRETS_FILE (fill in NEW_RELIC_API_KEY)."
fi

# ── pganalyze (http, OAuth) ─────────────────────────────────────────────────────

if already_registered pganalyze; then
  echo "mcp-install: pganalyze already registered — skipping."
else
  echo "mcp-install: adding pganalyze (http)..."
  claude mcp add --scope user --transport http pganalyze https://app.pganalyze.com/mcp \
    && echo "mcp-install: run 'claude mcp login pganalyze' to complete OAuth."
fi

# ── rollbar (stdio, public npm package — needs Node 20+) ────────────────────────
# Multi-project: one Rollbar project per app (crm/gw/jw), each with its own token.
# Tokens are inline in ~/.rollbar-mcp.json (the server has no env-var interpolation),
# so that file stays uncommitted with 600 perms — like the secrets sidecar.
# Pick a project in a tool call with the `project` arg (matches "name" below).

if [[ ! -f "$ROLLBAR_CONFIG" ]]; then
  cat > "$ROLLBAR_CONFIG" <<'EOF'
{
  "projects": [
    { "name": "crm", "token": "PASTE_CRM_READ_TOKEN" },
    { "name": "gw",  "token": "PASTE_GW_READ_TOKEN" },
    { "name": "jw",  "token": "PASTE_JW_READ_TOKEN" }
  ]
}
EOF
  chmod 600 "$ROLLBAR_CONFIG"
  echo "mcp-install: wrote $ROLLBAR_CONFIG (paste a per-project read token into each)."
fi

if already_registered rollbar; then
  echo "mcp-install: rollbar already registered — skipping."
else
  echo "mcp-install: adding rollbar (stdio via npx, multi-project config)..."
  claude mcp add --scope user rollbar \
    -e 'ROLLBAR_CONFIG_FILE=${HOME}/.rollbar-mcp.json' \
    -- npx -y @rollbar/mcp-server@latest
fi

if grep -q 'PASTE_' "$ROLLBAR_CONFIG" 2>/dev/null; then
  echo "mcp-install: ⚠ $ROLLBAR_CONFIG still has placeholder tokens — rollbar tools will fail until filled."
fi

# ── new-relic (stdio, in-house Ruby server — work laptop only) ──────────────────

install_new_relic() {
  local repo_dir="$CODE_DIR/fz-newrelic-mcp"
  local bin="$repo_dir/bin/fz_newrelic_mcp"

  # Clone if missing.
  if [[ ! -d "$repo_dir/.git" ]]; then
    echo "mcp-install: cloning fz-newrelic-mcp into $repo_dir..."
    if command -v gh >/dev/null 2>&1; then
      gh repo clone fatzebra/fz-newrelic-mcp "$repo_dir" || {
        echo "mcp-install: clone failed — skipping new-relic." >&2; return 1; }
    else
      git clone git@github.com:fatzebra/fz-newrelic-mcp.git "$repo_dir" || {
        echo "mcp-install: clone failed — skipping new-relic." >&2; return 1; }
    fi
  fi

  # Build = install gems (the bin/ script is committed; it just needs its bundle).
  if [[ ! -x "$bin" ]]; then
    echo "mcp-install: $bin missing/not executable — skipping new-relic." >&2
    return 1
  fi
  echo "mcp-install: bundle install for fz-newrelic-mcp..."
  ( cd "$repo_dir" && bundle install ) || {
    echo "mcp-install: bundle install failed (check Ruby version) — skipping new-relic." >&2
    return 1
  }

  # Register with the key as a runtime-expanded var, not the literal secret.
  echo "mcp-install: adding new-relic (stdio)..."
  claude mcp add --scope user new-relic \
    -e 'NEW_RELIC_API_KEY=${NEW_RELIC_API_KEY}' \
    -- "$bin"

  if ! grep -q '^[[:space:]]*export NEW_RELIC_API_KEY=' "$SECRETS_FILE" 2>/dev/null; then
    echo "mcp-install: ⚠ NEW_RELIC_API_KEY not set in $SECRETS_FILE — new-relic won't work until you add it."
  fi
}

if already_registered new-relic; then
  echo "mcp-install: new-relic already registered — skipping."
elif [[ "$ON_WORK_LAPTOP" -eq 1 ]]; then
  install_new_relic
else
  echo "mcp-install: not a Fat Zebra laptop — skipping new-relic (internal tool)."
fi

echo "mcp-install: done. Verify with 'claude mcp list'."
