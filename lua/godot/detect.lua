-- Godot project detection, engine discovery, and small shared helpers.
-- Everything here is dependency-free so it can be required before lazy.nvim
-- has loaded (keymaps.lua and treesitter.lua both gate on it).

local M = {}

M.PROJECT_FILE = "project.godot"

local cached_cwd, cached_root, cached_bin

---------------------------------------------------------------
-- Project root
---------------------------------------------------------------

--- Directory containing project.godot, searching upward from `start`.
function M.find_root(start)
  start = start or vim.uv.cwd()
  local found = vim.fs.find(M.PROJECT_FILE, { path = start, upward = true, type = "file" })[1]
  if not found then
    return nil
  end
  return vim.fs.dirname(found)
end

--- Project root for the current working directory (cached per-cwd).
function M.root()
  local cwd = vim.uv.cwd()
  if cached_cwd ~= cwd then
    cached_cwd = cwd
    cached_root = M.find_root(cwd)
  end
  return cached_root
end

function M.is_project()
  return M.root() ~= nil
end

--- Drop the cached root (used after :cd or by :GodotHealth).
function M.refresh()
  cached_cwd, cached_root, cached_bin = nil, nil, nil
  return M.root()
end

---------------------------------------------------------------
-- Engine binary
---------------------------------------------------------------

local function candidates()
  local list = {}
  for _, env in ipairs({ vim.env.GODOT, vim.env.GODOT_BIN }) do
    if env and env ~= "" then
      table.insert(list, env)
    end
  end
  vim.list_extend(list, { "godot", "godot4" })
  if vim.fn.has("mac") == 1 then
    vim.list_extend(list, {
      "/Applications/Godot.app/Contents/MacOS/Godot",
      "/Applications/Godot_mono.app/Contents/MacOS/Godot",
      vim.fn.expand("~/Applications/Godot.app/Contents/MacOS/Godot"),
    })
  end
  return list
end

--- Absolute path to the Godot executable, or nil.
function M.binary()
  if cached_bin and vim.fn.executable(cached_bin) == 1 then
    return cached_bin
  end
  for _, c in ipairs(candidates()) do
    if c:find("/", 1, true) then
      if vim.fn.executable(c) == 1 then
        cached_bin = c
        return c
      end
    else
      local resolved = vim.fn.exepath(c)
      if resolved ~= "" then
        cached_bin = resolved
        return resolved
      end
    end
  end
  return nil
end

function M.version()
  local bin = M.binary()
  if not bin then
    return nil
  end
  local out = vim.fn.system({ bin, "--version" })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return vim.trim((vim.split(out, "\n")[1] or ""))
end

---------------------------------------------------------------
-- project.godot / res:// helpers
---------------------------------------------------------------

--- `run/main_scene` from project.godot, e.g. "res://scenes/Main.tscn".
function M.main_scene()
  local root = M.root()
  if not root then
    return nil
  end
  local fd = io.open(root .. "/" .. M.PROJECT_FILE, "r")
  if not fd then
    return nil
  end
  local scene
  for line in fd:lines() do
    local match = line:match('^%s*run/main_scene%s*=%s*"([^"]+)"')
    if match then
      scene = match
      break
    end
  end
  fd:close()
  return scene
end

--- Turn a "res://..." path into an absolute path.
function M.res_to_path(res)
  local root = M.root()
  if not root or not res then
    return nil
  end
  return root .. "/" .. (res:gsub("^res://", ""))
end

--- Turn an absolute path into "res://...".
function M.path_to_res(path)
  local root = M.root()
  if not root or not path then
    return nil
  end
  local rel = path:gsub("^" .. vim.pesc(root) .. "/", "")
  return "res://" .. rel
end

---------------------------------------------------------------
-- TCP probe (Godot only opens its LSP/DAP ports while the editor runs)
---------------------------------------------------------------

function M.port_open(host, port, timeout)
  local tcp = vim.uv.new_tcp()
  if not tcp then
    return false
  end
  local done, reachable = false, false
  tcp:connect(host, port, function(err)
    reachable = err == nil
    done = true
    if not tcp:is_closing() then
      tcp:close()
    end
  end)
  vim.wait(timeout or 250, function()
    return done
  end, 5)
  if not tcp:is_closing() then
    tcp:close()
  end
  return reachable
end

return M
