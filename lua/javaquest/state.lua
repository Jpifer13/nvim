-- ---------------------------------------------------------------------------
-- Persistent state: only the things that CANNOT be derived from test results.
--
-- XP, level and per-module completion are all computed from the Surefire reports
-- every time, so they can never drift and cannot be farmed by re-running a green
-- test. What lives here is history: which days you ran tests (the streak), when
-- each achievement first unlocked (so it is celebrated once), and which
-- celebrations have already been shown.
-- ---------------------------------------------------------------------------

local M = {}

local function state_dir()
  return vim.fn.stdpath("data") .. "/javaquest"
end

local function state_path(root)
  -- One file per project, named after the directory with the path hashed in so
  -- two checkouts with the same basename cannot collide.
  local base = vim.fn.fnamemodify(root, ":t")
  local hash = vim.fn.sha256(root):sub(1, 8)
  return state_dir() .. "/" .. base .. "-" .. hash .. ".json"
end

local function today()
  return os.date("%Y-%m-%d")
end

local EMPTY = {
  days = {},          -- { "2026-09-30" = true }
  unlocked = {},      -- { achievement_id = timestamp }
  celebrated = {},    -- { key = true }
  first_seen = {},    -- { module_dir = timestamp }
  runs = 0,
}

function M.load(root)
  local path = state_path(root)
  if not vim.uv.fs_stat(path) then
    return vim.deepcopy(EMPTY)
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return vim.deepcopy(EMPTY)
  end
  local decoded
  ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok or type(decoded) ~= "table" then
    return vim.deepcopy(EMPTY)
  end
  -- Merge over the defaults, so a state file written by an older version still loads.
  return vim.tbl_deep_extend("force", vim.deepcopy(EMPTY), decoded)
end

function M.save(root, state)
  vim.fn.mkdir(state_dir(), "p")
  local ok, encoded = pcall(vim.json.encode, state)
  if not ok then
    return
  end
  pcall(vim.fn.writefile, { encoded }, state_path(root))
end

--- Records that a test run happened now. Drives the streak and the time-of-day
--- achievements.
function M.record_run(root, state)
  state.days[today()] = true
  state.runs = (state.runs or 0) + 1
  local hour = tonumber(os.date("%H"))
  if hour >= 0 and hour < 5 then
    state.night_owl = true
  end
  M.save(root, state)
end

--- Consecutive days ending today (or yesterday, so a streak survives until you
--- next sit down rather than resetting at midnight).
function M.streak(state)
  local days = state.days or {}
  local function has(offset)
    return days[os.date("%Y-%m-%d", os.time() - offset * 86400)] == true
  end

  local start
  if has(0) then
    start = 0
  elseif has(1) then
    start = 1
  else
    return 0
  end

  local count = 0
  local offset = start
  while has(offset) do
    count = count + 1
    offset = offset + 1
  end
  return count
end

function M.mark_first_seen(root, state, module_dir)
  state.first_seen = state.first_seen or {}
  if not state.first_seen[module_dir] then
    state.first_seen[module_dir] = os.time()
    M.save(root, state)
  end
end

return M
