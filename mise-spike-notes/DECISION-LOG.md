# Decision log — asdf → mise spike

Key design decisions on branch `spike/mise-migration` and why. Companion to
[MIGRATION.md](./MIGRATION.md). Newest context at top of each entry; each
decision states the choice, the alternative, and the rationale.

---

## 1. Split activation: shims on PATH for non-interactive, `activate` for interactive

**Decision.** Two coordinated changes, following mise's recommended split:
- `z_asdf.zsh` → `z_mise.zsh` with body `eval "$(mise activate zsh)"` (interactive
  zsh). Kept the `z_*` name so it sorts in the same block and still lands before
  `z_gup.zsh`, preserving load order. `bashrc` got the bash equivalent.
- `.zshenv` and `claude-env` keep the **shims dir on PATH** (swapping
  `$ASDF_DATA_DIR/shims` → `$XDG_DATA_HOME/mise/shims`).

**Why.** Non-interactive zsh reads `.zshenv` but never `.zshrc`, so activation
alone wouldn't resolve `ruby`/`node` for scripts, cron, or spawned shells —
exactly why asdf had the shims line there. `mise activate` handles interactive
shells and re-asserts its managed paths after anything that clobbers PATH (the
original reason the old asdf line re-prepended shims). Using both is mise's
documented approach, not a workaround.

**Detail confirmed empirically.** The real mise shims dir is
`/Users/james.ferguson/.local/share/mise/shims` (= `$XDG_DATA_HOME/mise/shims`),
verified to exist on the machine.

**Left optional.** Appending zsh completions (`eval "$(mise completion zsh)"`) —
`mise activate` doesn't load them, but it covers command resolution, so
completions are a nice-to-have, not required for the cutover.

---

## 2. Keep `z_asdf.zsh` as a no-op stub, don't delete it in the spike

**Decision.** `z_asdf.zsh` becomes a commented no-op that points at
`z_mise.zsh`, rather than being removed.

**Why.** Keeps the diff reviewable (you can see exactly what the old PATH hack
did and that mise now covers it) and makes the branch reversible without
resurrecting a deleted file. The comment says it's deletable after cutover, so
it's not permanent cruft.

---

## 3. `legacy_version_file = false` in `config.toml` is load-bearing

**Decision.** Ship `dot_config/mise/config.toml` with
`legacy_version_file = false`, the equivalent of the old
`~/.config/asdf/asdfrc` `legacy_version_file = no`.

**Why.** mise defaults this to `true` — the **opposite** of asdf — so out of the
box mise would start honouring `.ruby-version`/`.nvmrc`/`.python-version`.
Setting it false preserves "read only `.tool-versions`/`mise.toml`". Without it,
resolution behaviour changes silently across every repo.

**Version constraint.** Newer mise renames the key to `idiomatic_version_file`.
The installed mise (`2026.7.11`) **errors** on that spelling, so the branch keeps
`legacy_version_file` until mise is upgraded. Documented inline in the toml so
the next person doesn't "fix" it to the new name prematurely.

**Knock-on.** Because `.ruby-version`-only repos now silently fall to the global
ruby, `fix-ruby-pins.zsh` was written to make `.tool-versions` authoritative in
every ruby repo (create one from `.ruby-version` where missing, bump uninstalled
pins, sync the two files). Decision 3 is why decision 7's script exists.

---

## 4. Reinstall runtimes rather than migrate asdf's installs

**Decision.** Accept that cutover requires `mise install` to recompile every
runtime; don't try to point mise at asdf's `~/.local/share/asdf/installs`.

**Why.** mise builds its own installs from source and doesn't read asdf's tree.
There's no supported "adopt asdf's compiled rubies" path worth the fragility.
The cost (compile time once) is one-directional: the rollback path keeps asdf's
installs intact, so going *back* needs no recompile. Called out as the top
gotcha so it isn't a surprise mid-cutover.

---

## 5. VS Code: pin `rubyLsp.rubyVersionManager` to mise (explicit over auto)

**Decision.** Add `"rubyLsp.rubyVersionManager": { "identifier": "mise" }` to the
user-global settings — the one load-bearing VS Code change. Object form (what
current Ruby LSP expects); string `"mise"` for older extensions.

**Why.** The key was **unset** under asdf, so Ruby LSP used `"auto"` and found
ruby through whatever shims were on PATH. That was fragile specifically because
GUI-launched VS Code doesn't inherit the interactive shell's PATH — it depended
on `set-gui-path.plist` injecting a live shims dir *and* auto-detection guessing
right. Pinning `mise` makes LSP resolve the repo's `.tool-versions` ruby
directly. `solargraph.*` paths point at the XDG *system* gem bin (not
asdf/mise-managed) and were left byte-for-byte.

**Related, deferred.** `set-gui-path.plist` still points at the asdf shims dir on
this branch; the plist swap is a full-migration step, not part of the settings
file. Kept separate because the plist can't ride the dotfiles apply loop and the
settings copy is a distinct concern.

---

## 6. Version-control the VS Code settings as a plain `vscode/` dir + explicit symlink

**Decision.** Track the user-global settings under `vscode/` (not `dot_`-prefixed)
and apply via one hand-written symlink, documented in `vscode/README.md`.

