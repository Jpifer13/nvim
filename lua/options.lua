vim.g.mapleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.wrap = false
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.scrolloff = 8

-- Set terminal tab title to current working directory basename
vim.opt.title = true
vim.opt.titlestring = '%{fnamemodify(getcwd(), ":t")}'

vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.smartindent = true

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.clipboard = "unnamedplus"

-- Use OSC 52 for clipboard over SSH (no xclip/xsel needed on remote)
if os.getenv("SSH_TTY") then
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
      ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
    },
  }
end

-- Folding (code collapse like VSCode)
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

vim.api.nvim_create_autocmd({ "InsertLeave", "CursorHold", "CursorHoldI" }, {
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

-- Enhanced visual settings for more color
vim.opt.list = true  -- Show invisible characters
vim.opt.listchars = {
  tab = "→ ",
  trail = "·",
  extends = "⟩",
  precedes = "⟨",
  nbsp = "␣",
}

-- Make cursor line more visible
vim.api.nvim_set_hl(0, "CursorLine", { bg = "#2a2a3a" })
vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#f38ba8", bold = true })

-- Make line numbers more colorful
vim.api.nvim_set_hl(0, "LineNr", { fg = "#6c7086" })
vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "#585b70" })
vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#585b70" })

-- Enable filetype detection (required for proper plugin behavior)
vim.cmd([[
  filetype plugin indent on
]])
