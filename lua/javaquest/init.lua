-- ---------------------------------------------------------------------------
-- JavaQuest: a progress panel for a test-driven course repo.
--
-- Entirely gated on a .javaquest.json at the project root, exactly like
-- lua/godot/ is gated on project.godot. Outside such a project this registers
-- nothing: no keymaps, no autocmds, no commands beyond the one that tells you
-- there is no config.
--
-- Progress is DERIVED from Surefire's XML reports, never from a checklist, so the
-- panel cannot claim you have finished something you have not. See
-- lua/javaquest/progress.lua for the two traps that makes necessary.
-- ---------------------------------------------------------------------------

local M = {}

local detect = require("javaquest.detect")

local function ui()
  return require("javaquest.ui")
end

--- The keymap prefix, from `keys.prefix` in .javaquest.json.
---
--- Default <leader>Q, matching the <leader>G convention the Godot module uses for
--- a whole subsystem. It is a PURE PREFIX: nothing is mapped to the bare prefix,
--- because a key that is both a complete mapping and a prefix makes Neovim wait
--- `timeoutlen` on every press and then fire the standalone one.
---
--- That is not hypothetical. This originally used <leader>q, which in this config
--- is "close buffer, or quit when it is the last one" -- so the panel keymaps made
--- <Space>q ambiguous with quitting Neovim. Hence the guard below.
local DEFAULT_PREFIX = "<leader>Q"

local function resolve(lhs)
  local leader = vim.g.mapleader or "\\"
  return (lhs:gsub("<[lL]eader>", leader == " " and " " or leader))
end

--- Warns when the chosen prefix is already a COMPLETE mapping, which would make
--- every prefixed key ambiguous with it.
local function check_prefix(prefix)
  local existing = vim.fn.maparg(resolve(prefix), "n")
  if existing ~= nil and existing ~= "" then
    vim.notify(
      ("javaquest: the key prefix %s is already mapped to something else.\n\n"
        .. "Every %s… keymap will now wait for 'timeoutlen' and then run that mapping\n"
        .. "instead. Pick a free prefix in .javaquest.json:\n\n"
        .. '    "keys": { "prefix": "<leader>V" }'):format(prefix, prefix),
      vim.log.levels.WARN
    )
    return false
  end
  return true
end

local function prefix_for(config)
  return ((config or {}).keys or {}).prefix or DEFAULT_PREFIX
end

--- Called by lua/java/maven.lua after a test run finishes. Records the run for the
--- streak, then refreshes the panel so XP and progress land immediately.
function M.on_test_run(opts)
  opts = opts or {}
  local config, root = detect.config()
  if not config then
    return
  end

  -- A solutions run proves nothing about YOUR progress, so it must not touch the
  -- streak. (It cannot touch the test reports either: the parent pom sends them to
  -- target/surefire-reports-solutions.)
  if not opts.solutions then
    local statestore = require("javaquest.state")
    local state = statestore.load(root)
    statestore.record_run(root, state)
  end

  if ui().is_open() then
    vim.schedule(function()
      ui().refresh()
    end)
  end
end

function M.scan()
  local config = detect.config()
  if not config then
    vim.notify("javaquest: no .javaquest.json found", vim.log.levels.WARN)
    return
  end
  vim.notify("javaquest: running every module to rebuild progress…", vim.log.levels.INFO)
  require("java.maven").test_all()
end

--- A one-line summary, for a statusline or a quick check.
function M.status()
  local config, root = detect.config()
  if not config then
    return nil
  end
  local progress = require("javaquest.progress").scan(root, config)
  local game = require("javaquest.game")
  local xp = game.xp(config, progress)
  local level = game.level(config, xp)
  return ("Lv%d %s · %d/%d tests · %d/%d modules"):format(
    level.index,
    level.name,
    progress.passing,
    progress.tests,
    progress.complete_modules,
    #config.modules
  )
end

--- The step that owns a given buffer, matched on file name.
---
--- Looks at .javaquest.json rather than the language server: a step lists both its
--- exercise files and its test class, so this resolves from either side -- editing
--- Money.java or MoneyTest.java both find the Money step. Scoped to the module that
--- actually contains the path, because file names repeat across modules.
local function step_for_buffer(config, root, bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr or 0)
  if path == "" or not path:match("%.java$") then
    return nil
  end
  local base = vim.fn.fnamemodify(path, ":t")
  local stem = vim.fn.fnamemodify(path, ":t:r")

  for _, module in ipairs(config.modules or {}) do
    if path:find(root .. "/" .. module.dir, 1, true) == 1 then
      for _, step in ipairs(module.steps or {}) do
        -- The test class itself, or "MoneyTest" from "Money"...
        if step.test == stem then
          return module, step
        end
        -- ...or one of the step's exercise files.
        for _, file in ipairs(step.files or {}) do
          if vim.fn.fnamemodify(file, ":t") == base then
            return module, step
          end
        end
      end
    end
  end
  return nil
