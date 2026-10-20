-- ---------------------------------------------------------------------------
-- jdtls (Eclipse JDT Language Server) launcher.
--
-- Follows the same shape as lua/godot/lsp.lua: reuse the shared capabilities
-- and on_attach from lua/lsp.lua, then add only the language-specific pieces.
--
-- jdtls cannot use vim.lsp.config/enable like the other servers in this config:
-- it needs a per-project data directory passed on the command line, plus
-- extended client capabilities and Eclipse plugin bundles that the generic
-- client does not know about. That is exactly what nvim-jdtls exists for, so
-- it is started from after/ftplugin/java.lua instead.
-- ---------------------------------------------------------------------------

local M = {}

-- Pinned explicitly rather than trusting PATH: nvim is often launched from a
-- non-interactive shell that never sourced ~/.zshrc, and Homebrew's `maven`
-- formula pulls in an unversioned `openjdk` that would otherwise win.
local JDK_21 = "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"

local BUILD_MARKERS = { "pom.xml", "build.gradle", "build.gradle.kts", "mvnw", "gradlew" }

local function has_marker(dir)
  for _, marker in ipairs(BUILD_MARKERS) do
    if vim.uv.fs_stat(dir .. "/" .. marker) then
      return true
    end
  end
  return false
end

--- The OUTERMOST build root, not the closest one.
---
--- vim.fs.root stops at the first ancestor holding a marker, which for a file in
--- a Maven module means the module's own pom.xml. jdtls would then treat that
--- submodule as the whole project and lose the parent pom, the dependency
--- management and every sibling module. Walking up while the parent still looks
--- like a build root lands on the reactor root instead.
function M.project_root(bufnr)
  local start = vim.api.nvim_buf_get_name(bufnr or 0)
  if start == "" then
    start = vim.fn.getcwd()
  end

  local closest = vim.fs.root(start, BUILD_MARKERS)
  if not closest then
    return vim.fs.root(start, { ".git" }) or vim.fn.getcwd()
  end

  local current = closest
  while true do
    local parent = vim.fs.dirname(current)
    if not parent or parent == current then
      break
    end
    if not has_marker(parent) then
      break
    end
    current = parent
  end
  return current
end

--- Eclipse plugin bundles: java-debug-adapter gives DAP, java-test gives the
--- test runner. Both are Mason packages.
local function bundles()
  local packages = vim.fn.stdpath("data") .. "/mason/packages"
  local jars = {}

  vim.list_extend(
    jars,
    vim.fn.glob(
      packages .. "/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar",
      true,
      true
    )
  )

  -- java-test ships some jars that must NOT be handed to jdtls; passing the
  -- runner or the jacoco agent makes the server fail to start.
  for _, jar in ipairs(vim.fn.glob(packages .. "/java-test/extension/server/*.jar", true, true)) do
    if not jar:match("runner%-jar%-with%-dependencies") and not jar:match("jacocoagent") then
      table.insert(jars, jar)
    end
  end

  return jars
end

local function runtimes()
  local found = {}
  local candidates = {
    { name = "JavaSE-21", path = JDK_21, default = true },
    { name = "JavaSE-17", path = "/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home" },
  }
  for _, runtime in ipairs(candidates) do
    if vim.uv.fs_stat(runtime.path) then
      table.insert(found, runtime)
    end
  end
  return found
end

