return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      -- Test adapters
      "nvim-neotest/neotest-python",
      "nvim-neotest/neotest-jest",
      "rcasia/neotest-java",
      "fredrikaverpil/neotest-golang",
    },
    keys = {
      { "<leader>ae", function()
        -- Get AWS profiles and let user pick one, then run SSO login and set env
        vim.fn.jobstart({ "aws", "configure", "list-profiles" }, {
          stdout_buffered = true,
          on_stdout = function(_, data)
            local profiles = vim.tbl_filter(function(p) return p ~= "" end, data or {})
            if #profiles == 0 then
              vim.schedule(function()
                vim.notify("No AWS profiles found", vim.log.levels.WARN)
              end)
              return
            end
            vim.schedule(function()
              vim.ui.select(profiles, { prompt = "Select AWS profile:" }, function(profile)
                if not profile then return end
                vim.notify("Logging into AWS SSO for: " .. profile .. " ...", vim.log.levels.INFO)
                vim.fn.jobstart({ "aws", "sso", "login", "--profile", profile }, {
                  on_exit = function(_, code)
                    vim.schedule(function()
                      if code == 0 then
                        vim.fn.setenv("AWS_PROFILE", profile)
                        vim.notify("AWS profile set to: " .. profile, vim.log.levels.INFO)
                      else
                        vim.notify("AWS SSO login failed for: " .. profile, vim.log.levels.ERROR)
                      end
                    end)
                  end,
                })
              end)
            end)
          end,
        })
      end, desc = "Test: AWS env login" },
      { "<leader>nr", function() require("neotest").run.run() end, desc = "Test: Run nearest" },
      { "<leader>nf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Test: Run file" },
      { "<leader>ns", function() require("neotest").summary.toggle() end, desc = "Test: Summary panel" },
      { "<leader>no", function() require("neotest").output_panel.toggle() end, desc = "Test: Output panel" },
      { "<leader>np", function() require("neotest").output.open({ enter = true }) end, desc = "Test: Output popup" },
      { "<leader>nd", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "Test: Debug nearest" },
      { "<leader>nl", function() require("neotest").run.run_last() end, desc = "Test: Run last" },
      { "<leader>nx", function() require("neotest").run.stop() end, desc = "Test: Stop" },
      { "<leader>nw", function() require("neotest").watch.toggle(vim.fn.expand("%")) end, desc = "Test: Watch file" },
      { "[n", function() require("neotest").jump.prev({ status = "failed" }) end, desc = "Test: Prev failed" },
      { "]n", function() require("neotest").jump.next({ status = "failed" }) end, desc = "Test: Next failed" },
    },
    config = function()
      local adapters = {
        require("neotest-python")({
          dap = { justMyCode = false },
          runner = "pytest",
          python = function()
            -- Use venv python if available
            local venv = vim.fn.getcwd() .. "/.venv/bin/python"
            if vim.fn.filereadable(venv) == 1 then
              return venv
            end
            return "python3"
          end,
        }),
        require("neotest-jest")({
          jestCommand = "npx jest",
          cwd = function()
            return vim.fn.getcwd()
          end,
        }),
      }

      -- neotest-java is optional. It shells out to Maven/Gradle and fetches a
      -- JUnit platform launcher on first use, so a failure here must not take
      -- the Python and TypeScript adapters down with it. When it is missing,
      -- use the :JavaTest* commands / <leader>r* keymaps from lua/java/maven.lua.
      local java_ok, neotest_java = pcall(require, "neotest-java")
      if java_ok then
        table.insert(adapters, neotest_java({}))
      end

      -- neotest-golang, optional for the same reason. In a goquest course repo
      -- prefer <leader>rt / <leader>'t: neotest runs `go test` directly, so its
      -- runs are not recorded as progress.
      local go_ok, neotest_golang = pcall(require, "neotest-golang")
      if go_ok then
        table.insert(adapters, neotest_golang({}))
      end

      require("neotest").setup({
        adapters = adapters,
        summary = {
          mappings = {
            run = "r",
            debug = "d",
            mark = "m",
            run_marked = "R",
            debug_marked = "D",
            clear_marked = "M",
            output = "o",
            short = "O",
            expand = { "<CR>", "<2-LeftMouse>" },
            expand_all = "e",
            jumpto = "i",
            stop = "x",
            attach = "a",
            clear_target = "T",
            next_failed = "J",
            prev_failed = "K",
            target = "t",
            watch = "w",
          },
        },
        status = {
          virtual_text = true,
        },
        output = {
          open_on_run = false,
        },
        quickfix = {
          open = function()
            vim.cmd("copen")
          end,
        },
      })
    end,
  },
}
