return {
  {
    "folke/zen-mode.nvim",
    opts = {
      window = {
        backdrop = 1,
        width = 120,        -- or 0.85 for percentage
        height = 1,
        options = {
          signcolumn = "no",
          number = true,
          relativenumber = false,
          cursorline = true,
        },
      },
      plugins = {
        options = {
          enabled = true,
          ruler = false,
          showcmd = false,
          laststatus = 0,   -- hide lualine
        },
        gitsigns = { enabled = false },
        nvimtree = { enabled = false },
        tmux = { enabled = false },
      },
    },
  },
}
