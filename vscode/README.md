# VS Code user settings

Version-controlled, sanitized copy of the machine-global VS Code settings.

Live file on the machine (the source of truth VS Code actually reads):

```
~/Library/Application Support/Code/User/settings.json
```

## Why this wasn't version-controlled before

The rest of this repo installs via `install.sh`, which either symlinks named
files (`ln -fs $DOT_FILES_DIR/dot_bashrc/bashrc ~/.bashrc`, ...) or loops over
`dot_config/*` subdirs into `~/.config`. VS Code's user settings live under
`~/Library/Application Support/Code/User/` — a path with spaces and capitals,
outside `~/.config` — so nothing in `install.sh` ever touched it. It sat only
on the machine, unbacked and unshared.

### The chezmoi Library-path caveat

The repo uses chezmoi-style `dot_` source naming (though it currently applies
via the hand-rolled `install.sh`, not chezmoi itself). Either way, chezmoi's
source-name encoding (`dot_` → `.`, and its literal-name rules) can't cleanly
represent `Library/Application Support/Code/User/` — the space and capitals
don't round-trip through a source filename, and the target is outside `$HOME`
dotfile territory. So this file can't ride the generic `dot_config` loop or a
chezmoi-managed target. It needs one explicit symlink, kept here as a plain
`vscode/` dir (not `dot_`-prefixed, so no apply step picks it up by accident).

## How to apply it

Symlink the live user-settings path at this file. Back up the current one
first — the settings JSON is the source of truth VS Code writes to, and this
copy is deliberately trimmed (see "What was stripped").

```sh
DEST="$HOME/Library/Application Support/Code/User/settings.json"
cp "$DEST" "$DEST.bak.$(date +%Y%m%d)"          # keep the machine's current copy
ln -fs "$HOME/code/personal/dot-files/vscode/settings.json" "$DEST"
```

Caveats:
- VS Code rewrites this file in place when you change a setting through the UI.
  Editing settings from the GUI after symlinking writes back through the link
  into the repo — convenient, but commit intentionally.
- The path has a space; keep it quoted in any script.
- If you'd rather not symlink, just diff-and-copy the keys you want by hand.

## What changed for the asdf → mise migration

One load-bearing add:

```jsonc
"rubyLsp.rubyVersionManager": { "identifier": "mise" }
```

Under asdf this key was **unset**, so Ruby LSP used its `"auto"` fallback and
found `ruby` through whichever shims happened to be on `PATH`. Pinning it to
`mise` makes LSP resolve the repo's `.tool-versions` Ruby deterministically
instead of guessing.

Nothing else in this file is mise-related:
- `solargraph.bundlerPath` / `solargraph.commandPath` point at the XDG *system*
  gem bin (`$XDG_DATA_HOME/gem/bin`), which is neither asdf- nor mise-managed —
  left byte-for-byte.

### Why asdf was flaky here (the GUI PATH problem)

When VS Code launches from Finder or the Dock (not `code` from a terminal), it
does **not** inherit your interactive shell's `PATH`. So `ruby`, `rubocop`, and
the test explorer couldn't find the runtime from `.zshrc` — resolution leaned
entirely on the shims dir being injected into the GUI environment via
`plists/set-gui-path.plist`. Combined with `rubyLsp.rubyVersionManager` being
unset (falling back to `"auto"` detection through those same shims), Ruby
tooling in a GUI-launched window was implicit and fragile: it worked only while
the plist pointed at a live shims dir and auto-detection guessed right.

The mise cutover makes both halves explicit:
- `set-gui-path.plist` swaps the asdf shims dir for the mise shims dir
  (`~/.local/share/mise/shims`) — separate file, outside this settings copy.
- `rubyLsp.rubyVersionManager = mise` (this file) tells Ruby LSP to use mise
  directly rather than auto-detecting.

## What was stripped (sanitization)

There are no actual tokens or API keys in the live file, but these were removed
as account-, org-, or machine-specific (and in one case client-identifying):

- **All `snyk.*`** — `folderConfigs` (org UUIDs, plus a worktree path naming a
  client), `trustedFolders` (personal repo paths), `advanced.cliPath` (a
  machine-specific, malformed doubled `/Users/.../Users/...` path),
  `advanced.customEndpoint`, and the welcome-notification toggle.
- **`atlascode.jira.jqlList`** and **`atlascode.jira.lastCreateSiteAndProject`**
  — Jira site IDs and saved-query GUIDs.
- **`github.copilot.preferredAccount`** — GitHub username.

Kept: all editor, terminal, git, diff, Ruby / Ruby LSP, file-association,
code-runner, and Copilot-enablement preferences. The two `solargraph.*` absolute
paths are kept (not secret, and the whole repo is full of `/Users/james.ferguson`
paths).
