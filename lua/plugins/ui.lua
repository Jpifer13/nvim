return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        styles = { comments = { "italic" } },
        integrations = {
          treesitter = true,
          gitsigns = true,
          nvimtree = true,
          telescope = true,
          neogit = true,
          cmp = true,
          native_lsp = { enabled = true },
        },
      })

      vim.cmd.colorscheme("catppuccin")
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup()
    end,
  },

  { "nvim-tree/nvim-web-devicons" },
}
