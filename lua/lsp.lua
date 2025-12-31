-- LSP Configuration using Neovim 0.11+ native API
-- Mason auto-installs the servers

-- Capabilities (tell LSP we support completion)
local capabilities = vim.lsp.protocol.make_client_capabilities()
local cmp_lsp_ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
if cmp_lsp_ok then
  capabilities = cmp_lsp.default_capabilities(capabilities)
end

-- LSP keybinds (language actions, not motion changes)
local on_attach = function(client, bufnr)
  local opts = { buffer = bufnr, silent = true }
  
  -- Navigation
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
  vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
  vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
  vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, opts)
  
  -- References - use Telescope if available, fallback to default
  vim.keymap.set("n", "gr", function()
    local has_telescope, builtin = pcall(require, "telescope.builtin")
    if has_telescope then
      builtin.lsp_references()
    else
      vim.lsp.buf.references()
    end
  end, opts)
  
  -- Documentation & Info
  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
  
  -- Refactoring
  vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
  vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
  
  -- Formatting
  vim.keymap.set("n", "<leader>f", function()
    vim.lsp.buf.format({ async = true })
  end, opts)
  
  -- Diagnostics
  vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
  vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
  vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, opts)
  
  -- Debug: print message when LSP attaches
  vim.notify("LSP attached: " .. client.name, vim.log.levels.INFO)
end

-- Helper function to find Python path
local function get_python_path(workspace)
  -- Use activated virtualenv
  if vim.env.VIRTUAL_ENV then
    return vim.fn.join({vim.env.VIRTUAL_ENV, 'bin', 'python'}, '/')
  end

  -- Find and use virtualenv in workspace directory
  for _, pattern in ipairs({'*', '.*'}) do
    local match = vim.fn.glob(vim.fn.join({workspace, pattern, 'pyvenv.cfg'}, '/'))
    if match ~= '' then
      return vim.fn.join({vim.fn.fnamemodify(match, ':h'), 'bin', 'python'}, '/')
    end
  end
  
  -- Check common venv names
  for _, venv_name in ipairs({'.venv', 'venv', 'env'}) do
    local venv_path = vim.fn.join({workspace, venv_name, 'bin', 'python'}, '/')
    if vim.fn.executable(venv_path) == 1 then
      return venv_path
    end
  end

  -- Fallback to system Python
  return vim.fn.exepath('python3') or vim.fn.exepath('python') or 'python'
end

-- Configure servers using native Neovim 0.11+ API
vim.lsp.config("pyright", {
  cmd = { "pyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile", "pyrightconfig.json", ".git" },
  capabilities = capabilities,
  on_attach = on_attach,
  on_new_config = function(config, root_dir)
    config.settings.python.pythonPath = get_python_path(root_dir)
  end,
  settings = {
    python = {
      pythonPath = get_python_path(vim.fn.getcwd()),
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
        typeCheckingMode = "basic",
      },
    },
  },
})

vim.lsp.config("ts_ls", {
  cmd = { "typescript-language-server", "--stdio" },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
  capabilities = capabilities,
  on_attach = on_attach,
})

vim.lsp.config("lua_ls", {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = { ".luarc.json", ".luacheckrc", ".stylua.toml", "stylua.toml", ".git" },
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = {
        globals = { "vim" },
      },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },
      telemetry = { enable = false },
    },
  },
})

vim.lsp.config("yamlls", {
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml", "yaml.docker-compose" },
  root_markers = { ".git" },
  capabilities = capabilities,
  on_attach = on_attach,
})

-- Enable servers (they'll start when you open a matching file)
vim.lsp.enable({ "pyright", "ts_ls", "lua_ls", "yamlls" })

-- Commands for LSP management
vim.api.nvim_create_user_command("LspRestart", function()
  vim.lsp.stop_client(vim.lsp.get_clients())
  vim.defer_fn(function()
    vim.cmd("edit")
  end, 100)
  vim.notify("LSP restarted", vim.log.levels.INFO)
end, { desc = "Restart LSP servers" })

vim.api.nvim_create_user_command("LspPythonPath", function()
  local python_path = get_python_path(vim.fn.getcwd())
  vim.notify("Python path: " .. python_path, vim.log.levels.INFO)
  print("Python path: " .. python_path)
end, { desc = "Show Python path used by LSP" })
