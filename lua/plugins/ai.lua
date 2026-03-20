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
        terminal_cmd = "/opt/homebrew/bin/claude --model claude-opus-4-6",
        terminal = {
          split_side = "right",
          split_width_percentage = 0.30,
          provider = "snacks",
        },
      })
    end,
  },
}
