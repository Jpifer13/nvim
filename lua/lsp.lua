-- Neovim 0.11+ native LSP API
-- nvim-lspconfig provides server definitions; Mason installs servers.

-- Capabilities (tell LSP we support completion)
local capabilities = vim.lsp.protocol.make_client_capabilities()
local cmp_lsp_ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
if cmp_lsp_ok then
  capabilities = cmp_lsp.default_capabilities(capabilities)
end

-- LSP keybinds (language actions, not motion changes)
local on_attach = function(_, bufnr)
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
  vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
  vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
  vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
  vim.keymap.set("n", "<leader>f", function()
    vim.lsp.buf.format({ async = true })
  end, opts)
end

-- Configure servers
vim.lsp.config("pyright", {
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    python = {
      venvPath = ".",      -- look for venvs in the project
      venv = ".venv",      -- use ./venv
      pythonPath = "./.venv/bin/python",
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "workspace",
      },
    },
  },
})
vim.lsp.config("ts_ls",   { capabilities = capabilities, on_attach = on_attach })
vim.lsp.config("yamlls",  { capabilities = capabilities, on_attach = on_attach })

-- Enable servers
vim.lsp.enable({ "pyright", "ts_ls", "yamlls" })
