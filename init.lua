-- Entry point: keep this file small.
require("options")
require("keymaps")
require("plugins")
require("lsp")
require("env-manager").setup()
require("godot").setup() -- no-op outside a Godot project
