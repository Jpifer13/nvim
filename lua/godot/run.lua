-- Run the game / open the editor, with Godot's stdout+stderr streamed into a
-- dedicated console buffer instead of a throwaway terminal.

local detect = require("godot.detect")

local M = {}

local job_id
local out_buf
local out_win
-- True when the next job chunk should start its own line rather than continue
-- the last one (i.e. right after we wrote a header/footer banner).
local fresh_line = true

---------------------------------------------------------------
-- Console buffer
---------------------------------------------------------------

local function strip_ansi(str)
  return (str:gsub("\27%[[%d;?]*[%a]", ""):gsub("\r", ""))
end

local function ensure_buf()
  if out_buf and vim.api.nvim_buf_is_valid(out_buf) then
    return out_buf
  end
  out_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[out_buf].buftype = "nofile"
  vim.bo[out_buf].bufhidden = "hide"
  vim.bo[out_buf].swapfile = false
  vim.bo[out_buf].filetype = "godot-console"
  pcall(vim.api.nvim_buf_set_name, out_buf, "Godot Console")

  vim.keymap.set("n", "q", function()
    M.close_console()
  end, { buffer = out_buf, nowait = true, desc = "Close Godot console" })
  vim.keymap.set("n", "<C-l>", function()
    M.clear()
  end, { buffer = out_buf, nowait = true, desc = "Clear Godot console" })

  return out_buf
end

--- Append a jobstart data chunk; chunk[1] continues the buffer's last line.
local function feed(data)
  if not data then
    return
  end
  local buf = ensure_buf()
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local chunks = {}
  for i, line in ipairs(data) do
    chunks[i] = strip_ansi(line)
  end
  if #chunks == 0 then
    return
  end

  vim.bo[buf].modifiable = true
  if fresh_line then
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, chunks)
    fresh_line = false
  else
    local last = vim.api.nvim_buf_line_count(buf)
    local tail = vim.api.nvim_buf_get_lines(buf, last - 1, last, false)[1] or ""
    chunks[1] = tail .. chunks[1]
    vim.api.nvim_buf_set_lines(buf, last - 1, last, false, chunks)
  end
  vim.bo[buf].modifiable = false

  -- Follow output only when the cursor is already parked at the bottom.
  if out_win and vim.api.nvim_win_is_valid(out_win) then
    local line_count = vim.api.nvim_buf_line_count(buf)
    local cursor = vim.api.nvim_win_get_cursor(out_win)[1]
    if cursor >= line_count - #chunks then
      pcall(vim.api.nvim_win_set_cursor, out_win, { line_count, 0 })
    end
  end
end

local function write(lines)
  local buf = ensure_buf()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  vim.bo[buf].modifiable = false
  fresh_line = true
end

function M.console_open()
  return out_win and vim.api.nvim_win_is_valid(out_win)
end

function M.open_console()
  local buf = ensure_buf()
  if M.console_open() then
    return
  end
  local prev = vim.api.nvim_get_current_win()
  vim.cmd("botright 15split")
  out_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(out_win, buf)
  vim.wo[out_win].number = false
  vim.wo[out_win].relativenumber = false
  vim.wo[out_win].wrap = false
  vim.wo[out_win].winfixheight = true
  vim.api.nvim_set_current_win(prev)
end

function M.close_console()
  if M.console_open() then
    vim.api.nvim_win_close(out_win, false)
  end
  out_win = nil
end

function M.toggle_console()
  if M.console_open() then
    M.close_console()
  else
    M.open_console()
  end
end

function M.clear()
  local buf = ensure_buf()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  vim.bo[buf].modifiable = false
  fresh_line = true
end

---------------------------------------------------------------
-- Running
---------------------------------------------------------------

function M.is_running()
  return job_id ~= nil
end

function M.stop()
  if not job_id then
    return false
  end
  vim.fn.jobstop(job_id)
  job_id = nil
  return true
end

--- opts.scene: "current" (the .tscn in the active buffer), a path, or nil (main scene)
--- opts.args:  extra CLI args appended to the command
function M.run(opts)
  opts = opts or {}

  local root = detect.root()
  if not root then
    vim.notify("Not inside a Godot project", vim.log.levels.WARN)
    return
  end

  local bin = detect.binary()
  if not bin then
    vim.notify("Godot executable not found — set $GODOT to its path", vim.log.levels.ERROR)
    return
  end

  M.stop()

  local cmd = { bin, "--path", root }

  if opts.scene == "current" then
    local file = vim.api.nvim_buf_get_name(0)
    if file:match("%.tscn$") then
      table.insert(cmd, file)
    else
      vim.notify("Current buffer is not a .tscn — running the main scene instead", vim.log.levels.WARN)
    end
  elseif type(opts.scene) == "string" then
    table.insert(cmd, opts.scene)
  end

  vim.list_extend(cmd, opts.args or {})

  M.open_console()
  write({ "", "▶ " .. table.concat(cmd, " "), string.rep("─", 60) })

  job_id = vim.fn.jobstart(cmd, {
    cwd = root,
    on_stdout = function(_, data)
      feed(data)
    end,
    on_stderr = function(_, data)
      feed(data)
    end,
    on_exit = function(_, code)
      job_id = nil
      write({ string.rep("─", 60), ("■ exited with code %d"):format(code), "" })
    end,
  })

  if job_id <= 0 then
    job_id = nil
    vim.notify("Failed to launch Godot", vim.log.levels.ERROR)
  end
end

--- Open the project in the Godot editor (detached; not piped to the console).
function M.editor()
  local root = detect.root()
  local bin = detect.binary()
  if not root then
    vim.notify("Not inside a Godot project", vim.log.levels.WARN)
    return
  end
  if not bin then
    vim.notify("Godot executable not found — set $GODOT to its path", vim.log.levels.ERROR)
    return
  end
  vim.fn.jobstart({ bin, "--path", root, "-e" }, { detach = true })
  vim.notify("Opening project in the Godot editor…", vim.log.levels.INFO)
end

return M
