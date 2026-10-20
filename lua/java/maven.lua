-- ---------------------------------------------------------------------------
-- Running Maven from the editor.
--
-- Deliberately independent of the language server and of neotest: it is plain
-- string building plus a terminal, so it works while jdtls is still indexing
-- and it prints the same output you would get in a shell. When something looks
-- wrong, the command is visible at the top of the terminal and you can paste it.
-- ---------------------------------------------------------------------------

local M = {}

local JDK_21 = "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"

local term_buf, term_win

-- ---------------------------------------------------------------------------
-- Project geometry
-- ---------------------------------------------------------------------------

--- The module directory: nearest ancestor with a pom.xml.
local function module_root(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  if name == "" then
    name = vim.fn.getcwd()
  end
  return vim.fs.root(name, { "pom.xml" })
end

--- The reactor root, shared with the jdtls launcher so both agree.
local function reactor_root(bufnr)
  return require("java.jdtls").project_root(bufnr)
end

--- Fully-qualified class name from the buffer's path, so it works for both
--- src/main/java and src/test/java without parsing the file.
local function class_name(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr or 0)
  if path == "" or not path:match("%.java$") then
    return nil
  end
  return vim.fn.fnamemodify(path, ":t:r")
end

--- Nearest enclosing test method name, searching upwards from the cursor for a
--- method declaration that carries a JUnit annotation.
local function nearest_test_method()
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, cursor, false)

  for i = #lines, 1, -1 do
    -- A method declaration: optional modifiers, a return type, a name, then "(".
    local name = lines[i]:match("^%s*[%w%s<>%[%],%.]-%s+([%w_]+)%s*%(")
    if name and not lines[i]:match("^%s*//") and name ~= "if" and name ~= "for" and name ~= "while" then
      -- Walk back over annotations and blank lines looking for a JUnit marker.
      for j = i - 1, math.max(1, i - 12), -1 do
        local above = lines[j]
        if above:match("@Test") or above:match("@ParameterizedTest") or above:match("@RepeatedTest") then
          return name
        end
        -- Stop at the previous member: anything that is not an annotation,
        -- a comment or blank means we have left this method's header.
        if
          not above:match("^%s*@")
          and not above:match("^%s*$")
          and not above:match("^%s*//")
          and not above:match("^%s*%*")
          and not above:match("^%s*/%*")
        then
          break
        end
      end
    end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Terminal
-- ---------------------------------------------------------------------------

local function run(cmd, cwd, solutions)
  if not cwd then
    vim.notify("No pom.xml found above this file", vim.log.levels.ERROR)
    return
  end

  -- Reuse one bottom split so repeated runs do not stack up windows.
  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_win_close(term_win, true)
  end
  if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
    vim.api.nvim_buf_delete(term_buf, { force = true })
  end

  vim.cmd("botright 18split")
  term_win = vim.api.nvim_get_current_win()
  term_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(term_win, term_buf)

  local buf = term_buf
  vim.fn.jobstart(cmd, {
    term = true,
    cwd = cwd,
    env = { JAVA_HOME = JDK_21, PATH = JDK_21 .. "/bin:" .. vim.env.PATH },
    on_exit = function(_, code)
      vim.schedule(function()
        M.report(buf, code)
        -- Feed the progress panel, if this project has one. pcall because
        -- javaquest is optional and must never break a test run.
        pcall(function()
          require("javaquest").on_test_run({ solutions = solutions })
        end)
      end)
    end,
  })

  vim.bo[term_buf].filetype = "javatest"
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = term_buf, desc = "Close test output" })
  vim.cmd("normal! G")
  vim.cmd("wincmd p")
end

--- Reports the outcome honestly.
---
--- Maven's exit code is not enough. Surefire reports BUILD SUCCESS when a
--- -Dtest filter matches NOTHING — verified: both with and without
--- -DfailIfNoTests=false, a typo'd method name exits 0 with "Tests run: 0".
--- Trusting the exit code there means a typo looks exactly like a pass, which
--- is the worst possible failure mode for a TDD loop. So parse the summary.
function M.report(buf, code)
  local total, failures, errors, skipped

  if buf and vim.api.nvim_buf_is_valid(buf) then
    for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
      -- The aggregate summary has no trailing "-- in <class>"; the per-class
      -- lines do. Taking the last match that lacks it gives the total.
      local t, f, e, sk = line:match("Tests run: (%d+), Failures: (%d+), Errors: (%d+), Skipped: (%d+)")
      if t and not line:find("-- in ") then
        total, failures, errors, skipped = tonumber(t), tonumber(f), tonumber(e), tonumber(sk)
      end
    end
  end

  if total == nil then
    if code == 0 then
      vim.notify("Maven: finished (no test summary - compile-only run?)", vim.log.levels.INFO)
    else
      vim.notify("Maven: FAILED before running tests (exit " .. code .. ") - check the output",
        vim.log.levels.ERROR)
    end
    return
  end

  if total == 0 then
    vim.notify("Maven: NO TESTS MATCHED. Check the class or method name - this is not a pass.",
      vim.log.levels.ERROR)
    return
  end

  local bad = (failures or 0) + (errors or 0)
  local summary = ("%d run, %d failed, %d errors, %d skipped"):format(total, failures, errors, skipped)
  if bad == 0 and code == 0 then
    vim.notify("Maven: PASSED - " .. summary, vim.log.levels.INFO)
  else
    vim.notify("Maven: FAILED - " .. summary, vim.log.levels.WARN)
  end
