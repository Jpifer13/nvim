-- Go formatting is gofmt's call, not ours: real tabs, shown 4 wide.
vim.bo.expandtab = false
vim.bo.tabstop = 4
vim.bo.shiftwidth = 4
vim.bo.softtabstop = 0

require("go").attach(vim.api.nvim_get_current_buf())
