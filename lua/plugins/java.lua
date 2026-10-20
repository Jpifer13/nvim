return {
  -- jdtls needs more than vim.lsp.config can express (per-project data dir,
  -- Eclipse bundles, extended client capabilities, refactoring commands that
  -- are not in the LSP spec). nvim-jdtls provides exactly that.
  --
  -- Configuration lives in lua/java/, not here: see lua/java/jdtls.lua, which
  -- after/ftplugin/java.lua starts.
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
    dependencies = { "mfussenegger/nvim-dap" },
  },
}
