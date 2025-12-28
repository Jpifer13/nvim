-- Safe “command” keymaps only (no Vim motion overrides)

vim.keymap.set("n", "<leader>w", ":w<CR>", { silent = true })
vim.keymap.set("n", "<leader>q", ":q<CR>", { silent = true })

-- File tree
vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true })

-- Telescope
vim.keymap.set("n", "<leader>ff", function()
  require("telescope.builtin").find_files()
end, { silent = true })

vim.keymap.set("n", "<leader>fg", function()
  require("telescope.builtin").live_grep()
end, { silent = true })

vim.keymap.set("n", "<leader>fb", function()
  require("telescope.builtin").buffers()
end, { silent = true })

-- Neogit (Git UI)
vim.keymap.set("n", "<leader>gs", ":Neogit<CR>", { silent = true })

-- Terminal Split Horizontal Bottom
vim.keymap.set("n", "<leader>t", function()
  vim.cmd("botright 12split | terminal")
end, { desc = "Terminal (bottom split)" })

-- Easier window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")

vim.keymap.set("n", "<leader>rp", function()
  vim.cmd("botright split | terminal ./.venv/bin/python " .. vim.fn.expand("%"))
end, { desc = "Run Python file (.venv)" })

-- Debugger (nvim-dap) - no function keys
local dap_ok, dap = pcall(require, "dap")
if dap_ok then
  -- Start/Continue
  vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Debug: Continue" })

  -- Step controls
  vim.keymap.set("n", "<leader>dn", dap.step_over, { desc = "Debug: Step Over" })
  vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Debug: Step Into" })
  vim.keymap.set("n", "<leader>do", dap.step_out, { desc = "Debug: Step Out" })

  -- Breakpoints
  vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
  vim.keymap.set("n", "<leader>dB", function()
    dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
  end, { desc = "Debug: Conditional Breakpoint" })

  -- REPL / utilities
  vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "Debug: REPL" })
  vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "Debug: Run Last" })
  vim.keymap.set("n", "<leader>dq", dap.terminate, { desc = "Debug: Terminate" })
end

local dapui_ok, dapui = pcall(require, "dapui")
if dapui_ok then
  vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Debug: Toggle UI" })
end
