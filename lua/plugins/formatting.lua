return {
  {
    "stevearc/conform.nvim",
    config = function()
      local conform = require("conform")

      conform.setup({
        formatters_by_ft = {
          python = { "black" },
          javascript = { "prettier" },
          typescript = { "prettier" },
          json = { "prettier" },
          yaml = { "prettier" },
          markdown = { "prettier" },
        },
      })

      vim.api.nvim_create_autocmd("BufWritePre", {
        callback = function(args)
          conform.format({
            bufnr = args.buf,
            lsp_fallback = true,
          })
        end,
      })
    end,
  },
}
