-- ---------------------------------------------------------------------------
-- Java tooling. Same shape as lua/godot: a local module layered on the shared
-- LSP / DAP / terminal infrastructure rather than a pile of plugins.
--
-- jdtls itself is started per-buffer from after/ftplugin/java.lua. This file
-- only registers the global commands and the health check.
-- ---------------------------------------------------------------------------

local M = {}

local function cmd(name, fn, desc)
  vim.api.nvim_create_user_command(name, fn, { desc = desc })
end

function M.setup()
  local maven = function()
    return require("java.maven")
  end

  cmd("JavaTestClass", function() maven().test_class() end, "Run the current test class")
  cmd("JavaTestMethod", function() maven().test_method() end, "Run the test method under the cursor")
  cmd("JavaTestModule", function() maven().test_module() end, "Run every test in this Maven module")
  cmd("JavaTestAll", function() maven().test_all() end, "Run every test in the reactor")
  cmd("JavaTestSolutions", function() maven().test_class({ solutions = true }) end,
    "Run the current test class against solutions/")
  cmd("JavaCompile", function() maven().compile() end, "mvn test-compile")

  cmd("JavaRefresh", function()
    -- After editing a pom.xml: re-import the build so new dependencies resolve.
    local ok = pcall(function()
      require("jdtls").update_projects_config({ select_mode = "all" })
    end)
    vim.notify(ok and "jdtls: build configuration refreshed" or "jdtls: refresh failed",
      ok and vim.log.levels.INFO or vim.log.levels.ERROR)
  end, "Re-import the Maven/Gradle build into jdtls")

  cmd("JavaRestart", function()
    for _, client in ipairs(vim.lsp.get_clients({ name = "jdtls" })) do
      client:stop(true)
    end
    vim.defer_fn(function()
      require("java.jdtls").start()
      vim.notify("jdtls restarted", vim.log.levels.INFO)
    end, 500)
  end, "Restart jdtls for this project")

  cmd("JavaWipeWorkspace", function()
    -- The fix for jdtls reporting errors that make no sense: its incremental
    -- index is corrupt. Deleting the per-project workspace forces a clean import.
    local root = require("java.jdtls").project_root(0)
    local workspace = vim.fn.stdpath("cache") .. "/jdtls/workspace/" .. vim.fn.fnamemodify(root, ":t")
    vim.ui.select({ "no", "yes" }, { prompt = "Delete " .. workspace .. "?" }, function(choice)
      if choice ~= "yes" then
        return
      end
      for _, client in ipairs(vim.lsp.get_clients({ name = "jdtls" })) do
        client:stop(true)
      end
      vim.fn.delete(workspace, "rf")
      vim.notify("Workspace deleted. Reopen the file to re-index.", vim.log.levels.INFO)
    end)
  end, "Delete this project's jdtls workspace and re-index")

  cmd("JavaHealth", function() M.health() end, "Report on the Java toolchain")
end

local function status(label, ok, detail)
  return ("%s %-26s %s"):format(ok and "OK  " or "FAIL", label, detail or "")
end

function M.health()
  local mason = vim.fn.stdpath("data") .. "/mason"
  local lines = { "Java toolchain", "==============", "" }

  local jdk = "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  table.insert(lines, status("JDK 21", vim.uv.fs_stat(jdk) ~= nil, jdk))

  local mvn = vim.fn.exepath("mvn")
  table.insert(lines, status("maven", mvn ~= "", mvn ~= "" and mvn or "not on PATH"))

  for _, pkg in ipairs({ "jdtls", "java-debug-adapter", "java-test" }) do
    local path = mason .. "/packages/" .. pkg
    table.insert(lines, status("mason: " .. pkg, vim.uv.fs_stat(path) ~= nil, path))
  end

  table.insert(lines, status("nvim-jdtls", pcall(require, "jdtls")))

  local root = require("java.jdtls").project_root(0)
  table.insert(lines, "")
  table.insert(lines, status("project root", root ~= nil, root or "-"))
  local workspace = vim.fn.stdpath("cache") .. "/jdtls/workspace/" .. vim.fn.fnamemodify(root, ":t")
  table.insert(lines, status("jdtls workspace", true, workspace))

  local clients = vim.lsp.get_clients({ name = "jdtls" })
  table.insert(lines, status("jdtls attached", #clients > 0, #clients .. " client(s)"))

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

return M
