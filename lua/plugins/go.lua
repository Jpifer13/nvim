return {
  -- Delve debugging. nvim-dap-go registers the "go" adapter and the
  -- debug-the-test-under-the-cursor helpers; the existing <leader>d* keymaps and
  -- dap-ui then work unchanged. Keymaps live in lua/go/init.lua (buffer-local).
  --
  -- gopls itself needs no plugin: it is configured in lua/lsp.lua through the
  -- native vim.lsp.config API like the other servers.
  {
    "leoluz/nvim-dap-go",
    ft = "go",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      local mason_dlv = vim.fn.stdpath("data") .. "/mason/bin/dlv"
      require("dap-go").setup({
        delve = {
          -- Mason's delve, so it need not be on the shell PATH nvim inherited.
          path = vim.fn.executable(mason_dlv) == 1 and mason_dlv or "dlv",
        },
      })
    end,
  },
}
