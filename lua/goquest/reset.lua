-- ---------------------------------------------------------------------------
-- Starting over.
--
-- This is the only destructive code in goquest, so it is deliberately careful:
--
--   * it ALWAYS backs up your current exercise files first, to a timestamped
--     directory outside the repo, and tells you where
--   * it only ever touches EXERCISE files: non-test .go files inside a module.
--     *_test.go, _solutions/ and testdata/ are never written to, so the answers
--     and the specification survive
--   * it never touches git history. Only the working tree changes, so anything
--     you committed is still in your commits
--   * the full restart requires you to type the word, not just press y
--
-- Unlike the Java course, a Go package keeps its tests in the same directory as
-- the code, so a reset cannot restore a whole tree. It works file by file from
-- the list the pristine git ref says should exist.
-- ---------------------------------------------------------------------------

local detect = require("goquest.detect")

local M = {}

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------

local function git(root, args)
  local cmd = { "git", "-C", root }
  vim.list_extend(cmd, args)
  local result = vim.system(cmd, { text = true }):wait()
  return result.code == 0, (result.stdout or "") .. (result.stderr or "")
end

--- True for a path (relative to the repo root) that the learner edits.
function M.is_exercise(rel)
  if not rel:match("%.go$") or rel:match("_test%.go$") then
    return false
  end
  for part in rel:gmatch("[^/]+") do
    if part == "_solutions" or part == "testdata" or part:sub(1, 1) == "." then
      return false
    end
  end
  return true
end

--- Exercise files currently on disk in a module, relative to the repo root.
local function current_exercise_files(root, module)
  local out = {}
  local base = root .. "/" .. module.dir
  if not vim.uv.fs_stat(base) then
    return out
  end
  for name, type_ in vim.fs.dir(base, { depth = 20 }) do
    local rel = module.dir .. "/" .. name
    if type_ == "file" and M.is_exercise(rel) then
      table.insert(out, rel)
    end
  end
  return out
end

--- Every module the reset will act on: one, or all of them.
local function target_modules(config, only_dir)
  if not only_dir then
    return config.modules
  end
  for _, module in ipairs(config.modules) do
    -- accept "03", "03-generics", or "generics"
    if module.dir == only_dir
        or module.dir:match("^(%d+)") == only_dir
        or module.dir:match("^%d+%-(.+)$") == only_dir then
      return { module }
    end
  end
  return nil
end

--- Copies the current exercise files somewhere safe. Returns the backup dir.
function M.backup(root, modules)
  local stamp = os.date("%Y%m%d-%H%M%S")
  local dir = vim.fn.stdpath("data") .. "/goquest/backups/" .. vim.fn.fnamemodify(root, ":t") .. "-" .. stamp
  local copied = 0

  for _, module in ipairs(modules) do
    for _, rel in ipairs(current_exercise_files(root, module)) do
      local to = dir .. "/" .. rel
      vim.fn.mkdir(vim.fn.fnamemodify(to, ":h"), "p")
      local result = vim.system({ "cp", "-p", root .. "/" .. rel, to }, { text = true }):wait()
      if result.code == 0 then
        copied = copied + 1
      end
    end
  end

  if copied == 0 then
    return nil
  end
  return dir
end

--- Restores one module's exercise files to their state at `ref`, including
--- REMOVING exercise files that are not in the ref (files you added).
local function restore_module(root, ref, module)
  local ok, listing = git(root, { "ls-tree", "-r", "--name-only", ref, "--", module.dir })
  if not ok then
    return false, "cannot read " .. ref .. ": " .. listing
  end

  local pristine, pristine_list = {}, {}
  for _, line in ipairs(vim.split(vim.trim(listing), "\n")) do
    if line ~= "" and M.is_exercise(line) then
      pristine[line] = true
      table.insert(pristine_list, line)
    end
  end
  if #pristine_list == 0 then
    return false, "no exercise files for " .. module.dir .. " in " .. ref
  end

  -- Remove exercise files the ref does not have. One file at a time, and only
  -- files that pass is_exercise: never a directory, never a test.
  for _, rel in ipairs(current_exercise_files(root, module)) do
    if not pristine[rel] then
      vim.fn.delete(root .. "/" .. rel)
    end
  end

  -- Overwrite the rest from the ref, naming every file explicitly so a test
  -- file in the same directory cannot be caught up in it.
  local args = { "checkout", ref, "--" }
  vim.list_extend(args, pristine_list)
  local checked_out, err = git(root, args)
  if not checked_out then
    return false, err
  end
  return true, nil
end

--- Deletes the recorded reports, so progress genuinely returns to zero.
function M.clear_reports(root, modules)
  local removed = 0
  for _, module in ipairs(modules) do
    for _, name in ipairs({ "reports", "reports-solutions" }) do
      local dir = root .. "/.quest/" .. name .. "/" .. module.dir
      if vim.uv.fs_stat(dir) then
        vim.fn.delete(dir, "rf")
        removed = removed + 1
      end
    end
  end
  return removed
end

