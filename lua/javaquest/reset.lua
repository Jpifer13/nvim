-- ---------------------------------------------------------------------------
-- Starting over.
--
-- This is the only destructive code in javaquest, so it is deliberately careful:
--
--   * it ALWAYS backs up your current exercise files first, to a timestamped
--     directory outside the repo, and tells you where
--   * it only ever touches <module>/src/main/java. solutions/ and src/test/java
--     are never written to, so the answers and the specification survive
--   * it never touches git history. Only the working tree changes, so anything
--     you committed is still in your commits
--   * the full restart requires you to type the word, not just press y
-- ---------------------------------------------------------------------------

local detect = require("javaquest.detect")

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

local function exercise_paths(config, module)
  local paths = {}
  for _, rel in ipairs((config.pristine or {}).paths or { "src/main/java" }) do
    table.insert(paths, module.dir .. "/" .. rel)
  end
  return paths
end

--- Every module the reset will act on: one, or all of them.
local function target_modules(config, only_dir)
  if not only_dir then
    return config.modules
  end
  for _, module in ipairs(config.modules) do
    -- accept "03", "03-streams", or "streams"
    if module.dir == only_dir
        or module.dir:match("^(%d+)") == only_dir
        or module.dir:match("^%d+%-(.+)$") == only_dir then
      return { module }
    end
  end
  return nil
end

--- Copies the current exercise files somewhere safe. Returns the backup dir.
function M.backup(root, config, modules)
  local stamp = os.date("%Y%m%d-%H%M%S")
  local dir = vim.fn.stdpath("data") .. "/javaquest/backups/" .. vim.fn.fnamemodify(root, ":t") .. "-" .. stamp
  local copied = 0

  for _, module in ipairs(modules) do
    for _, rel in ipairs(exercise_paths(config, module)) do
      local from = root .. "/" .. rel
      if vim.uv.fs_stat(from) then
        local to = dir .. "/" .. rel
        vim.fn.mkdir(vim.fn.fnamemodify(to, ":h"), "p")
        -- cp -R rather than a hand-rolled walk: it preserves the tree exactly.
        local result = vim.system({ "cp", "-R", from, to }, { text = true }):wait()
        if result.code == 0 then
          copied = copied + 1
        end
      end
    end
  end

  if copied == 0 then
    return nil
  end
  return dir
end

--- Restores one path to its state at `ref`, including REMOVING files that are not
--- in the ref (a plain `git checkout` would leave those behind).
local function restore_path(root, ref, path)
  -- What the pristine ref says should be there.
  local ok, listing = git(root, { "ls-tree", "-r", "--name-only", ref, "--", path })
  if not ok then
    return false, "cannot read " .. ref .. ": " .. listing
  end

  local pristine = {}
  for _, line in ipairs(vim.split(vim.trim(listing), "\n")) do
    if line ~= "" then
      pristine[line] = true
    end
  end
  if vim.tbl_isempty(pristine) then
    return false, "no files at " .. path .. " in " .. ref
  end

  -- Remove anything currently there that the ref does not have: files you added,
  -- and files that moved. Surgical rather than `rm -rf`, so a typo in the config
  -- cannot wipe an unrelated directory.
  local base = root .. "/" .. path
  if vim.uv.fs_stat(base) then
    for name, type_ in vim.fs.dir(base, { depth = 20 }) do
      if type_ == "file" then
        local rel = path .. "/" .. name
        if not pristine[rel] then
          vim.fn.delete(base .. "/" .. name)
        end
      end
    end
  end

  -- Overwrite the rest from the ref.
  local checked_out, err = git(root, { "checkout", ref, "--", path })
  if not checked_out then
    return false, err
  end
  return true, nil
end

