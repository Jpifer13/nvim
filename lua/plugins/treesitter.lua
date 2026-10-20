-- Parsers to keep installed. nvim-treesitter `main` has no ensure_installed;
-- see lua/treesitter_parsers.lua for the install helper this uses.
local ENSURE_INSTALLED = {
  "python",
  "lua",
  "vim",
  "vimdoc",
  -- `main` has no separate jsonc parser; the jsonc filetype maps to `json`.
  "json",
  "markdown",
  "markdown_inline",
  "bash",
  "java",
  "go",
  "gomod",
  "gosum",
  "gowork",
  "typescript",
  "tsx",
  "javascript",
  "html",
  "css",
  "yaml",
  "toml",
  "sql",
  "dockerfile",
  "regex",
  "comment",
}

-- Treesitter indentation is still marked experimental upstream. Set this to
-- false to fall back to Neovim's smartindent (see lua/options.lua).
local ENABLE_INDENT = true

return {
  -- Treesitter for superior syntax highlighting.
  --
  -- Pinned to `main`, whose API is nothing like `master`: there are no
  -- highlight/indent/incremental_selection/auto_install modules. Highlighting
  -- is Neovim's own (vim.treesitter.start), indentation is an indentexpr,
  -- incremental selection lives in lua/treesitter_select.lua, and
  -- auto-install is the FileType autocmd below.
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    lazy = false,
    priority = 50,
    config = function()
      local parsers = require("treesitter_parsers")

      require("nvim-treesitter").setup({
        -- Prepended to runtimepath, so these parsers win over any bundled ones.
        install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site"),
      })

      -- Make sure Neovim baseline highlighting/filetype systems are on
      vim.cmd("filetype plugin indent on")
      vim.cmd("syntax enable")

      parsers.install(ENSURE_INSTALLED)

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("TreesitterAttach", { clear = true }),
        callback = function(args)
          local ft = vim.bo[args.buf].filetype
          if ft == "" then
            return
          end

          local lang = vim.treesitter.language.get_lang(ft)
          if not lang or not parsers.is_available(lang) then
            return
          end

          if not parsers.is_installed(lang) then
            -- Stand-in for the old `auto_install`: queue it quietly and let the
            -- next time this filetype is opened pick up the built parser.
            parsers.install({ lang }, { silent = true })
            return
          end

          if not pcall(vim.treesitter.start, args.buf, lang) then
            return
          end

          if ENABLE_INDENT then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      -- Install/refresh everything in ENSURE_INSTALLED on demand.
      vim.api.nvim_create_user_command("TSEnsure", function()
        local queued = parsers.install(ENSURE_INSTALLED)
        if #queued == 0 then
          vim.notify("All configured parsers are installed", vim.log.levels.INFO)
        end
      end, { desc = "Install any missing parsers from ENSURE_INSTALLED" })

      -- Quick diagnostic command (avoids older `has_parser` helpers)
      vim.api.nvim_create_user_command("TSStatus", function()
        local bufnr = vim.api.nvim_get_current_buf()
        local ft = vim.bo[bufnr].filetype
        local lang = vim.treesitter.language.get_lang(ft)

        local highlighter_ok = false
        if vim.treesitter.highlighter and vim.treesitter.highlighter.active then
          highlighter_ok = vim.treesitter.highlighter.active[bufnr] ~= nil
        end

        local missing = parsers.missing(ENSURE_INSTALLED)

        vim.notify(
          string.format(
            "TSStatus: ft=%s | lang=%s | parser=%s | highlighter=%s | indentexpr=%s\nmissing from ENSURE_INSTALLED: %s",
            ft,
            tostring(lang),
            (lang and parsers.is_installed(lang)) and "installed" or "no",
            tostring(highlighter_ok),
            vim.bo[bufnr].indentexpr ~= "" and "ts" or "-",
            #missing > 0 and table.concat(missing, ", ") or "none"
          ),
          vim.log.levels.INFO
        )
      end, { desc = "Show Tree-sitter parser/highlighter status for current buffer" })
    end,
  },

  -- Rainbow delimiters (no custom highlight overrides)
  {
    "HiPhish/rainbow-delimiters.nvim",
  },

  -- Indent guides (no custom colors)
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    config = function()
      require("ibl").setup()
    end,
  },

  -- Show current function/class context at top of screen
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "BufReadPost",
    opts = {
      max_lines = 3,
      min_window_height = 20,
      trim_scope = "outer",
    },
  },

  -- Highlight all references to symbol under cursor
  {
    "RRethy/vim-illuminate",
    event = "BufReadPost",
    config = function()
      require("illuminate").configure({
        providers = { "lsp", "treesitter", "regex" },
        delay = 120,
        under_cursor = true,
        min_count_to_highlight = 2,
      })
      vim.api.nvim_set_hl(0, "IlluminatedWordText", { bg = "#2d3f6c", underline = false })
      vim.api.nvim_set_hl(0, "IlluminatedWordRead", { bg = "#2d3f6c" })
      vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { bg = "#3d2f4c" })
    end,
  },

  -- Colorful TODO/FIXME/NOTE/HACK/WARN markers
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "BufReadPost",
    opts = {
      signs = true,
      keywords = {
        FIX  = { icon = " ", color = "error",   alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
        TODO = { icon = " ", color = "info" },
        HACK = { icon = " ", color = "warning" },
        WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
        PERF = { icon = " ", color = "default", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
        NOTE = { icon = " ", color = "hint",    alt = { "INFO" } },
        TEST = { icon = "⏲ ", color = "test",   alt = { "TESTING", "PASSED", "FAILED" } },
      },
    },
  },

  -- Color highlighter - show colors in the code
  {
    "norcalli/nvim-colorizer.lua",
    event = "BufReadPost",
    config = function()
      require("colorizer").setup({
        "*",
      }, {
        RGB = true,
        RRGGBB = true,
        names = true,
        RRGGBBAA = true,
        rgb_fn = true,
        hsl_fn = true,
        css = true,
        css_fn = true,
        mode = "background",
      })
      vim.cmd("ColorizerAttachToBuffer")
    end,
  },
}