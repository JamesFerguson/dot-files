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

# ── Claude settings: bake MCP tokens into settings.json `env` (option B) ────────
# The token-env MCP servers (new-relic, buildkite) read their key from the process env.
# Rather than rely on ${VAR} expansion from the launching shell — empty in headless / cron /
# launchd / `claude -p` — write the literal values into ~/.claude/settings.json `env`, which
# Claude reads from disk in EVERY context and injects into every subprocess (MCP servers AND
# Bash tool calls). So non-interactive "just works", and scripts Claude runs can hit the NR/BK
# APIs directly. ~/.fat_zebra_env.sh stays the single hand-edited source; this only propagates
# the current values — re-run after rotating a token. (Trade-off: the tokens are now in the env
# of every command Claude spawns, not just the two MCPs.)
[[ -f "$HOME/.fat_zebra_env.sh" ]] && source "$HOME/.fat_zebra_env.sh"
if [[ -n "$NEW_RELIC_API_KEY" || -n "$BUILDKITE_API_TOKEN" ]]; then
  echo "mcp-install: baking MCP tokens into ~/.claude/settings.json env..."
  python3 - <<'PY'
import json, os
p = os.path.expanduser("~/.claude/settings.json")
d = json.load(open(p)) if os.path.exists(p) else {}
env = d.setdefault("env", {})
for k in ("NEW_RELIC_API_KEY", "BUILDKITE_API_TOKEN"):
    v = os.environ.get(k)
    if v:
        env[k] = v
os.makedirs(os.path.dirname(p), exist_ok=True)
json.dump(d, open(p, "w"), indent=2)
os.chmod(p, 0o600)
print("mcp-install:   settings.json env now has:", ", ".join(env.keys()))
PY
else
  echo "mcp-install: ⚠ NEW_RELIC_API_KEY / BUILDKITE_API_TOKEN not in env — not baked. Fill ~/.fat_zebra_env.sh and re-run."
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
# limited (no way to page/search occurrences or run RQL). Both CLIs' upstream binary is
# named `rollbar`, so each is installed OUT of PATH and symlinked into ~/bin under a
# unique name — no collision, no npx cold-start:
#   • rollbar-rz -> robzolkos (brew robzolkos/tap/rollbar-cli). List/triage/resolve items,
#       browse occurrences. Reads ROLLBAR_ACCESS_TOKEN per call.
#   • rollbar-dx -> delexw (npm-installed under ~/.local/rollbar-dx). Full API + RQL.
#       Reads per-project tokens from the OS keychain.
# Per-project read tokens (crm/gw/jw) live in ~/.rollbar-mcp.json (uncommitted, 600); this
# seeds the delexw keychain from it so `rollbar-dx --project <name>` just works.
# See the `rollbar` skill (~/.claude/skills/rollbar) for usage.

ROLLBAR_DX_PREFIX="$HOME/.local/rollbar-dx"
mkdir -p "$HOME/bin"

# rollbar-rz: unique-name symlink to the brew (robzolkos) binary.
if [[ -x "$(brew --prefix 2>/dev/null)/bin/rollbar" ]]; then
  ln -sf "$(brew --prefix)/bin/rollbar" "$HOME/bin/rollbar-rz"
  echo "mcp-install: linked rollbar-rz -> brew rollbar (robzolkos)."
else
  echo "mcp-install: ⚠ brew 'rollbar' not found — run 'brew bundle' first, then re-run (rollbar-rz not linked)."
fi

# rollbar-dx: local (non-global) delexw install + unique-name symlink.
if command -v npm >/dev/null 2>&1; then
  echo "mcp-install: installing delexw locally under $ROLLBAR_DX_PREFIX..."
  npm install --silent --prefix "$ROLLBAR_DX_PREFIX" @delexw/rollbar-cli@latest >/dev/null 2>&1 \
    && ln -sf "$ROLLBAR_DX_PREFIX/node_modules/.bin/rollbar" "$HOME/bin/rollbar-dx" \
    && echo "mcp-install: linked rollbar-dx -> delexw." \
    || echo "mcp-install: ⚠ delexw install failed (need Node 20+) — rollbar-dx not linked."
else
  echo "mcp-install: ⚠ npm not found — skipping delexw (install Node 20+); rollbar-dx not linked."
fi

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

# Seed the delexw keychain from the token file (idempotent).
if grep -q 'PASTE_' "$ROLLBAR_CONFIG" 2>/dev/null; then
  echo "mcp-install: ⚠ $ROLLBAR_CONFIG still has placeholder tokens — fill them, then re-run to seed the delexw keychain."
