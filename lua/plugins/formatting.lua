return {
  {
    "stevearc/conform.nvim",
    config = function()
      local conform = require("conform")

      local formatters_by_ft = {
        python = { "black" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
      }

      -- gdformat ships with gdtoolkit (pip install gdtoolkit). Only wire it up
      -- inside a Godot project so a missing binary never breaks save elsewhere.
      if require("godot.detect").is_project() and vim.fn.executable("gdformat") == 1 then
        formatters_by_ft.gdscript = { "gdformat" }
      end

      conform.setup({
        formatters_by_ft = formatters_by_ft,
        formatters = {
          black = {
            -- Bypass pyenv shim to avoid timeout
            command = vim.fn.expand("~/.pyenv/versions/3.13.3/bin/black"),
          },
          gdformat = {
            command = "gdformat",
            args = { "-" },
            stdin = true,
          },
        },
      })

      vim.api.nvim_create_autocmd("BufWritePre", {
        callback = function(args)
          conform.format({
            bufnr = args.buf,
            lsp_fallback = true,
            timeout_ms = 5000,
          })
        end,
      })
    end,
  },
}
