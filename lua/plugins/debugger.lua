return {
  -- Core DAP
  {
    "mfussenegger/nvim-dap",
  },

  -- UI panels (variables, stack, breakpoints, etc.)
  {
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup()

      -- Auto-open/close UI like VS Code
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },

  -- Python DAP (uses debugpy from your selected python)
  {
    "mfussenegger/nvim-dap-python",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      local function python_path()
        local venv = vim.fn.getcwd() .. "/.venv/bin/python"
        if vim.fn.executable(venv) == 1 then
          return venv
        end
        return "python3"
      end

      require("dap-python").setup(python_path())
    end,
  },
}
