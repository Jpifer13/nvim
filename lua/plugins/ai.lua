return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false, -- never set to "*"
    build = vim.fn.has("win32") ~= 0
      and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
      or "make",

    opts = {
      instructions_file = "avante.md",

      -- ✅ Provider name EXACTLY as README
      provider = "claude",

      providers = {
        claude = {
          endpoint = "https://api.anthropic.com",

          -- Claude Sonnet 4.5 (your requested model)
          model = "claude-sonnet-4-5-20250929",

          timeout = 30000,

          extra_request_body = {
            temperature = 0,
            max_tokens = 64000,
          },
        },
      },
    },

    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      "nvim-treesitter/nvim-treesitter",
      "hrsh7th/nvim-cmp",
    },
  },
}