elif [[ -x "$HOME/bin/rollbar-dx" ]]; then
  echo "mcp-install: seeding delexw keychain from $ROLLBAR_CONFIG..."
  python3 - "$ROLLBAR_CONFIG" <<'PY' | while read -r name token; do
import json, sys
for p in json.load(open(sys.argv[1]))["projects"]:
    if "PASTE_" not in p["token"]:
        print(p["name"], p["token"])
PY
    "$HOME/bin/rollbar-dx" config set-token "$name" "$token" >/dev/null 2>&1 \
      && echo "mcp-install:   keychain token set for $name" \
      || echo "mcp-install:   ⚠ failed to set keychain token for $name"
  done
  "$HOME/bin/rollbar-dx" config set-default jw >/dev/null 2>&1
fi

# ── buildkite (bk-axi primary CLI + MCP fallback) ───────────────────────────────
# Adopted after evaluating the MCP and several CLIs:
#   • bk-axi (PRIMARY) — agent-shaped wrapper over `bk`: TOON output, and windowed job
#       logs (~4 KB vs ~2 MB raw — keeps the failure, drops the noise). Unpublished, so
#       built from source under ~/.local/bk-axi and symlinked to ~/bin/bk-axi. Wraps `bk`.
#   • buildkite-mcp-server (SECONDARY) — official MCP, registered DEFERRED (loaded on
#       demand via ToolSearch, NOT alwaysLoad) for the ~28 tools bk-axi lacks: clusters/
#       agents, artifacts, annotations, Test Engine, and tail_logs/search_logs on huge logs.
#   • bk — official CLI that bk-axi shells out to.
# Auth: all three read $BUILDKITE_API_TOKEN — a broad READ-ONLY token, SEPARATE from
# $BUILDKITE_TOKEN (which fz/clog/deploy use with minimal scopes). Export it in
# ~/.fat_zebra_env.sh. See the `buildkite` skill (~/.claude/skills/buildkite).

if [[ -z "$BUILDKITE_API_TOKEN" ]]; then
  echo "mcp-install: ⚠ BUILDKITE_API_TOKEN not set — export it in ~/.fat_zebra_env.sh (read-only token); Buildkite tools will fail until then."
fi

if command -v brew >/dev/null 2>&1; then
  brew tap buildkite/buildkite >/dev/null 2>&1
  brew trust buildkite/buildkite >/dev/null 2>&1 || true   # newer Homebrew requires trusting this tap's formulae
  command -v bk >/dev/null 2>&1 || { echo "mcp-install: installing bk..."; brew install buildkite/buildkite/bk >/dev/null 2>&1; }
  [[ -x "$(brew --prefix)/bin/buildkite-mcp-server" ]] || { echo "mcp-install: installing buildkite-mcp-server..."; brew install buildkite/buildkite/buildkite-mcp-server >/dev/null 2>&1; }
  # Drop any bk keychain cred so bk uses $BUILDKITE_API_TOKEN silently (no "overriding" warning).
  # bk then needs org-qualified pipelines (`-p org/pipeline`); bk-axi resolves org from the token.
  command -v bk >/dev/null 2>&1 && bk auth logout >/dev/null 2>&1
fi

# bk-axi (primary): unpublished → clone at a PINNED commit + build + symlink under a unique name.
# It's a 0-star from-source dep, so we pin rather than track HEAD. Bump BK_AXI_REF deliberately.
BK_AXI_REF="6e279483f8a085b59591d30ce69784708220ed05"  # 2026-07-08
mkdir -p "$HOME/bin"
if command -v npm >/dev/null 2>&1; then
  [[ -d "$HOME/.local/bk-axi/.git" ]] || git clone --quiet https://github.com/megakid/bk-axi.git "$HOME/.local/bk-axi" >/dev/null 2>&1
  if [[ -d "$HOME/.local/bk-axi/.git" ]]; then
    ( cd "$HOME/.local/bk-axi" && git fetch --quiet origin && git checkout --quiet "$BK_AXI_REF" ) 2>/dev/null
  fi
  if [[ -d "$HOME/.local/bk-axi" ]]; then
    ( cd "$HOME/.local/bk-axi" && npm install --silent >/dev/null 2>&1 && npm run build >/dev/null 2>&1 ) \
      && chmod +x "$HOME/.local/bk-axi/dist/bin/bk-axi.js" \
      && ln -sf "$HOME/.local/bk-axi/dist/bin/bk-axi.js" "$HOME/bin/bk-axi" \
      && echo "mcp-install: linked bk-axi -> ~/.local/bk-axi (built from source)." \
      || echo "mcp-install: ⚠ bk-axi build failed (need Node 20+); bk-axi not linked."
  fi
