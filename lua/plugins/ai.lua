return {
  {
    "folke/snacks.nvim",
    lazy = false,
    opts = {},
  },

  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    config = function()
      require("claudecode").setup({
        terminal_cmd = (vim.fn.exepath("claude") or "claude") .. " --model claude-opus-4-6",
        terminal = {
          provider = "snacks",
          snacks_win_opts = {
            position = "float",
            width = 0.85,
            height = 0.8,
            border = "rounded",
          },
        },
        diff_opts = {
          open_in_new_tab = true,
        },
      })
    end,
  },
}
