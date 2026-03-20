local M = {}

-- Define highlight groups for colors
local function setup_highlights()
  vim.api.nvim_set_hl(0, "CheatHeader", { fg = "#89b4fa", bold = true })
  vim.api.nvim_set_hl(0, "CheatSection", { fg = "#cba6f7", bold = true })
  vim.api.nvim_set_hl(0, "CheatKey", { fg = "#f38ba8" })  -- Light red for keybindings
  vim.api.nvim_set_hl(0, "CheatDesc", { fg = "#a6adc8" })  -- Gray for descriptions
  vim.api.nvim_set_hl(0, "CheatBorder", { fg = "#585b70" })
end

local function pad_right(str, width)
  local len = vim.fn.strdisplaywidth(str)
  if len >= width then
    return str:sub(1, width)
  end
  return str .. string.rep(" ", width - len)
end

local function create_section_lines(title, items)
  local lines = {}
  table.insert(lines, "┌─ " .. title .. " " .. string.rep("─", 32 - #title) .. "┐")
  for _, item in ipairs(items) do
    table.insert(lines, "│ " .. pad_right(item, 34) .. "│")
  end
  table.insert(lines, "└" .. string.rep("─", 36) .. "┘")
  return lines
end

local function lines()
  return {
    "",
    "                          🚀 NEOVIM CHEAT SHEET 🚀",
    "        ═══════════════════════════════════════════════════════════",
    "",
    "┌─ 📁 GENERAL ───────────────┐  ┌─ 🤖 AI (CLAUDE CODE) ──────┐  ┌─ 🔀 GIT ───────────────────┐",
    "│ <Space>w   Save file       │  │ <Space>at  Toggle panel   │  │ <Space>gs  Git sidebar     │",
    "│ <Space>q   Quit            │  │ <Space>af  Focus panel    │  │ <Space>gm  Git menu        │",
    "│ <Space>e   File tree       │  │ <Space>aa  Send selection │  │ <Space>gb  Toggle blame    │",
    "│ <Space>ff  Find files      │  │ <Space>am  Select model   │  │ <Space>gh  Preview hunk    │",
    "│ <Space>fg  Live grep       │  │ <Space>ab  Add file       │  │ <Space>gr  Reset hunk      │",
    "│ <Space>fb  Buffers         │  │                           │  │ <Space>go  Open diff       │",
    "│ <Space>?   Cheat sheet     │  │                           │  │ <Space>gf  File history    │",
    "│ <Space>z   Zen mode        │  │                           │  │ ]c/[c      Next/Prev hunk  │",
    "│ <Space>ta  Toggle autosave │  │                           │  └────────────────────────────┘",
    "└────────────────────────────┘  └───────────────────────────┘",
    "",
    "┌─ 🎯 HARPOON ───────────────┐   ┌─ 📄 LSP ──────────────────┐  ┌─ ✏️  EDITING ───────────────┐",
    "│ <Space>ha   Add file       │  │ gd          Go to def      │  │ <Space>k/j Move line up/dn  │",
    "│ <Space>hh   Toggle menu    │  │ gD          Declaration    │  │ dd         Delete line      │",
    "│ <Space>h1-4 Jump to file   │  │ gi          Implementation │  │ yy         Copy line        │",
    "│ <Space>hn   Next           │  │ gr          References     │  │ p/P        Paste after/bfr  │",
    "│ <Space>hp   Previous       │  │ K           Hover docs     │  │ u          Undo             │",
    "│ <Space>hc   Clear all      │  │ <Space>rn   Rename         │  │ Ctrl+r     Redo             │",
    "└────────────────────────────┘  │ <Space>ca   Code actions   │  │ ciw        Change word      │",
    "                                │ <Space>f    Format         │  │ >>         Indent right     │",
    "┌─ 📋 FOLDING ──────────────┐   │ ]d/[d       Next/Prev err  │  │ <<         Indent left      │",
    "│ <Space>↑   Collapse all    │  └────────────────────────────┘  └────────────────────────────┘",
    "│ <Space>↓   Expand all      │",
    "│ <Space>    Toggle fold     │  ┌─ 🐛 DEBUGGER ──────────────┐  ┌─ 🎯 MODES ─────────────────┐",
    "│ zc/zo/za   Close/Open/Tog  │  │ <Space>dc  Continue/Start  │  │ i          Insert mode      │",
    "└────────────────────────────┘  │ <Space>dn  Step over       │  │ a          Insert after     │",
    "                                │ <Space>di  Step into       │  │ I/A        Start/End line   │",
    "┌─ 🪟 WINDOWS ───────────────┐  │ <Space>do  Step out        │  │ v          Visual mode      │",
    "│ <C-h/j/k/l> Navigate split │  │ <Space>db  Breakpoint      │  │ V          Visual line      │",
    "│ <C-w>w      Cycle splits   │  │ <Space>du  Toggle UI       │  │ Ctrl+v     Visual block     │",
    "│ <C-w>=      Equal size     │  │ <Space>dq  Stop            │  │ Esc        Normal mode      │",
    "│ <C-w>H/J/K/L Move window   │  │ <Space>df  Debug FastAPI   │  └─────────────────────────────┘",
    "│ <C-w>o      Only this win  │  └────────────────────────────┘",
    "│ :split      Horizontal     │  ┌─ ⏪ UNDOTREE ──────────────┐",
    "│ :vsplit     Vertical       │  │ <Space>u   Toggle undo tree│",
    "└────────────────────────────┘  │ j/k        Navigate history│",
    "                                │ <Space>u   Toggle undo tree│",
    "                                │ j/k        Navigate history│",
    "                                │ Enter      Restore state   │",
    "                                └────────────────────────────┘",
    "                                ┌─ 📝 MARKDOWN PREVIEW ─────┐",
    "                                │ :MarkdownPreview    Start  │",
    "                                │ :MarkdownPreviewStop Stop  │",
    "                                │ :MarkdownPreviewToggle Tog │",
    "                                └────────────────────────────┘",
    "",
    "        ═══════════════════════════════════════════════════════════",
    "                          🚀 NAVIGATION & MOTIONS",
    "        ───────────────────────────────────────────────────────────",
    "",
    "  BASIC:  h/j/k/l ← ↓ ↑ →    JUMP:  <Space>J/K Down/Up 20   LINE:  0/^/$ Start/First/End",
    "  FILE:   gg/G Top/Bottom    FIND:  f<x>/t<x> Find/Till     BRACKET: % Match paren",
    "  SEARCH: /text Forward      */#  Word under cursor        JUMP:  Ctrl+o/i Back/Forward",
    "  SCROLL: Ctrl+u/d Half      Ctrl+b/f Full page            zz Center screen",
    "",
    "        ═══════════════════════════════════════════════════════════",
    "                          🎯 TEXT OBJECTS & SEARCH",
    "        ───────────────────────────────────────────────────────────",
    "",
    "  OBJECTS:  iw/aw Word    i\"/a\" Quotes    i(/a( Parens    i{/a{ Braces    ip/ap Paragraph",
    "  EXAMPLES: diw Del word  ci\" Change quote  yap Yank para  va{ Select braces",
    "  SEARCH:   /text →       ?text ←           n Next         N Prev         :noh Clear",
    "",
    "        ═══════════════════════════════════════════════════════════",
    "               Press 'q' or 'Esc' to close  •  Auto-save enabled",
    "",
  }
end

function M.open()
  setup_highlights()
  
  local buf = vim.api.nvim_create_buf(false, true)
  local content = lines()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "cheatsheet"
  
  -- Size to fit content
  local width = 118  -- Fixed width for consistent layout
  local height = math.min(#content + 2, math.floor(vim.o.lines * 0.95))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  })
  
  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = true
  
  -- Apply syntax highlighting
  local ns = vim.api.nvim_create_namespace("cheatsheet")
  
  for i, line in ipairs(content) do
    -- Highlight borders first
    if line:match("[┌┐└┘├┤│─═]") then
      vim.api.nvim_buf_add_highlight(buf, ns, "CheatBorder", i - 1, 0, -1)
    end
    
    -- Highlight section titles (emojis + text after ┌─)
    local section_title = line:match("┌─ (.+) ─+┐")
    if section_title then
      local start = line:find(section_title, 1, true)
      if start then
        vim.api.nvim_buf_add_highlight(buf, ns, "CheatSection", i - 1, start - 1, start + #section_title - 1)
      end
    end
    
    -- For lines inside boxes (containing │)
    if line:match("│") then
      -- Highlight <Space>... patterns
      local pos = 1
      while true do
        local s, e = line:find("<Space>[%w<>↑↓]+", pos)
        if not s then break end
        vim.api.nvim_buf_add_highlight(buf, ns, "CheatKey", i - 1, s - 1, e)
        pos = e + 1
      end
      
      -- Highlight <C-...> patterns
      pos = 1
      while true do
        local s, e = line:find("<C%-[%w]+>", pos)
        if not s then break end
        vim.api.nvim_buf_add_highlight(buf, ns, "CheatKey", i - 1, s - 1, e)
        pos = e + 1
      end
      
      -- Highlight Ctrl+... patterns
      pos = 1
      while true do
        local s, e = line:find("Ctrl%+[%w\\]", pos)
        if not s then break end
        vim.api.nvim_buf_add_highlight(buf, ns, "CheatKey", i - 1, s - 1, e)
        pos = e + 1
      end
      
      -- Highlight ]x/[x patterns (like ]c/[c, ]d/[d)
      pos = 1
      while true do
        local s, e = line:find("%][%w]/[[]%w]", pos)
        if not s then break end
        vim.api.nvim_buf_add_highlight(buf, ns, "CheatKey", i - 1, s - 1, e)
        pos = e + 1
      end
      
      -- Highlight command patterns at the beginning: "gd", "dd", "yy", etc.
      -- Match 1-2 letter commands followed by spaces
      local patterns = {
        "│%s+([a-z][a-z]?)%s+",           -- Single/double letter
        "│%s+([a-z][a-z]?/[a-z][a-z]?)%s+", -- Patterns like p/P
        "│%s+([A-Z])%s+",                 -- Single capital letter
        "│%s+([%%*#])%s+",                -- Special chars
        "│%s+(Esc)%s+",                   -- Esc
        "│%s+(Enter)%s+",                 -- Enter
        "│%s+(Tab)%s+",                   -- Tab
      }
      
      for _, pattern in ipairs(patterns) do
        local cmd = line:match(pattern)
        if cmd then
          local s = line:find(cmd, 1, true)
          if s then
            vim.api.nvim_buf_add_highlight(buf, ns, "CheatKey", i - 1, s - 1, s + #cmd - 1)
          end
        end
      end
    end
    
    -- For bottom section navigation lines
    if line:match("BASIC:") or line:match("FILE:") or line:match("SEARCH:") or 
       line:match("SCROLL:") or line:match("OBJECTS:") or line:match("EXAMPLES:") then
      
      -- Highlight all command patterns in bottom section
      local patterns = {
        "[hH]/[jJ]/[kK]/[lL]",
        "[wW]/[bB]/[eE]",
        "[gG][gG]",
        "[gG]_",
        "0/%^/%$",
        "f%<x%>",
        "t%<x%>",
        "Ctrl%+[oudbfi]",
        "zz",
        "[iI][wW]",
        "[aA][wW]",
        "[iI]\"",
        "[aA]\"",
        "[iI]%(",
        "[aA]%(",
        "[iI]{",
        "[aA]{",
        "[iI][pP]",
        "[aA][pP]",
        "diw",
        "ci\"",
        "yap",
        "va{",
        "/text",
        "%?text",
        "[nN]",
        ":noh",
        "[%%]",
        "[%*]",
        "#",
      }
      
      for _, pattern in ipairs(patterns) do
        local pos = 1
        while true do
          local s, e = line:find(pattern, pos)
          if not s then break end
          vim.api.nvim_buf_add_highlight(buf, ns, "CheatKey", i - 1, s - 1, e)
          pos = e + 1
        end
      end
    end
  end
  
  -- Close handlers
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", { buffer = buf, silent = true })
end

return M
