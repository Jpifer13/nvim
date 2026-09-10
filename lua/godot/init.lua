-- Godot tooling, loaded only when the cwd sits inside a Godot project.
--
-- Deliberately thin: LSP capabilities/on_attach come from lua/lsp.lua, the
-- debugger UI and <leader>d* keymaps come from lua/plugins/debugger.lua, and
-- highlighting/indent come from the generic FileType autocmd in
-- lua/plugins/treesitter.lua. This module adds only the Godot-specific pieces.

local detect = require("godot.detect")

local M = {}

M.detect = detect

local function commands()
  local cmd = vim.api.nvim_create_user_command

  cmd("GodotRun", function()
    require("godot.run").run()
  end, { desc = "Godot: run the main scene" })

  cmd("GodotRunScene", function(opts)
    require("godot.run").run({ scene = opts.args ~= "" and opts.args or "current" })
  end, { nargs = "?", complete = "file", desc = "Godot: run the current (or given) scene" })

  cmd("GodotStop", function()
    if not require("godot.run").stop() then
      vim.notify("No Godot process running", vim.log.levels.INFO)
    end
  end, { desc = "Godot: stop the running game" })

  cmd("GodotConsole", function()
    require("godot.run").toggle_console()
  end, { desc = "Godot: toggle the output console" })

  cmd("GodotEditor", function()
    require("godot.run").editor()
  end, { desc = "Godot: open the project in the Godot editor" })

  cmd("GodotSceneTree", function(opts)
    require("godot.scene_tree").open(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", complete = "file", desc = "Godot: inspect the scene tree" })

  cmd("GodotDocs", function(opts)
    require("godot.docs").open(opts.args ~= "" and opts.args or nil)
  end, { nargs = "?", desc = "Godot: open the class reference for a symbol" })

  cmd("GodotLspAttach", function()
    require("godot.lsp").attach_all()
  end, { desc = "Godot: (re)connect the GDScript language server" })

  cmd("GodotParsers", function()
    require("godot.treesitter").install(require("godot.treesitter").parsers)
  end, { desc = "Godot: install/refresh the GDScript treesitter parsers" })

  cmd("GodotHealth", function()
    require("godot.health").report()
  end, { desc = "Godot: show the tooling health report" })
end

--- Returns true when the Godot tooling was actually enabled.
function M.setup()
  if not detect.is_project() then
    return false
  end

  -- project.godot itself is an ini-style resource file.
  vim.filetype.add({ filename = { ["project.godot"] = "gdresource" } })

  require("godot.treesitter").setup()
  require("godot.lsp").setup()
  require("godot.dap").setup()
  commands()

  return true
end

return M
