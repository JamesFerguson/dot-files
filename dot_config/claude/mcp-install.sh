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
# Put any non-Fat-Zebra machine-local secret here, e.g.:
#   export SOME_API_KEY="..."
#
# Fat Zebra secrets do NOT go here:
#   - NEW_RELIC_API_KEY (used by the new-relic MCP) lives in ~/.fat_zebra_env.sh
#     alongside the other FZ creds; .zshenv sources it on work laptops.
#   - Rollbar tokens live in ~/.rollbar-mcp.json (one per project).
EOF
  chmod 600 "$SECRETS_FILE"
  echo "mcp-install: wrote secrets template $SECRETS_FILE."
fi

# ── pganalyze (http, OAuth) ─────────────────────────────────────────────────────

if already_registered pganalyze; then
  echo "mcp-install: pganalyze already registered — skipping."
else
  echo "mcp-install: adding pganalyze (http)..."
  claude mcp add --scope user --transport http pganalyze https://app.pganalyze.com/mcp \
    && echo "mcp-install: run 'claude mcp login pganalyze' to complete OAuth."
fi

# ── rollbar (CLIs, not MCP) ─────────────────────────────────────────────────────
# Rollbar is queried via two CLIs now, NOT an MCP. The @rollbar/mcp-server was very 
# limited (no way to page/search occurrences or run RQL). CLI tools are:
#   • robzolkos `rollbar` — installed via Brewfile (robzolkos/tap/rollbar-cli).
#       List/triage/resolve items, browse occurrences. Reads ROLLBAR_ACCESS_TOKEN per call.
#   • delexw rollbar-cli  — run via `npx -y @delexw/rollbar-cli@latest` (its npm bin is
#       ALSO named `rollbar`, so it's deliberately never installed globally — that would
#       collide with the brew binary). Full API + RQL. Reads tokens from the OS keychain.
# Per-project read tokens (crm/gw/jw) still live in ~/.rollbar-mcp.json (uncommitted, 600);
# this seeds the delexw keychain from it so `rollbar --project <name>` just works.

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

if grep -q 'PASTE_' "$ROLLBAR_CONFIG" 2>/dev/null; then
  echo "mcp-install: ⚠ $ROLLBAR_CONFIG still has placeholder tokens — fill them, then re-run to seed the delexw keychain."
elif command -v npx >/dev/null 2>&1; then
  echo "mcp-install: seeding delexw keychain from $ROLLBAR_CONFIG..."
  python3 - "$ROLLBAR_CONFIG" <<'PY' | while read -r name token; do
import json, sys
for p in json.load(open(sys.argv[1]))["projects"]:
    if "PASTE_" not in p["token"]:
        print(p["name"], p["token"])
PY
    npx -y @delexw/rollbar-cli@latest config set-token "$name" "$token" >/dev/null 2>&1 \
      && echo "mcp-install:   keychain token set for $name" \
      || echo "mcp-install:   ⚠ failed to set keychain token for $name"
  done
  npx -y @delexw/rollbar-cli@latest config set-default jw >/dev/null 2>&1
else
  echo "mcp-install: npx not found — skipping delexw keychain seed (install Node 20+)."
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
  # Launch via `sh -c "cd $repo_dir && exec ..."` so asdf picks the repo's pinned
  # Ruby and bundler finds its Gemfile. Claude starts MCP servers from the current
  # session's cwd otherwise, which uses the global Ruby and dies with
  # Bundler::GemNotFound if that differs from the repo's pinned version.
  echo "mcp-install: adding new-relic (stdio)..."
  claude mcp add --scope user new-relic \
    -e 'NEW_RELIC_API_KEY=${NEW_RELIC_API_KEY}' \
    -- sh -c "cd $repo_dir && exec bin/fz_newrelic_mcp"

  # The key is an FZ account secret, so it lives in ~/.fat_zebra_env.sh (sourced by
  # .zshenv on work laptops) alongside the other FZ creds — not in the sidecar.
  if ! grep -qE '^[[:space:]]*(export[[:space:]]+)?NEW_RELIC_API_KEY=' "$HOME/.fat_zebra_env.sh" 2>/dev/null; then
    echo "mcp-install: ⚠ NEW_RELIC_API_KEY not found in ~/.fat_zebra_env.sh — add it there; new-relic won't work until you do."
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
