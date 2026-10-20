-- ---------------------------------------------------------------------------
-- Progress, derived from Surefire's XML reports.
--
-- Deliberately NOT a checklist you tick. The only source of truth is what the
-- test runner actually produced, so the panel cannot tell you a comfortable lie.
--
-- Two things learned the hard way while building this, both encoded below:
--
--   1. The <testsuite tests="N"> attribute is WRONG for @Nested classes -- it
--      reports 0 while the file contains 14 <testcase> elements. So count the
--      testcase elements, never the attribute.
--
--   2. A `mvn -Psolutions` run used to overwrite these same files, which marked
--      modules complete when you had written nothing. The parent pom now sends
--      solutions runs to target/surefire-reports-solutions, and this module only
--      ever reads target/surefire-reports.
--
-- Stale reports (a test class you deleted) are ignored, because only classes that
-- still exist under src/test/java are considered.
-- ---------------------------------------------------------------------------

local M = {}

local REPORTS = "target/surefire-reports"

--- Every test class that currently exists in a module, as simple class names.
local function expected_classes(module_dir)
  local root = module_dir .. "/src/test/java"
  if not vim.uv.fs_stat(root) then
    return {}
  end
  local classes = {}
  for name, type_ in vim.fs.dir(root, { depth = 10 }) do
    if type_ == "file" and name:match("%.java$") then
      local simple = vim.fn.fnamemodify(name, ":t:r")
      classes[simple] = true
    end
  end
  return classes
end

--- Parses one report file into { total, failing, failures = {names} }.
local function parse_report(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  local xml = table.concat(lines, "\n")

  local result = { total = 0, failing = 0, skipped = 0, failures = {} }

  -- Split on <testcase and inspect each chunk up to the next one: if it contains
  -- <failure or <error, that case did not pass.
  local chunks = vim.split(xml, "<testcase", { plain = true })
  for i = 2, #chunks do
    local chunk = chunks[i]
    result.total = result.total + 1

    local name = chunk:match('^%s*name="([^"]*)"')
    if chunk:find("<failure", 1, true) or chunk:find("<error", 1, true) then
      result.failing = result.failing + 1
      if name then
        -- Strip the parameterized-test suffix so the list reads cleanly.
        table.insert(result.failures, (name:gsub("%b()", ""):gsub("%[%d+%]$", "")))
      end
    elseif chunk:find("<skipped", 1, true) then
      result.skipped = result.skipped + 1
    end
  end

  return result
end

--- Scans one module. `attempted` is false when no reports exist yet.
function M.scan_module(root, module)
  local dir = root .. "/" .. module.dir
  local reports_dir = dir .. "/" .. REPORTS

  local out = {
    dir = module.dir,
    total = 0,
    passing = 0,
    failing = 0,
    attempted = false,
    classes = {},
  }

  -- The fallback total from the config, applied on EVERY exit path below.
  --
  -- This matters most immediately after :JavaQuestRestart, when the reports
  -- directory does not exist at all: without it the panel reported "0/0 tests"
  -- instead of "0/338", which reads like the repo is empty rather than untouched.
  local function finish()
    if out.total == 0 and module.tests then
      out.total = module.tests
    end
    out.complete = out.attempted and out.failing == 0 and out.total > 0
    return out
  end

  if not vim.uv.fs_stat(reports_dir) then
    return finish()
  end

  local wanted = expected_classes(dir)

  for name, type_ in vim.fs.dir(reports_dir) do
    local class = type_ == "file" and name:match("^TEST%-(.+)%.xml$")
    if class then
      local simple = class:match("([^.]+)$")
      -- Ignore reports for classes that no longer exist (stale artifacts), and
      -- ignore the inner-class report variants Surefire sometimes emits.
      local base = simple and simple:match("^([^%$]+)") or nil
      if base and wanted[base] then
        local parsed = parse_report(reports_dir .. "/" .. name)
        if parsed and parsed.total > 0 then
          out.attempted = true
          local existing = out.classes[base]
          if existing then
            existing.total = existing.total + parsed.total
            existing.failing = existing.failing + parsed.failing
            vim.list_extend(existing.failures, parsed.failures)
          else
            out.classes[base] = {
              name = base,
              total = parsed.total,
              failing = parsed.failing,
              failures = parsed.failures,
            }
          end
        end
      end
    end
  end

  for _, class in pairs(out.classes) do
    out.total = out.total + class.total
    out.failing = out.failing + class.failing
  end
  out.passing = out.total - out.failing

  return finish()
end

--- Scans every module in the config.
function M.scan(root, config)
  local result = {
    modules = {},
    by_dir = {},
    tests = 0,
    passing = 0,
    failing = 0,
    complete_modules = 0,
  }

  for _, module in ipairs(config.modules) do
    local scanned = M.scan_module(root, module)
    scanned.config = module
    table.insert(result.modules, scanned)
    result.by_dir[module.dir] = scanned

    result.tests = result.tests + scanned.total
    result.passing = result.passing + scanned.passing
    result.failing = result.failing + scanned.failing
    if scanned.complete then
      result.complete_modules = result.complete_modules + 1
    end
  end

  return result
end

--- The next thing to do: the first incomplete module, and within it the first
--- step (in the config's declared order) that is not yet green.
function M.next_step(progress)
  for _, module in ipairs(progress.modules) do
    if not module.complete then
      local steps = module.config.steps or {}
      for _, step in ipairs(steps) do
        local class = module.classes[step.test]
        if not class or class.failing > 0 then
          return {
            module = module,
            step = step,
            class = class,
            failures = class and class.failures or {},
          }
        end
      end
      -- Module incomplete but every configured step is green: something failing
      -- was not listed in the config. Point at it anyway rather than lying.
      for _, class in pairs(module.classes) do
        if class.failing > 0 then
          return { module = module, step = { test = class.name, files = {} }, class = class, failures = class.failures }
        end
      end
      return { module = module, step = steps[1], class = nil, failures = {} }
    end
  end
  return nil
end

return M