end

--- Runs the test class for the step you are on, from anywhere in the repo.
---
--- "The step you are on" means the current buffer's step when the buffer belongs to
--- one, and otherwise the quest's current step (the first that is not green). So it
--- does the right thing from an exercise file, from its test, and from a README or
--- the panel alike.
function M.test_current_step(opts)
  opts = opts or {}
  local config, root = detect.config()
  if not config then
    vim.notify("javaquest: no .javaquest.json found", vim.log.levels.WARN)
    return
  end

  local module, step = step_for_buffer(config, root, 0)
  if not step then
    local progressor = require("javaquest.progress")
    local next_step = progressor.next_step(progressor.scan(root, config))
    if not next_step or not next_step.step then
      vim.notify("javaquest: everything is green — nothing to run", vim.log.levels.INFO)
      return
    end
    module, step = next_step.module.config, next_step.step
  end

  vim.notify(
    ("javaquest: %s%s"):format(step.label or step.test, opts.solutions and " (solutions)" or ""),
    vim.log.levels.INFO
  )
  require("java.maven").test_class_at(root .. "/" .. module.dir, step.test, opts)
end

function M.setup()
  -- Commands are always registered: they are how you find out the config is
  -- missing, and they are harmless elsewhere.
  local cmd = vim.api.nvim_create_user_command
  cmd("JavaQuest", function() ui().toggle() end, { desc = "Toggle the JavaQuest panel" })
  cmd("JavaQuestOpen", function() ui().open() end, { desc = "Open the JavaQuest panel" })
  cmd("JavaQuestFocus", function() ui().focus() end, { desc = "Open and jump into the JavaQuest panel" })
  cmd("JavaQuestClose", function() ui().close() end, { desc = "Close the JavaQuest panel" })
  cmd("JavaQuestRefresh", function() ui().refresh({ open = true }) end, { desc = "Re-read test reports" })
  cmd("JavaQuestScan", function() M.scan() end, { desc = "Run every module, then refresh progress" })
  cmd("JavaQuestNext", function() M.goto_next() end, { desc = "Open the next exercise file" })
  cmd("JavaQuestTest", function(args)
    M.test_current_step({ solutions = args.bang })
  end, { bang = true, desc = "Run the current step's test class (! = against solutions/)" })

  cmd("JavaQuestKeys", function()
    local config = detect.config()
    local prefix = prefix_for(config)
    vim.notify(table.concat({
      "JavaQuest keys  (prefix: " .. prefix .. ")",
      "",
      "  " .. prefix .. "q   toggle the panel",
      "  " .. prefix .. "f   focus the panel",
      "  " .. prefix .. "n   jump to the next exercise file",
      "  " .. prefix .. "t   run this step's test class",
      "  " .. prefix .. "s   run this step against solutions/",
      "",
      "Change the prefix in .javaquest.json (any free key; it must NOT be one that",
      "is already a complete mapping on its own):",
      '    "keys": { "prefix": "<leader>;" }',
      "",
      "In the panel: <CR> open · t test this step · r module · s solutions · R all · a rescan · c compact · q close",
      "Starting over is commands only: :JavaQuestRestart, :JavaQuestRestartModule, :JavaQuestResetHistory",
    }, "\n"), vim.log.levels.INFO)
  end, { desc = "Show the JavaQuest keymaps and the configured prefix" })

  cmd("JavaQuestStatus", function()
    vim.notify(M.status() or "javaquest: not in a quest project", vim.log.levels.INFO)
  end, { desc = "One-line progress summary" })
  -- ---- starting over -----------------------------------------------------
  --
  -- Three levels, from least to most destructive. Deliberately commands only and
  -- NOT bound to a panel key: a fat finger in a sidebar should not be able to
  -- delete an evening's work.

  cmd("JavaQuestResetHistory", function()
    local _, root = detect.config()
    if not root then
      vim.notify("javaquest: no .javaquest.json found", vim.log.levels.WARN)
      return
    end
    vim.ui.select({ "no", "yes" }, {
      prompt = "Clear the streak and trophy dates? Your FILES and progress are untouched.",
    }, function(choice)
      if choice ~= "yes" then
        return
      end
      require("javaquest.reset").clear_history(root)
      vim.notify("javaquest: streak and trophies cleared. Progress is re-derived from your tests, so it is unchanged.", vim.log.levels.INFO)
      ui().refresh()
    end)
  end, { desc = "Clear the streak and trophy history (keeps your files and progress)" })

  cmd("JavaQuestRestartModule", function(args)
    require("javaquest.reset").restart_module(args.args)
  end, {
    nargs = "?",
    complete = function()
      return require("javaquest.reset").module_names()
    end,
    desc = "Reset ONE module's exercise files back to their TODO stubs",
  })

  cmd("JavaQuestRestart", function()
    require("javaquest.reset").restart_all()
  end, { desc = "Start the whole thing over: all stubs restored, progress and trophies cleared" })

  -- Everything below only exists inside a quest project.
  local group = vim.api.nvim_create_augroup("JavaQuest", { clear = true })

  --- Attaches the panel keymaps to one buffer. Idempotent.
  ---
  --- Bound to BufEnter rather than `FileType java`, because the panel toggle has to
  --- work from anywhere in the project: a README, the file tree, the unnamed startup
  --- buffer, or the panel itself. Scoping it to Java files meant <leader>'q silently
  --- did nothing everywhere else, which is exactly how it was first reported.
  local function attach(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    if vim.b[bufnr].javaquest_keys then
      return
    end
    if not detect.active(bufnr) then
      return
    end

    local config = detect.config()
    local prefix = prefix_for(config)

    if not vim.g.javaquest_prefix_checked then
      vim.g.javaquest_prefix_checked = true
      check_prefix(prefix)
    end

    local function map(suffix, fn, desc)
      vim.keymap.set("n", prefix .. suffix, fn, {
        buffer = bufnr,
        silent = true,
        desc = "JavaQuest: " .. desc,
      })
    end

    map("q", function() ui().toggle() end, "toggle panel")
    map("f", function() ui().focus() end, "focus panel")
    map("n", function() M.goto_next() end, "jump to the next exercise file")
    map("t", function() M.test_current_step() end, "run this step's test class")
    map("s", function() M.test_current_step({ solutions = true }) end, "run this step against solutions/")

    vim.b[bufnr].javaquest_keys = true
    vim.b[bufnr].javaquest_prefix = prefix
  end

  M.attach = attach

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = group,
    callback = function(args)
      attach(args.buf)
    end,
  })

  -- The buffer that already exists when Neovim starts never fires BufEnter.
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
      attach(vim.api.nvim_get_current_buf())
    end,
  })

  -- Auto-open the panel, once per session, on the first Java file.
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "java",
    callback = function(args)
      if not detect.active(args.buf) then
        return
      end
      attach(args.buf)
      if not vim.g.javaquest_opened and vim.bo[args.buf].buftype == "" then
        vim.g.javaquest_opened = true
        vim.schedule(function()
          ui().refresh({ open = true })
        end)
      end
    end,
  })

  -- Attach to whatever is already loaded, so enabling this mid-session works.
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      attach(bufnr)
    end
  end
end

--- Opens the next exercise file. Shared by the keymap and :JavaQuestNext.
function M.goto_next()
  local config, root = detect.config()
  if not config then
    vim.notify("javaquest: no .javaquest.json found", vim.log.levels.WARN)
    return
  end
  ui().open()

  local progressor = require("javaquest.progress")
  local next_step = progressor.next_step(progressor.scan(root, config))
  if not next_step then
    vim.notify("javaquest: everything is green", vim.log.levels.INFO)
    return
  end

  local files = (next_step.step or {}).files or {}
  if files[1] then
    local base = root .. "/" .. next_step.module.config.dir .. "/src/main/java"
    local want = vim.fn.fnamemodify(files[1], ":t")
    for name, type_ in vim.fs.dir(base, { depth = 12 }) do
      if type_ == "file" and vim.fn.fnamemodify(name, ":t") == want then
        -- Never open a file INTO the panel window.
        if vim.bo.filetype == "javaquest" then
          vim.cmd("wincmd p")
        end
        vim.cmd("edit " .. vim.fn.fnameescape(base .. "/" .. name))
        return
      end
    end
  end
  vim.notify("javaquest: could not locate the next file", vim.log.levels.WARN)
end

return M
