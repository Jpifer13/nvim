-- env-manager.lua
-- Auto-loads .env from project root on startup.
-- Provides a floating editor to view/edit/add env vars and sync them
-- back to both the Neovim process and the .env file.

local M = {}

--- Resolve the .env path (project root = cwd)
local function env_path()
  return vim.fn.getcwd() .. "/.env"
end

--- Parse KEY=VALUE lines, ignoring comments and blanks.
--- Handles quoted values and inline comments.
local function parse_lines(lines)
  local vars = {}
  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed ~= "" and not trimmed:match("^#") then
      local key, value = trimmed:match("^([%w_]+)%s*=%s*(.*)")
      if key then
        -- Strip surrounding quotes if present
        value = value:gsub("^[\"'](.-)[\"']$", "%1")
        -- Strip inline comments (only outside quotes)
        value = value:gsub("%s+#.*$", "")
        vars[key] = value
      end
    end
  end
  return vars
end

--- Apply a table of env vars to Neovim's process environment.
local function apply_env(vars)
  for key, value in pairs(vars) do
    vim.fn.setenv(key, value)
  end
end

--- Load .env file and set all vars in the Neovim process.
--- Called on startup and can be called manually.
function M.load()
  local path = env_path()
  if vim.fn.filereadable(path) ~= 1 then
    return
  end
  local lines = vim.fn.readfile(path)
  local vars = parse_lines(lines)
  apply_env(vars)
  local count = vim.tbl_count(vars)
  vim.schedule(function()
    vim.notify("Loaded " .. count .. " env vars from .env", vim.log.levels.INFO)
  end)
end

--- Set env vars in the running Neovim process, and optionally keep .env in step.
--- `opts.persist` only rewrites keys the .env ALREADY defines: a profile switch made
--- elsewhere should not create a project file, nor add keys to one written by hand.
--- Returns how many lines of .env were updated.
function M.set(vars, opts)
  apply_env(vars)
  if not (opts and opts.persist) then
    return 0
  end
  local path = env_path()
  if vim.fn.filereadable(path) ~= 1 then
    return 0
  end
  local lines = vim.fn.readfile(path)
  local written = 0
  for key, value in pairs(vars) do
    for i, line in ipairs(lines) do
      if line:match("^%s*" .. vim.pesc(key) .. "%s*=") then
        lines[i] = key .. "=" .. value
        written = written + 1
        break
      end
    end
  end
  if written > 0 then
    vim.fn.writefile(lines, path)
  end
  return written
end

--- Track the editor state
local state = {
  buf = nil,
  win = nil,
}

local function is_open()
  return state.win
    and vim.api.nvim_win_is_valid(state.win)
    and vim.api.nvim_win_get_config(state.win).relative ~= ""
end

local function close()
  if is_open() then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  state.buf = nil
  state.win = nil
end

--- Save buffer contents → .env file + Neovim process env.
local function save_buffer()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local path = env_path()

  -- Write to file
  vim.fn.writefile(lines, path)

  -- Apply to process env
  local vars = parse_lines(lines)
  apply_env(vars)

  vim.bo[state.buf].modified = false
  vim.notify("Saved " .. vim.tbl_count(vars) .. " env vars", vim.log.levels.INFO)
end

--- Open the floating env editor.
function M.open()
  if is_open() then
    close()
    return
  end

  local path = env_path()

  -- Read existing .env or start with a blank template
  local lines
  if vim.fn.filereadable(path) == 1 then
    lines = vim.fn.readfile(path)
  else
    lines = { "# Add environment variables below (KEY=VALUE)", "" }
  end

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "sh" -- syntax highlight as shell
  vim.bo[buf].buftype = ""    -- allow normal :w behaviour
  vim.bo[buf].modified = false

  -- Float dimensions
  local width = math.floor(vim.o.columns * 0.6)
  local height = math.floor(vim.o.lines * 0.6)
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
    title = " .env editor ",
    title_pos = "center",
  })

  state.buf = buf
  state.win = win

  -- <CR> in normal mode saves and closes
  vim.keymap.set("n", "<CR>", function()
    save_buffer()
    close()
  end, { buffer = buf, desc = "Env: Save and close" })

  -- :w saves without closing
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      save_buffer()
    end,
  })

  -- q / Esc closes without saving
  vim.keymap.set("n", "q", close, { buffer = buf, desc = "Env: Close" })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, desc = "Env: Close" })
end

--- Setup: auto-load on startup, register keymap.
function M.setup()
  M.load()
  vim.keymap.set("n", "<leader>en", M.open, { desc = "Env: Edit .env vars" })
end

return M
