return {
  -- GitLens-style inline git (gitsigns)
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local gs = require("gitsigns")

      gs.setup({
        signs = {
          add          = { text = "│" },
          change       = { text = "│" },
          delete       = { text = "_" },
          topdelete    = { text = "‾" },
          changedelete = { text = "~" },
        },

        -- keep this OFF by default; you can toggle it with <leader>gb
        current_line_blame = false,
        current_line_blame_opts = {
          delay = 300,
        },

        on_attach = function(bufnr)
          local opts = { buffer = bufnr, silent = true }

          -- Hunks
          vim.keymap.set("n", "]c", gs.next_hunk, opts)
          vim.keymap.set("n", "[c", gs.prev_hunk, opts)

          -- GitLens-ish
          vim.keymap.set("n", "<leader>gb", gs.toggle_current_line_blame, opts) -- inline blame on/off
          vim.keymap.set("n", "<leader>gh", gs.preview_hunk, opts)
          vim.keymap.set("n", "<leader>gr", gs.reset_hunk, opts)
          vim.keymap.set("n", "<leader>gd", gs.diffthis, opts)
          vim.keymap.set("n", "<leader>gB", function() gs.blame_line({ full = true }) end, opts)
          
          -- GitLens-style menu popup
          vim.keymap.set("n", "<leader>gm", function()
            require("plugins.git.menu").open()
          end, { buffer = bufnr, silent = true, desc = "Git: Open menu" })
        end,
      })

      -- ---------------------------
      -- Hover blame popup (toggle)
      -- ---------------------------
      vim.g.gitsigns_hover_blame = vim.g.gitsigns_hover_blame or false

      local function set_hover_blame(enabled)
        vim.g.gitsigns_hover_blame = enabled
        if enabled then
          vim.notify("Gitsigns hover blame: ON")
        else
          vim.notify("Gitsigns hover blame: OFF")
        end
      end

      vim.keymap.set("n", "<leader>gk", function()
        set_hover_blame(not vim.g.gitsigns_hover_blame)
      end, { desc = "Git: Toggle hover blame" })

      local aug = vim.api.nvim_create_augroup("GitsignsHoverBlame", { clear = true })
      vim.api.nvim_create_autocmd("CursorHold", {
        group = aug,
        callback = function()
          if not vim.g.gitsigns_hover_blame then return end
          -- only show on normal buffers
          if vim.bo.buftype ~= "" then return end
          -- show blame in a small float
          pcall(gs.blame_line, { full = false })
        end,
      })
    end,
  },

  -- Git UI (Neogit) + Diffview integration
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
    },
    config = function()
      require("neogit").setup({
        kind = "tab",
        integrations = { diffview = true },
      })

      -- Diffview keybinds (GitLens-ish diffs/history)
      vim.keymap.set("n", "<leader>go", "<cmd>DiffviewOpen<CR>", { desc = "Git: Diffview open", silent = true })
      vim.keymap.set("n", "<leader>gq", "<cmd>DiffviewClose<CR>", { desc = "Git: Diffview close", silent = true })
      vim.keymap.set("n", "<leader>gF", "<cmd>DiffviewFileHistory<CR>", { desc = "Git: Repo history", silent = true })
      vim.keymap.set("n", "<leader>gf", "<cmd>DiffviewFileHistory %<CR>", { desc = "Git: File history", silent = true })
    end,
  },
}

