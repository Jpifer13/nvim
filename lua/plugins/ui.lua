-- ============================================================
-- UI / Themes
-- Toggle between TokyoNight and Nightfox easily
-- ============================================================

-- Change this value to switch themes quickly:
-- TokyoNight:
--   "tokyonight-night"
--   "tokyonight-storm"
--   "tokyonight-moon"
--   "tokyonight-day"
-- Nightfox:
--   "nightfox"
--   "duskfox"
--   "carbonfox"
local ACTIVE_THEME = "tokyonight-night"

local function starts_with(str, prefix)
  return str:sub(1, #prefix) == prefix
end

local function tokyonight_style_from_theme(theme)
  -- theme is like "tokyonight-night"
  local style = theme:gsub("^tokyonight%-", "")
  if style == "storm" or style == "night" or style == "moon" or style == "day" then
    return style
  end
  return "night"
end

return {
  ------------------------------------------------------------------
  -- TokyoNight
  ------------------------------------------------------------------
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
  },

  ------------------------------------------------------------------
  -- Nightfox
  ------------------------------------------------------------------
  {
    "EdenEast/nightfox.nvim",
    lazy = false,
    priority = 1000,
  },

  ------------------------------------------------------------------
  -- Apply colorscheme + (optional) TokyoNight custom highlights
  ------------------------------------------------------------------
  {
    -- Dummy plugin used only to run config early and reliably
    "nvim-lua/plenary.nvim",
    lazy = false,
    priority = 1001,
    config = function()
      -- If using TokyoNight, configure it BEFORE colorscheme is applied
      if starts_with(ACTIVE_THEME, "tokyonight") then
        local style = tokyonight_style_from_theme(ACTIVE_THEME)

        require("tokyonight").setup({
          style = style,
          transparent = false,
          terminal_colors = true,
          styles = {
            comments = { italic = true },
            keywords = { italic = true },
            functions = { bold = true },
            variables = {},
            sidebars = "dark",
            floats = "dark",
          },

          -- Make the UI + syntax *very* colorful.
          -- We intentionally map many groups to distinct palette colors.
          on_highlights = function(hl, c)
            local util = require("tokyonight.util")

            -- Core editor UI
            hl.Normal = { fg = c.fg, bg = c.bg }
            hl.NormalNC = { fg = c.fg_dark, bg = c.bg }
            hl.CursorLine = { bg = c.bg_highlight }
            hl.CursorColumn = { bg = c.bg_highlight }
            hl.ColorColumn = { bg = c.bg_highlight }
            hl.Visual = { bg = util.darken(c.blue, 0.8) }

            hl.LineNr = { fg = c.dark5 }
            hl.CursorLineNr = { fg = c.orange, bold = true }
            hl.WinSeparator = { fg = c.blue0 }
            hl.FloatBorder = { fg = c.cyan, bg = c.bg_float }

            hl.Search = { fg = c.bg, bg = c.yellow, bold = true }
            hl.IncSearch = { fg = c.bg, bg = c.orange, bold = true }

            hl.Pmenu = { fg = c.fg, bg = c.bg_popup }
            hl.PmenuSel = { fg = c.bg, bg = c.blue, bold = true }
            hl.PmenuSbar = { bg = c.bg_popup }
            hl.PmenuThumb = { bg = c.blue0 }

            -- Diagnostics (make them loud)
            hl.DiagnosticError = { fg = c.red1, bold = true }
            hl.DiagnosticWarn = { fg = c.yellow, bold = true }
            hl.DiagnosticInfo = { fg = c.cyan, bold = true }
            hl.DiagnosticHint = { fg = c.teal, bold = true }
            hl.DiagnosticOk = { fg = c.green1, bold = true }

            hl.DiagnosticUnderlineError = { undercurl = true, sp = c.red1 }
            hl.DiagnosticUnderlineWarn = { undercurl = true, sp = c.yellow }
            hl.DiagnosticUnderlineInfo = { undercurl = true, sp = c.cyan }
            hl.DiagnosticUnderlineHint = { undercurl = true, sp = c.teal }

            -- Standard syntax groups (distinct colors)
            hl.Comment = { fg = c.dark5, italic = true }
            hl.Constant = { fg = c.magenta }
            hl.String = { fg = c.green }
            hl.Character = { fg = c.green1 }
            hl.Number = { fg = c.orange }
            hl.Boolean = { fg = c.orange, bold = true }
            hl.Float = { fg = c.orange }

            hl.Identifier = { fg = c.blue }
            hl.Function = { fg = c.cyan, bold = true }

            hl.Statement = { fg = c.purple, bold = true }
            hl.Conditional = { fg = c.purple, bold = true }
            hl.Repeat = { fg = c.purple, bold = true }
            hl.Label = { fg = c.yellow }
            hl.Operator = { fg = c.red }
            hl.Keyword = { fg = c.purple, italic = true }
            hl.Exception = { fg = c.red1 }

            hl.PreProc = { fg = c.yellow }
            hl.Include = { fg = c.yellow }
            hl.Define = { fg = c.yellow }
            hl.Macro = { fg = c.yellow }
            hl.PreCondit = { fg = c.yellow }

            hl.Type = { fg = c.teal, bold = true }
            hl.StorageClass = { fg = c.teal }
            hl.Structure = { fg = c.teal }
            hl.Typedef = { fg = c.teal }

            hl.Special = { fg = c.red1 }
            hl.SpecialChar = { fg = c.red1 }
            hl.Tag = { fg = c.blue }
            hl.Delimiter = { fg = c.fg_dark }
            hl.SpecialComment = { fg = c.dark5, italic = true }
            hl.Debug = { fg = c.orange }

            -- Treesitter captures (where “everything has a color” really happens)
            hl["@comment"] = { fg = c.dark5, italic = true }

            hl["@keyword"] = { fg = c.purple, italic = true }
            hl["@keyword.function"] = { fg = c.purple, italic = true }
            hl["@keyword.return"] = { fg = c.purple, italic = true }
            hl["@keyword.operator"] = { fg = c.red }

            hl["@function"] = { fg = c.cyan, bold = true }
            hl["@function.call"] = { fg = c.cyan }
            hl["@function.method"] = { fg = c.cyan, bold = true }       -- 0.10+ (was @method)
            hl["@function.method.call"] = { fg = c.cyan }               -- 0.10+ (was @method.call)
            hl["@function.builtin"] = { fg = c.teal, bold = true }      -- print, len, range, etc.
            hl["@constructor"] = { fg = c.teal, bold = true }

            hl["@type"] = { fg = c.teal, bold = true }
            hl["@type.builtin"] = { fg = c.teal, bold = true }
            hl["@type.definition"] = { fg = c.teal, bold = true }

            hl["@module"] = { fg = c.blue }                             -- module/namespace names
            hl["@module.builtin"] = { fg = c.teal }                     -- builtins like __builtins__

            hl["@variable"] = { fg = c.blue1 }
            hl["@variable.builtin"] = { fg = c.red1 }                   -- self, cls, super
            hl["@variable.parameter"] = { fg = c.yellow }               -- 0.10+ (was @parameter)
            hl["@variable.parameter.builtin"] = { fg = c.orange }       -- *args, **kwargs
            hl["@variable.member"] = { fg = c.magenta }                 -- 0.10+ (was @field/@property)
            hl["@property"] = { fg = c.magenta }
            hl["@attribute"] = { fg = c.yellow }
            hl["@attribute.builtin"] = { fg = c.orange, italic = true } -- __dunder__ attributes

            hl["@constant"] = { fg = c.magenta, bold = true }
            hl["@constant.builtin"] = { fg = c.magenta, bold = true }
            hl["@number"] = { fg = c.orange }
            hl["@boolean"] = { fg = c.orange, bold = true }
            hl["@string"] = { fg = c.green }
            hl["@string.escape"] = { fg = c.red1 }
            hl["@string.special"] = { fg = c.red1 }

            hl["@operator"] = { fg = c.red }
            hl["@punctuation.delimiter"] = { fg = c.fg_dark }
            hl["@punctuation.bracket"] = { fg = c.blue0 }
            hl["@punctuation.special"] = { fg = c.red1 }

            -- Common Python-ish specifics (extra pop)
            hl["@type.qualifier"] = { fg = c.purple, italic = true }
            hl["@keyword.import"] = { fg = c.yellow, italic = true }

            -- LSP semantic tokens (pyright + general)
            hl["@lsp.type.variable"] = { fg = c.blue1 }
            hl["@lsp.type.parameter"] = { fg = c.yellow }
            hl["@lsp.type.function"] = { fg = c.cyan, bold = true }
            hl["@lsp.type.method"] = { fg = c.cyan, bold = true }
            hl["@lsp.type.property"] = { fg = c.magenta }
            hl["@lsp.type.type"] = { fg = c.teal, bold = true }
            hl["@lsp.type.class"] = { fg = c.teal, bold = true }
            hl["@lsp.type.namespace"] = { fg = c.blue }
            hl["@lsp.type.module"] = { fg = c.blue }
            hl["@lsp.type.enum"] = { fg = c.teal }
            hl["@lsp.type.enumMember"] = { fg = c.magenta }
            hl["@lsp.type.keyword"] = { fg = c.purple, italic = true }
            hl["@lsp.type.operator"] = { fg = c.red }
            hl["@lsp.type.string"] = { fg = c.green }
            hl["@lsp.type.number"] = { fg = c.orange }
            hl["@lsp.type.decorator"] = { fg = c.yellow, italic = true }
            hl["@lsp.type.selfParameter"] = { fg = c.red1 }
            hl["@lsp.type.clsParameter"] = { fg = c.red1 }
            -- Pyright modifier combos — these override plain @lsp.type.* for special cases
            hl["@lsp.typemod.variable.readonly"] = { fg = c.magenta, bold = true }      -- constants
            hl["@lsp.typemod.variable.defaultLibrary"] = { fg = c.teal }                -- builtins
            hl["@lsp.typemod.function.builtin"] = { fg = c.teal, bold = true }
            hl["@lsp.typemod.class.defaultLibrary"] = { fg = c.teal, bold = true }
            hl["@lsp.typemod.variable.typeHint"] = { fg = c.teal }                      -- type annotation vars

            -- Make TODO/FIXME stand out
            hl.Todo = { fg = c.bg, bg = c.yellow, bold = true }
            hl.Error = { fg = c.red1, bold = true }
            hl.WarningMsg = { fg = c.yellow, bold = true }

            -- DAP UI
            hl.DapBreakpoint = { fg = c.red1, bold = true }
            hl.DapStopped = { fg = c.green1, bold = true }
          end,
        })
      end

      -- Apply the selected scheme
      vim.cmd.colorscheme(ACTIVE_THEME)
    end,
  },

  ------------------------------------------------------------------
  -- Statusline
  ------------------------------------------------------------------
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = ACTIVE_THEME,
          section_separators = "",
          component_separators = "",
        },
      })
    end,
  },

  ------------------------------------------------------------------
  -- Bufferline (tab-style buffer bar)
  ------------------------------------------------------------------
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup({
        options = {
          mode = "buffers",
          diagnostics = "nvim_lsp",
          show_buffer_close_icons = false,
          show_close_icon = false,
          separator_style = "slant",
          tab_size = 24,
          max_name_length = 24,
          offsets = {
            { filetype = "NvimTree", text = "File Explorer", highlight = "Directory", separator = true },
          },
        },
      })
    end,
  },

  ------------------------------------------------------------------
  -- File icons
  ------------------------------------------------------------------
  {
    "nvim-tree/nvim-web-devicons",
  },
}