local M = {}

-- Keep a persistent reference so we can reuse the same terminal session
-- (so ae/start exports stay in that shell)
local STATE = {
  term_job_id = nil,
}

local function ensure_bottom_terminal()
  -- If the current buffer is a terminal, reuse it and remember it
  if vim.bo.buftype == "terminal" and vim.b.terminal_job_id then
    STATE.term_job_id = vim.b.terminal_job_id
    return STATE.term_job_id
  end

  -- If we already have a remembered terminal job, try to reuse it
  if STATE.term_job_id and STATE.term_job_id ~= 0 then
    return STATE.term_job_id
  end

  -- Otherwise open a bottom terminal split and remember it
  vim.cmd("botright 12split | terminal")
  STATE.term_job_id = vim.b.terminal_job_id
  return STATE.term_job_id
end

local function send_to_term(job_id, lines)
  if not job_id or job_id == 0 then
    vim.notify("No terminal job id found. Open a terminal first.", vim.log.levels.ERROR)
    return
  end
  for _, line in ipairs(lines) do
    vim.api.nvim_chan_send(job_id, line .. "\n")
  end
end

local function get_aws_profiles(cb)
  vim.system({ "aws", "configure", "list-profiles" }, { text = true }, function(res)
    if res.code ~= 0 then
      vim.schedule(function()
        vim.notify("Failed to list AWS profiles.\n" .. (res.stderr or ""), vim.log.levels.ERROR)
      end)
      return
    end

    local items = {}
    for line in (res.stdout or ""):gmatch("[^\r\n]+") do
      if line and line ~= "" then
        table.insert(items, line)
      end
    end

    vim.schedule(function()
      cb(items)
    end)
  end)
end

local function start_fastapi_in_terminal(profile)
  local job_id = ensure_bottom_terminal()

  -- Stable debug command:
  -- - no --reload (keeps breakpoints reliable)
  -- - --wait-for-client (attach first, then run)
  -- - -Xfrozen_modules=off (fixes warning and missed breaks)
  --
  -- FastAPI stays on port 8000 by default; we keep --port 8000 explicitly.
  local cmd =
    "python -Xfrozen_modules=off -m debugpy --listen 5678 --wait-for-client -m uvicorn app:fast_app --port 8000"

  send_to_term(job_id, {
    "ae " .. profile,
    "start",
    cmd,
  })

  -- Auto-attach after a delay (gives time to click session login popup)
  -- debugpy is waiting for us with --wait-for-client
  vim.defer_fn(function()
    local ok, dap = pcall(require, "dap")
    if not ok then return end

    dap.run({
      type = "python",
      request = "attach",
      name = "Attach (debugpy :5678)",
      connect = { host = "127.0.0.1", port = 5678 },
      justMyCode = true,
      -- Helps ensure breakpoints map to the right files
      pathMappings = {
        { localRoot = vim.fn.getcwd(), remoteRoot = vim.fn.getcwd() },
      },
    })
  end, 5000)
end

function M.pick_and_debug()
  get_aws_profiles(function(profiles)
    if #profiles == 0 then
      vim.notify("No AWS profiles found (aws configure list-profiles returned empty).", vim.log.levels.WARN)
      return
    end

    local ok, pickers = pcall(require, "telescope.pickers")
    local ok2, finders = pcall(require, "telescope.finders")
    local ok3, conf = pcall(require, "telescope.config")
    local ok4, actions = pcall(require, "telescope.actions")
    local ok5, action_state = pcall(require, "telescope.actions.state")
    if not (ok and ok2 and ok3 and ok4 and ok5) then
      vim.notify("Telescope is required for the AWS profile picker.", vim.log.levels.ERROR)
      return
    end

    pickers
      .new({}, {
        prompt_title = "AWS Profile (ae)",
        finder = finders.new_table({ results = profiles }),
        sorter = conf.values.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, _)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            if not selection or not selection[1] then return end
            start_fastapi_in_terminal(selection[1])
          end)
          return true
        end,
      })
      :find()
  end)
end

return M
