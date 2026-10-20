-- awsdash (~/dev/personal/awsdash) in a persistent floating terminal.
-- Hiding keeps the session (and where you had drilled to); quitting awsdash with q
-- closes the window. The process inherits nvim's env, so AWS_PROFILE/AWS_REGION from
-- env-manager's .env apply -- and a profile switched inside awsdash comes back the
-- other way when the float closes (see M.adopt).
local M = {}

local buf, win

-- awsdash writes what it is pointed at here whenever a profile or region is switched
-- in its session window; reading it back when the float closes is what makes the rest
-- of Neovim (terminals, test runners, the debug flows) follow that choice.
local SESSION_FILE = vim.env.AWSDASH_SESSION_FILE
  or ((vim.env.AWSDASH_CACHE_DIR or ((vim.env.HOME or vim.fn.expand("~")) .. "/.cache/awsdash")) .. "/session.json")
local opened_at                       -- when this awsdash process started
local adopted                         -- the last "profile|region" taken from the file
local pushed_region, region_before    -- AWS_REGION is only ours while an override is on

local function read_session(since)
  local uv = vim.uv or vim.loop
  local stat = uv.fs_stat(SESSION_FILE)
  if not stat or not since or stat.mtime.sec < since then
    return nil -- no switch since this awsdash started; the file is from an older run
  end
  local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(SESSION_FILE), "\n"))
  return ok and type(data) == "table" and data.profile and data or nil
end

--- Take the profile awsdash was left on into this Neovim process (and .env, if it
--- already names the key), so what runs next uses the same account. Called when the
--- float closes; `opts.since` (default: when awsdash started) bounds how old a switch
--- may be, so an earlier run's leftovers are ignored.
function M.adopt(opts)
  local data = read_session((opts or {}).since or opened_at)
  if not data then
    return
  end
  local stamp = data.profile .. "|" .. (data.region or "")
  if stamp == adopted then
    return
  end
  adopted = stamp

  -- Only an explicit region switch inside awsdash sets AWS_REGION: pinning it otherwise
  -- would override the configured region of whatever profile is chosen next.
  if data.region and data.region ~= data.profile_region then
    if not pushed_region then
      region_before, pushed_region = vim.env.AWS_REGION, true
    end
    vim.fn.setenv("AWS_REGION", data.region)
  elseif pushed_region then
    vim.fn.setenv("AWS_REGION", region_before or vim.NIL)
    pushed_region = false
  end

  local persisted = require("env-manager").set({ AWS_PROFILE = data.profile }, { persist = true })
  vim.notify(
    ("AWS_PROFILE = %s · %s%s"):format(data.profile, data.region or "?", persisted > 0 and "  (.env updated)" or ""),
    vim.log.levels.INFO
  )
end

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
  M.adopt()
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
  opened_at = os.time()
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
