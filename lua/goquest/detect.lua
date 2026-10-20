-- ---------------------------------------------------------------------------
-- Project detection.
--
-- Everything in goquest is gated on a .goquest.json at the project root,
-- the same way lua/godot/ is gated on project.godot. No config file, no panel,
-- no autocmds, no keymaps -- so this is inert in every other project you open.
-- ---------------------------------------------------------------------------

local M = {}

local CONFIG_NAME = ".goquest.json"

local cache = {}

--- The last root we resolved successfully.
---
--- This matters because the panel's own buffer is a scratch buffer named
--- goquest://panel, which has no path to search upward from. Without a
--- remembered root, every action taken while the cursor is INSIDE the panel would
--- fail to find the config.
local last_root = nil

local function is_real_path(path)
  return path ~= nil and path ~= "" and not path:match("^%a[%w+.-]*://")
end

--- Searches upward from exactly ONE path. No cwd fallback, no remembered root.
---
--- This is what "is this buffer really in a quest project?" needs. Consulting the
--- cwd there is wrong: opening ~/.config/nvim/init.lua while the cwd happens to be
--- the quest repo would attach the panel keymaps to an unrelated file, which is the
--- same class of surprise as mapping over <leader>q.
function M.root_of_path(path)
  if not is_real_path(path) then
    return nil
  end
  local found = vim.fs.find(CONFIG_NAME, { path = path, upward = true, type = "file" })[1]
  if not found then
    return nil
  end
  last_root = vim.fs.dirname(found)
  return last_root
end

--- Searches upward from the given candidates (including the cwd). Used to RESOLVE
--- the config once we already know we are in a project.
function M.find_root_strict(start)
  local candidates = {}
  if is_real_path(start) then
    table.insert(candidates, start)
  end
  local bufname = vim.api.nvim_buf_get_name(0)
  if is_real_path(bufname) then
    table.insert(candidates, bufname)
  end
  table.insert(candidates, vim.fn.getcwd())

  for _, candidate in ipairs(candidates) do
    local found = vim.fs.find(CONFIG_NAME, { path = candidate, upward = true, type = "file" })[1]
    if found then
      last_root = vim.fs.dirname(found)
      return last_root
    end
  end
  return nil
end

--- Walks up from a path looking for .goquest.json. Returns the root dir, or nil.
---
--- Falls back to the last root we resolved, which is what keeps the panel's own
--- actions working while the cursor is inside the panel buffer (it has no path).
--- Use find_root_strict when you need a truthful "is this in a project" answer.
function M.find_root(start)
  return M.find_root_strict(start) or last_root
end

--- Resolves a root from a START PATH (a file or directory anywhere in the project),
--- as opposed to M.config which takes an already-resolved root.
function M.root_for(start)
  return M.find_root(start)
end

--- Loads and validates the config. Cached per root, with the file's mtime as the
--- key so editing .goquest.json is picked up without restarting Neovim.
function M.config(root)
  root = root or M.find_root()
  if not root then
    return nil, nil
  end

  local path = root .. "/" .. CONFIG_NAME
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return nil, nil
  end

  local key = path .. ":" .. tostring(stat.mtime.sec)
  if cache[key] then
    return cache[key], root
  end

  local ok, content = pcall(vim.fn.readfile, path)
  if not ok then
    return nil, root
  end

  local decoded, err = nil, nil
  ok, decoded = pcall(vim.json.decode, table.concat(content, "\n"))
  if not ok then
    err = decoded
    vim.notify("goquest: " .. CONFIG_NAME .. " is not valid JSON\n" .. tostring(err), vim.log.levels.ERROR)
    return nil, root
  end

  if type(decoded) ~= "table" or type(decoded.modules) ~= "table" then
    vim.notify("goquest: " .. CONFIG_NAME .. " needs a `modules` array", vim.log.levels.ERROR)
    return nil, root
  end

  -- Defaults, so a minimal config works.
  decoded.title = decoded.title or vim.fn.fnamemodify(root, ":t")
  decoded.xp_per_test = decoded.xp_per_test or 10
  decoded.module_bonus = decoded.module_bonus or 150
  decoded.levels = decoded.levels or { { at = 0, name = "Level 1" } }
  decoded.achievements = decoded.achievements or {}
  if decoded.compact == nil then
    decoded.compact = false
  end

  cache = { [key] = decoded }
  return decoded, root
end

--- True when this buffer belongs to a goquest project.
---
--- Accepts more than just a named file on disk: an unnamed buffer (the one you get
--- from a bare `nvim`) and a scratch buffer such as the panel itself both fall back
--- to the cwd. Without that, the panel keymaps were only ever attached to Go
--- FILES, so the toggle did nothing on a README, in the file tree, on the startup
--- buffer, or inside the panel.
---
--- Uses the STRICT lookup, so it does not report true for an unrelated project just
--- because a quest project was opened earlier in the session.
function M.active(bufnr)
  bufnr = bufnr or 0
  local name = vim.api.nvim_buf_get_name(bufnr)
  if is_real_path(name) then
    -- A real file: judge it on its OWN location only.
    return M.root_of_path(name) ~= nil
  end
  -- Unnamed or scratch buffer (the startup buffer, the panel): the cwd is the only
  -- thing we can go on.
  return M.root_of_path(vim.fn.getcwd()) ~= nil
end

return M
