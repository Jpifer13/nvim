return {
  -- Mason: LSP/DAP/Linter installer
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup({
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          },
        },
      })
      
      -- Auto-install language servers on first launch
      local mason_registry = require("mason-registry")
      local servers = {
        "pyright",
        "typescript-language-server",
        "lua-language-server",
        "yaml-language-server",
        "debugpy",
        -- Java. jdtls is started by after/ftplugin/java.lua via lua/java/jdtls.lua,
        -- not by vim.lsp.enable(); java-debug-adapter and java-test are loaded into
        -- it as Eclipse bundles to provide DAP and the test runner.
        "jdtls",
        "java-debug-adapter",
        "java-test",
        -- Go. gopls is enabled in lua/lsp.lua; delve backs nvim-dap-go
        -- (lua/plugins/go.lua); goimports is the conform formatter.
        "gopls",
        "delve",
        "goimports",
      }
      
      for _, server in ipairs(servers) do
        if not mason_registry.is_installed(server) then
          vim.notify("Installing " .. server .. "...", vim.log.levels.INFO)
          vim.cmd("MasonInstall " .. server)
        end
      end
    end,
  },

  -- Mason registry for checking installed packages
  {
    "williamboman/mason-registry",
    lazy = true,
  },
}

