-- =============================================================================
-- ssh_remote — SSH session manager for Neovim
--
-- Flow:
--   1. Telescope picker reads ~/.ssh/config
--   2. User selects a host
--   3. Bootstrap script is copied to the remote over SSH (non-interactive)
--   4. A floating terminal opens running the script interactively:
--        → checks each dependency, prompts y/n to install missing ones
--        → clones / updates the nvim config from the public repo
--        → on completion, drops the user into a live remote shell
-- =============================================================================

local M = {}

local ssh_config = require("ssh_remote.ssh_config")

-- Paths to shell scripts (same directory as this file)
local SCRIPT_DIR    = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local BOOTSTRAP_SH  = SCRIPT_DIR .. "/bootstrap.sh"
local CONNECT_SH    = SCRIPT_DIR .. "/connect.sh"

-- Active SSH windows: alias → { buf, win }
local ssh_windows = {}

-- =============================================================================
-- Floating window helpers
-- =============================================================================

local function make_float_win(buf, title)
  local width  = math.floor(vim.o.columns * 0.85)
  local height = math.floor(vim.o.lines   * 0.80)
  local row    = math.floor((vim.o.lines   - height) / 2)
  local col    = math.floor((vim.o.columns - width)  / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative  = "editor",
    width     = width,
    height    = height,
    row       = row,
    col       = col,
    style     = "minimal",
    border    = "rounded",
    title     = " " .. title .. " ",
    title_pos = "center",
  })

  vim.wo[win].number         = false
  vim.wo[win].relativenumber = false
  return win
end

-- =============================================================================
-- Open an SSH terminal
-- cmd  — the full shell command to run inside the floating terminal.
--        Defaults to a plain interactive SSH session.
-- =============================================================================

local function close_window(alias)
  local session = ssh_windows[alias]
  if not session then return end
  ssh_windows[alias] = nil
  if vim.api.nvim_win_is_valid(session.win) then
    vim.api.nvim_win_close(session.win, true)
  end
  if vim.api.nvim_buf_is_valid(session.buf) then
    vim.api.nvim_buf_delete(session.buf, { force = true })
  end
end

local function open_ssh_terminal(alias, cmd)
  -- If a live window for this alias already exists, bring it into focus
  local existing = ssh_windows[alias]
  if existing then
    if vim.api.nvim_buf_is_valid(existing.buf) then
      if not vim.api.nvim_win_is_valid(existing.win) then
        local win = make_float_win(existing.buf, "SSH: " .. alias)
        ssh_windows[alias].win = win
      end
      vim.api.nvim_set_current_win(ssh_windows[alias].win)
      vim.cmd("startinsert")
      return
    else
      ssh_windows[alias] = nil
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local win = make_float_win(buf, "SSH: " .. alias)

  vim.fn.termopen(cmd, {
    on_exit = function(_, code)
      vim.schedule(function()
        if code == 0 then
          -- Clean exit (user typed `exit`) — close the window automatically
          close_window(alias)
        else
          -- Non-zero exit means something went wrong — keep the window open
          -- so the user can read the error output, and set up q/Esc to dismiss
          ssh_windows[alias] = nil
          if vim.api.nvim_buf_is_valid(buf) then
            vim.notify(
              "[ssh-remote] Connection to " .. alias .. " ended with an error (exit " .. code .. ")",
              vim.log.levels.WARN
            )
            for _, key in ipairs({ "q", "<Esc>" }) do
              vim.keymap.set("n", key, function() close_window(alias) end, {
                buffer  = buf,
                silent  = true,
                nowait  = true,
                desc    = "Close SSH terminal",
              })
            end
          end
        end
      end)
    end,
  })

  ssh_windows[alias] = { buf = buf, win = win }

  -- If the user manually wipes the buffer (e.g. :bd), clean up tracking
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer   = buf,
    once     = true,
    callback = function()
      ssh_windows[alias] = nil
    end,
  })

  vim.cmd("startinsert")
end

-- =============================================================================
-- Connect: open the floating terminal running connect.sh
--
-- connect.sh handles everything:
--   1. Opens an SSH ControlMaster connection — password prompt appears here
--   2. Copies bootstrap.sh to the remote over the existing socket (no re-auth)
--   3. Runs the bootstrap interactively, then drops into a live shell
-- =============================================================================

