-- Entry point: keep this file small.
require("options")
require("keymaps")
require("plugins")
require("lsp")
require("env-manager").setup()
require("java").setup() -- :Java* commands; jdtls starts from after/ftplugin/java.lua
require("javaquest").setup() -- no-op unless a .javaquest.json is found above the file
require("go").setup() -- :Go* commands; keymaps attach from after/ftplugin/go.lua
require("godot").setup() -- no-op outside a Godot project
