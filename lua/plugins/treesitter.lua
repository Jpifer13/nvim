return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local ok, configs = pcall(require, "nvim-treesitter.configs")
      if not ok then return end

      configs.setup({
        ensure_installed = {
          "python", "javascript", "typescript",
          "json", "yaml", "markdown",
          "markdown_inline", "bash", "lua",
        },
        highlight = { enable = true },
      })
    end,
  },
}
