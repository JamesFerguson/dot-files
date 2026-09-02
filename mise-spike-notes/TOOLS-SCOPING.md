# Migrating the other asdf tools to mise — scoping

Ruby is handled (prebuilt binaries via `[settings.ruby] compile = false`). This
scopes the **other** tools pinned in `dot_tool_versions/tool-versions`. Findings
from `mise registry` / `mise ls-remote` on mise `2026.7.11` (2026-08-04). Nothing
here was installed — this is scoping only.

## Per-tool

| Tool (asdf name) | Version | mise backend | Install method | Migrates cleanly? |
|---|---|---|---|---|
| `nodejs` → `node` | 26.5.0 | `core:node` | prebuilt binary | ✅ (asdf alias `nodejs` resolves) |
| `golang` → `go` | 1.26.5 | `core:go` | prebuilt binary | ✅ (asdf alias `golang` resolves) |
| `rust` | 1.97.1 | `core:rust` (rustup) | prebuilt toolchain | ✅ |
| `elixir` | 1.20.2-otp-29 | `core:elixir` | precompiled release | ✅ (needs erlang/OTP 29 present) |
| `awscli` | 2.36.9 | `aqua:aws/aws-cli` | prebuilt binary | ✅ (aqua backend) |
| `kubectl` | 1.36.3 | `aqua:kubernetes/…/kubectl` | prebuilt binary | ✅ (aqua) |
| `terraform` | 1.15.8 | `aqua:hashicorp/terraform` | prebuilt binary | ✅ (aqua) |
| `pnpm` | 11.17.0 | `aqua:pnpm/pnpm` | prebuilt binary | ✅ (aqua) |
| `yarn` | 1.22.22 | default backend | prebuilt | ✅ — classic 1.22.22 resolves (Berry-vs-classic worry was unfounded) |
| `erlang` | 29.0.4 | `core:erlang` (kerl) | **source compile** | ⚠️ compiles — see below |
| `python` | **3.14.6t** | `core:python` (python-build-standalone) | prebuilt standalone | ⚠️ free-threaded `t` variant — see below |
| `ruby` | 4.0.6 | `core:ruby` | prebuilt (compile=false) | ✅ done — being pre-installed |

## The two things that need attention

### 1. erlang — the one source compile (the new "slow step")
`core:erlang` builds OTP from source via kerl; there's no prebuilt. So erlang is
now what ruby *used* to be: a multi-minute compile that needs build deps
(openssl, ncurses, autoconf; wxwidgets only if you want `observer`). Two
consequences:
- Budget ~5–15 min for the erlang build during cutover, and make sure the brew
  build deps are present first (they almost certainly are, since asdf built
  erlang 29.0.4 the same way).
- `elixir` is a fast precompiled release but is **useless without erlang/OTP 29**,
  so erlang must succeed first. If a scripted cutover ever runs unattended, this
  is the step to guard with abort-on-error (a failed erlang build shouldn't be
  silent).
- Worth checking before cutover whether you still actively need erlang/elixir
  locally — if not, dropping the pins (like opensearch) removes the only compile.

### 2. python 3.14.6t — free-threaded variant
The global pin is `python 3.14.6t` (the `t` = free-threaded / no-GIL build).
`mise ls-remote python` lists `3.14.6` but **not** a `3.14.6t`, so the pin may not
resolve as-is under mise's python-build-standalone. Before cutover, decide one of:
- confirm the mise syntax for a free-threaded standalone build (python-build-standalone
  does publish freethreaded builds — the request form may differ from asdf's `t` suffix), or
- if you don't actually need free-threaded locally, change the pin to plain `3.14.6`.
Don't let a bare `mise install` silently fall back to the wrong interpreter.

## Non-issues (confirmed)
- **asdf legacy names work:** `nodejs`/`golang` resolve to `node`/`go` — no need to
  rewrite `.tool-versions`.
- **aqua backends** (awscli/kubectl/terraform/pnpm) install prebuilt binaries; mise
  resolves them without a git plugin. First install may need to accept the aqua
  backend, but it's automatic in normal use.
- **No conflict with asdf:** mise installs under `~/.local/share/mise/installs`,
  asdf under `~/.local/share/asdf/installs` — fully separate trees + shims.

## Suggested cutover order for tools (fast → slow)
Prebuilt binaries first (seconds each): node, go, rust, awscli, kubectl,
terraform, pnpm, yarn, elixir-release. Then the two that need care: **python**
(resolve the `t` question) and **erlang** (the one compile — do it last, watch it).
A bare `mise install` after the dotfiles are applied does all of these; the two
⚠️ rows are the only ones that can surprise you.

## Resolution — pre-install run (2026-08-04, supersedes the ⚠️ predictions above)

All tools pre-installed under mise (isolated tree; asdf untouched) and verified:

- **python `3.14.6t` — KEPT free-threaded.** No *precompiled* 3.14.6t exists, but mise
  falls back to python-build and compiles it, and the result is genuinely free-threaded
  (`sys._is_gil_enabled()` → False, verified). So the pin stays `3.14.6t` — it just
  compiles (~a few min) instead of downloading. No GIL downgrade.
- **erlang `29.0.4` — installed fine and fast** (seconds, not the multi-minute kerl
  compile feared). `erl` runs (OTP 29); `elixir 1.20.2-otp-29` runs against it.
- **Everything else** (awscli, go, kubectl, node ×several, pnpm, rust, terraform, yarn)
  installed as prebuilt binaries in seconds.
- **elasticsearch (2.4.6 / 7.1.0) — NOT installed.** Non-core (needs a backend) and almost
  certainly orphaned like opensearch (local ES is the brew server on :9200). Verify, then
  likely drop the pins from the repos that carry them.

### Two operational gotchas found
1. **`mise exec` auto-installs missing tools** for the resolved config chain — running it in
   a repo before cutover pulled in the whole global toolset. Harmless (isolated), but expect
   mise to install-on-demand.
2. **`legacy_version_file = false` (our config) ignores `.nvmrc` / `.node-version` /
   `.python-version`.** Repos that pin node/python *only* via those files (not
   `.tool-versions`) fall back to the global version under mise. `fix-ruby-pins.zsh` handles
   this for ruby; node/python have no equivalent. Before cutover, add `.tool-versions`
   entries to such repos or accept the global fallback. (The stray `node 20.1.0` mise pulled
   in came from exactly such an `.nvmrc`.)

### Version-pin drift fixed
master's committed `tool-versions` lagged the live working file on awscli/erlang/kubectl/pnpm;
the branch now carries the versions actually in use, so cutover won't downgrade them.
