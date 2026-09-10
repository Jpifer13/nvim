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
lua/floating_terminal.lua   -- Persistent floating terminal (85%x80%, rounded border)
lua/cheatsheet.lua          -- Modal keybinding reference (<leader>?)
lua/env-manager.lua         -- Auto-loads .env into process, floating editor (<leader>en)
lua/markdown_preview.lua    -- In-terminal markdown renderer (not web-based)
lua/treesitter_parsers.lua  -- Parser install/query helpers for nvim-treesitter `main`
lua/treesitter_select.lua   -- Incremental selection (<CR>/<Tab>/<S-Tab>)
lua/debug/fastapi_aws.lua   -- FastAPI + AWS SSO + debugpy workflow
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
- **Godot tooling is conditional**: everything under `lua/godot/` is gated on `require("godot.detect").is_project()`, which walks upward from the cwd looking for `project.godot`. Outside a Godot project no commands, keymaps, autocmds, LSP clients, DAP configs, or parsers are registered.

## Plugin Ecosystem

| Category | Plugins |
|---|---|
| AI | claudecode.nvim (Claude Code CLI, opus model), copilot.lua (via cmp) |
| UI | tokyonight, lualine, nvim-web-devicons, indent-blankline, rainbow-delimiters, nvim-colorizer, todo-comments, illuminate |
| Navigation | nvim-tree, telescope, harpoon v2, popnav |
| Git | gitsigns, neogit (vsplit sidebar), diffview |
| LSP | Native Neovim LSP, mason (auto-installs pyright, ts_ls, lua_ls, yamlls, debugpy) |
| Completion | nvim-cmp, copilot-cmp, LuaSnip, cmp-path, cmp-buffer |
| Testing | neotest (pytest + jest adapters), AWS profile selector for test env |
| Debugging | nvim-dap, dap-ui, dap-python, custom FastAPI+debugpy launcher |
| Misc | conform (formatting), zen-mode, undotree, trouble, treesitter-context, csv/csvview, markdown-preview |

## LSP Servers

- **pyright** — Python (auto-detects venv: VIRTUAL_ENV > project .venv > system python3)
- **ts_ls** — TypeScript/JavaScript
- **lua_ls** — Lua (Neovim runtime aware)
- **yamlls** — YAML
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
| `<leader>G` | Godot (project-gated) |

## Custom Modules (not plugins)

- **floating_terminal** — Reusable persistent floating terminal; used by popnav and Claude Code.
- **env-manager** — Parses `.env` at startup, provides floating editor. All child processes (terminals, test runners, debuggers) inherit the vars.
- **cheatsheet** — Full keybinding reference rendered as a styled modal. Update this when adding keymaps.
- **markdown_preview** — Pure-Lua markdown renderer in a floating window with syntax highlighting.
- **treesitter_parsers** — Wraps `require("nvim-treesitter").install()` with the bookkeeping `main` doesn't provide: what's actually installed (Neovim bundles some parsers, which never appear in the install dir), what's available to build, and an in-flight guard. Used by both the treesitter config and the Godot module.
- **treesitter_select** — Incremental selection on core `vim.treesitter`: `<CR>` selects the node under the cursor, `<CR>` in visual grows to the parent, `<Tab>` jumps to the enclosing scope, `<S-Tab>` shrinks. Falls back to the built-in `<CR>` in buffers with no parser.
- **debug/fastapi_aws** — Orchestrates: pick AWS profile -> SSO login -> start uvicorn with debugpy -> auto-attach DAP.
- **godot** — Godot 4 support layered on the existing LSP/DAP/treesitter/conform infrastructure rather than a plugin. Adds only the Godot-specific pieces: socket LSP, debug adapter, parsers, `:GodotRun`/`:GodotRunScene` with a streamed console, a static `.tscn` scene-tree inspector, and `:GodotHealth`. Debugging reuses the standard `<leader>d*` keymaps.

## When Editing This Config

- All plugin specs return a Lua table from their file; `plugins/init.lua` aggregates them via `vim.list_extend`.
- Keymaps are centralized in `lua/keymaps.lua` (not scattered in plugin configs), except for plugin-specific buffer-local keymaps set in `on_attach` or `config` callbacks.
- The cheatsheet (`lua/cheatsheet.lua`) is manually maintained — update it when adding/changing keybindings.
- Mason auto-installs are listed in `lua/plugins/mason.lua`; add new LSP servers/tools there.
- Treesitter parsers are listed in `ENSURE_INSTALLED` at the top of `lua/plugins/treesitter.lua`; `:TSEnsure` installs any that are missing and `:TSStatus` reports the current buffer plus anything outstanding. Note `main` has no separate `jsonc` parser — the `jsonc` filetype maps to `json`.
- Python tooling paths (black, debugpy, pyright) sometimes use hardcoded paths to specific pyenv or Mason installs to avoid PATH/timeout issues.