end

--- Builds `mvn <goals> -pl <module>` run from the reactor root, which is what
--- makes a multi-module project behave: -pl scopes to one module while the
--- parent pom and sibling dependencies stay resolvable.
local function mvn(args, opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local root = reactor_root(bufnr)
  local module = module_root(bufnr)

  local cmd = { "mvn", "-B" }
  if opts.solutions then
    table.insert(cmd, "-Psolutions")
  end
  vim.list_extend(cmd, args)

  if module and root and module ~= root then
    local relative = module:sub(#root + 2)
    vim.list_extend(cmd, { "-pl", relative })
  end

  vim.notify("$ " .. table.concat(cmd, " "), vim.log.levels.INFO)
  run(cmd, root, opts.solutions)
end

-- ---------------------------------------------------------------------------
-- Public actions
-- ---------------------------------------------------------------------------

function M.test_class(opts)
  local class = class_name()
  if not class then
    vim.notify("Not a Java file", vim.log.levels.WARN)
    return
  end
  -- A bare class name already picks up @Nested inner classes.
  mvn({ "test", "-Dtest=" .. class }, opts)
end

function M.test_method(opts)
  local class = class_name()
  if not class then
    vim.notify("Not a Java file", vim.log.levels.WARN)
    return
  end
  local method = nearest_test_method()
  if not method then
    vim.notify("No @Test method found above the cursor; running the whole class", vim.log.levels.WARN)
    M.test_class(opts)
    return
  end
  -- The trailing * matters. Surefire's "Class#method" form does NOT match a
  -- method inside a @Nested class -- verified: it silently selects 0 tests.
  -- @Nested classes compile to Outer$Inner, and "Class*#method" matches both
  -- the outer class and any nested one, so one form covers both cases.
  mvn({ "test", "-Dtest=" .. class .. "*#" .. method }, opts)
end

function M.test_module(opts)
  mvn({ "test" }, opts)
end

function M.test_all(opts)
  local root = reactor_root(vim.api.nvim_get_current_buf())
  local cmd = { "mvn", "-B", "test" }
  if opts and opts.solutions then
    table.insert(cmd, 2, "-Psolutions")
  end
  vim.notify("$ " .. table.concat(cmd, " "), vim.log.levels.INFO)
  run(cmd, root, opts.solutions)
end

--- Builds and runs Maven against an EXPLICIT module directory, instead of deriving
--- it from the current buffer. That is what lets the JavaQuest panel -- a sidebar
--- buffer that belongs to no Maven module -- and the "run the current step" keymap
--- work from anywhere in the repo, including from a README or the file tree.
local function mvn_at(module_dir, args, opts)
  opts = opts or {}
  local root = require("java.jdtls").project_root(0)
  if not root or not module_dir then
    vim.notify("No Maven project found", vim.log.levels.ERROR)
    return
  end

  local cmd = { "mvn", "-B" }
  if opts.solutions then
    table.insert(cmd, "-Psolutions")
  end
  vim.list_extend(cmd, args)

  if module_dir ~= root then
    vim.list_extend(cmd, { "-pl", module_dir:sub(#root + 2) })
  end

  vim.notify("$ " .. table.concat(cmd, " "), vim.log.levels.INFO)
  run(cmd, root, opts.solutions)
end

--- Runs every test in the module at `module_dir`, regardless of which file is open.
--- The JavaQuest panel uses this to run "the next module" from anywhere.
function M.test_module_at(module_dir, opts)
  mvn_at(module_dir, { "test" }, opts)
end

--- Runs ONE test class in the module at `module_dir`, regardless of which file is
--- open. The point is the exercise loop: you are editing Money.java, but the tests
--- live in MoneyTest, so <leader>rt (which derives the class from the buffer) would
--- select 0 tests and report "NO TESTS MATCHED". JavaQuest knows the pairing from
--- .javaquest.json and calls this with the test class name.
function M.test_class_at(module_dir, class, opts)
  if not class then
    vim.notify("No test class is configured for this step", vim.log.levels.WARN)
    return
  end
  -- Bare class name, no "*": it already matches @Nested inner classes.
  mvn_at(module_dir, { "test", "-Dtest=" .. class }, opts)
end

function M.compile()
  mvn({ "-q", "test-compile" })
end

function M.attach_keymaps(bufnr)
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
  end
  map("<leader>rt", function() M.test_class() end, "Java: test this class")
  map("<leader>rm", function() M.test_method() end, "Java: test method under cursor")
  map("<leader>ra", function() M.test_module() end, "Java: test this module")
  map("<leader>rA", function() M.test_all() end, "Java: test every module")
  map("<leader>rs", function() M.test_class({ solutions = true }) end, "Java: test this class vs solutions")
  map("<leader>rc", function() M.compile() end, "Java: compile (main + test)")
end

return M
