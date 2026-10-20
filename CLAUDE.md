# Neovim Configuration

## Overview

Lua-based Neovim config using **lazy.nvim** as the plugin manager. Leader key is `<Space>`. The config is modular: `init.lua` loads `options`, `keymaps`, `plugins`, `lsp`, and `env-manager`.

## Structure

```
init.lua                    -- Entry point
lua/options.lua             -- Editor settings (2-space indent, relative numbers, auto-save, folding)
lua/keymaps.lua             -- All keybindings (organized by category)
lua/lsp.lua                 -- LSP setup using Neovim 0.11+ native API (not nvim-lspconfig patterns)
lua/plugins/init.lua        -- lazy.nvim bootstrap + aggregates all plugin modules
lua/plugins/*.lua           -- Plugin configs (one file per concern)
lua/plugins/git/plugins.lua -- Git plugins (gitsigns, neogit, diffview)
scripts/export-to-usb.sh    -- Pack config + plugins + LSP servers + parsers onto a drive
scripts/usb-install.sh      -- Installer that ships with the bundle (@EXT@ is substituted)
scripts/usb-README.md       -- Instructions that ship with the bundle
lua/floating_terminal.lua   -- Persistent floating terminal (85%x80%, rounded border)
lua/awsdash.lua             -- awsdash AWS TUI (~/dev/personal/awsdash) in its own persistent float (<leader>A)
lua/cheatsheet.lua          -- Modal keybinding reference (<leader>?)
lua/env-manager.lua         -- Auto-loads .env into process, floating editor (<leader>en)
lua/markdown_preview.lua    -- In-terminal markdown renderer (not web-based)
lua/treesitter_parsers.lua  -- Parser install/query helpers for nvim-treesitter `main`
lua/treesitter_select.lua   -- Incremental selection (<CR>/<Tab>/<S-Tab>)
lua/debug/fastapi_aws.lua   -- FastAPI + AWS SSO + debugpy workflow
lua/java/                   -- Java tooling (jdtls, Maven test runner)
  init.lua                  --   setup() + :Java* commands + :JavaHealth
  jdtls.lua                 --   jdtls launcher, reactor-root detection, DAP wiring
  maven.lua                 --   run tests from the editor, honest pass/fail reporting
after/ftplugin/java.lua     -- starts jdtls per Java buffer
lua/javaquest/              -- progress panel for a TDD course repo (gated on .javaquest.json)
  init.lua                  --   setup() + :JavaQuest* commands + the post-test-run hook
  detect.lua                --   finds .javaquest.json upward; remembers the root
  progress.lua              --   derives progress from Surefire XML reports
  state.lua                 --   streak + trophy unlock history (NOT progress)
  game.lua                  --   XP, levels, achievements, progress bars
  ui.lua                    --   the right-hand sidebar, rendered like cheatsheet.lua
  reset.lua                 --   the only destructive code: restore stubs from a git tag
lua/go/                     -- Go tooling (gopls is in lua/lsp.lua; delve via nvim-dap-go)
  init.lua                  --   setup() + :Go* commands + :GoHealth + buffer-local keymaps
  runner.lua                --   run tests from the editor: ./quest in a course repo, go test elsewhere
after/ftplugin/go.lua       -- real tabs, then require("go").attach(buf)
lua/goquest/                -- javaquest's sibling for a Go course repo (gated on .goquest.json)
  init.lua / detect.lua / state.lua / game.lua / ui.lua   -- same shape as javaquest
  progress.lua              --   derives progress from .quest/reports/*.json, not Surefire
  reset.lua                 --   per-FILE restore (Go tests live next to the code)
lua/godot/                  -- Godot tooling, only active inside a project.godot tree
  init.lua                  --   setup() + :Godot* commands (no-op outside a project)
  detect.lua                --   project root / engine binary / port probes (dependency-free)
  lsp.lua                   --   GDScript LSP over TCP 6005
  dap.lua                   --   Godot debug adapter on 6006 + launch/attach configs
  treesitter.lua            --   gdscript/godot_resource/gdshader parsers
  run.lua                   --   run game/scene, streamed console buffer, open editor
  scene_tree.lua            --   static .tscn scene-tree inspector
  docs.lua                  --   class reference lookup
  health.lua                --   :GodotHealth and :checkhealth godot
```

## Key Architectural Decisions

