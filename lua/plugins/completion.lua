return {
  -- Copilot core
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = { enabled = false }, -- handled by nvim-cmp
        panel = { enabled = false },
      })
    end,
  },

  -- Copilot as an nvim-cmp source
  {
    "zbirenbaum/copilot-cmp",
    event = "InsertEnter",
    dependencies = { "zbirenbaum/copilot.lua" },
    config = function()
      require("copilot_cmp").setup()
    end,
  },

  -- Completion engine
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "L3MON4D3/LuaSnip",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-buffer",
      "zbirenbaum/copilot-cmp", -- ensure copilot source exists
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },

        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },

        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),

          -- ✅ VS Code / Cursor behavior:
          -- Tab accepts the current completion
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.confirm({ select = true })
            else
              fallback()
            end
          end, { "i", "s" }),

          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            else
              fallback()
            end
          end, { "i", "s" }),
        }),

        sources = cmp.config.sources({
          { name = "copilot", priority = 1000 }, -- [AI]
          { name = "nvim_lsp", priority = 750 }, -- [LSP]
          { name = "path", priority = 500 },     -- [Path]
          { name = "buffer", priority = 250 },   -- [Buf]
        }),

        formatting = {
          fields = { "abbr", "kind", "menu" },
          format = function(entry, item)
            item.menu = ({
              copilot = "[AI]",
              nvim_lsp = "[LSP]",
              path = "[Path]",
              buffer = "[Buf]",
            })[entry.source.name]
            return item
          end,
        },
      })
    end,
  },
}
