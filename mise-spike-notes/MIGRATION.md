# asdf → mise migration guide

Grounded in the `spike/mise-migration` branch of this dot-files repo. This spike
swaps the runtime version manager from **asdf** to **mise** and nothing else.
`master` and the live machine environment stay on asdf until you deliberately
cut over — see [Scope](#scope--this-is-a-spike) and [Rollback](#rollback).

mise reads the same `.tool-versions` files asdf did, so per-repo pins keep
working. The moving parts are: which binary is on PATH, how it activates in each
shell, how non-core tools (opensearch/elasticsearch) get a backend, and where
VS Code's Ruby LSP looks for a runtime.

---

## Scope — this is a spike

- Everything below lives on branch **`spike/mise-migration`**.
- `master` and the running machine are **still asdf**. Both `mise` and `asdf`
  are installed side by side right now (`/opt/homebrew/bin/{mise,asdf}`), and
  both shim dirs exist (`~/.local/share/{mise,asdf}/shims`). Nothing is
  destroyed by trying mise.
- The trial steps let you run mise in one shell without touching asdf. The full
  migration steps are what you run once you've decided to commit.

---

## What changed, per file

| File | Change |
|---|---|
| `dot_config/brew/Brewfile` | `brew 'asdf'` → `brew 'mise'`. |
| `dot_zshrc/includes/z_asdf.zsh` | Old body prepended `$ASDF_DATA_DIR/shims` to PATH. Now a no-op stub pointing at `z_mise.zsh`; deletable after cutover. |
| `dot_zshrc/includes/z_mise.zsh` **(new)** | Interactive-zsh activation: `eval "$(mise activate zsh)"`. Sorts in the same `z_*` block, before `z_gup.zsh`, so ordering is preserved. |
| `dot_config/zsh/.zshenv` | Dropped `ASDF_CONFIG_FILE` / `ASDF_DATA_DIR` exports. In the big PATH assignment swapped `$ASDF_DATA_DIR/shims` → `$XDG_DATA_HOME/mise/shims` so runtimes resolve in **non-interactive** zsh (reads `.zshenv`, never `.zshrc`). |
| `dot_config/zsh/.zshrc` | `bashcompinit` comment updated — kept for bash-style completion files, but mise uses native zsh completions via `mise activate`. |
| `dot_bashrc/bashrc` | Dropped the ASDF exports + the `asdf.sh` / `asdf.bash` sourcing block. PATH shims dir swapped to mise. Added `eval "$(mise activate bash)"`. |
| `dot_claude-env/claude-env` | Dropped ASDF exports; PATH shims dir swapped to mise. (This is the env Claude Code / non-login tooling reads.) |
| `dot_config/mise/config.toml` **(new)** | `legacy_version_file = false` — the asdf `legacy_version_file = no` equivalent. See gotchas: mise defaults this the **opposite** way. |
| `dot_zshrc/includes/z_gup.zsh` | `asdf current ruby` → `mise current ruby` (trace line in the `gup` git-update fn). |
| `dot_zshrc/includes/brew_refresh.zsh` | Ruby-version listing, uninstall, rubygems update loop, and outdated-tool prompt all rewritten from asdf commands to mise equivalents. See [command map](#command-cheat-sheet). |
| `dot_config/claude/mcp-install.sh` | Comment only — "asdf picks the repo's pinned Ruby" → "mise picks…". Behaviour (launch MCP via `sh -c "cd $repo && exec …"`) unchanged. |
| `vscode/settings.json` + `vscode/README.md` **(new)** | Adds `"rubyLsp.rubyVersionManager": { "identifier": "mise" }`. See [VS Code](#vs-code-ruby-lsp). |
| `nightly-skill-mise/` **(new)** | mise ports of the nightly maintenance scripts (`system-update.zsh`, `repo-sweep.zsh`, `fix-ruby-pins.zsh`, `ruby-unused.zsh`, `brew-ready.zsh`). |

**Not yet changed (do it during full migration):** `plists/set-gui-path.plist`
still points GUI PATH at `~/.local/share/asdf/shims`. It must swap to
`~/.local/share/mise/shims` — see [VS Code](#vs-code-ruby-lsp) for why the GUI
PATH matters.

---

## Quick-start: trial mise without committing

Try mise in a single shell. asdf, your rc files, and PATH stay untouched.

```sh
brew install mise                       # installs alongside asdf, no conflict

# In a throwaway shell, activate mise for this session only:
eval "$(mise activate zsh)"             # or: mise activate bash

# Preserve asdf's version-file behaviour for the test (see gotcha #3):
mkdir -p ~/.config/mise
printf '[settings]\nlegacy_version_file = false\n' > ~/.config/mise/config.toml

cd ~/code/some-ruby-repo
mise install                            # compiles the .tool-versions ruby FRESH
mise current                            # confirm it resolved the repo's pins
ruby -v && which ruby                   # shim should be under ~/.local/share/mise/shims
```

Open a **new** normal terminal and you're back on asdf. Nothing persisted.

To try the repo's actual config without symlinking, source the spike files by
hand in a throwaway shell instead of `mise activate` alone.

---

## Full migration

Do this once you've decided to cut over. Assumes the `spike/mise-migration`
branch content is what you're applying (via `install.sh` symlinks or by merging
to `master` first).

1. **Install mise, keep asdf for now.**
   ```sh
   brew install mise
   ```
   (The Brewfile already says `mise`; `brew bundle` will install it. Don't
   `brew uninstall asdf` yet — leave the rollback path intact.)

2. **Apply the dotfiles** so `z_mise.zsh`, `config.toml`, the PATH swaps, and the
   bashrc activation land (run `install.sh`, or your normal apply step). Open a
   fresh shell.

3. **Reinstall every runtime.** This is the big one — **mise does not reuse
   asdf's compiled rubies**. It builds its own from source into
   `~/.local/share/mise/installs/`. Nothing under `~/.local/share/asdf` is
   visible to mise.
   ```sh
   mise install                         # installs everything pinned in reachable .tool-versions
   mise ls                              # verify each tool shows an installed version
   ```
   Global pins live in `~/.tool-versions`; the repo's tracked copy is
   `dot_tool_versions/tool-versions` (awscli, elixir, erlang, golang, kubectl,
   nodejs, pnpm, python, ruby, rust, terraform, yarn, opensearch).
   **Expect this to error on `opensearch`** — it has no registry entry, so it
   stays unresolved until step 4. That's fine; the other tools still install.

4. **Add backends for non-core tools** (opensearch, elasticsearch). These are
   **not** mise core tools and will fail a bare `mise install` until you give
   them a backend — see gotcha #2 for the exact commands. Run this before, or
   right after, step 3 to clear the opensearch error.

5. **Swap the GUI PATH plist.** Edit `plists/set-gui-path.plist`: change
   `~/.local/share/asdf/shims` → `~/.local/share/mise/shims` (and drop the
   trailing `~/.asdf/bin`). Reload it:
   ```sh
   launchctl unload ~/Library/LaunchAgents/set-gui-path.plist 2>/dev/null
   launchctl load  ~/Library/LaunchAgents/set-gui-path.plist
   ```
   Then fully quit and relaunch VS Code so it re-reads GUI PATH.

6. **Point VS Code Ruby LSP at mise.** The setting
   (`"rubyLsp.rubyVersionManager": { "identifier": "mise" }`) is in
   `vscode/settings.json` on this branch, but **`install.sh` never applies it** —
   the live file lives outside `~/.config`, so it needs the manual symlink from
   `vscode/README.md` ("How to apply it": back up the live file, then
   `ln -fs .../vscode/settings.json "$HOME/Library/Application Support/Code/User/settings.json"`).
   Do that, then restart the Ruby LSP server. See [VS Code](#vs-code-ruby-lsp).

7. **Normalise repo ruby pins** so every ruby repo actually runs on its declared
   ruby under mise's stricter version-file rules:
   ```sh
   nightly-skill-mise/fix-ruby-pins.zsh --dry     # preview
   nightly-skill-mise/fix-ruby-pins.zsh           # apply
   ```
   (Why this is needed: gotcha #3.)

8. **Verify**, then only afterwards retire asdf:
   ```sh
   mise doctor
   which -a ruby node python           # every one should resolve to a mise shim
   # sanity-check a few repos build/boot, then:
   brew uninstall asdf                 # optional, final step
   rm -rf ~/.local/share/asdf ~/.config/asdf   # optional cleanup
   ```

---

## Gotchas

**1. mise compiles rubies fresh — runtimes must be reinstalled.**
mise ignores asdf's install tree entirely. After cutover, `mise install` builds
every runtime from source into `~/.local/share/mise/installs/`. Budget time for
ruby/python compiles. Until you run it, `ruby`/`node`/etc. resolve to empty mise
shims and fail. This is the single biggest surprise of the migration.

**2. opensearch / elasticsearch need explicit backends.**
Core tools (ruby, node, python, go, …) resolve from mise's built-in registry
with no setup. opensearch/elasticsearch do **not**:
- `elasticsearch` exists in the registry but only via a non-core backend
  (`vfox:jdx/vfox-elasticsearch` or `asdf:mise-plugins/mise-elasticsearch`).
- **bare `opensearch` is not in the registry at all** — only `opensearch-cli`
  is. Our `.tool-versions` pins `opensearch 3.6.0`, so mise can't resolve it
  from a short name. Give it a full backend spec, e.g.:
  ```sh
  # elasticsearch: registry short-name works once you accept the backend
  mise install elasticsearch@<version>
  # opensearch: no registry entry — install the plugin/backend explicitly
  mise plugins install opensearch https://github.com/<opensearch-asdf-plugin>
  mise install opensearch@3.6.0
  ```
  Confirm what's available with `mise registry | grep -iE 'opensearch|elastic'`
  before installing. A bare `mise install` will silently skip or error on these
  until a backend is in place.

**3. `.ruby-version` stays ignored by default — and mise's default is the
opposite of asdf's.**
Under asdf, `~/.config/asdf/asdfrc` had `legacy_version_file = no`, so asdf read
only `.tool-versions`. **mise defaults this setting to `true`** (it *does* read
`.ruby-version`/`.nvmrc`/etc. out of the box). `dot_config/mise/config.toml`
sets `legacy_version_file = false` to preserve the old behaviour — it is
load-bearing, not cosmetic. Consequence: a repo with **only** a `.ruby-version`
and no `.tool-versions` silently runs on the **global** ruby. `fix-ruby-pins.zsh`
fixes this by making `.tool-versions` the source of truth in every ruby repo.
(Version note: newer mise renames this key to `idiomatic_version_file`; the
installed mise `2026.7.11` errors on that name, so keep the `legacy_version_file`
spelling until mise is upgraded.)

**4. VS Code Ruby LSP now points at mise — and why asdf was flaky.** See below.

**5. Non-interactive shells.** `.zshenv` (not `.zshrc`) is what non-interactive
zsh reads, so the PATH shims-dir swap there is what keeps `ruby`/`node`
resolvable for scripts, cron, and tools that spawn a non-login shell. mise's
recommended split is deliberate: **shims on PATH** (via `.zshenv`/`claude-env`)
for non-interactive shells, plus **`mise activate`** (via `z_mise.zsh`/`bashrc`)
for interactive ones.

---

## VS Code Ruby LSP

The one load-bearing VS Code change:
`"rubyLsp.rubyVersionManager": { "identifier": "mise" }`.

Under asdf this key was **unset**, so Ruby LSP fell back to `"auto"` and found
`ruby` through whatever shims were on PATH. Pinning it to `mise` makes LSP
resolve the repo's `.tool-versions` ruby deterministically.

**Why asdf was flaky (the GUI PATH problem):** when VS Code launches from Finder
or the Dock (not `code` from a terminal) it does **not** inherit your interactive
shell's PATH. So `ruby`/`rubocop`/the test explorer couldn't see the runtime from
`.zshrc` — resolution leaned entirely on the shims dir being injected into the
GUI environment via `plists/set-gui-path.plist`, combined with `"auto"`
detection guessing right. It worked only while the plist pointed at a live shims
dir. The cutover makes both halves explicit: the plist points at the mise shims
dir, and `rubyVersionManager = mise` tells LSP to use mise directly instead of
guessing.

(`solargraph.bundlerPath` / `solargraph.commandPath` point at the XDG *system*
gem bin, which is neither asdf- nor mise-managed — left byte-for-byte. If your
Ruby LSP extension predates the object form, use the string form `"mise"`.)

---

## Command cheat-sheet

What the scripts on this branch had to translate:

| Task | asdf | mise |
|---|---|---|
| Activate (interactive) | `source .../asdf.sh` | `eval "$(mise activate zsh)"` |
| Current ruby | `asdf current ruby` | `mise current ruby` |
| List installed rubies | `asdf list ruby` | `mise ls ruby --installed` |
| Where a version lives | `asdf where ruby $v` | `mise where ruby@$v` |
| Install | `asdf install ruby $v` | `mise install ruby@$v` |
| Uninstall | `asdf uninstall ruby $v` | `mise uninstall ruby@$v` |
| Set global pin | `asdf set --home ruby $v` | `mise use --path ~/.tool-versions ruby@$v` |
| Update plugin lists | `asdf plugin update --all` | `mise plugins update` (only if plugins installed) |
| Outdated tools | `asdf latest --all` | `mise outdated --bump --json` |

Two mise subtleties the scripts encode:
- `mise ls ruby --installed` puts the version in **column 2** (`awk '{print $2}'`),
  where asdf's `asdf list` needed `sed 's/[* ]//g'`.
- **Pin with `mise use --path ~/.tool-versions`, not `mise use -g`.**
  `~/.tool-versions` overrides `~/.config/mise/config.toml` in precedence, so a
  `-g` write would be silently ignored when a `~/.tool-versions` entry exists.
- `mise plugins update` / `mise plugins ls` only matter for asdf/vfox-backed
  plugins; core tools have no git plugin to update, so the scripts guard the call
  and no-op when no plugins are installed.

---

## Rollback

Getting back to asdf is clean because the spike never removes asdf.

1. **Stay on / return to `master`** (or `git checkout master` in the dot-files
   repo) and re-apply dotfiles (`install.sh`). That restores `z_asdf.zsh`'s PATH
   line, the asdf exports in `.zshenv` / `bashrc` / `claude-env`, and the
   asdf-based `brew_refresh.zsh`.
2. **Remove the mise-only files** if they were applied: `z_mise.zsh` and
   `~/.config/mise/config.toml`. (On `master` they don't exist, so re-applying is
   usually enough.)
3. **Revert the GUI plist** if you changed it: `set-gui-path.plist` back to
   `~/.local/share/asdf/shims`, then `launchctl unload/load` it.
4. **Revert VS Code**: remove `rubyLsp.rubyVersionManager` (back to unset/`auto`),
   restart the Ruby LSP server.
5. asdf's compiled runtimes under `~/.local/share/asdf/installs` were never
   touched, so `asdf current` / `ruby -v` work immediately in a fresh shell. No
   reinstall needed on the way back.
6. Optionally `brew uninstall mise` and `rm -rf ~/.local/share/mise ~/.config/mise`.

The asymmetry is the point: **mise → asdf rollback needs no recompile** (asdf's
installs survived), whereas **asdf → mise cutover does** (mise builds fresh).
