-- ---------------------------------------------------------------------------
-- The sidebar panel.
--
-- A rendered scratch buffer, not a terminal: that way lines can carry actions
-- (<CR> opens the file a line refers to) and colours, which a shell pane cannot.
-- Same approach as lua/cheatsheet.lua.
-- ---------------------------------------------------------------------------

local detect = require("javaquest.detect")
local progressor = require("javaquest.progress")
local statestore = require("javaquest.state")
local game = require("javaquest.game")

local M = {}

local win, buf
local WIDTH = 42

-- Each rendered line can carry an action, keyed by line number.
local actions = {}

-- ---------------------------------------------------------------------------
-- Highlights
-- ---------------------------------------------------------------------------

local NS = vim.api.nvim_create_namespace("javaquest")

local function setup_highlights()
  local groups = {
    JavaQuestTitle = { link = "Title" },
    JavaQuestGoal = { link = "Comment" },
    JavaQuestLevel = { link = "Constant" },
    JavaQuestXP = { link = "Number" },
    JavaQuestStreak = { link = "WarningMsg" },
    JavaQuestBarFull = { link = "String" },
    JavaQuestBarEmpty = { link = "NonText" },
    JavaQuestDone = { link = "DiagnosticOk" },
    JavaQuestActive = { link = "DiagnosticInfo" },
    JavaQuestTodo = { link = "NonText" },
    JavaQuestFail = { link = "DiagnosticError" },
    JavaQuestHeader = { link = "Function" },
    JavaQuestHint = { link = "Comment" },
    JavaQuestKey = { link = "Special" },
    JavaQuestLocked = { link = "NonText" },
    JavaQuestUnlocked = { link = "Identifier" },
  }
  for name, opts in pairs(groups) do
    if vim.fn.hlexists(name) == 0 then
      vim.api.nvim_set_hl(0, name, opts)
    end
  end
end

-- ---------------------------------------------------------------------------
-- Rendering helpers
-- ---------------------------------------------------------------------------

local Buffer = {}
Buffer.__index = Buffer

local function new_buffer()
  return setmetatable({ lines = {}, marks = {}, actions = {} }, Buffer)
end

function Buffer:add(text, highlights, action)
  table.insert(self.lines, text or "")
  local lnum = #self.lines
  for _, hl in ipairs(highlights or {}) do
    table.insert(self.marks, { lnum = lnum - 1, from = hl[1], to = hl[2], group = hl[3] })
  end
  if action then
    self.actions[lnum] = action
  end
  return lnum
end

--- Adds a bar as two highlighted segments so the filled part is coloured.
function Buffer:add_bar(prefix, current, total, width, suffix)
  local bar = game.bar(current, total, width)
  local text = prefix .. bar .. (suffix or "")
  local start = #prefix
  local filled = select(2, bar:gsub("█", "")) -- count of filled blocks
  local byte_per_block = 3 -- these are 3-byte UTF-8 characters
  self:add(text, {
    { start, start + filled * byte_per_block, "JavaQuestBarFull" },
    { start + filled * byte_per_block, start + width * byte_per_block, "JavaQuestBarEmpty" },
  })
end

local function truncate(text, width)
  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  return vim.fn.strcharpart(text, 0, width - 1) .. "…"
end

--- Word wrap, returning a list of lines that each fit `width`.
local function wrap(text, width)
  local out, line = {}, ""
  for word in tostring(text):gmatch("%S+") do
    local candidate = (line == "") and word or (line .. " " .. word)
    if vim.fn.strdisplaywidth(candidate) > width and line ~= "" then
      table.insert(out, line)
      line = word
    else
      line = candidate
    end
  end
  if line ~= "" then
    table.insert(out, line)
  end
  return out
end

--- A section header padded to a fixed width, so they all line up.
local function header(label, width)
  local text = "  ── " .. label .. " "
  local pad = width - vim.fn.strdisplaywidth(text)
  return text .. string.rep("─", math.max(0, pad))
end

-- ---------------------------------------------------------------------------
-- The panel content
-- ---------------------------------------------------------------------------