else
  echo "mcp-install: ⚠ npm not found — skipping bk-axi (install Node 20+)."
fi

# buildkite MCP (secondary): register DEFERRED — no alwaysLoad, so its ~28 tools load on
# demand via ToolSearch instead of sitting in context. Token comes from settings.json env (baked above).
if already_registered buildkite; then
  echo "mcp-install: buildkite MCP already registered — skipping."
elif [[ -x "$(brew --prefix 2>/dev/null)/bin/buildkite-mcp-server" ]]; then
  echo "mcp-install: registering buildkite MCP (deferred)..."
  claude mcp add --scope user buildkite \
    -- "$(brew --prefix)/bin/buildkite-mcp-server" stdio
fi

# ── readme (rdme + @readme/cli CLIs, + ReadMe management MCP) ───────────────────
# FZ's public API docs live in ReadMe at https://docs.fatzebra.com — hand-edited in the
# ReadMe UI (creds in 1Password). The in-repo OpenAPI specs are mostly fossils (gateway
# 2017, jabberwocky 2019); only CRM's crm/docs/*openapi.yaml are current. Tooling:
#   • rdme  (npm 'rdme', v10+ for ReadMe "Refactored" projects) — push/pull docs, sync OpenAPI.
#   • readme (@readme/cli) — lint/validate a git-backed ReadMe project.
#   • readme MCP (http) — ReadMe's management MCP at https://docs.readme.com/mcp (one shared
#       ReadMe-hosted endpoint; the rdme_ key scopes it to our project). Auth `Authorization:
#       Bearer <rdme_ key>` — ReadMe's own documented Claude Code config. Lets Claude search
#       our docs and, with the key, edit pages. NOT docs.fatzebra.com/mcp — that's our project's
#       consumer MCP (exposes the documented FZ API) and 401s here; different tool, revisit later.
# npm's global prefix here (~/.local/share/npm/bin) is OFF PATH, so symlink both bins into
# ~/bin (which is on PATH) — same reason as rollbar-dx.
# Auth: README_API_KEY (from 1Password) in ~/.fat_zebra_env.sh serves all three.
# MCP header caveat: Claude Code bug #51581 means ${VAR} in an http server's headers is NOT
# expanded (the literal string gets sent), so we bake the literal key into the header via
# `claude mcp add --header`. That puts a WRITE-capable key cleartext in ~/.claude.json (600).
# To keep the key only in ~/.fat_zebra_env.sh instead, swap this for an `mcp-remote` stdio
# shim. Rotating the key: `claude mcp remove readme`, then re-run this script.

mkdir -p "$HOME/bin"
if [[ -x "$HOME/bin/rdme" && -x "$HOME/bin/readme" ]]; then
  echo "mcp-install: rdme + @readme/cli already linked in ~/bin — skipping npm install."
elif command -v npm >/dev/null 2>&1; then
  echo "mcp-install: installing rdme + @readme/cli (npm global)..."
  npm install -g rdme @readme/cli >/dev/null 2>&1
  npm_global_bin="$(npm prefix -g 2>/dev/null)/bin"
  for cli in rdme readme; do
    if [[ -x "$npm_global_bin/$cli" ]]; then
      ln -sf "$npm_global_bin/$cli" "$HOME/bin/$cli"
      echo "mcp-install: linked $cli -> $npm_global_bin/$cli"
    else
      echo "mcp-install: ⚠ $cli not found after npm install — not linked."
    fi
  done
else
  echo "mcp-install: ⚠ npm not found — skipping rdme/@readme-cli (install Node 20+)."
fi

if already_registered readme; then
  echo "mcp-install: readme MCP already registered — skipping (run 'claude mcp remove readme' to re-key)."
elif [[ -n "$README_API_KEY" ]]; then
  echo "mcp-install: registering readme MCP (http, Bearer)..."
  claude mcp add --scope user --transport http readme https://docs.readme.com/mcp \
    --header "Authorization: Bearer $README_API_KEY"
else
  echo "mcp-install: ⚠ README_API_KEY not set — readme MCP not registered. Add it to ~/.fat_zebra_env.sh and re-run."
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

  # The key comes from settings.json env (baked above), injected into this server's process.
  # Launch via `sh -c "cd $repo_dir && exec ..."` so mise picks the repo's pinned
  # Ruby and bundler finds its Gemfile. Claude starts MCP servers from the current
  # session's cwd otherwise, which uses the global Ruby and dies with
  # Bundler::GemNotFound if that differs from the repo's pinned version.
  echo "mcp-install: adding new-relic (stdio)..."
  claude mcp add --scope user new-relic \
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
