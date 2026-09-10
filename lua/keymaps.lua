-- ============================================================
-- Safe “command” keymaps only (no Vim motion overrides)
-- ============================================================

---------------------------------------------------------------
-- Core file / editor commands
---------------------------------------------------------------
vim.keymap.set("n", "<leader>w", ":w<CR>", { silent = true, desc = "Save" })
vim.keymap.set("n", "<leader>q", function()
  local bufs = vim.tbl_filter(function(b)
    return vim.bo[b].buflisted and vim.bo[b].filetype ~= "NvimTree"
  end, vim.api.nvim_list_bufs())
  if #bufs <= 1 then
    vim.cmd("qa")
    return
  end

  local cur = vim.api.nvim_get_current_buf()
  -- Don't try to close the tree itself if it's focused.
  if vim.bo[cur].filetype == "NvimTree" then
    return
  end

  -- Focus the neighbouring buffer before deleting, so focus stays in the
  -- editor instead of jumping to the file tree. Direction is controlled by
  -- vim.g.close_tab_direction ("right" or "left"); falls back to the other
  -- side at the ends of the list.
  local target
  local prefer_left = vim.g.close_tab_direction == "left"
  for i, b in ipairs(bufs) do
    if b == cur then
      if prefer_left then
        target = bufs[i - 1] or bufs[i + 1]
      else
        target = bufs[i + 1] or bufs[i - 1]
      end
      break
    end
  end
  if target then
    vim.api.nvim_set_current_buf(target)
  end
  vim.cmd("bdelete " .. cur)
end, { silent = true, desc = "Close tab (quit if last)" })

-- Toggle auto-save
vim.g.autosave_enabled = true  -- Enabled by default
vim.keymap.set("n", "<leader>ta", function()
  vim.g.autosave_enabled = not vim.g.autosave_enabled
  if vim.g.autosave_enabled then
    vim.notify("Auto-save enabled", vim.log.levels.INFO)
  else
    vim.notify("Auto-save disabled", vim.log.levels.WARN)
  end
end, { desc = "Toggle auto-save" })

---------------------------------------------------------------
-- File tree
---------------------------------------------------------------
vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { silent = true, desc = "File Tree" })

---------------------------------------------------------------
-- Telescope
---------------------------------------------------------------
vim.keymap.set("n", "<leader>ff", function()
  require("telescope.builtin").find_files()
end, { silent = true, desc = "Find Files" })

vim.keymap.set("n", "<leader>fg", function()
  require("telescope.builtin").live_grep()
end, { silent = true, desc = "Live Grep" })

vim.keymap.set("n", "<leader>fb", function()
  require("telescope.builtin").buffers()
end, { silent = true, desc = "Buffers" })

---------------------------------------------------------------
-- Git (Neogit)
---------------------------------------------------------------
vim.keymap.set("n", "<leader>gs", ":Neogit<CR>", { silent = true, desc = "Neogit Status" })

---------------------------------------------------------------
-- Terminal (floating, persistent session)
---------------------------------------------------------------
vim.keymap.set("n", "<leader>\\", function()
  require("floating_terminal").toggle()
end, { desc = "Toggle Floating Terminal" })

vim.keymap.set("t", "<leader>\\", function()
  require("floating_terminal").toggle()
end, { desc = "Toggle Floating Terminal" })

---------------------------------------------------------------
-- Buffer tab navigation (falls through to window at edges)
---------------------------------------------------------------
local function listed_bufs_sorted()
  local bufs = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].buflisted then
      table.insert(bufs, b)
    end
  end
  table.sort(bufs)
  return bufs
end

vim.keymap.set("n", "<C-h>", function()
  local cur = vim.api.nvim_get_current_buf()
  if not vim.bo[cur].buflisted then
    vim.cmd("wincmd h")
    return
  end
  local bufs = listed_bufs_sorted()
  if #bufs <= 1 or cur == bufs[1] then
    vim.cmd("wincmd h")
  else
    vim.cmd("BufferLineCyclePrev")
  end
end, { desc = "Prev tab / window left at edge" })