local function render_full(b, config, progress, state, xp, level, earned, next_step)
  local inner = WIDTH - 2

  b:add("  ⚔  " .. config.title:upper(), { { 0, 200, "JavaQuestTitle" } })
  if config.goal then
    for _, line in ipairs(wrap(config.goal, inner - 2)) do
      b:add("  " .. line, { { 0, 200, "JavaQuestGoal" } })
    end
  end
  b:add("")

  -- level + xp
  local level_line = ("  Lv %d  %s"):format(level.index, level.name)
  b:add(level_line, { { 2, 8, "JavaQuestLevel" }, { 8, 200, "JavaQuestLevel" } })

  local xp_text
  if level.next_at then
    xp_text = ("  %d / %d XP"):format(xp, level.next_at)
  else
    xp_text = ("  %d XP  (max level)"):format(xp)
  end
  b:add(xp_text, { { 0, 200, "JavaQuestXP" } })

  if level.span then
    b:add_bar("  ", level.into, level.span, 24)
  else
    b:add_bar("  ", 1, 1, 24)
  end

  local streak = statestore.streak(state)
  local streak_text = streak > 0 and ("  %d day streak"):format(streak) or "  no streak yet"
  b:add(streak_text, { { 0, 200, streak > 0 and "JavaQuestStreak" or "JavaQuestTodo" } })
  b:add("")

  -- overall
  b:add(header("PROGRESS", WIDTH), { { 0, 200, "JavaQuestHeader" } })
  local pct = progress.tests > 0 and math.floor(progress.passing / progress.tests * 100) or 0
  b:add_bar("  ", progress.passing, progress.tests, 24, ("  %d%%"):format(pct))
  b:add(("  %d / %d tests  ·  %d/%d modules"):format(
    progress.passing, progress.tests, progress.complete_modules, #config.modules
  ), { { 0, 200, "JavaQuestXP" } })
  b:add("")

  -- modules
  for _, module in ipairs(progress.modules) do
    local cfg = module.config
    local number = cfg.dir:match("^(%d+)") or "??"
    local icon, group
    if module.complete then
      icon, group = "✓", "JavaQuestDone"
    elseif module.passing > 0 or module.attempted then
      icon, group = "▸", "JavaQuestActive"
    else
      icon, group = "·", "JavaQuestTodo"
    end

    local name = truncate(cfg.name, 17)
    local counts = ("%d/%d"):format(module.passing, module.total)
    local bar = game.bar(module.passing, module.total, 6)
    local line = ("  %s %s %-17s %s %s"):format(icon, number, name, bar, counts)
    b:add(line, {
      { 2, 5, group },
      { 6, 24, group },
      { 24, 24 + 6 * 3, module.complete and "JavaQuestBarFull" or "JavaQuestBarEmpty" },
    }, { kind = "module", module = module })

    if cfg.requires == "docker" and not module.complete then
      b:add("       needs docker running", { { 0, 200, "JavaQuestHint" } })
    end
  end
  b:add("")

  -- ------------------------------------------------------------------ steps
  --
  -- The whole step list for the current module, so you can see where you are in it
  -- and what is still ahead, with the CURRENT step expanded into its files, its
  -- numbered instructions and its failing tests.
  if not next_step then
    b:add(header("DONE", WIDTH), { { 0, 200, "JavaQuestHeader" } })
    b:add("  Everything is green.", { { 0, 200, "JavaQuestDone" } })
    b:add("  Go and do INTERVIEW_NOTES.md.", { { 0, 200, "JavaQuestHint" } })
  else
    local module = next_step.module
    local current = next_step.step or {}
    local steps = module.config.steps or {}

    b:add(header(module.config.name:upper(), WIDTH), { { 0, 200, "JavaQuestHeader" } })

    if module.config.read_first and not module.attempted then
      local rf = module.config.read_first
      b:add("  ! READ FIRST", { { 0, 200, "JavaQuestStreak" } })
      b:add("    " .. truncate(vim.fn.fnamemodify(rf.file, ":t"), inner - 4), {
        { 4, 200, "JavaQuestUnlocked" },
      }, { kind = "open", path = module.config.dir .. "/" .. rf.file })
      for _, piece in ipairs(wrap(rf.why, inner - 6)) do
        b:add("      " .. piece, { { 0, 200, "JavaQuestHint" } })
      end
      b:add("")
    end

    -- the step list
    for index, step in ipairs(steps) do
      local class = module.classes[step.test]
      local total = (class and class.total) or step.tests or 0
      local passing = class and (class.total - class.failing) or 0
      local done = class ~= nil and class.failing == 0 and class.total > 0
      local is_current = step.test == current.test

      local icon, group
      if done then
        icon, group = "✓", "JavaQuestDone"
      elseif is_current then
        icon, group = "▸", "JavaQuestActive"
      elseif passing > 0 then
        -- Partially green but not the current step: visibly different from untouched,
        -- otherwise "1/18" and "0/18" look identical at a glance.
        icon, group = "◐", "JavaQuestActive"
      else
        icon, group = "·", "JavaQuestTodo"
      end

      local label = step.label or step.test
      local counts = total > 0 and ("%d/%d"):format(passing, total) or "-"
      local line = ("  %s %d. %-20s %7s"):format(icon, index, truncate(label, 20), counts)
      b:add(line, { { 0, 200, group } }, {
        kind = "step",
        module = module,
        step = step,
      })
    end

    -- anything in the module that is not part of a step
    local step_total = 0
    for _, step in ipairs(steps) do
      local class = module.classes[step.test]
      step_total = step_total + ((class and class.total) or step.tests or 0)
    end
    if module.attempted and module.total > step_total then
      b:add(("       (+%d other tests in this module)"):format(module.total - step_total), {
        { 0, 200, "JavaQuestTodo" },
      })
    end

    -- the current step, expanded
    b:add("")
    b:add(header("NOW: " .. truncate(current.label or current.test or "?", 24), WIDTH), {
      { 0, 200, "JavaQuestHeader" },
    })

    for _, file in ipairs(current.files or {}) do
      local label = vim.fn.fnamemodify(file, ":t")
      b:add("  → " .. truncate(label, inner - 4), { { 0, 2, "JavaQuestKey" }, { 4, 200, "JavaQuestUnlocked" } }, {
        kind = "open",
        path = module.config.dir .. "/src/main/java/dev/jake/refresher/" .. file,
        fallback_file = file,
        module = module,
      })
    end

    local instructions = current.instructions
    if instructions and #instructions > 0 then
      b:add("")
      for index, instruction in ipairs(instructions) do
        local lines = wrap(instruction, inner - 5)
        for line_index, line in ipairs(lines) do
          if line_index == 1 then
            b:add(("  %d. %s"):format(index, line), { { 2, 4, "JavaQuestKey" }, { 5, 200, "JavaQuestHint" } })
          else
            b:add("     " .. line, { { 0, 200, "JavaQuestHint" } })
          end
        end
      end
    elseif current.hint then
      b:add("")
      for _, line in ipairs(wrap(current.hint, inner - 2)) do
        b:add("  " .. line, { { 0, 200, "JavaQuestHint" } })
      end
    end

    if next_step.class and next_step.class.failing > 0 then
      b:add("")
      b:add(("  %d failing:"):format(next_step.class.failing), { { 0, 200, "JavaQuestFail" } })
      local shown = 0
      for _, failure in ipairs(next_step.failures) do
        if shown >= 5 then
          break
        end
        shown = shown + 1
        b:add("    ✗ " .. truncate(failure, inner - 6), { { 4, 200, "JavaQuestFail" } })
      end
      if #next_step.failures > shown then
        b:add(("    … and %d more"):format(#next_step.failures - shown), { { 0, 200, "JavaQuestTodo" } })
      end
    elseif not module.attempted then
      b:add("")
      b:add("  Not run yet — press r to run it", { { 0, 200, "JavaQuestTodo" } })
    end
  end
  b:add("")

  -- achievements
  local unlocked_count = 0
  for _, a in ipairs(config.achievements) do
    if earned[a.id] then
      unlocked_count = unlocked_count + 1
    end
  end
  b:add(header(("TROPHIES  %d/%d"):format(unlocked_count, #config.achievements), WIDTH), {
    { 0, 200, "JavaQuestHeader" },
  })
  for _, a in ipairs(config.achievements) do
    local got = earned[a.id]
    local line = ("  %s %s"):format(got and "▣" or "▢", truncate(a.name, inner - 4))
    b:add(line, { { 0, 200, got and "JavaQuestUnlocked" or "JavaQuestLocked" } }, {
      kind = "trophy",
      achievement = a,
      earned = got,
    })
  end
  b:add("")
  b:add("  t step · r module · s sol · R all · a scan", { { 0, 200, "JavaQuestKey" } })
  b:add("  <CR> open · c compact · q close · ? help", { { 0, 200, "JavaQuestKey" } })
end

local function render_compact(b, config, progress, state, next_step)
  local pct = progress.tests > 0 and math.floor(progress.passing / progress.tests * 100) or 0
  b:add("  " .. config.title:upper(), { { 0, 200, "JavaQuestTitle" } })
  b:add_bar("  ", progress.passing, progress.tests, 24, ("  %d%%"):format(pct))
  local streak = statestore.streak(state)
  b:add(("  %d/%d tests · %d day streak"):format(progress.passing, progress.tests, streak), {
    { 0, 200, "JavaQuestXP" },
  })
  b:add("")

  for _, module in ipairs(progress.modules) do
    local number = module.config.dir:match("^(%d+)") or "??"
    local icon, group
    if module.complete then
      icon, group = "✓", "JavaQuestDone"
    elseif module.attempted then
      icon, group = "▸", "JavaQuestActive"
    else
      icon, group = "·", "JavaQuestTodo"
    end
    b:add(
      ("  %s %s %-18s %d/%d"):format(icon, number, truncate(module.config.name, 18), module.passing, module.total),
      { { 0, 200, group } },
      { kind = "module", module = module }
    )
  end
  b:add("")
  if not next_step then
    b:add(header("DONE", WIDTH), { { 0, 200, "JavaQuestHeader" } })
    b:add("  All green.", { { 0, 200, "JavaQuestDone" } })
  else
    local module = next_step.module
    local current = next_step.step or {}
    b:add(header(truncate(module.config.name:upper(), 24), WIDTH), { { 0, 200, "JavaQuestHeader" } })

    for index, step in ipairs(module.config.steps or {}) do
      local class = module.classes[step.test]
      local total = (class and class.total) or step.tests or 0
      local passing = class and (class.total - class.failing) or 0
      local done = class ~= nil and class.failing == 0 and class.total > 0
      local is_current = step.test == current.test
      local icon, group
      if done then
        icon, group = "✓", "JavaQuestDone"
      elseif is_current then
        icon, group = "▸", "JavaQuestActive"
      elseif passing > 0 then
        icon, group = "◐", "JavaQuestActive"
      else
        icon, group = "·", "JavaQuestTodo"
      end
      b:add(("  %s %d. %-18s %6s"):format(icon, index, truncate(step.label or step.test, 18), total > 0 and ("%d/%d"):format(passing, total) or "-"),
        { { 0, 200, group } }, { kind = "step", module = module, step = step })
    end

    for _, file in ipairs(current.files or {}) do
      b:add("  → " .. truncate(vim.fn.fnamemodify(file, ":t"), 32), { { 0, 2, "JavaQuestKey" } }, {
        kind = "open",
        path = module.config.dir .. "/src/main/java/dev/jake/refresher/" .. file,
        fallback_file = file,
        module = module,
      })
    end

    -- just the first instruction in compact mode; `c` switches to the full view
    local first = (current.instructions or {})[1]
    if first then
      for _, line in ipairs(wrap(first, 38)) do
        b:add("  " .. line, { { 0, 200, "JavaQuestHint" } })
      end
    end
    for index, failure in ipairs(next_step.failures or {}) do
      if index > 3 then
        break
      end
      b:add("    ✗ " .. truncate(failure, 32), { { 4, 200, "JavaQuestFail" } })
    end
  end
  b:add("")
  b:add("  t test · r module · <CR> open · q close", { { 0, 200, "JavaQuestKey" } })
end

-- ---------------------------------------------------------------------------
-- Window management
-- ---------------------------------------------------------------------------

--- The keymap prefix as you would actually type it, for the help text.
local function outside_prefix()
  local config = detect.config()
  local prefix = ((config or {}).keys or {}).prefix or "<leader>Q"
  local leader = vim.g.mapleader
  if leader == " " then
    return (prefix:gsub("<[lL]eader>", "<Space>"))
  end
  return prefix
end

local function is_open()
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

--- Normal (non-floating) windows in the current tab page.
local function layout_windows()
  local out = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_config(w).relative == "" then
      table.insert(out, w)
    end
  end
  return out
end

--- True when no other window starts further right than the panel.
local function is_rightmost()
  if not is_open() then
    return true
  end
  local panel_col = vim.fn.win_screenpos(win)[2]
  for _, w in ipairs(layout_windows()) do
    if w ~= win and vim.fn.win_screenpos(w)[2] > panel_col then
      return false
    end
  end
  return true
end

local repositioning = false

--- Moves the panel back to the far right if something displaced it.
---
--- Opening a vertical split, closing a window, or `:vsplit`ing from the panel's
--- neighbour can all leave it stranded mid-layout. `wincmd L` means "move this
--- window to the far right", which is the one command that fixes it regardless of
--- how the layout got that way.
function M.reposition()
  if repositioning or not is_open() then
    return
  end
  if is_rightmost() then
    -- Still re-assert the width: a sibling split can squeeze it.
    if vim.api.nvim_win_get_width(win) ~= WIDTH then
      pcall(vim.api.nvim_win_set_width, win, WIDTH)
    end
    return
  end

  repositioning = true
  local previous = vim.api.nvim_get_current_win()
  pcall(function()
    vim.api.nvim_set_current_win(win)
    vim.cmd("noautocmd wincmd L")
    vim.api.nvim_win_set_width(win, WIDTH)
    vim.wo[win].winfixwidth = true
  end)
  if vim.api.nvim_win_is_valid(previous) then
    pcall(vim.api.nvim_set_current_win, previous)
  end
  repositioning = false
end

M.is_open = is_open

local function ensure_window()
  if is_open() then
    return
  end
  local previous = vim.api.nvim_get_current_win()

  -- `botright vertical Nvsplit` puts the window at the FAR RIGHT of the tab page.
  -- `rightbelow vsplit` (the obvious-looking choice) splits relative to whichever
  -- window happens to be focused, so the panel would land in the middle of the
  -- layout whenever you opened it from anything other than the rightmost window.
  vim.cmd("noautocmd botright vertical " .. WIDTH .. "vsplit")
  win = vim.api.nvim_get_current_win()

  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "javaquest"
    vim.api.nvim_buf_set_name(buf, "javaquest://panel")
    M.attach_keymaps(buf)
    -- The panel is a scratch buffer, so BufEnter's detect.active() check relies on
    -- the cwd. Attach the global prefix keymaps explicitly so <leader>'q toggles the
    -- panel from inside the panel too, whatever the cwd happens to be.
    pcall(function()
      require("javaquest").attach(buf)
    end)
  end

  vim.api.nvim_win_set_buf(win, buf)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].winfixwidth = true
  vim.wo[win].list = false
  vim.wo[win].spell = false

  vim.api.nvim_set_current_win(previous)

  -- Watch for anything that could displace it. One augroup, created with the panel.
  local group = vim.api.nvim_create_augroup("JavaQuestLayout", { clear = true })
  vim.api.nvim_create_autocmd({ "WinNew", "WinClosed", "WinResized", "VimResized", "TabEnter" }, {
    group = group,
    callback = function()
      vim.schedule(M.reposition)
    end,
  })
end

--- Redraws the panel. Safe to call when it is closed (it does nothing).
function M.refresh(opts)
  opts = opts or {}
  local config, root = detect.config()
  if not config then
    return
  end
  if not is_open() and not opts.open then
    return
  end

  setup_highlights()
  ensure_window()
  M.reposition()

  local progress = progressor.scan(root, config)
  local state = statestore.load(root)
  local xp = game.xp(config, progress)
  local level = game.level(config, xp)
  local newly, earned = game.reconcile(root, config, progress, state)
  local next_step = progressor.next_step(progress)

  local b = new_buffer()
  if config.compact then
    render_compact(b, config, progress, state, next_step)
  else
    render_full(b, config, progress, state, xp, level, earned, next_step)
  end

  actions = b.actions

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, b.lines)
  vim.bo[buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  for _, mark in ipairs(b.marks) do
    local line = b.lines[mark.lnum + 1] or ""
    pcall(vim.api.nvim_buf_set_extmark, buf, NS, mark.lnum, math.min(mark.from, #line), {
      end_col = math.min(mark.to, #line),
      hl_group = mark.group,
    })
  end

  -- Celebrate once per unlock.
  for _, achievement in ipairs(newly) do
    vim.notify(
      ("  TROPHY UNLOCKED  %s\n  %s"):format(achievement.name, achievement.desc),
      vim.log.levels.INFO
    )
  end

  return progress
end

function M.open()
  local config = detect.config()
  if not config then
    vim.notify("javaquest: no .javaquest.json found above this file", vim.log.levels.WARN)
    return
  end
  M.refresh({ open = true })
end

function M.close()
  if is_open() then
    vim.api.nvim_win_close(win, true)
    win = nil
  end
end

function M.toggle()
  if is_open() then
    M.close()
  else
    M.open()
  end
end

function M.focus()
  M.open()
  if is_open() then
    vim.api.nvim_set_current_win(win)
  end
end

-- ---------------------------------------------------------------------------
-- In-panel keymaps
-- ---------------------------------------------------------------------------

--- Resolves the source file for an action, searching the module when the guessed
--- path does not exist (the package layout differs per module).
local function resolve_path(root, action)
  if action.path and vim.uv.fs_stat(root .. "/" .. action.path) then
    return root .. "/" .. action.path
  end
  if action.fallback_file and action.module then
    local base = root .. "/" .. action.module.config.dir .. "/src/main/java"
    local want = vim.fn.fnamemodify(action.fallback_file, ":t")
    for name, type_ in vim.fs.dir(base, { depth = 12 }) do
      if type_ == "file" and vim.fn.fnamemodify(name, ":t") == want then
        return base .. "/" .. name
      end
    end
  end
  return nil
end

local function open_under_cursor()
  local config, root = detect.config()
  if not config then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local action = actions[lnum]
  if not action then
    return
  end

  local target
  if action.kind == "step" then
    local files = action.step.files or {}
    if files[1] then
      target = resolve_path(root, {
        path = action.module.config.dir .. "/src/main/java/dev/jake/refresher/" .. files[1],
        fallback_file = files[1],
        module = action.module,
      })
    end
    if not target then
      target = root .. "/" .. action.module.config.dir .. "/README.md"
    end
  elseif action.kind == "module" then
    target = root .. "/" .. action.module.config.dir .. "/README.md"
  elseif action.kind == "trophy" then
    vim.notify(
      ("%s  %s\n%s"):format(action.earned and "▣ UNLOCKED" or "▢ LOCKED", action.achievement.name, action.achievement.desc),
      vim.log.levels.INFO
    )
    return
  elseif action.kind == "open" then
    target = resolve_path(root, action)
  end

  if not target then
    vim.notify("javaquest: could not find that file", vim.log.levels.WARN)
    return
  end

  -- Never open a file into the panel. Leave it by moving left, which is always a
  -- real window now that the panel is pinned to the far right.
  if vim.api.nvim_get_current_win() == win then
    vim.cmd("wincmd h")
  end
  -- If the panel somehow was the only window, moving left is a no-op: make room.
  if vim.api.nvim_get_current_win() == win then
    vim.cmd("noautocmd topleft vsplit")
  end
  vim.cmd("edit " .. vim.fn.fnameescape(target))
  M.reposition()
end

local function run(kind)
  local config, root = detect.config()
  if not config then
    return
  end
  local progress = progressor.scan(root, config)
  local next_step = progressor.next_step(progress)

  local maven = require("java.maven")
  if kind == "all" then
    maven.test_all()
    return
  end

  if not next_step then
    vim.notify("javaquest: nothing left to run", vim.log.levels.INFO)
    return
  end

  local module_dir = root .. "/" .. next_step.module.config.dir
  maven.test_module_at(module_dir, { solutions = kind == "solutions" })
end

--- Runs the test class for ONE step: the step under the cursor when the cursor is
--- on a step line, otherwise whichever step the quest is currently on. This is the
--- tight loop -- one class, a couple of seconds -- as against `r`, which runs the
--- module's whole suite.
local function run_step(opts)
  local config, root = detect.config()
  if not config then
    return
  end

  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local action = actions[lnum]
  if action and action.kind == "step" and action.step then
    require("java.maven").test_class_at(
      root .. "/" .. action.module.config.dir,
      action.step.test,
      opts
    )
    return
  end

  -- Not on a step line: fall back to the current step. The panel buffer is not a
  -- Java file, so this resolves through the progress scan.
  require("javaquest").test_current_step(opts)
end

function M.attach_keymaps(bufnr)
  local map = function(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = bufnr, silent = true, nowait = true, desc = desc })
  end

  map("<CR>", open_under_cursor, "JavaQuest: open this file / module README")
  map("o", open_under_cursor, "JavaQuest: open")
  map("t", function() run_step() end, "JavaQuest: run this step's test class")
  map("T", function() run_step({ solutions = true }) end, "JavaQuest: run this step against solutions/")
  map("r", function() run("module") end, "JavaQuest: run the next module's tests")
  map("s", function() run("solutions") end, "JavaQuest: run the next module against solutions/")
  map("R", function() run("all") end, "JavaQuest: run every module")
  map("a", function() require("javaquest").scan() end, "JavaQuest: rescan (full test run)")
  map("c", function()
    local config, root = detect.config()
    if not config then
      return
    end
    config.compact = not config.compact
    M.refresh()
    vim.notify("javaquest: " .. (config.compact and "compact" or "full") .. " view (set `compact` in .javaquest.json to persist)")
  end, "JavaQuest: toggle compact")
  map("q", M.close, "JavaQuest: close")
  map("<Esc>", M.close, "JavaQuest: close")
  map("g?", function()
    vim.notify(table.concat({
      "JavaQuest panel keys",
      "",
      "  <CR> / o   open the file or module README under the cursor",
      "  t          run the test class for the step under the cursor",
      "  T          run that step against solutions/",
      "  r          run the next module's tests",
      "  s          run the next module against solutions/",
      "  R          run every module",
      "  a          rescan: full test run, then refresh",
      "  c          toggle compact / full view",
      "  q / <Esc>  close",
      "",
      "Outside the panel: " .. outside_prefix() .. "q toggle, " .. outside_prefix() .. "f focus,",
      "                   " .. outside_prefix() .. "t test this step, " .. outside_prefix() .. "s vs solutions",
      "                   :JavaQuestKeys shows the prefix, :JavaQuest* for the rest",
      "",
      "Starting over is commands only, on purpose:",
      "  :JavaQuestRestartModule NN   one module back to stubs",
      "  :JavaQuestRestart            everything back (type 'reset')",
      "  :JavaQuestResetHistory       streak/trophies only",
    }, "\n"), vim.log.levels.INFO)
  end, "JavaQuest: help")
  map("?", function() vim.cmd("normal g?") end, "JavaQuest: help")
end

return M
