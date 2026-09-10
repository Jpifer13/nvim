return {
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local harpoon = require("harpoon")
      harpoon:setup({
        settings = {
          save_on_toggle = true,
          sync_on_ui_close = true,
        },
      })

      local function harpoon_select(idx)
        local item = harpoon:list():get(idx)
        if not item then return end

        local path = vim.fn.fnamemodify(item.value, ":p")
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.api.nvim_buf_get_name(buf) == path then
            vim.api.nvim_set_current_win(win)
            return
          end
        end

        harpoon:list():select(idx)
      end

      local function harpoon_nav(direction)
        local list = harpoon:list()
        local len = list:length()
        if len == 0 then return end

        local current = vim.api.nvim_buf_get_name(0)
        local cur_idx = nil
        for i = 1, len do
          local item = list:get(i)
          if item and vim.fn.fnamemodify(item.value, ":p") == current then
            cur_idx = i
            break
          end
        end

        local next_idx
        if not cur_idx then
          next_idx = 1
        elseif direction == "next" then
          next_idx = cur_idx % len + 1
        else
          next_idx = (cur_idx - 2) % len + 1
        end

        harpoon_select(next_idx)
      end

      -- Add file to harpoon
      vim.keymap.set("n", "<leader>ha", function()
        harpoon:list():add()
        vim.notify("Added to Harpoon", vim.log.levels.INFO)
      end, { desc = "Harpoon: Add file" })

      -- Toggle harpoon menu
      vim.keymap.set("n", "<leader>hh", function()
        harpoon.ui:toggle_quick_menu(harpoon:list())
      end, { desc = "Harpoon: Toggle menu" })

      -- Navigate to specific files (1-4)
      vim.keymap.set("n", "<leader>h1", function() harpoon_select(1) end, { desc = "Harpoon: File 1" })
      vim.keymap.set("n", "<leader>h2", function() harpoon_select(2) end, { desc = "Harpoon: File 2" })
      vim.keymap.set("n", "<leader>h3", function() harpoon_select(3) end, { desc = "Harpoon: File 3" })
      vim.keymap.set("n", "<leader>h4", function() harpoon_select(4) end, { desc = "Harpoon: File 4" })

      -- Navigate through list
      vim.keymap.set("n", "<leader>hn", function() harpoon_nav("next") end, { desc = "Harpoon: Next" })
      vim.keymap.set("n", "<leader>hp", function() harpoon_nav("prev") end, { desc = "Harpoon: Previous" })

      -- Clear all
      vim.keymap.set("n", "<leader>hc", function()
        harpoon:list():clear()
        vim.notify("Harpoon cleared", vim.log.levels.INFO)
      end, { desc = "Harpoon: Clear all" })
    end,
  },
}

