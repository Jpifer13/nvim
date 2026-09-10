-- Static scene-tree inspector.
--
-- Parses a .tscn on disk (no running editor required) and renders the node
-- hierarchy in a floating window. <CR> jumps to the node's declaration.

local detect = require("godot.detect")

local M = {}

local ns = vim.api.nvim_create_namespace("GodotSceneTree")

---------------------------------------------------------------
-- Parsing
---------------------------------------------------------------

local function parse(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil, "could not read " .. path
  end

  local resources = {}
  local nodes = {}

  for lnum, line in ipairs(lines) do
    if line:match("^%[ext_resource") then
      -- Godot 4 quotes ids; Godot 3 does not. The leading %s keeps `uid="..."`
      -- from being mistaken for `id="..."`.
      local id = line:match('%sid="([^"]+)"') or line:match("%sid=(%d+)")
      local res = line:match('path="([^"]+)"')
      if id and res then
        resources[id] = res
      end
    elseif line:match("^%[node%s") then
      local instance_id = line:match('instance=ExtResource%(%s*"?([^"%)%s]+)"?%s*%)')
      table.insert(nodes, {
        name = line:match('name="([^"]*)"') or "?",
        type = line:match('type="([^"]*)"'),
        parent = line:match('parent="([^"]*)"'),
        instance = instance_id and resources[instance_id] or nil,
        lnum = lnum,
        children = {},
      })
    end
  end

  if #nodes == 0 then
    return nil, "no nodes found in " .. vim.fs.basename(path)
  end

  local by_path = {}
  local root

  for _, node in ipairs(nodes) do
    if not node.parent then
      node.path = "."
      root = node
      by_path["."] = node
    else
      node.path = (node.parent == ".") and node.name or (node.parent .. "/" .. node.name)
      local parent = by_path[node.parent]
      if parent then
        table.insert(parent.children, node)
      elseif root then
        -- Orphan (parent lives in an inherited scene); hang it off the root.
        table.insert(root.children, node)
      end
      by_path[node.path] = node
    end
  end

  return root
end

---------------------------------------------------------------
-- Rendering
---------------------------------------------------------------

local function label(node)
  if node.instance then
    return ("  [%s]"):format(vim.fs.basename(node.instance))
  end
  if node.type then
    return "  " .. node.type
  end
  return ""
end

--- Flatten into display lines plus a parallel line -> node map.
local function render(root)
  local lines, meta = {}, {}

  local function walk(node, prefix, is_last, is_root)
    local branch = is_root and "" or (is_last and "└─ " or "├─ ")
    local name = prefix .. branch .. node.name
    table.insert(lines, name .. label(node))
    table.insert(meta, { node = node, name_col = #prefix + #branch, name_len = #node.name })

    local child_prefix = is_root and "" or (prefix .. (is_last and "   " or "│  "))
    for i, child in ipairs(node.children) do
      walk(child, child_prefix, i == #node.children, false)
    end
  end

  walk(root, "", true, true)
  return lines, meta
end

---------------------------------------------------------------
-- Window
---------------------------------------------------------------

local function open_float(buf, title)
  local width = math.min(math.floor(vim.o.columns * 0.7), 100)
  local height = math.min(math.floor(vim.o.lines * 0.7), 40)

  return vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " 🌳 " .. title .. " ",
    title_pos = "center",
  })
end

--- Path of the scene to inspect: the current buffer if it is a .tscn,
--- otherwise the project's main scene.
function M.current_scene_path()
  local current = vim.api.nvim_buf_get_name(0)
  if current:match("%.tscn$") then
    return current
  end
  local main = detect.main_scene()
  return main and detect.res_to_path(main) or nil
end

function M.open(path)
  path = path or M.current_scene_path()
  if not path then
    vim.notify("No scene to inspect — open a .tscn or set run/main_scene", vim.log.levels.WARN)
    return
  end
  if vim.fn.filereadable(path) ~= 1 then
    vim.notify("Scene not found: " .. path, vim.log.levels.ERROR)
    return
  end

  local root, err = parse(path)
  if not root then
    vim.notify("Scene tree: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  local lines, meta = render(root)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "godot-scene-tree"

  local win = open_float(buf, vim.fs.basename(path))
  vim.wo[win].cursorline = true

  -- Dim the branch drawing, highlight names, comment-colour the types.
  for i, entry in ipairs(meta) do
    local row = i - 1
    if entry.name_col > 0 then
      vim.api.nvim_buf_add_highlight(buf, ns, "Comment", row, 0, entry.name_col)
    end
    vim.api.nvim_buf_add_highlight(buf, ns, "Identifier", row, entry.name_col, entry.name_col + entry.name_len)
    vim.api.nvim_buf_add_highlight(buf, ns, "Type", row, entry.name_col + entry.name_len, -1)
  end

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, desc = "Close" })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true, desc = "Close" })

  vim.keymap.set("n", "<CR>", function()
    local entry = meta[vim.api.nvim_win_get_cursor(win)[1]]
    close()
    if not entry then
      return
    end
    -- An instanced node points at another scene; open that instead.
    local target = entry.node.instance and detect.res_to_path(entry.node.instance)
    if target and vim.fn.filereadable(target) == 1 then
      vim.cmd.edit(vim.fn.fnameescape(target))
    else
      vim.cmd.edit(vim.fn.fnameescape(path))
      vim.api.nvim_win_set_cursor(0, { entry.node.lnum, 0 })
      vim.cmd("normal! zz")
    end
  end, { buffer = buf, nowait = true, desc = "Jump to node / open instanced scene" })
end

return M
