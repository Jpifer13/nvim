-- awsdash (~/dev/personal/awsdash) in a persistent floating terminal.
-- Hiding keeps the session (and where you had drilled to); quitting awsdash with q
-- closes the window. The process inherits nvim's env, so AWS_PROFILE/AWS_REGION from
-- env-manager's .env apply.
local M = {}

local buf, win

local function valid_buf()
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function valid_win()
  return win and vim.api.nvim_win_is_valid(win)
end

local function open_win()
  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.85)
  win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " awsdash ",
    title_pos = "center",
  })
  vim.cmd("startinsert")
end

function M.hide()
  if valid_win() then
    vim.api.nvim_win_close(win, false)
    win = nil
  end
end

function M.toggle()
  if valid_win() then
    return M.hide()
  end
  if valid_buf() then
    return open_win()
  end

  if vim.fn.executable("awsdash") == 0 then
    vim.notify("awsdash not on PATH (pipx install -e ~/dev/personal/awsdash)", vim.log.levels.ERROR)
    return
  end

  buf = vim.api.nvim_create_buf(false, true)
  open_win()
  vim.fn.termopen({ "awsdash" }, {
    on_exit = function()
      vim.schedule(function()
        M.hide()
        if valid_buf() then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
        buf = nil
      end)
    end,
  })
  -- nowait: the global terminal-mode <leader>AT (hide Claude) would otherwise make
  -- this wait timeoutlen.
  vim.keymap.set("t", "<leader>A", M.hide, { buffer = buf, nowait = true, desc = "Hide awsdash" })
end

return M