--- Deletes the streak and trophy history for this project.
function M.clear_history(root)
  local base = vim.fn.fnamemodify(root, ":t")
  local hash = vim.fn.sha256(root):sub(1, 8)
  local path = vim.fn.stdpath("data") .. "/goquest/" .. base .. "-" .. hash .. ".json"
  if vim.uv.fs_stat(path) then
    vim.fn.delete(path)
    return true
  end
  return false
end

-- ---------------------------------------------------------------------------
-- the operations
-- ---------------------------------------------------------------------------

--- Restores files, clears reports, optionally clears history. No prompting: the
--- callers below do that.
local function perform(root, config, modules, opts)
  local ref = (config.pristine or {}).git_ref or "goquest-pristine"

  -- Fail before touching anything if the reference point is missing.
  if not git(root, { "rev-parse", "--verify", ref }) then
    vim.notify(
      ("goquest: cannot restore, the '%s' reference does not exist.\n\n"
        .. "Recreate it from a commit where the stubs are untouched:\n"
        .. "    git tag %s <commit>\n\nNothing was changed."):format(ref, ref),
      vim.log.levels.ERROR
    )
    return false
  end

  local backup = M.backup(root, modules)

  local restored, failed = 0, {}
  for _, module in ipairs(modules) do
    local done, reason = restore_module(root, ref, module)
    if done then
      restored = restored + 1
    else
      table.insert(failed, module.dir .. ": " .. tostring(reason))
    end
  end

  M.clear_reports(root, modules)
  if opts.history then
    M.clear_history(root)
  end

  -- Any open buffer for a restored file is now stale on disk.
  vim.cmd("silent! checktime")

  local lines = {
    ("goquest: restored %d of %d module(s) to their TODO stubs"):format(restored, #modules),
    "",
    "  reports cleared, so progress is back to zero",
  }
  if opts.history then
    table.insert(lines, "  streak and trophies cleared")
  else
    table.insert(lines, "  streak and trophies KEPT (use :GoQuestResetHistory to clear them)")
  end
  table.insert(lines, "  git history untouched: your commits are still there")
  if backup then
    table.insert(lines, "")
    table.insert(lines, "  your previous work was copied to:")
    table.insert(lines, "    " .. backup)
  end
  if #failed > 0 then
    table.insert(lines, "")
    table.insert(lines, "  FAILED:")
    for _, f in ipairs(failed) do
      table.insert(lines, "    " .. f)
    end
  end

  vim.notify(table.concat(lines, "\n"), #failed > 0 and vim.log.levels.WARN or vim.log.levels.INFO)

  pcall(function()
    require("goquest.ui").refresh()
  end)
  return true
end

--- Full restart: every module, plus the streak and trophies. Requires typing.
function M.restart_all()
  local config, root = detect.config()
  if not config then
    vim.notify("goquest: no .goquest.json found", vim.log.levels.WARN)
    return
  end

  local modules = config.modules
  local prompt = table.concat({
    "",
    "  ⚠  FULL RESTART",
    "",
    ("  This discards your work in all %d modules and starts from scratch:"):format(#modules),
    "",
    "    · every exercise .go file goes back to its TODO stub",
    "    · all test reports are deleted, so progress returns to 0",
    "    · your streak and trophies are cleared",
    "",
    "  Kept: _solutions/, every *_test.go, and your git commits.",
    "  Your current files are backed up first.",
    "",
    "  Type  reset  to confirm (anything else aborts): ",
  }, "\n")

  local answer = vim.fn.input(prompt)
  print("")
  if vim.trim(answer):lower() ~= "reset" then
    vim.notify("goquest: aborted, nothing changed", vim.log.levels.INFO)
    return
  end

  perform(root, config, modules, { history = true })
end

--- Restarts one module, keeping your streak and trophies.
function M.restart_module(which)
  local config, root = detect.config()
  if not config then
    vim.notify("goquest: no .goquest.json found", vim.log.levels.WARN)
    return
  end

  local function go(dir)
    local modules = target_modules(config, dir)
    if not modules then
      vim.notify("goquest: no module matching '" .. tostring(dir) .. "'", vim.log.levels.WARN)
      return
    end
    local module = modules[1]
    vim.ui.select({ "no", "yes" }, {
      prompt = ("Reset %s (%s) to its TODO stubs? Your work there is backed up first."):format(
        module.dir, module.name
      ),
    }, function(choice)
      if choice ~= "yes" then
        vim.notify("goquest: aborted", vim.log.levels.INFO)
        return
      end
      perform(root, config, modules, { history = false })
    end)
  end

  if which and which ~= "" then
    go(which)
    return
  end

  local labels, lookup = {}, {}
  for _, module in ipairs(config.modules) do
    local label = module.dir .. "  ·  " .. module.name
    table.insert(labels, label)
    lookup[label] = module.dir
  end
  vim.ui.select(labels, { prompt = "Reset which module?" }, function(choice)
    if choice then
      go(lookup[choice])
    end
  end)
end

--- Module names, for command completion.
function M.module_names()
  local config = detect.config()
  if not config then
    return {}
  end
  local names = {}
  for _, module in ipairs(config.modules) do
    table.insert(names, module.dir)
  end
  return names
end

return M
