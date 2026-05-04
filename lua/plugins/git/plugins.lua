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

  -- Diffview (merge/diff UI with conflict resolution keymaps)
  {
    "sindrets/diffview.nvim",
    config = function()
      local actions = require("diffview.actions")
      require("diffview").setup({
        keymaps = {
          view = {
            { "n", "<leader>co", actions.conflict_choose("ours"), { desc = "Conflict: accept ours" } },
            { "n", "<leader>ct", actions.conflict_choose("theirs"), { desc = "Conflict: accept theirs" } },
            { "n", "<leader>cb", actions.conflict_choose("base"), { desc = "Conflict: accept base" } },
            { "n", "<leader>ca", actions.conflict_choose("all"), { desc = "Conflict: accept all" } },
            { "n", "<leader>cO", actions.conflict_choose_all("ours"), { desc = "Conflict: accept ALL ours (file)" } },
            { "n", "<leader>cT", actions.conflict_choose_all("theirs"), { desc = "Conflict: accept ALL theirs (file)" } },
            { "n", "<leader>cB", actions.conflict_choose_all("base"), { desc = "Conflict: accept ALL base (file)" } },
            { "n", "<leader>cA", actions.conflict_choose_all("all"), { desc = "Conflict: accept ALL (file)" } },
            { "n", "]x", actions.next_conflict, { desc = "Next conflict" } },
            { "n", "[x", actions.prev_conflict, { desc = "Previous conflict" } },
          },
          file_panel = {
            { "n", "<leader>co", actions.conflict_choose("ours"), { desc = "Conflict: accept ours" } },
            { "n", "<leader>ct", actions.conflict_choose("theirs"), { desc = "Conflict: accept theirs" } },
            { "n", "<leader>cO", actions.conflict_choose_all("ours"), { desc = "Conflict: accept ALL ours (file)" } },
            { "n", "<leader>cT", actions.conflict_choose_all("theirs"), { desc = "Conflict: accept ALL theirs (file)" } },
          },
        },
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
        -- VSCode-style sidebar (vertical split on the right)
        kind = "vsplit",
        
        -- Configure split behavior
        signs = {
          section = { "", "" },  -- Collapsible sections
          item = { "", "" },
          hunk = { "", "" },
        },
        
        -- Commit popup settings
        commit_popup = {
          kind = "split",
        },
        
        -- Popup settings
        popup = {
          kind = "split",
        },
        
        -- Integrations
        integrations = { 
          diffview = true,
          telescope = true,
        },
        
        -- Auto-refresh when files change
        auto_refresh = true,
        
        -- Show commit graph
        graph_style = "unicode",
        
        -- Sections to show (like VSCode source control)
        sections = {
          untracked = {
            folded = false,  -- Show untracked files expanded
            hidden = false,
          },
          unstaged = {
            folded = false,  -- Show unstaged changes expanded
            hidden = false,
          },
          staged = {
            folded = false,  -- Show staged changes expanded
            hidden = false,
          },
          stashes = {
            folded = true,
            hidden = false,
          },
          unpulled = {
            folded = true,
            hidden = false,
          },
          unmerged = {
            folded = false,
            hidden = false,
          },
          recent = {
            folded = true,
            hidden = false,
          },
        },
      })

      -- Diffview keybinds (GitLens-ish diffs/history)
      vim.keymap.set("n", "<leader>go", "<cmd>DiffviewOpen<CR>", { desc = "Git: Diffview open", silent = true })
      vim.keymap.set("n", "<leader>gq", "<cmd>DiffviewClose<CR>", { desc = "Git: Diffview close", silent = true })
      vim.keymap.set("n", "<leader>gF", "<cmd>DiffviewFileHistory<CR>", { desc = "Git: Repo history", silent = true })
      vim.keymap.set("n", "<leader>gf", "<cmd>DiffviewFileHistory %<CR>", { desc = "Git: File history", silent = true })
    end,
  },
}

