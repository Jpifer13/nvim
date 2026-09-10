-- GDScript LSP.
--
-- Godot hosts the language server itself (Editor Settings -> Network -> Language
-- Server), so there is nothing for Mason to install; we just open a TCP socket.
-- The port is only listening while the Godot editor has the project open, so we
-- probe it before starting a client instead of letting vim.lsp.enable() spam
-- connection errors on every .gd buffer.

local detect = require("godot.detect")

local M = {}

M.host = vim.env.GDSCRIPT_LSP_HOST or "127.0.0.1"
M.port = tonumber(vim.env.GDSCRIPT_LSP_PORT) or 6005

local warned = false
local augroup = vim.api.nvim_create_augroup("GodotLsp", { clear = true })

--- Reuse the capabilities/on_attach defined in lua/lsp.lua so GDScript gets the
--- same keymaps and completion wiring as every other server.
local function shared()
  local ok, mod = pcall(require, "lsp")
  if ok and type(mod) == "table" then
    return mod
  end
  return {}
end

local function config(root)
  local base = shared()
  return {
    name = "gdscript",
    cmd = vim.lsp.rpc.connect(M.host, M.port),
    root_dir = root,
    capabilities = base.capabilities,
    on_attach = base.on_attach,
    settings = {},
  }
end

function M.reachable()
  return detect.port_open(M.host, M.port)
end

--- Start (or reuse) a gdscript client for `bufnr`. Returns true on attach.
function M.attach(bufnr, opts)
  opts = opts or {}
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local root = detect.root()
  if not root or vim.bo[bufnr].filetype ~= "gdscript" then
    return false
  end

  if not opts.skip_probe and not M.reachable() then
    if not opts.silent and not warned then
      warned = true
      vim.notify(
        ("Godot LSP not listening on %s:%d — open the project in the Godot editor, then :GodotLspAttach")
          :format(M.host, M.port),
        vim.log.levels.WARN
      )
    end
    return false
  end

  warned = false
  local ok, err = pcall(vim.lsp.start, config(root), { bufnr = bufnr })
  if not ok then
    vim.notify("Godot LSP failed to start: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

--- Attach every loaded gdscript buffer. Used by :GodotLspAttach.
function M.attach_all()
  if not M.reachable() then
    vim.notify(
      ("Godot LSP not listening on %s:%d — is the project open in the Godot editor?"):format(M.host, M.port),
      vim.log.levels.WARN
    )
    return
  end

  local count = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "gdscript" then
      if M.attach(buf, { skip_probe = true }) then
        count = count + 1
      end
    end
  end
  vim.notify(("Godot LSP attached (%d buffer%s)"):format(count, count == 1 and "" or "s"), vim.log.levels.INFO)
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = "gdscript",
    callback = function(args)
      M.attach(args.buf)
    end,
  })

  -- Catch buffers that were already open when setup ran.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "gdscript" then
      M.attach(buf, { silent = true })
    end
  end
end

return M
