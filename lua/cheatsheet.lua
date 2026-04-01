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
    "                              🚀 NEOVIM CHEAT SHEET 🚀",
    "          ═══════════════════════════════════════════════════════════",
    "",
    "",
    "  ┌─ 📄 LSP ───────────────────────┐  ┌─ 📁 GENERAL ──────────────────┐  ┌─ 🔀 GIT ──────────────────────┐",
    "  │ gd         Go to definition    │  │ <Space>w   Save file          │  │ <Space>gs  Git sidebar        │",
    "  │ gD         Declaration         │  │ <Space>q   Quit               │  │ <Space>gm  Git menu           │",
    "  │ gi         Implementation      │  │ <Space>e   File tree          │  │ <Space>gb  Toggle blame       │",
    "  │ gr         References          │  │ <Space>ff  Find files         │  │ <Space>gh  Preview hunk       │",
    "  │ K          Hover docs          │  │ <Space>fg  Live grep          │  │ <Space>gr  Reset hunk         │",
    "  │ <Space>rn  Rename              │  │ <Space>fb  Buffers            │  │ <Space>go  Open diff          │",
    "  │ <Space>ca  Code actions        │  │ <Space>?   Cheat sheet        │  │ <Space>gf  File history       │",
    "  │ <Space>f   Format              │  │ <Space>z   Zen mode           │  │ ]c/[c      Next/Prev hunk     │",
    "  │ ]d/[d      Next/Prev error     │  │ <Space>ta  Toggle autosave    │  └───────────────────────────────┘",
    "  └────────────────────────────────┘  │                                │",
    "                                      │ Telescope: in file picker      │",
    "                                      │ Enter      Open in buffer      │",
    "                                      │ Ctrl+v     Open vertical split │",
    "                                      │ Ctrl+x     Open horiz split    │",
    "                                      └───────────────────────────────┘",
    "",
    "",
    "  ┌─ ✏️  EDITING ──────────────────┐  ┌─ 🎯 HARPOON ──────────────────┐  ┌─ 🤖 AI (CLAUDE CODE) ────────┐",
    "  │ <Space>k/j Move line up/down   │  │ <Space>ha   Add file          │  │ <Space>at  Toggle/picker     │",
    "  │ dd         Delete line         │  │ <Space>hh   Toggle menu       │  │ <Space>as  Switch session    │",
    "  │ yy         Copy line           │  │ <Space>h1-4 Jump to file      │  │ <Space>af  Focus panel       │",
    "  │ p/P        Paste after/before  │  │ <Space>hn   Next              │  │ <Space>aa  Send selection    │",
    "  │ u          Undo                │  │ <Space>hp   Previous          │  │ <Space>am  Select model      │",
    "  │ Ctrl+r     Redo                │  │ <Space>hc   Clear all         │  │ <Space>ab  Add file          │",
    "  │ ciw        Change word         │  └──────────────────────────────┘  └──────────────────────────────┘",
    "  │ >>/<<      Indent right/left   │                                     ┌─ 🐛 DEBUGGER ────────────────┐",
    "  └────────────────────────────────┘   ┌─ 🪟 WINDOWS ─────────────────┐  │ <Space>dc  Continue/Start    │",
    "                                       │ <C-h/j/k/l> Navigate splits  │  │ <Space>dn  Step over         │",
    "  ┌─ 📋 FOLDING ──────────────────┐    │ <C-w>w      Cycle splits     │  │ <Space>di  Step into         │",
    "  │ <Space>↑   Collapse all       │    │ <C-w>=      Equal size       │  │ <Space>do  Step out          │",
    "  │ <Space>↓   Expand all         │    │ <C-w>H/J/K/L Move window     │  │ <Space>db  Breakpoint        │",
    "  │ <Space>    Toggle fold        │    │ <C-w>o      Only this win    │  │ <Space>du  Toggle UI         │",
    "  │ zc/zo/za   Close/Open/Toggle  │    │ :split      Horizontal       │  │ <Space>dq  Stop              │",
    "  └───────────────────────────────┘    │ :vsplit     Vertical         │  │ <Space>df  Debug FastAPI     │",
    "                                       └──────────────────────────────┘  └──────────────────────────────┘",
    "",
    "",
    "  ┌─ 🧭 POPNAV (POPUP NAVIGATION) ───────────────────────────────────────────────────────────────────┐",
    "  │ <Space>pp  Toggle menu          <Space>pn  Next popup        <Space>pP  Previous popup           │",
    "  │ <Space>p1-4 Jump to popup       <Space>px  Close all popups                                      │",
    "  │                                                                                                   │",
    "  │ Menu:  j/k  Navigate    Enter  Open    1-9  Jump    J/K  Reorder    dd  Remove    q/Esc  Close   │",
    "  └───────────────────────────────────────────────────────────────────────────────────────────────────┘",
    "",
    "",
    "  ┌─ 🎯 MODES ────────────────────┐  ┌─ ⏪ UNDOTREE ─────────────────┐  ┌─ 📝 MARKDOWN PREVIEW ────────┐",
    "  │ i          Insert mode        │  │ <Space>u   Toggle undo tree   │  │ <Space>mp  Toggle preview    │",
    "  │ a          Insert after       │  │ j/k        Navigate history   │  │ <Space>ms  Stop preview      │",
    "  │ I/A        Start/End of line  │  │ Enter      Restore state      │  └──────────────────────────────┘",
    "  │ v          Visual mode        │  └──────────────────────────────┘",
    "  │ V          Visual line        │",
    "  │ Ctrl+v     Visual block       │",
    "  │ Esc        Normal mode        │",
    "  └───────────────────────────────┘",
    "",
    "",
    "  ┌─ 🧪 TESTING (NEOTEST) ─────────────────────────────────────────────────────────────────────────┐",
    "  │ <Space>ae  AWS env login (pick profile, sets creds for test runner)                              │",
    "  │ <Space>nr  Run nearest test       <Space>nf  Run file         <Space>nd  Debug nearest         │",
    "  │ <Space>ns  Summary panel          <Space>no  Output panel     <Space>nx  Stop test             │",
    "  │ <Space>np  Output popup           <Space>nl  Run last test    <Space>nw  Watch file            │",
    "  │ ]n/[n      Next/Prev failure                                                                   │",
    "  │                                                                                                │",
    "  │ Summary panel:  r  Run test    m  Mark test     R  Run marked     d  Debug test                │",
    "  │                 D  Debug marked   M  Clear marks   o  Show output   x  Stop test               │",
    "  │                 e  Expand all     i  Jump to test  w  Watch test    J/K  Next/Prev failed      │",
    "  └────────────────────────────────────────────────────────────────────────────────────────────────┘",
    "",
    "",
    "  ┌─ 🌍 ENV MANAGER ───────────────────────────────────────────────────────────────────────────────┐",
    "  │ Auto-loads .env from project root on startup into Neovim's process environment.                │",
    "  │ All child processes (neotest, terminals, etc.) inherit the vars.                               │",
    "  │                                                                                                │",
    "  │ <Space>en  Open .env editor popup (floating KEY=VALUE buffer)                                  │",
    "  │            Enter   Save + close   │   :w   Save (stay open)   │   q/Esc   Close (no save)     │",
    "  └────────────────────────────────────────────────────────────────────────────────────────────────┘",
    "",
    "",
    "  ┌─ 🐘 POSTGRES MCP ────────────────────────────────────────────────────────────────────────────┐",
    "  │ connect           Connect to DB             disconnect         Disconnect from DB              │",
    "  │ query             Run SELECT (read-only)    execute            Run INSERT/UPDATE/DELETE/DDL    │",
    "  │ list_tables       List tables in schema     describe_table     Show columns/types              │",
    "  │ list_indexes      List indexes              list_constraints   Show constraints                │",
    "  │ list_schemas      List all schemas          list_enums         List enum types                 │",
    "  │ list_functions    List stored functions      sample_table_data  Preview rows                   │",
    "  │ get_table_stats   Table size/row counts     explain_query      Show execution plan             │",
    "  │ get_active_queries Running queries           get_slow_queries   Slow/long queries              │",
    "  │ get_locks         Current lock info         get_database_info  DB version/size/info            │",
    "  │ list_connections  Show active connections                                                      │",
    "  └────────────────────────────────────────────────────────────────────────────────────────────────┘",
    "",
    "",
    "  ┌─ 💻 TERMINAL ────────────────────────────────────────────────────────────────────────────────┐",
    "  │ <Space>\\   Toggle floating terminal (session persists when hidden)    Esc  Exit insert mode   │",
    "  └────────────────────────────────────────────────────────────────────────────────────────────────┘",
    "",
    "",
    "  ┌─ 🖥️  SSH REMOTE ──────────────────────────────────────────────────────────────────────────────┐",
    "  │ <Space>sr  Open SSH host picker (reads ~/.ssh/config)                                         │",
    "  │                                                                                                │",
    "  │ In picker:  Enter   Bootstrap deps + install nvim config + connect                             │",
    "  │             <C-s>   Connect directly (skip bootstrap)                                         │",
    "  │             Select '+ Add new connection' to save a new host to ~/.ssh/config                 │",
    "  │                                                                                                │",
    "  │ Bootstrap:  checks git + neovim, prompts y/n to install each, then clones nvim config         │",
    "  │             on completion drops into an interactive remote shell  (● = session active)        │",
    "  └────────────────────────────────────────────────────────────────────────────────────────────────┘",
    "",
    "",
    "          ═══════════════════════════════════════════════════════════",
    "                              🚀 NAVIGATION & MOTIONS",
    "          ───────────────────────────────────────────────────────────",
    "",
    "  BASIC:    h/j/k/l ← ↓ ↑ →       JUMP:  <Space>J/K Down/Up 20    LINE:    0/^/$ Start/First/End",
    "  FILE:     gg/G Top/Bottom        FIND:  f<x>/t<x> Find/Till      BRACKET: % Match paren",
    "  SEARCH:   /text Forward          */#  Word under cursor          JUMP:    Ctrl+o/i Back/Forward",
    "  SCROLL:   Ctrl+u/d Half          Ctrl+b/f Full page              zz Center screen",
    "",
    "          ═══════════════════════════════════════════════════════════",
    "                              🎯 TEXT OBJECTS & SEARCH",
    "          ───────────────────────────────────────────────────────────",
    "",
    "  OBJECTS:   iw/aw Word    i\"/a\" Quotes    i(/a( Parens    i{/a{ Braces    ip/ap Paragraph",
    "  EXAMPLES:  diw Del word  ci\" Change quote  yap Yank para  va{ Select braces",
    "  SEARCH:    /text →       ?text ←           n Next         N Prev         :noh Clear",
    "",
    "          ═══════════════════════════════════════════════════════════",
    "                 Press 'q' or 'Esc' to close  •  Auto-save enabled",
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
