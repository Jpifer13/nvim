-- Incremental selection, reimplemented on core vim.treesitter.
--
-- nvim-treesitter `main` dropped the incremental_selection module. This
-- provides the same four operations the old config asked for:
--   init    <CR>     (normal)  select the node under the cursor
--   grow    <CR>     (visual)  widen to the parent node
--   scope   <Tab>    (visual)  widen to the nearest enclosing scope
--   shrink  <S-Tab>  (visual)  step back down the selection stack

local M = {}

-- Lua patterns matched against node types to decide what counts as a "scope"
-- for <Tab>. "function" therefore also catches function_definition,
-- function_declaration, arrow_function, and so on.
M.scope_patterns = {
  "function",
  "method",
  "class",
  "struct",
  "enum",
  "module",
  "interface",
  "statement_block",
  "compound_statement",
  "block$",
  "table_constructor",
  "if_statement",
  "for_statement",
  "while_statement",
  "try_statement",
  "object$",
  "array$",
  "dictionary",
  "arguments",
  "parameters",
}

-- bufnr -> stack of nodes, innermost first
local stacks = {}

local augroup = vim.api.nvim_create_augroup("TreesitterSelect", { clear = true })

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = augroup,
  callback = function(args)
    stacks[args.buf] = nil
  end,
})

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------

--- A node held across a buffer edit can go stale; range() then throws.
local function range_of(node)
  if not node then
    return nil
  end
  local ok, srow, scol, erow, ecol = pcall(function()
    local a, b, c, d = node:range()
    return a, b, c, d
  end)
  if not ok or srow == nil then
    return nil
  end
  return srow, scol, erow, ecol
end

local function same_range(a, b)
  local a1, a2, a3, a4 = range_of(a)
  local b1, b2, b3, b4 = range_of(b)
  if a1 == nil or b1 == nil then
    return false
  end
  return a1 == b1 and a2 == b2 and a3 == b3 and a4 == b4
end

local function in_visual()
  return vim.api.nvim_get_mode().mode:match("^[vV\22]") ~= nil
end

local function select_node(node)
  local srow, scol, erow, ecol = range_of(node)
  if srow == nil then
    return false
  end

  local bufnr = vim.api.nvim_get_current_buf()

  -- Treesitter end positions are exclusive: a node ending at column 0 really
  -- ends at the end of the previous line.
  if ecol == 0 and erow > srow then
    erow = erow - 1
    ecol = #(vim.api.nvim_buf_get_lines(bufnr, erow, erow + 1, false)[1] or "")
  end

  if in_visual() then
    vim.cmd("normal! \27")
  end

  local ok = pcall(vim.api.nvim_win_set_cursor, 0, { srow + 1, scol })
  if not ok then
    return false
  end
  vim.cmd("normal! v")
  pcall(vim.api.nvim_win_set_cursor, 0, { erow + 1, math.max(ecol - 1, 0) })
  return true
end

local function node_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, nil, { error = false })
  if not ok or not parser then
    return nil
  end

  -- vim.treesitter.start() parses lazily on redraw, so the tree may not exist
  -- yet in a buffer that has not been drawn. Parse the cursor line first.
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  pcall(parser.parse, parser, { row, row + 1 })

  local got, node = pcall(vim.treesitter.get_node)
  if got then
    return node
  end
  return nil
end

local function is_scope(node)
  local node_type = node:type()
  for _, pattern in ipairs(M.scope_patterns) do
    if node_type:find(pattern) then
      return true
    end
  end
  return false
end

--- Current stack for the buffer, dropped if its nodes went stale.
local function current(bufnr)
  local stack = stacks[bufnr]
  if not stack or #stack == 0 then
    return nil
  end
  if range_of(stack[#stack]) == nil then
    stacks[bufnr] = nil
    return nil
  end
  return stack
end

---------------------------------------------------------------
-- Operations (each returns false when treesitter can't help)
---------------------------------------------------------------

function M.init()
  local bufnr = vim.api.nvim_get_current_buf()
  local node = node_at_cursor()
  if not node then
    return false
  end
  stacks[bufnr] = { node }
  return select_node(node)
end

function M.grow()
  local bufnr = vim.api.nvim_get_current_buf()
  local stack = current(bufnr)
  if not stack then
    return M.init()
  end

  local node = stack[#stack]
  local parent = node:parent()
  while parent and same_range(parent, node) do
    parent = parent:parent()
  end

  if not parent then
    return select_node(node)
  end

  table.insert(stack, parent)
  return select_node(parent)
end

function M.scope()
  local bufnr = vim.api.nvim_get_current_buf()
  local stack = current(bufnr)
  if not stack then
    if not M.init() then
      return false
    end
    stack = current(bufnr)
    if not stack then
      return false
    end
  end

  local node = stack[#stack]
  local parent = node:parent()
  while parent and (same_range(parent, node) or not is_scope(parent)) do
    parent = parent:parent()
  end

  if not parent then
    -- Nothing scope-like left above us; just widen by one.
    return M.grow()
  end

  table.insert(stack, parent)
  return select_node(parent)
end

function M.shrink()
  local bufnr = vim.api.nvim_get_current_buf()
  local stack = current(bufnr)
  if not stack then
    return false
  end
  if #stack > 1 then
    table.remove(stack)
  end
  return select_node(stack[#stack])
end

return M
