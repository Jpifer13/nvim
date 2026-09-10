-- Godot debug adapter.
--
-- Godot 4 ships a DAP server (Editor Settings -> Network -> Debug Adapter).
-- Requires "Debug with External Editor" enabled in the Script view's debug
-- settings. Reuses the nvim-dap/dap-ui setup in lua/plugins/debugger.lua, so
-- all the existing <leader>d* keymaps work unchanged.

local detect = require("godot.detect")

local M = {}

M.host = vim.env.GODOT_DAP_HOST or "127.0.0.1"
M.port = tonumber(vim.env.GODOT_DAP_PORT) or 6006

function M.reachable()
  return detect.port_open(M.host, M.port)
end

function M.setup()
  local ok, dap = pcall(require, "dap")
  if not ok then
    return false
  end

  local root = detect.root()
  if not root then
    return false
  end

  dap.adapters.godot = {
    type = "server",
    host = M.host,
    port = M.port,
  }

  dap.configurations.gdscript = {
    {
      type = "godot",
      request = "launch",
      name = "Godot: Launch main scene",
      project = root,
      scene = "main",
    },
    {
      type = "godot",
      request = "launch",
      name = "Godot: Launch current scene",
      project = root,
      scene = "current",
    },
    {
      type = "godot",
      request = "launch",
      name = "Godot: Launch with collision + navigation shapes",
      project = root,
      scene = "main",
      debug_collisions = true,
      debug_navigation = true,
    },
    {
      type = "godot",
      request = "attach",
      name = "Godot: Attach to running game",
      project = root,
      address = M.host,
      port = M.port,
    },
  }

  -- Let <leader>dc work from a .tscn/.tres buffer too.
  dap.configurations.gdresource = dap.configurations.gdscript

  return true
end

return M