- **LSP uses Neovim 0.11+ native API** (`vim.lsp.config` / `vim.lsp.enable`), not the traditional `lspconfig.server.setup()` pattern. See `lua/lsp.lua`.
- **Completion priority**: Copilot (1000) > LSP (750) > Path (500) > Buffer (250). Copilot panel/suggestion disabled; everything flows through nvim-cmp.
- **Tab accepts completion** (VS Code/Cursor style), `<CR>` confirms, `<C-e>` aborts.
- **Auto-save** is on by default (toggle: `<leader>ta`). Triggers on InsertLeave/CursorHold after 1s.
- **Format on save** via conform.nvim: black for Python (hardcoded pyenv 3.13.3 path to avoid timeout), prettier for JS/TS/JSON/YAML/MD.
- **Theme**: tokyonight-night with 80+ custom Treesitter highlight overrides for maximum color differentiation.
- **nvim-treesitter is pinned to `main`**, not `master`. The two branches share no API: `main` has no `nvim-treesitter.configs` and no `ensure_installed` / `auto_install` / `highlight` / `indent` / `incremental_selection` modules. In this config that means highlighting is Neovim's own `vim.treesitter.start()`, indentation is `indentexpr`, parser installation goes through `lua/treesitter_parsers.lua`, auto-install is the `FileType` autocmd in `lua/plugins/treesitter.lua`, and incremental selection is reimplemented in `lua/treesitter_select.lua`. Never reach for `configs.setup()` or `:TSBufEnable` here — neither exists.
- **Java uses nvim-jdtls, not `vim.lsp.config`.** jdtls needs a per-project `-data`
  workspace on the command line, Eclipse bundles for debug/test, and extended client
  capabilities the generic client cannot express, so it is started from
  `after/ftplugin/java.lua` rather than `vim.lsp.enable()`. Two things to know before
  touching `lua/java/jdtls.lua`:
  - **Never gate a Java keymap on `client.server_capabilities`.** jdtls announces
    definition, codeAction, formatting, rename and hover through *dynamic registration*
    after `initialize`, so those fields still read `nil` while the features work. A
    capability guard there silently never binds.
  - **Root detection walks to the OUTERMOST pom.xml**, not the nearest. `vim.fs.root`
    stops at a submodule's own pom and would cost you the parent pom, dependency
    management and every sibling module.
- **Java tests run through `lua/java/maven.lua`, and it parses Surefire's summary rather
  than trusting the exit code.** Verified behaviour: when a `-Dtest` filter matches
  nothing, Maven prints `Tests run: 0` and exits **0** — with or without
  `-DfailIfNoTests=false`. A typo'd method name would otherwise look exactly like a pass.
  Relatedly, `-Dtest=Class#method` does not match a method inside a `@Nested` class; the
  runner uses `Class*#method`, which matches both.
- **JavaQuest is gated on a `.javaquest.json` at the project root**, the same way the Godot
  module is gated on `project.godot`. No config file means no panel, no autocmds and no
  keymaps, so it is inert in every other project. Three things to know before touching it:
  - **Progress is DERIVED from `target/surefire-reports/TEST-*.xml`, never from a checklist**,
    so the panel cannot claim work you have not done. XP and level are recomputed every
    refresh, which is also why re-running an already-green test earns nothing.
  - **Count `<testcase>` elements, not the `<testsuite tests="N">` attribute.** The attribute
    reports `0` for a class whose tests live in `@Nested` inner classes while the file
    contains all of them.
  - **`mvn -Psolutions` used to overwrite those reports**, which marked modules complete when
    nothing had been written. The parent pom now redirects solutions runs to
    `target/surefire-reports-solutions` via a `surefire.reports.dir` property, and
    `progress.lua` only ever reads the real directory. `state.lua` likewise ignores solutions
    runs for the streak.
- **`lua/javaquest/reset.lua` is the only destructive code in the config**, so it is written
  defensively and should stay that way: it backs the current exercise files up to
  `stdpath("data")/javaquest/backups/<ts>/` before touching anything, restores from the
  `javaquest-pristine` git tag (refusing to run at all if the tag is missing), enumerates the
  pristine file list with `git ls-tree` so it can delete files the user ADDED rather than issuing
  a blind `rm -rf`, only ever writes under `<module>/src/main/java`, and never touches git
  history. The full restart requires a typed word; the destructive commands are deliberately NOT
  bound to any panel key.
- **The JavaQuest panel is pinned to the far right.** It is created with
  `botright vertical Nvsplit`, not `rightbelow vsplit` — the latter splits relative to the focused
  window, so the panel landed mid-layout whenever it was opened from anything but the rightmost
  window. A `JavaQuestLayout` augroup watches `WinNew`/`WinClosed`/`WinResized`/`VimResized`/
  `TabEnter` and calls `ui.reposition()`, which uses `wincmd L` (move window to far right) and
  re-asserts the width. `reposition` is guarded by a `repositioning` flag, since moving a window
  fires the same events.
