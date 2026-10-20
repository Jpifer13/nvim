-- ---------------------------------------------------------------------------
-- Go tooling. Same shape as lua/java and lua/godot: a local module layered on
-- the shared LSP / DAP / terminal infrastructure.
--
-- gopls is configured in lua/lsp.lua (native vim.lsp.config, no special launcher
-- needed, unlike jdtls). This file registers the :Go* commands, the health
-- check, and the buffer-local keymaps that after/ftplugin/go.lua attaches.
-- ---------------------------------------------------------------------------

local M = {}

local function runner()
  return require("go.runner")
end

local function cmd(name, fn, desc, opts)
  opts = opts or {}
  opts.desc = desc
  vim.api.nvim_create_user_command(name, fn, opts)
end

function M.setup()
  cmd("GoTestFile", function() runner().test_file() end, "Run this test file (goquest) or this package")
  cmd("GoTestNearest", function() runner().test_nearest() end, "Run the test func or t.Run under the cursor")
  cmd("GoTestModule", function() runner().test_module() end, "Run this course module, or ./...")
  cmd("GoTestAll", function() runner().test_all() end, "Run every test")
  cmd("GoTestSolutions", function() runner().test_file({ solutions = true }) end,
    "Run this test file against _solutions/ (goquest projects)")
  cmd("GoVet", function() runner().vet() end, "go vet ./...")
  cmd("GoModTidy", function()
    local root = runner().module_root(0)
    local result = vim.system({ "go", "mod", "tidy" }, { cwd = root, text = true }):wait()
    if result.code == 0 then
      vim.notify("go mod tidy: done", vim.log.levels.INFO)
      -- gopls caches the module graph; nudge it.
      vim.cmd("silent! checktime")
    else
      vim.notify("go mod tidy failed:\n" .. (result.stderr or ""), vim.log.levels.ERROR)
    end
  end, "go mod tidy in the go.mod directory")
  cmd("GoHealth", function() M.health() end, "Report on the Go toolchain")
end

--- Buffer-local keymaps for a Go buffer. Called from after/ftplugin/go.lua.
function M.attach(bufnr)
  if vim.b[bufnr].go_keys then
    return
  end
  vim.b[bufnr].go_keys = true

  runner().attach_keymaps(bufnr)

  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
  end
  -- Same keys as Java's: <leader>dt debugs the nearest test there too.
  map("<leader>dt", function() require("dap-go").debug_test() end, "Go: debug nearest test")
  map("<leader>dT", function() require("dap-go").debug_last_test() end, "Go: debug last test again")
end

local function status(label, ok, detail)
  return ("%s %-26s %s"):format(ok and "OK  " or "FAIL", label, detail or "")
end

local function version_of(bin, args)
  if vim.fn.executable(bin) ~= 1 then
    return nil
  end
  local result = vim.system(vim.list_extend({ bin }, args), { text = true }):wait()
  return vim.trim(((result.stdout or "") .. (result.stderr or "")):match("[^\n]*"))
end

function M.health()
  local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/"
  local lines = { "Go toolchain", "============", "" }

  local go = version_of("go", { "version" })
  table.insert(lines, status("go", go ~= nil, go or "not on PATH"))

  for _, tool in ipairs({ "gopls", "dlv", "goimports" }) do
    local path = mason_bin .. tool
    local found = vim.fn.executable(path) == 1 and path or (vim.fn.exepath(tool) ~= "" and vim.fn.exepath(tool) or nil)
    table.insert(lines, status(tool, found ~= nil, found or "missing: :MasonInstall " .. (tool == "dlv" and "delve" or tool)))
  end

  table.insert(lines, status("nvim-dap-go", (pcall(require, "dap-go"))))

  local root = runner().module_root(0)
  table.insert(lines, "")
  table.insert(lines, status("go.mod root", root ~= nil, root or "-"))
  local clients = vim.lsp.get_clients({ name = "gopls", bufnr = 0 })
  table.insert(lines, status("gopls attached", #clients > 0, #clients .. " client(s)"))

  local ok, detect = pcall(require, "goquest.detect")
  local quest_root = ok and detect.root_of_path(vim.api.nvim_buf_get_name(0) ~= "" and vim.api.nvim_buf_get_name(0) or vim.fn.getcwd())
  table.insert(lines, status("goquest project", true, quest_root or "no (plain go test mode)"))

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
