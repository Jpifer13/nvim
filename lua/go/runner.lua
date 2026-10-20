-- ---------------------------------------------------------------------------
-- Running Go tests from the editor.
--
-- The Go counterpart of lua/java/maven.lua, and deliberately the same shape:
-- plain string building plus a terminal, independent of gopls and of neotest,
-- with the exact command echoed so you can paste it into a shell.
--
-- Two modes:
--   * In a goquest project (a .goquest.json above the file) it runs the course's
--     ./quest wrapper, which records results for the progress panel and can run
--     the same tests against _solutions/.
--   * Anywhere else it runs plain `go test` from the go.mod directory.
--
-- Like maven.lua it reports from the OUTPUT, not the exit code. `go test -run
-- Typo ./...` exits 0 with "no tests to run", and a typo must never look like a
-- pass.
-- ---------------------------------------------------------------------------

local M = {}

local term_buf, term_win

-- ---------------------------------------------------------------------------
-- Project geometry
-- ---------------------------------------------------------------------------

local function buf_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  if name == "" or name:match("^%a[%w+.-]*://") then
    return nil
  end
  return name
end

--- The directory holding go.mod (or go.work), searched from the buffer or cwd.
function M.module_root(bufnr)
  return vim.fs.root(buf_path(bufnr) or vim.fn.getcwd(), { "go.work", "go.mod" })
end

--- The goquest root and config when the buffer is inside a course repo.
local function quest(bufnr)
  local ok, detect = pcall(require, "goquest.detect")
  if not ok then
    return nil
  end
  local path = buf_path(bufnr) or vim.fn.getcwd()
  local root = detect.root_of_path(path)
  if not root then
    return nil
  end
  local config = detect.config(root)
  if not config or vim.fn.executable(root .. "/quest") ~= 1 then
    return nil
  end
  return root, config
end

--- The course module a path belongs to, and the path relative to it.
local function quest_module(root, config, path)
  for _, module in ipairs(config.modules or {}) do
    local prefix = root .. "/" .. module.dir .. "/"
    if path and path:find(prefix, 1, true) == 1 then
      return module, path:sub(#prefix + 1)
    end
  end
  return nil
end

--- Nearest enclosing TestXxx/FuzzXxx/ExampleXxx above the cursor, plus the first
--- literal `t.Run("...")` between that func and the cursor, if any.
---
--- Subtest names in -run are matched per level against the name AFTER go test
--- rewrites it (spaces become underscores), so the literal is converted the
--- same way and regexp-quoted.
local function nearest_test()
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, cursor, false)
  for i = #lines, 1, -1 do
    local name = lines[i]:match("^func%s+((Test%w*))%s*%(")
      or lines[i]:match("^func%s+((Fuzz%w*))%s*%(")
      or lines[i]:match("^func%s+((Example%w*))%s*%(")
    if name and name ~= "TestMain" then
      local sub
      for j = i + 1, #lines do
        local literal = lines[j]:match('t%.Run%(%s*"([^"]+)"')
        if literal then
          sub = literal
        end
      end
      return name, sub
    end
  end
  return nil
end

local function regexp_quote(s)
  return (s:gsub("[%.%+%*%?%(%)%[%]%^%$|{}\\]", "\\%0"))
end

local function run_pattern(name, sub)
  local pattern = "^" .. name .. "$"
  if sub then
    pattern = pattern .. "/^" .. regexp_quote(sub:gsub(" ", "_")) .. "$"
  end
  return pattern
end

-- ---------------------------------------------------------------------------
-- Terminal
-- ---------------------------------------------------------------------------

local function run(cmd, cwd, opts)
  opts = opts or {}
  if not cwd then
    vim.notify("No go.mod found above this file", vim.log.levels.ERROR)
    return
  end

  -- Reuse one bottom split so repeated runs do not stack up windows.
  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_win_close(term_win, true)
  end
  if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
    vim.api.nvim_buf_delete(term_buf, { force = true })
  end

  vim.notify("$ " .. table.concat(cmd, " "), vim.log.levels.INFO)

  vim.cmd("botright 18split")
  term_win = vim.api.nvim_get_current_win()
  term_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(term_win, term_buf)

  local result_file = opts.quest and (cwd .. "/.quest/last-run.json") or nil
  if result_file then
    vim.fn.delete(result_file)
  end

  local buf = term_buf
  vim.fn.jobstart(cmd, {
    term = true,
    cwd = cwd,
    on_exit = function(_, code)
      -- on_exit can fire before the terminal has rendered the last of the
      -- output, and the line that matters (quest's RESULT) IS the last. Wait for
      -- the "[Process exited N]" marker Neovim appends once everything is in.
      local function finished()
        if not vim.api.nvim_buf_is_valid(buf) then
          return true
        end
        for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, -6, -1, false)) do
          if line:match("^%[Process exited") then
            return true
          end
        end
        return false
      end
      local deadline = vim.uv.now() + 3000
      local function settle(next_step)
        if finished() or vim.uv.now() > deadline then
          next_step()
        else
          vim.defer_fn(function() settle(next_step) end, 25)
        end
      end
      settle(function()
        M.report(buf, code, result_file)
        if opts.quest then
          -- Feed the progress panel. pcall because goquest is optional and must
          -- never break a test run.
          pcall(function()
            require("goquest").on_test_run({ solutions = opts.solutions })
          end)
        end
      end)
    end,
  })

  vim.bo[term_buf].filetype = "gotest"
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = term_buf, desc = "Close test output" })
  vim.cmd("normal! G")
  vim.cmd("wincmd p")