**Why.** The live file lives at `~/Library/Application Support/Code/User/` — a
path with spaces and capitals, outside `~/.config`. Neither `install.sh`'s named
symlinks nor its `dot_config/*` loop ever touched it, and chezmoi's `dot_` source
encoding can't round-trip that path. Naming it `vscode/` (no `dot_` prefix)
guarantees no apply step picks it up by accident. The copy is also sanitized —
`snyk.*`, `atlascode.jira.*`, and `github.copilot.preferredAccount` stripped as
account/org/client-identifying.

---

## 7. Port the nightly scripts to mise commands, encoding two precedence traps

**Decision.** New `nightly-skill-mise/` scripts (`system-update.zsh`,
`repo-sweep.zsh`, `fix-ruby-pins.zsh`, `ruby-unused.zsh`, `brew-ready.zsh`)
mirror `brew_refresh.zsh` but non-interactive, with all asdf commands translated.

**Why / traps encoded.**
- **Pin with `mise use --path ~/.tool-versions`, not `mise use -g`.**
  `~/.tool-versions` overrides `~/.config/mise/config.toml` in precedence, so a
  global write would be silently ignored whenever a `~/.tool-versions` entry
  exists. Both `system-update.zsh` and `brew_refresh.zsh` use `--path`.
- **Guard `mise plugins update`.** Core tools (ruby/node/python/go) have no git
  plugin, so `plugins update` only applies to asdf/vfox-backed tools. Scripts
  no-op cleanly when no plugins are installed instead of erroring.
- **`mise outdated --bump --json`** replaces `asdf latest --all`: keys tools by
  canonical name with a `bump` field (version string when an upgrade exists,
  else null). Reduced to `<tool>\t<bump>` lines. Note the canonical key (e.g.
  `node`) differs from the `.tool-versions` line (`nodejs`) — mise rewrites the
  matching line in place.
- **Column shift.** `mise ls ruby --installed` puts the version in column 2
  (`awk '{print $2}'`), unlike asdf's `sed 's/[* ]//g'`.

---

## 8. Comment-only touch on `mcp-install.sh`; behaviour unchanged

**Decision.** Only update the comment (asdf → mise) that explains launching the
New Relic MCP via `sh -c "cd $repo && exec …"`.

**Why.** The mechanism is version-manager-agnostic: it `cd`s into the repo so the
active manager (asdf then, mise now) picks the repo's pinned ruby and bundler
finds the right Gemfile. Nothing functional changes, but the comment would
mislead if left saying "asdf".

---

## 9. Spike stays on its branch; master + live env remain asdf

**Decision.** All of the above lives on `spike/mise-migration`. `master` and the
running machine keep asdf; both managers are installed side by side during the
trial.

**Why.** Lets mise be exercised (trial steps in MIGRATION.md run mise in one
shell without touching asdf) before any irreversible step. asdf isn't uninstalled
until the final verify passes, keeping [Rollback](./MIGRATION.md#rollback) a
no-recompile path the whole time.

---

## Verify pass

A syntax check ran over every `dot_zshrc/includes/*.zsh` include on the branch
(the touched `z_mise.zsh`, `z_gup.zsh`, `brew_refresh.zsh` plus all untouched
neighbours) — **all parsed OK**, so the mise edits didn't break shell sourcing.
This is a syntax gate, not a behavioural test; the behavioural verification is
the full-migration `mise doctor` / `which -a` / repo-boot checks in MIGRATION.md.

## opensearch pin — DROP it (resolved 2026-07-22)

**Decision:** remove `opensearch <ver>` from `.tool-versions`. Do NOT register an
asdf-opensearch plugin under mise.

**Why it's safe (evidence gathered on this machine):**
- The local server CRM's request-log pages actually talk to is **Homebrew
  `opensearch@1` (running v1.3.20, cluster `opensearch_homebrew`, Java 11)**,
  listening on `127.0.0.1:9200`, booted by the launch agents
  `homebrew.mxcl.opensearch@1.plist` + `com.fatzebra.opensearch-java11.plist`.
  This is 100% Homebrew-managed and independent of asdf/mise.
- CRM specs connect to `ENV['ELASTICSEARCH_URL'] || http://localhost:9200`
  (rails_helper) — i.e. the brew server above. Recent crm commits also stub ES
  indexing in specs by default (#455).
- The asdf `opensearch` installs (2.15/3.2/3.6/3.7) are **orphaned**: nothing
  boots them — no Procfile/dev script invokes the bare `opensearch` shim, and the
  launch agents use the brew binary. They were leftovers from trialing newer
  OpenSearch versions locally (the AP-3454 "support OpenSearch2" effort).
- So dropping the pin breaks neither `bundle`/specs (they use :9200 = brew@1) nor
  server boot (brew + launch agent, untouched). It also silences mise's per-shell
  `opensearch not in registry` WARN with no plugin needed.

**Context (not blocking):** the platform team is standing up a managed
`fz-opensearch-workspace` in prod (deploys/PRs ~2026-07-20/21), and CRM has an
in-flight branch migrating from the `elasticsearch-*` gems to a `fatzebra_opensearch`
gem. Neither changes the local picture: dev still hits :9200 (brew opensearch@1).

**Optional cleanup (user's call, not done here):** `asdf uninstall opensearch 2.15.0 3.2.0 3.6.0 3.7.0`
to reclaim disk, and drop the same line from the live master `dot_tool_versions/tool-versions`.
