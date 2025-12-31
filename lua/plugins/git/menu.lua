local M = {}

local function execute_git_action(action, gs)
  if action == "1" then
    gs.preview_hunk()
  elseif action == "2" then
    gs.stage_hunk()
  elseif action == "3" then
    gs.reset_hunk()
  elseif action == "4" then
    gs.undo_stage_hunk()
  elseif action == "5" then
    gs.blame_line({ full = true })
  elseif action == "6" then
    gs.toggle_current_line_blame()
  elseif action == "7" then
    gs.diffthis()
  elseif action == "8" then
    vim.cmd("DiffviewOpen")
  elseif action == "9" then
    vim.cmd("DiffviewFileHistory %")
  elseif action == "0" then
    vim.cmd("Neogit")
  elseif action == "n" then
    gs.next_hunk()
  elseif action == "p" then
    gs.prev_hunk()
  end
end

local function get_menu_lines()
  return {
    "GIT ACTIONS (GitLens Style)",
    "═══════════════════════════════════════════════════════",
    "",
    "📝 HUNK ACTIONS (Current Location)",
    "  1    Preview hunk",
    "  2    Stage hunk",
    "  3    Reset hunk (discard changes)",
    "  4    Undo stage hunk",
    "",
    "🔍 BLAME & INFO",
    "  5    Show full blame (popup)",
    "  6    Toggle inline blame",
    "",
    "🔀 DIFF & HISTORY",
    "  7    Diff this file",
    "  8    Open full diff view (all changes)",
    "  9    File commit history",
    "",
    "📊 GIT STATUS",
    "  0    Open Neogit (full git UI)",
    "",
    "🧭 NAVIGATION",
    "  n    Next hunk",
    "  p    Previous hunk",
    "",
    "═══════════════════════════════════════════════════════",
    "Press a key to execute action, or 'q'/'Esc' to close",
  }
end

function M.open()
  local gs = require("gitsigns")
  
  -- Check if we're in a git repo (simple check)
  if vim.fn.isdirectory(".git") == 0 then
    -- Try to check if we're in a subdirectory of a git repo
    local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
    if vim.v.shell_error ~= 0 then
      vim.notify("Not in a git repository", vim.log.levels.WARN)
      return
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, get_menu_lines())
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "markdown"

  local width = 60
  local height = 28
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Git Menu ",
    title_pos = "center",
  })

  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = true

  -- Close handlers
  local function close_menu()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set("n", "q", close_menu, { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", close_menu, { buffer = buf, silent = true })

  -- Action handlers
  for _, key in ipairs({ "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "n", "p" }) do
    vim.keymap.set("n", key, function()
      close_menu()
      vim.schedule(function()
        execute_git_action(key, gs)
      end)
    end, { buffer = buf, silent = true })
  end
end

return M

