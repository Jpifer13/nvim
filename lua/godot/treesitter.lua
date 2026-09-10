-- Treesitter parsers for GDScript, .tscn/.tres resources, and shaders.
--
-- Highlighting and indent attachment are handled generically by the FileType
-- autocmd in lua/plugins/treesitter.lua, which covers any filetype with an
-- available parser. This module only makes sure the Godot parsers are present
-- up front (rather than on the second time you open a .gd file) and exposes
-- the state :GodotHealth reports on.

local parsers = require("treesitter_parsers")

local M = {}

M.parsers = { "gdscript", "godot_resource", "gdshader" }

function M.missing()
  return parsers.missing(M.parsers)
end

function M.install(langs)
  return parsers.install(langs or M.parsers)
end

function M.setup()
  -- nvim-treesitter already maps the gdresource filetype to the
  -- godot_resource parser; this is a no-op safety net if it ever stops.
  pcall(vim.treesitter.language.register, "godot_resource", "gdresource")

  -- Deferred so it never blocks startup.
  vim.schedule(function()
    M.install()
  end)
end

return M
