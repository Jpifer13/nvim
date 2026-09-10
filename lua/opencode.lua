local M = {}

-- Persistent snacks terminal (created once, toggled thereafter)
local term = nil
local session_started = false

local WIN_OPTS = {
  win = {
    position = "float",
    width = 0.85,
    height = 0.8,
    border = "rounded",
  },
}

local function is_valid()
  return term ~= nil and term:buf_valid()
end

-- True when the opencode window is currently visible
function M.is_open()
  return term ~= nil and term:valid()
end

-- Create the opencode terminal on first open (with a session picker), then
-- toggle the same persistent terminal on subsequent calls.
function M.open()
  if session_started then
    if is_valid() then
      term:toggle()
    else
      -- Terminal was closed (e.g. opencode exited); start a fresh one
      term = require("snacks").terminal.open("opencode", WIN_OPTS)
    end
    return term
  end

  vim.ui.select(
    { "New session", "Continue last session" },
    { prompt = "OpenCode:" },
    function(choice)
      if not choice then return end
      session_started = true
      local cmd = choice == "Continue last session" and { "opencode", "--resume" } or "opencode"
      term = require("snacks").terminal.open(cmd, WIN_OPTS)
    end
  )
end

function M.close()
  if is_valid() then
    term:hide()
  end
end

return M
