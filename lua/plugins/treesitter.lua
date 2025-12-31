return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      local ok, configs = pcall(require, "nvim-treesitter.configs")
      if not ok then return end

      configs.setup({
        -- Install parsers automatically
        ensure_installed = {
          "python", "javascript", "typescript",
          "json", "yaml", "markdown",
          "markdown_inline", "bash", "lua",
        },
        
        -- Install parsers synchronously (only on first install)
        sync_install = false,
        
        -- Auto-install missing parsers when entering buffer
        auto_install = true,
        
        highlight = { enable = true },
        indent = { enable = true },
        fold = { enable = true },  -- Enable treesitter folding
      })
    end,
  },
}
