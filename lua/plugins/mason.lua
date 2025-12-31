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
      local servers = { "pyright", "typescript-language-server", "lua-language-server", "yaml-language-server" }
      
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