end

--- Reports the outcome honestly, from the output rather than the exit code.
---
--- `result_file` is quest's .quest/last-run.json, deleted before the run started,
--- so if it exists it belongs to this run. It is read instead of the terminal:
--- with the goquest panel pinned to the right the terminal can be narrow, and a
--- terminal hard-wraps long lines, which once split quest's RESULT line in two.
function M.report(buf, code, result_file)
  local lines = {}
  if buf and vim.api.nvim_buf_is_valid(buf) then
    lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

  if result_file then
    local ok, content = pcall(vim.fn.readfile, result_file)
    local decoded = ok and pcall(vim.json.decode, table.concat(content, "\n")) and vim.json.decode(table.concat(content, "\n"))
    if type(decoded) ~= "table" then
      vim.notify(("Go: FAILED before any test ran (exit %d) - check the output"):format(code), vim.log.levels.ERROR)
      return
    end
    do
      local total, passed, failed, skipped, build =
        decoded.total, decoded.passed, decoded.failed, decoded.skipped, decoded.build_failed
      if build > 0 then
        vim.notify(("Go: DOES NOT COMPILE (%d package%s) - check the output"):format(build, build == 1 and "" or "s"),
          vim.log.levels.ERROR)
      elseif total == 0 then
        vim.notify("Go: NO TESTS MATCHED. Check the file or test name - this is not a pass.", vim.log.levels.ERROR)
      elseif failed == 0 then
        vim.notify(("Go: PASSED - %d run, %d skipped"):format(total, skipped), vim.log.levels.INFO)
      else
        vim.notify(("Go: FAILED - %d run, %d passed, %d failed"):format(total, passed, failed), vim.log.levels.WARN)
      end
      return
    end
  end

  -- Plain go test.
  local fails, oks, no_tests, build_failed = 0, 0, 0, false
  for _, line in ipairs(lines) do
    if line:match("^%s*%-%-%- FAIL") then
      fails = fails + 1
    elseif line:match("^ok%s") then
      oks = oks + 1
      if line:match("%[no tests to run%]") then
        no_tests = no_tests + 1
      end
    elseif line:match("%[build failed%]") or line:match("%[setup failed%]") then
      build_failed = true
    end
  end

  if build_failed then
    vim.notify("Go: DOES NOT COMPILE - check the output", vim.log.levels.ERROR)
  elseif code == 0 and oks > 0 and no_tests == oks then
    vim.notify("Go: NO TESTS MATCHED. Check the test name - this is not a pass.", vim.log.levels.ERROR)
  elseif code == 0 then
    vim.notify("Go: PASSED", vim.log.levels.INFO)
  elseif fails > 0 then
    vim.notify(("Go: FAILED - %d failing test%s"):format(fails, fails == 1 and "" or "s"), vim.log.levels.WARN)
  else
    vim.notify("Go: FAILED (exit " .. code .. ") - check the output", vim.log.levels.ERROR)
  end
end

-- ---------------------------------------------------------------------------
-- Command builders
-- ---------------------------------------------------------------------------

local function quest_cmd(root, args, opts)
  local cmd = { root .. "/quest", "test" }
  vim.list_extend(cmd, args)
  if opts and opts.solutions then
    table.insert(cmd, "-solutions")
  end
  return cmd
end

