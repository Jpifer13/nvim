-----------------------------------------------------------
-- Bootstrap lazy.nvim
-----------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-----------------------------------------------------------
-- Load plugin modules
-----------------------------------------------------------
local plugins = {}

local function extend(tbl)
  vim.list_extend(plugins, tbl)
end

extend(require("plugins.ui"))
extend(require("plugins.navigation"))
extend(require("plugins.git"))
extend(require("plugins.treesitter"))
extend(require("plugins.completion"))
extend(require("plugins.formatting"))
extend(require("plugins.ai"))
extend(require("plugins.debugger"))

-----------------------------------------------------------
-- Setup lazy.nvim
-----------------------------------------------------------
require("lazy").setup(plugins)