vim.keymap.set("n", "<C-l>", function()
  local cur = vim.api.nvim_get_current_buf()
  if not vim.bo[cur].buflisted then
    vim.cmd("wincmd l")
    return
  end
  local bufs = listed_bufs_sorted()
  if #bufs <= 1 or cur == bufs[#bufs] then
    vim.cmd("wincmd l")
  else
    vim.cmd("BufferLineCycleNext")
  end
end, { desc = "Next tab / window right at edge" })

---------------------------------------------------------------
-- Window navigation
---------------------------------------------------------------
vim.keymap.set("n", "<C-S-h>", "<C-w>h", { desc = "Window Left" })
vim.keymap.set("n", "<C-S-l>", "<C-w>l", { desc = "Window Right" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Window Down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Window Up" })

---------------------------------------------------------------
-- Run Python file in venv
---------------------------------------------------------------
vim.keymap.set("n", "<leader>rp", function()
  vim.cmd("botright split | terminal ./.venv/bin/python " .. vim.fn.expand("%"))
end, { desc = "Run Python (.venv)" })

---------------------------------------------------------------
-- Debugger (nvim-dap) — lazy-safe
---------------------------------------------------------------
vim.keymap.set("n", "<leader>dc", function()
  require("dap").continue()
end, { desc = "Debug: Continue" })

vim.keymap.set("n", "<leader>dn", function()
  require("dap").step_over()
end, { desc = "Debug: Step Over" })

vim.keymap.set("n", "<leader>di", function()
  require("dap").step_into()
end, { desc = "Debug: Step Into" })

vim.keymap.set("n", "<leader>do", function()
  require("dap").step_out()
end, { desc = "Debug: Step Out" })

vim.keymap.set("n", "<leader>db", function()
  require("dap").toggle_breakpoint()
end, { desc = "Debug: Toggle Breakpoint" })

vim.keymap.set("n", "<leader>dB", function()
  require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, { desc = "Debug: Conditional Breakpoint" })

vim.keymap.set("n", "<leader>dr", function()
  require("dap").repl.open()
end, { desc = "Debug: REPL" })

vim.keymap.set("n", "<leader>dl", function()
  require("dap").run_last()
end, { desc = "Debug: Run Last" })

vim.keymap.set("n", "<leader>dq", function()
  require("dap").terminate()
end, { desc = "Debug: Terminate" })

vim.keymap.set("n", "<leader>du", function()
  require("dapui").toggle()
end, { desc = "Debug: Toggle UI" })

---------------------------------------------------------------
-- SSH Remote
---------------------------------------------------------------
vim.keymap.set("n", "<leader>sr", function()
  require("ssh_remote").pick()
end, { desc = "SSH Remote: pick host" })

---------------------------------------------------------------
-- Cheat sheet
---------------------------------------------------------------
vim.keymap.set("n", "<leader>?", function()
  require("cheatsheet").open()
end, { desc = "Cheat Sheet" })

---------------------------------------------------------------
-- Previews
---------------------------------------------------------------
vim.keymap.set(
  "n",
  "<leader>mp",
  function() require("markdown_preview").open() end,
  { desc = "Markdown Preview Popup", silent = true }
)

vim.keymap.set(
  "n",
  "<leader>cv",
  "<cmd>CsvViewToggle<CR>",
  { desc = "CSV Table View Toggle", silent = true }
)

vim.keymap.set("n", "<leader>df", function()
  require("debug.fastapi_aws").pick_and_debug()
end, { desc = "Debug FastAPI: pick AWS profile -> ae -> start -> debugpy -> attach" })

---------------------------------------------------------------
-- Tetris
---------------------------------------------------------------
vim.keymap.set("n", "<leader>TT", function()
  require("tetris").start()
end, { desc = "Tetris" })

---------------------------------------------------------------
-- Zen mode
---------------------------------------------------------------
vim.keymap.set("n", "<leader>z", "<cmd>ZenMode<CR>", { desc = "Focus mode (Zen)" })

---------------------------------------------------------------
-- Claude Code AI
---------------------------------------------------------------
local claude_session_started = false

-- Toggle Claude — shows session picker only on first open per Neovim session
local function claude_toggle()
  if claude_session_started then
    -- Already launched this session, just toggle
    vim.cmd("ClaudeCode")
    return
  end

  -- First time opening — ask how to start
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
end

-- Toggle OpenCode — persistent snacks terminal (see lua/opencode.lua)
local function opencode_toggle()
  require("opencode").open()
end

-- Toggle AI assistant — close if one is open, otherwise pick
local function is_claude_open()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_get_name(buf):match("claude") then
        return true
      end
    end
  end
  return false
end

vim.keymap.set("n", "<leader>at", function()
  if is_claude_open() then
    vim.cmd("ClaudeCode")
    return
  end
  if require("opencode").is_open() then
    require("opencode").close()
    return
  end
  vim.ui.select(
    { "Claude Code", "OpenCode" },
    { prompt = "AI assistant:" },
    function(choice)
      if not choice then return end
      if choice == "Claude Code" then
        claude_toggle()
      elseif choice == "OpenCode" then
        opencode_toggle()
      end
    end
  )
end, { desc = "AI: Pick assistant (Claude Code / OpenCode)" })

-- Switch to a new session or pick a different one mid-session
vim.keymap.set("n", "<leader>as", function()
  claude_session_started = false
  -- Close current if open
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_get_name(buf):match("claude") then
        vim.cmd("ClaudeCode")
        break
      end
    end
  end
  -- Show picker for next open
  vim.notify("Claude session reset — next <leader>at will show session picker", vim.log.levels.INFO)
end, { desc = "Claude: Switch session" })

-- Hide Claude from inside the terminal (like floating terminal toggle)
vim.keymap.set("t", "<leader>AT", function()
  vim.cmd("ClaudeCode")
end, { desc = "Claude: Minimize (hide window)" })

vim.keymap.set("n", "<leader>af", "<cmd>ClaudeCodeFocus<CR>", { desc = "Claude: Focus panel" })
vim.keymap.set("v", "<leader>aa", "<cmd>ClaudeCodeSend<CR>", { desc = "Claude: Send selection" })
vim.keymap.set("n", "<leader>am", "<cmd>ClaudeCodeSelectModel<CR>", { desc = "Claude: Select model" })
vim.keymap.set("n", "<leader>ab", "<cmd>ClaudeCodeAdd %<CR>", { desc = "Claude: Add current file" })

---------------------------------------------------------------
-- AI Git helpers (Claude Code CLI)
---------------------------------------------------------------
local function get_claude_path()
  local path = vim.fn.exepath("claude")
  return path ~= "" and path or "claude"
end

-- AI branch: generate name from current changes
vim.keymap.set("n", "<leader>gn", function()
  local diff = vim.fn.system("git diff HEAD")
  if vim.v.shell_error ~= 0 or vim.trim(diff) == "" then
    diff = vim.fn.system("git status --porcelain")
  end
  if vim.trim(diff) == "" then
    vim.notify("No changes to base branch name on", vim.log.levels.WARN)
    return
  end
  if #diff > 8000 then diff = diff:sub(1, 8000) .. "\n...(truncated)" end

  vim.notify("Generating branch name...", vim.log.levels.INFO)

  local prompt = "Based on this git diff, suggest ONE branch name. kebab-case, 2-4 words, prefix with feat/ fix/ refactor/ or chore/. Output ONLY the branch name, nothing else.\n\n" .. diff

  vim.fn.jobstart({ get_claude_path(), "-p", prompt }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local branch = vim.trim(table.concat(data, ""))
      if branch == "" then return end
      vim.schedule(function()
        vim.ui.input({ prompt = "Create branch: ", default = branch }, function(input)
          if not input or input == "" then return end
          local out = vim.fn.system({ "git", "checkout", "-b", input })
          vim.notify(
            vim.v.shell_error == 0 and ("Switched to: " .. input) or ("Error: " .. out),
            vim.v.shell_error == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
          )
        end)
      end)
    end,
  })
end, { desc = "Git: AI create branch" })

-- AI commit: generate message from staged changes, with staging picker
vim.keymap.set("n", "<leader>gc", function()
  local status = vim.fn.system("git status --porcelain")
  if vim.trim(status) == "" then
    vim.notify("Nothing to commit", vim.log.levels.WARN)
    return
  end

  -- Parse staged vs unstaged files
  local unstaged = {}
  local has_staged = false
  for line in status:gmatch("[^\n]+") do
    local x, y = line:sub(1, 1), line:sub(2, 2)
    local file = line:sub(4)
    if x ~= " " and x ~= "?" then has_staged = true end
    if y ~= " " or x == "?" then
      table.insert(unstaged, line:sub(1, 2) .. " " .. file)
    end
  end

  -- Generate AI commit message from whatever is staged, then commit
  local function ai_commit()
    local diff = vim.fn.system("git diff --staged")
    if vim.trim(diff) == "" then
      vim.notify("Nothing staged", vim.log.levels.WARN)
      return
    end
    if #diff > 8000 then diff = diff:sub(1, 8000) .. "\n...(truncated)" end

    vim.notify("Generating commit message...", vim.log.levels.INFO)

    local prompt = "Write a concise git commit message for these staged changes. Conventional commit format (feat:, fix:, refactor:, etc). One line, under 72 chars. Output ONLY the message, nothing else.\n\n" .. diff

    vim.fn.jobstart({ get_claude_path(), "-p", prompt }, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        local msg = vim.trim(table.concat(data, ""))
        if msg == "" then return end
        vim.schedule(function()
          vim.ui.input({ prompt = "Commit message: ", default = msg }, function(input)
            if not input or input == "" then return end
            local out = vim.fn.system({ "git", "commit", "-m", input })
            vim.notify(
              vim.v.shell_error == 0 and ("Committed: " .. input) or ("Error: " .. out),
              vim.v.shell_error == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
            )
          end)
        end)
      end,
    })
  end

  -- Telescope multi-select picker for staging files
  local function pick_files_to_stage(callback)
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers.new({}, {
      prompt_title = "Stage files (Tab = select, Enter = confirm)",
      finder = finders.new_table({ results = unstaged }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local picker = action_state.get_current_picker(prompt_bufnr)
          local selections = picker:get_multi_selection()
          if #selections == 0 then
            local entry = action_state.get_selected_entry()
            if entry then selections = { entry } end
          end
          actions.close(prompt_bufnr)

          local files = {}
          for _, sel in ipairs(selections) do
            local val = sel[1] or sel.value
            -- Strip the status prefix (e.g. " M " or "?? ") to get the filename
            table.insert(files, val:sub(4))
          end
          if #files > 0 then
            local cmd = { "git", "add", "--" }
            vim.list_extend(cmd, files)
            vim.fn.system(cmd)
            vim.notify("Staged " .. #files .. " file(s)", vim.log.levels.INFO)
          end
          callback()
        end)
        return true
      end,
    }):find()
  end

  -- Decide flow based on current state
  if #unstaged == 0 then
    -- Everything already staged
    ai_commit()
  elseif has_staged then
    -- Some staged, some not — offer choices
    vim.ui.select(
      { "Commit staged only", "Stage more files", "Stage all and commit" },
      { prompt = "Unstaged changes exist:" },
      function(choice)
        if not choice then return end
        if choice == "Commit staged only" then
          ai_commit()
        elseif choice == "Stage more files" then
          pick_files_to_stage(ai_commit)
        elseif choice == "Stage all and commit" then
          vim.fn.system("git add -A")
          ai_commit()
        end
      end
    )
  else
    -- Nothing staged — must stage something
    vim.ui.select(
      { "Select files to stage", "Stage all" },
      { prompt = "Nothing staged:" },
      function(choice)
        if not choice then return end
        if choice == "Select files to stage" then
          pick_files_to_stage(ai_commit)
        elseif choice == "Stage all" then
          vim.fn.system("git add -A")
          ai_commit()
        end
      end
    )
  end
end, { desc = "Git: AI commit" })

---------------------------------------------------------------
-- Color/Highlighting test and toggle commands
---------------------------------------------------------------
-- Test command to verify syntax highlighting is working
vim.keymap.set("n", "<leader>th", function()
  local parsers = require("treesitter_parsers")
  local buf = vim.api.nvim_get_current_buf()
  local ft = vim.bo[buf].filetype
  local lang = vim.treesitter.language.get_lang(ft)

  if not lang or not parsers.is_available(lang) then
    vim.notify("No treesitter parser exists for " .. ft, vim.log.levels.WARN)
    return
  end

  if not parsers.is_installed(lang) then
    vim.notify("Parser for " .. lang .. " not installed — installing", vim.log.levels.WARN)
    parsers.install({ lang })
    return
  end

  -- Force Treesitter highlighting on for this buffer
  if pcall(vim.treesitter.start, buf, lang) then
    vim.notify("Treesitter highlighting ON (" .. lang .. ")", vim.log.levels.INFO)
  else
    vim.notify("Treesitter failed to start for " .. lang, vim.log.levels.ERROR)
  end
end, { desc = "Toggle highlights test" })

-- Quick command to force Treesitter
vim.keymap.set("n", "<leader>tf", function()
  local buf = vim.api.nvim_get_current_buf()
  local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
  if not lang then
    vim.notify("No treesitter language for this buffer", vim.log.levels.WARN)
    return
  end

  pcall(vim.treesitter.stop, buf)
  if pcall(vim.treesitter.start, buf, lang) then
    vim.notify("Forced Treesitter refresh (" .. lang .. ")", vim.log.levels.INFO)
  else
    vim.notify("Treesitter refresh failed — try :TSEnsure", vim.log.levels.ERROR)
  end
end, { desc = "Force Treesitter refresh" })

---------------------------------------------------------------
-- Treesitter incremental selection (lua/treesitter_select.lua)
-- `main` dropped nvim-treesitter's incremental_selection module.
---------------------------------------------------------------
vim.keymap.set("n", "<CR>", function()
  if not require("treesitter_select").init() then
    -- No parser here; keep the built-in <CR> (down to first non-blank).
    pcall(vim.cmd, "normal! +")
  end
end, { silent = true, desc = "Select node under cursor" })

vim.keymap.set("x", "<CR>", function()
  require("treesitter_select").grow()
end, { silent = true, desc = "Expand selection to parent node" })

vim.keymap.set("x", "<Tab>", function()
  require("treesitter_select").scope()
end, { silent = true, desc = "Expand selection to enclosing scope" })

vim.keymap.set("x", "<S-Tab>", function()
  require("treesitter_select").shrink()
end, { silent = true, desc = "Shrink selection to previous node" })

-- Command to check what's highlighting the file
vim.keymap.set("n", "<leader>tc", function()
  local buf = vim.api.nvim_get_current_buf()
  local ft = vim.bo[buf].filetype
  
  vim.notify("Filetype: " .. ft, vim.log.levels.INFO)
  vim.notify("Syntax: " .. vim.bo[buf].syntax, vim.log.levels.INFO)
  
  -- Check if treesitter is active
  local ts_highlighter = vim.treesitter.highlighter.active[buf]
  if ts_highlighter then
    vim.notify("✓ Treesitter IS active!", vim.log.levels.INFO)
  else
    vim.notify("✗ Treesitter NOT active", vim.log.levels.WARN)
  end
end, { desc = "Check syntax highlighting status" })

---------------------------------------------------------------
-- Jump up/down 20 lines at a time
---------------------------------------------------------------
vim.keymap.set("n", "<leader>J", "20j", { desc = "Jump down 20 lines" })
vim.keymap.set("n", "<leader>K", "20k", { desc = "Jump up 20 lines" })

---------------------------------------------------------------
-- Move lines up/down (Space+j/k)
---------------------------------------------------------------
-- Normal mode: move current line
vim.keymap.set("n", "<leader>k", function()
  local line = vim.fn.line(".")
  if line > 1 then
    vim.cmd("move " .. (line - 2))
    vim.cmd("normal! ==")
  end
end, { silent = true, desc = "Move line up" })

vim.keymap.set("n", "<leader>j", function()
  local line = vim.fn.line(".")
  local lastline = vim.fn.line("$")
  if line < lastline then
    vim.cmd("move " .. (line + 1))
    vim.cmd("normal! ==")
  end
end, { silent = true, desc = "Move line down" })

-- Visual mode: move selected lines
vim.keymap.set("v", "<leader>k", function()
  vim.cmd("'<,'>move '<-2")
  vim.cmd("normal! gv=gv")
end, { silent = true, desc = "Move selection up" })

vim.keymap.set("v", "<leader>j", function()
  vim.cmd("'<,'>move '>+1")
  vim.cmd("normal! gv=gv")
end, { silent = true, desc = "Move selection down" })

---------------------------------------------------------------
-- Code Folding (VSCode-style collapse)
---------------------------------------------------------------
-- Collapse/Expand all (VSCode-like) - using arrow keys
vim.keymap.set("n", "<leader><up>", function()
  -- Check fold settings
  local foldmethod = vim.opt.foldmethod:get()
  local foldenable = vim.opt.foldenable:get()
  
  if not foldenable then
    vim.notify("Folding is disabled! Run :set foldenable", vim.log.levels.WARN)
    return
  end
  
  vim.cmd("normal! zM")  -- Close all folds
  vim.notify("Collapsed all (foldmethod=" .. foldmethod .. ")", vim.log.levels.INFO)
end, { desc = "Collapse all folds" })

vim.keymap.set("n", "<leader><down>", function()
  vim.cmd("normal! zR")  -- Open all folds
  vim.notify("Expanded all", vim.log.levels.INFO)
end, { desc = "Expand all folds" })

-- Individual fold control
vim.keymap.set("n", "<leader>fc", "zc", { desc = "Close fold under cursor" })
vim.keymap.set("n", "<leader>fo", "zo", { desc = "Open fold under cursor" })
vim.keymap.set("n", "<leader>ft", "za", { desc = "Toggle fold under cursor" })

-- Also support za (toggle) on <Space> for quick access
vim.keymap.set("n", "<leader><Space>", "za", { desc = "Toggle fold" })

-- Debug command to check fold settings
vim.keymap.set("n", "<leader>fd", function()
  print("Fold settings:")
  print("  foldmethod: " .. vim.opt.foldmethod:get())
  print("  foldenable: " .. tostring(vim.opt.foldenable:get()))
  print("  foldlevel: " .. vim.opt.foldlevel:get())
  print("  foldcolumn: " .. vim.opt.foldcolumn:get())
end, { desc = "Debug fold settings" })

---------------------------------------------------------------
-- Godot (only registered inside a Godot project)
---------------------------------------------------------------
if require("godot.detect").is_project() then
  vim.keymap.set("n", "<leader>Gr", function()
    require("godot.run").run()
  end, { desc = "Godot: Run main scene" })

  vim.keymap.set("n", "<leader>Gc", function()
    require("godot.run").run({ scene = "current" })
  end, { desc = "Godot: Run current scene" })

  vim.keymap.set("n", "<leader>Gk", function()
    if not require("godot.run").stop() then
      vim.notify("No Godot process running", vim.log.levels.INFO)
    end
  end, { desc = "Godot: Stop running game" })

  vim.keymap.set("n", "<leader>Go", function()
    require("godot.run").toggle_console()
  end, { desc = "Godot: Toggle output console" })

  vim.keymap.set("n", "<leader>Ge", function()
    require("godot.run").editor()
  end, { desc = "Godot: Open project in editor" })

  vim.keymap.set("n", "<leader>Gt", function()
    require("godot.scene_tree").open()
  end, { desc = "Godot: Scene tree inspector" })

  vim.keymap.set("n", "<leader>Gd", function()
    require("godot.docs").open()
  end, { desc = "Godot: Docs for symbol under cursor" })

  vim.keymap.set("n", "<leader>Gl", function()
    require("godot.lsp").attach_all()
  end, { desc = "Godot: Reconnect GDScript LSP" })

  vim.keymap.set("n", "<leader>Gh", function()
    require("godot.health").report()
  end, { desc = "Godot: Health check" })
end