--- Deletes the Surefire reports, so progress genuinely returns to zero rather
--- than showing whatever the last run happened to produce.
function M.clear_reports(root, modules)
  local removed = 0
  for _, module in ipairs(modules) do
    for _, name in ipairs({ "surefire-reports", "surefire-reports-solutions" }) do
      local dir = root .. "/" .. module.dir .. "/target/" .. name
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
  local path = vim.fn.stdpath("data") .. "/javaquest/" .. base .. "-" .. hash .. ".json"
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
  local backup = M.backup(root, config, modules)
  local ref = (config.pristine or {}).git_ref or "javaquest-pristine"

  -- Fail before touching anything if the reference point is missing.
  local ok, err = git(root, { "rev-parse", "--verify", ref })
  if not ok then
    vim.notify(
      ("javaquest: cannot restore, the '%s' reference does not exist.\n\n"
        .. "Recreate it from a commit where the stubs are untouched:\n"
        .. "    git tag %s <commit>\n\nNothing was changed."):format(ref, ref),
      vim.log.levels.ERROR
    )
    return false
  end

  local restored, failed = 0, {}
  for _, module in ipairs(modules) do
    for _, path in ipairs(exercise_paths(config, module)) do
      local done, reason = restore_path(root, ref, path)
      if done then
        restored = restored + 1
      else
        table.insert(failed, path .. ": " .. tostring(reason))
      end
    end
  end

  M.clear_reports(root, modules)
  if opts.history then
    M.clear_history(root)
  end

  -- Any open buffer for a restored file is now stale on disk.
  vim.cmd("silent! checktime")

  local lines = {
    ("javaquest: restored %d path(s) across %d module(s)"):format(restored, #modules),
    "",
    "  reports cleared, so progress is back to zero",
  }
  if opts.history then
    table.insert(lines, "  streak and trophies cleared")
  else
    table.insert(lines, "  streak and trophies KEPT (use :JavaQuestResetHistory to clear them)")
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
    require("javaquest.ui").refresh()
  end)
  return true
end

--- Full restart: every module, plus the streak and trophies. Requires typing.
function M.restart_all()
  local config, root = detect.config()
  if not config then
    vim.notify("javaquest: no .javaquest.json found", vim.log.levels.WARN)
    return
  end

  local modules = config.modules
  local prompt = table.concat({
    "",
    "  ⚠  FULL RESTART",
    "",
    ("  This discards your work in all %d modules and starts from scratch:"):format(#modules),
    "",
    "    · every src/main/java file goes back to its TODO stub",
    "    · all test reports are deleted, so progress returns to 0",
    "    · your streak and trophies are cleared",
    "",
    "  Kept: solutions/, src/test/java, and your git commits.",
    "  Your current files are backed up first.",
    "",
    "  Type  reset  to confirm (anything else aborts): ",
  }, "\n")

  local answer = vim.fn.input(prompt)
  print("")
  if vim.trim(answer):lower() ~= "reset" then
    vim.notify("javaquest: aborted, nothing changed", vim.log.levels.INFO)
    return
  end

  perform(root, config, modules, { history = true })
end

--- Restarts one module, keeping your streak and trophies.
function M.restart_module(which)
  local config, root = detect.config()
  if not config then
    vim.notify("javaquest: no .javaquest.json found", vim.log.levels.WARN)
    return
  end

  local function go(dir)
    local modules = target_modules(config, dir)
    if not modules then
      vim.notify("javaquest: no module matching '" .. tostring(dir) .. "'", vim.log.levels.WARN)
      return
    end
    local module = modules[1]
    vim.ui.select({ "no", "yes" }, {
      prompt = ("Reset %s (%s) to its TODO stubs? Your work there is backed up first."):format(
        module.dir, module.name
      ),
    }, function(choice)
      if choice ~= "yes" then
        vim.notify("javaquest: aborted", vim.log.levels.INFO)
        return
      end
      perform(root, config, modules, { history = false })
    end)
  end

  if which and which ~= "" then
    go(which)
    return
  end

  -- No argument: pick from a list.
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
