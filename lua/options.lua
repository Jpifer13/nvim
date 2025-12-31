vim.g.mapleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.wrap = false
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8

vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.smartindent = true

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.clipboard = "unnamedplus"

-- Folding (code collapse like VSCode)
-- Using indent-based folding (simple and reliable)
vim.opt.foldmethod = "indent"
vim.opt.foldlevel = 99  -- Open all folds by default
vim.opt.foldlevelstart = 99  -- Start with all folds open
vim.opt.foldenable = true
vim.opt.foldcolumn = "1"  -- Show fold column

-- Nice visual feedback when copying
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

-- Auto-save after pause in typing (VSCode-style)
vim.opt.updatetime = 1000  -- Save after 1 second of inactivity (adjust as needed)

vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
  pattern = "*",
  callback = function()
    -- Check if auto-save is enabled (can be toggled with <Space>ta)
    if not vim.g.autosave_enabled then
      return
    end
    
    -- Only save if file is modifiable, modified, and has a name
    if vim.bo.modifiable and vim.bo.modified and vim.fn.expand("%") ~= "" then
      -- Silently save
      vim.cmd("silent! write")
      -- Optional: show a subtle message (uncomment if you want feedback)
      -- vim.notify("Auto-saved", vim.log.levels.INFO)
    end
  end,
})

-- (Optional) make terminal open ready to type
-- vim.api.nvim_create_autocmd("TermOpen", {
--   pattern = "*",
--   command = "startinsert",
-- })
