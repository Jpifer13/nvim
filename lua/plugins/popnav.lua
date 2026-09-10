return {
  {
    "Jpifer13/popnav.nvim",
    keys = {
      { "<leader>pp", function() require("popnav").menu() end, desc = "Popnav: menu" },
      { "<leader>pn", function() require("popnav").next() end, desc = "Popnav: next" },
      { "<leader>pP", function() require("popnav").prev() end, desc = "Popnav: prev" },
      { "<leader>px", function() require("popnav").close_all() end, desc = "Popnav: close all" },
      { "<leader>p1", function() require("popnav").select(1) end, desc = "Popnav: popup 1" },
      { "<leader>p2", function() require("popnav").select(2) end, desc = "Popnav: popup 2" },
      { "<leader>p3", function() require("popnav").select(3) end, desc = "Popnav: popup 3" },
      { "<leader>p4", function() require("popnav").select(4) end, desc = "Popnav: popup 4" },
    },
    config = function()
      local ft = require("floating_terminal")
      local claude_session_started = false

      require("popnav").setup({
        popups = {
          {
            name = "Terminal",
            icon = "🖥",
            open = ft.open,
            close = ft.close,
            destroy = ft.destroy,
            is_open = ft.is_open,
          },
          {
            name = "Cheatsheet",
            icon = "📋",
            open = function() require("cheatsheet").open() end,
            close = function()
              for _, win in ipairs(vim.api.nvim_list_wins()) do
                local buf = vim.api.nvim_win_get_buf(win)
                if vim.bo[buf].filetype == "cheatsheet" then
                  vim.api.nvim_win_close(win, true)
                  return
                end
              end
            end,
            is_open = function()
              for _, win in ipairs(vim.api.nvim_list_wins()) do
                local buf = vim.api.nvim_win_get_buf(win)
                if vim.bo[buf].filetype == "cheatsheet" then
                  return true
                end
              end
              return false
            end,
          },
          {
            name = "Claude",
            icon = "🤖",
            open = function()
              if claude_session_started then
                vim.cmd("ClaudeCode")
                return
              end
              vim.ui.select(
                { "New session", "Continue last session", "Pick session" },
                { prompt = "Claude Code:" },
                function(choice)
                  if not choice then return end
                  claude_session_started = true
                  if choice == "New session" then
                    vim.cmd("ClaudeCode")
                  elseif choice == "Continue last session" then
                    vim.cmd("ClaudeCode --continue")
                  elseif choice == "Pick session" then
                    vim.cmd("ClaudeCode --resume")
                  end
                end
              )
            end,
            close = function() vim.cmd("ClaudeCode") end,
            is_open = function()
              for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_get_config(win).relative ~= "" then
                  local buf = vim.api.nvim_win_get_buf(win)
                  if vim.api.nvim_buf_get_name(buf):match("claude") then
                    return true
                  end
                end
              end
              return false
            end,
          },
          {
            name = "OpenCode",
            icon = "📝",
            open = function() require("opencode").open() end,
            close = function() require("opencode").close() end,
            is_open = function() return require("opencode").is_open() end,
          },
        },
      })
    end,
  },
}