--- `./pkg` relative to the module root, for the buffer's package.
local function package_pattern(root, bufnr)
  local path = buf_path(bufnr)
  if not path then
    return "./..."
  end
  local dir = vim.fn.fnamemodify(path, ":h")
  if dir == root then
    return "."
  end
  return "./" .. dir:sub(#root + 2)
end

-- ---------------------------------------------------------------------------
-- Public actions (buffer-relative)
-- ---------------------------------------------------------------------------

--- This test file in a course repo (the step it belongs to, from an exercise
--- file); this package otherwise.
function M.test_file(opts)
  opts = opts or {}
  local qroot, config = quest(0)
  local path = buf_path(0)

  if qroot then
    local module, rel = quest_module(qroot, config, path)
    if not module then
      return M.test_all(opts)
    end
    rel = rel:gsub("^_solutions/", "")
    local test = rel:match("_test%.go$") and rel or nil
    if not test then
      for _, step in ipairs(module.steps or {}) do
        if vim.tbl_contains(step.files or {}, rel) then
          test = step.test
        end
      end
    end
    if not test then
      return M.test_module(opts)
    end
    return run(quest_cmd(qroot, { module.dir, "-file", test }, opts), qroot, { quest = true, solutions = opts.solutions })
  end

  if opts.solutions then
    vim.notify("Solutions runs only exist in a goquest project", vim.log.levels.WARN)
    return
  end
  local root = M.module_root(0)
  run({ "go", "test", package_pattern(root, 0) }, root)
end

--- The test function (and literal subtest) under the cursor.
function M.test_nearest(opts)
  opts = opts or {}
  local name, sub = nearest_test()
  if not name then
    vim.notify("No Test/Fuzz/Example func above the cursor; running the file", vim.log.levels.WARN)
    return M.test_file(opts)
  end
  local pattern = run_pattern(name, sub)

  local qroot, config = quest(0)
  if qroot then
    local module = quest_module(qroot, config, buf_path(0))
    if module then
      return run(quest_cmd(qroot, { module.dir, "-run", pattern }, opts), qroot,
        { quest = true, solutions = opts.solutions })
    end
  end
  local root = M.module_root(0)
  run({ "go", "test", "-run", pattern, "-v", package_pattern(root, 0) }, root)
end

--- Every test in the course module (quest) or under the go.mod directory.
function M.test_module(opts)
  opts = opts or {}
  local qroot, config = quest(0)
  if qroot then
    local module = quest_module(qroot, config, buf_path(0))
    if module then
      return M.test_module_at(qroot .. "/" .. module.dir, opts)
    end
  end
  local root = M.module_root(0)
  run({ "go", "test", "./..." }, root)
end

function M.test_all(opts)
  opts = opts or {}
  local qroot = quest(0)
  if qroot then
    return M.test_all_at(qroot, opts)
  end
  local root = M.module_root(0)
  run({ "go", "test", "./..." }, root)
end

function M.vet()
  local root = M.module_root(0)
  run({ "go", "vet", "./..." }, root)
end

-- ---------------------------------------------------------------------------
-- Public actions (explicit paths, for the goquest panel)
-- ---------------------------------------------------------------------------

local function split_module_dir(module_dir)
  local root = require("goquest.detect").root_of_path(module_dir)
  if not root then
    return nil
  end
  return root, module_dir:sub(#root + 2)
end

--- Runs every test in the course module at `module_dir`.
function M.test_module_at(module_dir, opts)
  opts = opts or {}
  local root, dir = split_module_dir(module_dir)
  if not root then
    vim.notify("Not inside a goquest project", vim.log.levels.ERROR)
    return
  end
  run(quest_cmd(root, { dir }, opts), root, { quest = true, solutions = opts.solutions })
end

--- Runs ONE test file in the course module at `module_dir`. The point is the
--- exercise loop: editing money.go, the tests live in money_test.go, and the
--- panel knows the pairing from .goquest.json.
function M.test_file_at(module_dir, test_file, opts)
  opts = opts or {}
  if not test_file then
    vim.notify("No test file is configured for this step", vim.log.levels.WARN)
    return
  end
  local root, dir = split_module_dir(module_dir)
  if not root then
    vim.notify("Not inside a goquest project", vim.log.levels.ERROR)
    return
  end
  run(quest_cmd(root, { dir, "-file", test_file }, opts), root, { quest = true, solutions = opts.solutions })
end

--- Runs every course module.
function M.test_all_at(root, opts)
  opts = opts or {}
  if not root then
    vim.notify("Not inside a goquest project", vim.log.levels.ERROR)
    return
  end
  run(quest_cmd(root, {}, opts), root, { quest = true, solutions = opts.solutions })
end

function M.attach_keymaps(bufnr)
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
  end
  map("<leader>rt", function() M.test_file() end, "Go: test this file (quest) / package")
  map("<leader>rm", function() M.test_nearest() end, "Go: test func (or t.Run) under cursor")
  map("<leader>ra", function() M.test_module() end, "Go: test this module")
  map("<leader>rA", function() M.test_all() end, "Go: test everything")
  map("<leader>rs", function() M.test_file({ solutions = true }) end, "Go: test this file vs _solutions/")
  map("<leader>rc", function() M.vet() end, "Go: go vet ./...")
end

return M