local function on_attach(client, bufnr)
  -- Shared keymaps first (gd, gr, K, <leader>rn, <leader>ca, [d, ]d, ...), so
  -- Java behaves like every other language here.
  local shared = require("lsp")
  if shared and shared.on_attach then
    shared.on_attach(client, bufnr)
  end

  local jdtls = require("jdtls")
  local map = function(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
  end

  -- Code actions that have no generic LSP equivalent. All of these are also
  -- reachable through <leader>ca; these are just the ones worth a direct key.
  map("n", "<leader>co", jdtls.organize_imports, "Java: organize imports")
  map("n", "<leader>cg", function()
    -- The "source" action family: generate getters/setters, constructors,
    -- toString, hashCode/equals, override methods, delegate methods.
    vim.lsp.buf.code_action({ context = { only = { "source" } } })
  end, "Java: generate... (getters, constructor, toString)")
  map("n", "<leader>cx", jdtls.extract_variable, "Java: extract variable")
  map("v", "<leader>cx", function()
    jdtls.extract_variable(true)
  end, "Java: extract variable")
  map("n", "<leader>ck", jdtls.extract_constant, "Java: extract constant")
  map("v", "<leader>ck", function()
    jdtls.extract_constant(true)
  end, "Java: extract constant")
  map("v", "<leader>cm", function()
    jdtls.extract_method(true)
  end, "Java: extract method")

  -- Test + build keymaps live in lua/java/maven.lua so they work even when the
  -- language server is still indexing.
  require("java.maven").attach_keymaps(bufnr)

  -- DAP. java-debug-adapter registers a "java" adapter; the existing <leader>d*
  -- keymaps and dap-ui then work unchanged.
  local ok = pcall(jdtls.setup_dap, { hotcodereplace = "auto", config_overrides = {} })
  if ok then
    map("n", "<leader>dt", jdtls.test_class, "Java: debug test class")
    map("n", "<leader>dT", jdtls.test_nearest_method, "Java: debug nearest test")
    -- Discovering main classes hits the build system, so it is deferred and
    -- allowed to fail quietly in a project that has none.
    vim.defer_fn(function()
      pcall(function()
        require("jdtls.dap").setup_dap_main_class_configs()
      end)
    end, 2000)
  end

  -- No capability guard here, and none anywhere else in this file: jdtls
  -- announces definition / codeAction / formatting / rename / hover through
  -- dynamic registration AFTER initialize, so client.server_capabilities still
  -- reads nil for them long after they work. Gating a keymap on it silently
  -- never binds. lua/lsp.lua's on_attach already maps <leader>f to format.
end

function M.config(bufnr)
  local root = M.project_root(bufnr)
  local shared = require("lsp")

  -- One jdtls workspace per project, keyed by directory name. Sharing a single
  -- workspace across projects is the usual cause of phantom errors.
  local workspace = vim.fn.stdpath("cache") .. "/jdtls/workspace/" .. vim.fn.fnamemodify(root, ":t")

  local extended = vim.tbl_deep_extend(
    "force",
    require("jdtls").extendedClientCapabilities,
    { resolveAdditionalTextEditsSupport = true }
  )

  return {
    name = "jdtls",
    cmd = {
      vim.fn.stdpath("data") .. "/mason/bin/jdtls",
      "-data",
      workspace,
      "--jvm-arg=-Xmx2G",
      "--jvm-arg=-XX:+UseParallelGC",
      "--jvm-arg=-XX:GCTimeRatio=4",
      "--jvm-arg=-Dlog.level=WARN",
    },
    -- Forces the server itself onto JDK 21 no matter how nvim was launched.
    cmd_env = { JAVA_HOME = JDK_21 },
    root_dir = root,
    capabilities = shared and shared.capabilities or nil,
    on_attach = on_attach,
    init_options = {
      bundles = bundles(),
      extendedClientCapabilities = extended,
    },
    settings = {
      java = {
        signatureHelp = { enabled = true },
        contentProvider = { preferred = "fernflower" },
        references = { includeDecompiledSources = true },
        implementationsCodeLens = { enabled = false },
        referencesCodeLens = { enabled = false },
        inlayHints = { parameterNames = { enabled = "literals" } },
        maven = { downloadSources = true },
        eclipse = { downloadSources = true },
        format = { enabled = true },
        configuration = {
          -- "interactive" prompts before re-importing when a pom changes.
          -- :JavaRefresh forces it.
          updateBuildConfiguration = "interactive",
          runtimes = runtimes(),
        },
        sources = {
          -- Never collapse imports into java.util.* — reviewers hate it and it
          -- hides ambiguity between same-named classes.
          organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 },
        },
        completion = {
          importOrder = { "java", "javax", "jakarta", "org", "com", "" },
          -- Static members offered without an explicit import first. This is the
          -- single biggest quality-of-life setting for writing tests: typing
          -- `assertThat` just works.
          favoriteStaticMembers = {
            "org.junit.jupiter.api.Assertions.*",
            "org.junit.jupiter.api.Assumptions.*",
            "org.assertj.core.api.Assertions.*",
            "org.mockito.Mockito.*",
            "org.mockito.ArgumentMatchers.*",
            "org.awaitility.Awaitility.*",
            "org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*",
            "org.springframework.test.web.servlet.result.MockMvcResultMatchers.*",
            "org.springframework.test.web.servlet.result.MockMvcResultHandlers.*",
            "java.util.Objects.requireNonNull",
            "java.util.stream.Collectors.*",
          },
        },
      },
    },
  }
end

function M.start(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ok, jdtls = pcall(require, "jdtls")
  if not ok then
    vim.notify("nvim-jdtls is not installed", vim.log.levels.ERROR)
    return
  end

  if vim.fn.executable(vim.fn.stdpath("data") .. "/mason/bin/jdtls") == 0 then
    vim.notify("jdtls not installed. Run :MasonInstall jdtls", vim.log.levels.ERROR)
    return
  end

  jdtls.start_or_attach(M.config(bufnr))
end

return M
