-- Entry point: keep this file small.
require("options")
require("keymaps")
require("plugins")
require("lsp")
require("env-manager").setup()
require("java").setup() -- :Java* commands; jdtls starts from after/ftplugin/java.lua
require("godot").setup() -- no-op outside a Godot project
