-- ---------------------------------------------------------------------------
-- Progress, derived from the reports the course's own runner writes.
--
-- Deliberately NOT a checklist you tick. `./quest test` (which lua/go/runner.lua
-- calls in a goquest project) wraps `go test -json` and records one small JSON
-- file per test file:
--
--   <root>/.quest/reports/<module>/<test file>.json
--   { "build_failed": false, "tests": [ { "name": "TestX/sub", "status": "pass" } ] }
--
-- Only LEAF tests are recorded (a TestXxx with subtests is a container, like a
-- JUnit class), so the counts mean the same thing they did in javaquest.
--
-- Solutions runs go to .quest/reports-solutions/, which this never reads, so
-- checking an answer cannot mark a module complete.
--
-- Mirrors readModule in internal/quest/runner.go: keep the two in step.
-- ---------------------------------------------------------------------------

local M = {}

local REPORTS = ".quest/reports"

local function read_json(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  local decoded
  ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok or type(decoded) ~= "table" then
    return nil
  end
  return decoded
end

--- "TestMoneyArithmetic/Plus_rejects_mixed_currencies"
---   -> "MoneyArithmetic: Plus rejects mixed currencies"
function M.pretty(name)
  local top, rest = name:match("^([^/]+)/(.+)$")
  top = (top or name):gsub("^Test", ""):gsub("^Fuzz", "fuzz ")
  if not rest then
    return top
  end
  return top .. ": " .. rest:gsub("_", " "):gsub("/", " › ")
end

--- Parses one report into { total, failing, failures = {names}, build_failed }.
local function parse_report(path)
  local report = read_json(path)
  if not report then
    return nil
  end
  local out = { total = 0, failing = 0, failures = {}, build_failed = report.build_failed == true }
  for _, test in ipairs(report.tests or {}) do
    out.total = out.total + 1
    if test.status == "fail" then
      out.failing = out.failing + 1
      table.insert(out.failures, M.pretty(test.name or "?"))
    end
  end
  if out.build_failed then
    -- Nothing ran. Say so first, rather than listing tests that never got a chance.
    table.insert(out.failures, 1, "does not compile — see the test output")
  end
  return out
end

--- Scans one module. `attempted` is false when no reports exist yet.
---
--- `classes` is keyed by the step's test file (e.g. "money_test.go"), the Go
--- equivalent of javaquest's test class, so the UI code is shared in shape.
function M.scan_module(root, module)
  local reports_dir = root .. "/" .. REPORTS .. "/" .. module.dir
  local out = {
    dir = module.dir,
    total = 0,
    passing = 0,
    failing = 0,
    attempted = false,
    build_failed = false,
    classes = {},
  }

  local in_steps = {}
  for _, step in ipairs(module.steps or {}) do
    in_steps[step.test] = true
    local parsed = parse_report(reports_dir .. "/" .. step.test .. ".json")
    if parsed then
      out.attempted = true
      -- An empty, compiled report keeps the configured count: there is no
      -- evidence of how many tests there are.
      if parsed.total == 0 then
        parsed.total = step.tests or 0
        parsed.failing = parsed.total
      end
      parsed.name = step.test
      out.classes[step.test] = parsed
      out.build_failed = out.build_failed or parsed.build_failed
      out.total = out.total + parsed.total
      out.failing = out.failing + parsed.failing
    else
      -- Not run yet: counts as its configured tests, all outstanding. Without
      -- this, running one step would make the module look finished the moment
      -- that step went green.
      out.total = out.total + (step.tests or 0)
      out.failing = out.failing + (step.tests or 0)
    end
  end

  -- Test files that are not part of any step still count toward the module.
  if vim.uv.fs_stat(reports_dir) then
    for name, type_ in vim.fs.dir(reports_dir, { depth = 10 }) do
      local rel = type_ == "file" and name:match("^(.+)%.json$")
      if rel and not in_steps[rel] then
        local parsed = parse_report(reports_dir .. "/" .. name)
        if parsed and parsed.total > 0 then
          parsed.name = rel
          out.classes[rel] = parsed
          out.attempted = true
          out.total = out.total + parsed.total
          out.failing = out.failing + parsed.failing
        end
      end
    end
  end

  if out.total == 0 and module.tests then
    out.total = module.tests
    out.failing = module.tests
  end
  out.passing = out.total - out.failing

  local all_reported = true
  for _, step in ipairs(module.steps or {}) do
    if not out.classes[step.test] then
      all_reported = false
    end
  end
  out.complete = out.attempted and all_reported and not out.build_failed and out.failing == 0 and out.total > 0
  return out
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
        if not class or class.failing > 0 or class.build_failed then
          return {
            module = module,
            step = step,
            class = class,
            failures = class and class.failures or {},
          }
        end
      end
      -- Every configured step is green but something else in the module is not.
      -- Point at it rather than lying.
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