- **JavaQuest's keymaps attach on `BufEnter` for every buffer in the project, not on
  `FileType java`.** Scoping them to Java files meant the panel toggle silently did nothing on a
  README, on `pom.xml`, in the file tree, on the unnamed startup buffer and inside the panel
  itself. Note the two detection helpers in `detect.lua` and why both exist: `root_of_path` judges
  a named file on its OWN location only (consulting the cwd there would attach the keymaps to an
  unrelated file opened while the cwd happened to be the quest repo), while `find_root` may fall
  back to the cwd and to a remembered root, which is what keeps the panel's own actions working
  from inside its pathless scratch buffer.
- **Never give a key both a standalone mapping and a prefix role.** Neovim then waits
  `timeoutlen` on every press before firing the standalone one. The standalone `<leader>`+single
  char maps in this config are `? A e f j J k K q u w z`, so none of those may become a prefix.
  JavaQuest originally used `<leader>qq`, which collided with `<leader>q` (close buffer, or `qa`
  when it is the last one) — so the panel now uses `<leader>'` as a PURE prefix, configurable via
  `keys.prefix` in `.javaquest.json`, and `lua/javaquest/init.lua` warns at startup if the chosen
  prefix is already a complete mapping.
- **Go uses plain gopls through `vim.lsp.config`** in `lua/lsp.lua` (no launcher needed, unlike
  jdtls), with Mason's binary via `mason_cmd`. Root markers put `go.work` before `go.mod`.
  Formatting is conform's `goimports` with `gofmt` as `stop_after_first` fallback; Go buffers
  get real tabs from `after/ftplugin/go.lua`. Debugging is nvim-dap-go with Mason's `dlv`.
- **Go tests run through `lua/go/runner.lua`**, the counterpart of `maven.lua`, and it too reports
  from evidence rather than the exit code: `go test -run Typo` exits 0 with `[no tests to run]`.
  Inside a goquest repo it runs the repo's `./quest` wrapper (so runs are recorded) and reads the
  totals from `.quest/last-run.json`, which it deletes before each run. It does NOT parse the
  terminal for them: a terminal buffer hard-wraps at its width, and with the quest panel pinned
  right the test split is narrow enough to break quest's `RESULT` line in two (verified).
  `maven.lua` parses Surefire's summary from its terminal the same way and could in principle
  hit the same wrap on a narrow screen.
