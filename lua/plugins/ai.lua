return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false, -- never set to "*"
    build = vim.fn.has("win32") ~= 0
      and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
      or "make",

    opts = function()
      local models = {
        "openai/gpt-oss-20b",
        "qwen3-32b",
        "athene-v2-chat",
        "qwq-32b",
        "llama-3.3-70b-instruct",
        "gemma-3-27b-it",
        "deepseek-r1-distill-qwen-7b",
      }

      local function provider_name_for(model)
        return ("lmstudio_%s"):format(model:gsub("[^%w]+", "_"))
      end

      local providers = {
        -- Keep Claude as an option
        claude = {
          endpoint = "https://api.anthropic.com",
          model = "claude-sonnet-4-5-20250929",
          timeout = 30000,
          extra_request_body = { temperature = 0.2, max_tokens = 4096 },
         -- extra_request_body = { temperature = 0, max_tokens = 64000 },
        },
      }

      -- One provider per LM Studio model
      for _, model in ipairs(models) do
        local name = provider_name_for(model)
        providers[name] = {
          __inherited_from = "openai",
          endpoint = "http://localhost:1234/v1",
          model = model,
          timeout = 60000,
          extra_request_body = { temperature = 0.2, max_tokens = 4096 },
        }
      end

      local default_provider = provider_name_for("openai/gpt-oss-20b")

      -- Popup picker
      vim.keymap.set("n", "<leader>am", function()
        vim.ui.select(models, { prompt = "Avante model (LM Studio):" }, function(choice)
          if not choice then return end
          local provider = provider_name_for(choice)
          vim.cmd("AvanteSwitchProvider " .. provider)
          vim.notify("Avante model: " .. choice)
        end)
      end, { desc = "Avante: switch LM Studio model" })

      -- Quick switch back to Claude
      vim.keymap.set("n", "<leader>ac", function()
        vim.cmd("AvanteSwitchProvider claude")
        vim.notify("Avante provider: claude")
      end, { desc = "Avante: switch to Claude" })

      return {
        instructions_file = "avante.md",
        provider = default_provider,
        providers = providers,
      }
    end,

    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      "nvim-treesitter/nvim-treesitter",
      "hrsh7th/nvim-cmp",
    },
  },
}