function M.connect(alias)
  for _, path in ipairs({ CONNECT_SH, BOOTSTRAP_SH }) do
    if vim.fn.filereadable(path) == 0 then
      vim.notify("[ssh-remote] script not found: " .. path, vim.log.levels.ERROR)
      return
    end
  end

  local cmd = string.format("bash %s %s %s", CONNECT_SH, alias, BOOTSTRAP_SH)
  open_ssh_terminal(alias, cmd)
end

-- =============================================================================
-- Connect without bootstrapping — password prompt still works because
-- connect.sh opens the ControlMaster first, then drops straight to a shell.
-- =============================================================================

function M.connect_direct(alias)
  if vim.fn.filereadable(CONNECT_SH) == 0 then
    vim.notify("[ssh-remote] script not found: " .. CONNECT_SH, vim.log.levels.ERROR)
    return
  end

  local cmd = string.format("bash %s %s %s --skip-bootstrap", CONNECT_SH, alias, BOOTSTRAP_SH)
  open_ssh_terminal(alias, cmd)
end

-- =============================================================================
-- Telescope picker
-- =============================================================================

function M.pick()
  local ok_p,  pickers      = pcall(require, "telescope.pickers")
  local ok_f,  finders      = pcall(require, "telescope.finders")
  local ok_c,  conf         = pcall(require, "telescope.config")
  local ok_a,  actions      = pcall(require, "telescope.actions")
  local ok_s,  action_state = pcall(require, "telescope.actions.state")

  if not (ok_p and ok_f and ok_c and ok_a and ok_s) then
    vim.notify("[ssh-remote] telescope.nvim is required", vim.log.levels.ERROR)
    return
  end

  local hosts   = ssh_config.parse()
  local entries = {}

  for _, host in ipairs(hosts) do
    local active = ssh_windows[host.alias]
      and vim.api.nvim_buf_is_valid(ssh_windows[host.alias].buf)

    local prefix  = active and "● " or "  "
    local display = prefix .. host.alias

    if host.hostname ~= host.alias then
      display = display .. "  →  " .. host.hostname
    end
    if host.user then
      display = display .. "  (" .. host.user .. ")"
    end

    table.insert(entries, {
      display = display,
      ordinal = host.alias .. " " .. host.hostname,
      alias   = host.alias,
    })
  end

  table.insert(entries, {
    display = "  + Add new connection",
    ordinal = "__new__",
    alias   = "__new__",
  })

  pickers.new({}, {
    prompt_title = "SSH Remote",
    finder = finders.new_table({
      results     = entries,
      entry_maker = function(e)
        return { value = e, display = e.display, ordinal = e.ordinal }
      end,
    }),
    sorter = conf.values.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)

      -- <CR>  →  bootstrap then connect
      actions.select_default:replace(function()
        local sel = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if sel.value.alias == "__new__" then
          M.add_host()
        else
          M.connect(sel.value.alias)
        end
      end)

      -- <C-s>  →  skip bootstrap, open SSH directly
      map({ "i", "n" }, "<C-s>", function()
        local sel = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if sel.value.alias ~= "__new__" then
          M.connect_direct(sel.value.alias)
        end
      end)

      return true
    end,
  }):find()
end

-- =============================================================================
-- Add a new host entry to ~/.ssh/config
-- =============================================================================

function M.add_host()
  vim.ui.input({ prompt = "Host alias: " }, function(alias)
    if not alias or alias:match("^%s*$") then return end
    alias = alias:match("^%s*(.-)%s*$")

    vim.ui.input({ prompt = "HostName (IP or domain): " }, function(hostname)
      if not hostname or hostname:match("^%s*$") then return end
      hostname = hostname:match("^%s*(.-)%s*$")

      vim.ui.input({ prompt = "User (leave blank to skip): " }, function(user)
        local u = (user and user:match("^%s*(.-)%s*$") ~= "") and user:match("^%s*(.-)%s*$") or nil

        if ssh_config.append(alias, hostname, u, nil) then
          vim.notify("[ssh-remote] Added '" .. alias .. "' to ~/.ssh/config", vim.log.levels.INFO)
        else
          vim.notify("[ssh-remote] Could not write to ~/.ssh/config", vim.log.levels.ERROR)
        end

        vim.schedule(M.pick)
      end)
    end)
  end)
end

return M