- **GoQuest is javaquest's sibling, not a shared engine.** `lua/goquest/` was derived from
  `lua/javaquest/` and keeps the same shape (detect/state/game/ui/init) so a fix in one ports to
  the other; only `progress.lua` (reads `<root>/.quest/reports/<module>/<test file>.json`, leaf
  tests only, written by the course's `internal/quest` runner) and `reset.lua` really differ.
  Reset differs because Go keeps `*_test.go` next to the code: it restores exercise files ONE
  BY ONE from the `goquest-pristine` tag, where an exercise file is any non-test `.go` file not
  under `_solutions/`, `testdata/` or a dot-dir, and never deletes a directory. Same prefix
  (`<leader>'`) and same panel keys as JavaQuest; the two never attach in the same project.
- **Godot tooling is conditional**: everything under `lua/godot/` is gated on `require("godot.detect").is_project()`, which walks upward from the cwd looking for `project.godot`. Outside a Godot project no commands, keymaps, autocmds, LSP clients, DAP configs, or parsers are registered.

## Offline Export

`scripts/export-to-usb.sh /Volumes/DRIVE` bundles this config for a machine that cannot
reach this GitHub account: the config, `~/.local/share/nvim/lazy` (plugins),
`mason` (LSP servers, debug adapters) and `site` (compiled treesitter parsers).
Verified end to end by installing into a sandbox `HOME`: 49 plugins, none pending.

- **It ships tar archives, not loose files, and that is the point.** Thumbdrives are
  usually exFAT/FAT32, which store neither the executable bit nor symlinks —
  `mason/bin/*` are symlinks into `mason/packages/*`, so a plain copy arrives broken.
- **The other `~/.local/share/nvim` directories are deliberately left out**: `avante`
  (AI chat history), `telescope_history`, `harpoon`, `javaquest`/`goquest` progress.
  They are this machine's state, and some of it is private.
- **`usb-install.sh` removes the `origin` remote** after unpacking (history is kept), so
  an absent-minded `git push` on a work machine cannot reach a personal account.
- **Mason binaries and `.so` parsers are native code.** The bundle records
  `uname -ms` and the Neovim version in `MANIFEST.txt`, and the installer warns when the
  target differs — parsers are tied to Neovim's parser ABI.
- The installer also checks the two paths this config hardcodes (pyenv 3.13.3 `black`,
  Homebrew `openjdk@21`), since neither travels with the bundle.

## Plugin Ecosystem

| Category | Plugins |
|---|---|
| AI | claudecode.nvim (Claude Code CLI, opus model), copilot.lua (via cmp) |
| UI | tokyonight, lualine, nvim-web-devicons, indent-blankline, rainbow-delimiters, nvim-colorizer, todo-comments, illuminate |
| Navigation | nvim-tree, telescope, harpoon v2, popnav |
| Git | gitsigns, neogit (vsplit sidebar), diffview |
| LSP | Native Neovim LSP, mason (auto-installs pyright, ts_ls, lua_ls, yamlls, debugpy, jdtls, gopls, delve, goimports) |
| Completion | nvim-cmp, copilot-cmp, LuaSnip, cmp-path, cmp-buffer |
| Testing | neotest (pytest + jest + java + golang adapters), AWS profile selector for test env |
| Debugging | nvim-dap, dap-ui, dap-python, java-debug-adapter, nvim-dap-go (delve), custom FastAPI+debugpy launcher |
| Misc | conform (formatting), zen-mode, undotree, trouble, treesitter-context, csv/csvview, markdown-preview |

## LSP Servers

- **pyright** — Python (auto-detects venv: VIRTUAL_ENV > project .venv > system python3)
- **ts_ls** — TypeScript/JavaScript
- **lua_ls** — Lua (Neovim runtime aware)
- **yamlls** — YAML
- **jdtls** — Java, via nvim-jdtls (see `lua/java/jdtls.lua`). Pinned to Homebrew's
  keg-only JDK 21 through `cmd_env`, because nvim is often launched from a shell that
  never sourced `~/.zshrc` and Homebrew's `maven` pulls in an unversioned `openjdk`.
- **gopls** — Go, via `vim.lsp.config` in `lua/lsp.lua`; staticcheck on, gofumpt off. `_solutions/`
  in the Go course is invisible to it because the go tool ignores `_`-prefixed directories.
- **gdscript** — GDScript, via a TCP socket to the Godot editor's built-in server (`127.0.0.1:6005`); nothing to install, but the editor must have the project open. `lua/lsp.lua` returns `{ capabilities, on_attach, mason_cmd }` so `lua/godot/lsp.lua` reuses the same client setup.

## Important Keymap Prefixes

| Prefix | Category |
|---|---|
| `<leader>a` | AI / Claude Code |
| `<leader>d` | Debugger (DAP) |
| `<leader>f` | Find (Telescope) + fold control |
| `<leader>g` | Git |
| `<leader>h` | Harpoon |
| `<leader>n` | Neotest |
| `<leader>p` | Popnav |
| `<leader>t` | Toggles (auto-save, treesitter, highlighting) |
| `<leader>s` | SSH remote |
| `<leader>c` | Code actions (Java, buffer-local: organize imports, generate, extract) |
| `<leader>'` | JavaQuest / GoQuest panel (buffer-local, only in a `.javaquest.json` / `.goquest.json` project) |
| `<leader>r` | Run (Java and Go tests, buffer-local) + `<leader>rn` rename, `<leader>rp` |
| `<leader>G` | Godot (project-gated) |

## Custom Modules (not plugins)

- **floating_terminal** — Reusable persistent floating terminal; used by popnav and Claude Code.
- **awsdash** — Toggles the external `awsdash` TUI (pipx-installed from `~/dev/personal/awsdash`) in a
  persistent float, inheriting env-manager's `AWS_PROFILE`. Hidden from inside with a buffer-local
  `nowait` terminal-mode `<leader>A`; `nowait` is needed because the global terminal-mode `<leader>AT`
  (hide Claude) would otherwise make it wait `timeoutlen`. The profile also travels back: when the
  float closes, `M.adopt()` reads `~/.cache/awsdash/session.json` (which awsdash writes whenever its
  session window switches environment) and pushes `AWS_PROFILE` into this Neovim process through
  `env-manager.set`, so terminals, test runners and debug sessions started afterwards use the same
  account. `:AwsdashRestart` quits the running one and opens a fresh float, which is how a
  rebuilt awsdash is picked up -- hiding keeps the process, and a process keeps the code it
  started with. There is no keymap for it on purpose: `<leader>A` is a standalone map and must
  not become a prefix. Two things that are easy to get wrong here:
  - **`vim.cmd("startinsert")` must be scheduled.** Run inline it does nothing from a command
    line, or before `termopen` has turned the buffer into a terminal, and the float then sits
    in NORMAL mode: every key meant for the TUI is a Vim motion instead, and `m` silently sets
    a mark. Verified by driving nvim in a pty.
  - **`on_exit` must check that the buffer it closes is still the current one.** The callback
    is scheduled, so after a restart it arrives once the replacement float is already open and
    would close it and delete its buffer.
  Two deliberate limits:
  - **`AWS_REGION` is set only when awsdash's region differs from the profile's own.** An env var
    beats a profile's configured region, so pinning one here would silently override the region of
    whatever profile is chosen next; when an override is dropped the previous value is restored.
  - **A file older than the current awsdash process is ignored**, so a switch from last week's run is
    never adopted. `M.adopt{ since = 0 }` reads it regardless.
- **env-manager** — Parses `.env` at startup, provides floating editor. All child processes (terminals, test runners, debuggers) inherit the vars. `M.set(vars, { persist = true })` is the way other modules push a var in; it rewrites only keys the `.env` ALREADY defines, so nothing creates a project file or adds keys to a hand-written one.
- **cheatsheet** — Full keybinding reference rendered as a styled modal. Update this when adding keymaps.
- **markdown_preview** — Pure-Lua markdown renderer in a floating window with syntax highlighting.
- **treesitter_parsers** — Wraps `require("nvim-treesitter").install()` with the bookkeeping `main` doesn't provide: what's actually installed (Neovim bundles some parsers, which never appear in the install dir), what's available to build, and an in-flight guard. Used by both the treesitter config and the Godot module.
- **treesitter_select** — Incremental selection on core `vim.treesitter`: `<CR>` selects the node under the cursor, `<CR>` in visual grows to the parent, `<Tab>` jumps to the enclosing scope, `<S-Tab>` shrinks. Falls back to the built-in `<CR>` in buffers with no parser.
- **debug/fastapi_aws** — Orchestrates: pick AWS profile -> SSO login -> start uvicorn with debugpy -> auto-attach DAP.
- **javaquest** — A gamified progress panel for a test-driven course repo: a right-hand sidebar
  showing XP, level, a day streak, per-module progress bars, the next file to work on with its
  failing test names, and trophies. `lua/java/maven.lua` calls
  `require("javaquest").on_test_run{...}` after every run so the panel updates itself. Entirely
  optional and entirely gated on `.javaquest.json`.
- **goquest** — the same panel for a Go course repo, fed by `lua/go/runner.lua` calling
  `require("goquest").on_test_run{...}`. Gated on `.goquest.json`.
- **godot** — Godot 4 support layered on the existing LSP/DAP/treesitter/conform infrastructure rather than a plugin. Adds only the Godot-specific pieces: socket LSP, debug adapter, parsers, `:GodotRun`/`:GodotRunScene` with a streamed console, a static `.tscn` scene-tree inspector, and `:GodotHealth`. Debugging reuses the standard `<leader>d*` keymaps.

## When Editing This Config

- All plugin specs return a Lua table from their file; `plugins/init.lua` aggregates them via `vim.list_extend`.
- Keymaps are centralized in `lua/keymaps.lua` (not scattered in plugin configs), except for plugin-specific buffer-local keymaps set in `on_attach` or `config` callbacks.
- The cheatsheet (`lua/cheatsheet.lua`) is manually maintained — update it when adding/changing keybindings.
- Mason auto-installs are listed in `lua/plugins/mason.lua`; add new LSP servers/tools there.
- `lua/plugins/lsp.lua` (nvim-lspconfig) and `lua/lsp.lua` (native API) BOTH configure
  pyright/ts_ls/lua_ls/yamlls and both set `gd`/`gr`/`K`/`<leader>ca`. The plugin one is
  lazy-loaded on `BufReadPre`, so it runs last and wins. Pick one before adding a server.
- Treesitter parsers are listed in `ENSURE_INSTALLED` at the top of `lua/plugins/treesitter.lua`; `:TSEnsure` installs any that are missing and `:TSStatus` reports the current buffer plus anything outstanding. Note `main` has no separate `jsonc` parser — the `jsonc` filetype maps to `json`.
- Python tooling paths (black, debugpy, pyright) sometimes use hardcoded paths to specific pyenv or Mason installs to avoid PATH/timeout issues.
