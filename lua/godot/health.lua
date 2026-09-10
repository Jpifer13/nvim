-- Health report for the Godot tooling.
--
-- Doubles as `:checkhealth godot` (M.check) and a floating summary
-- reachable via :GodotHealth / <leader>Gh (M.report).

local detect = require("godot.detect")

local M = {}


--- Gather every check as { status, label, detail } where status is ok|warn|error.
local function collect()
  local rows = {}
  local function add(status, label, detail)
    table.insert(rows, { status = status, label = label, detail = detail or "" })
  end

  local root = detect.root()
  if root then
    add("ok", "Project root", root)
  else
    add("error", "Project root", "no project.godot found from " .. vim.uv.cwd())
  end

  local bin = detect.binary()
  if bin then
    add("ok", "Godot binary", bin)
    add("ok", "Godot version", detect.version() or "unknown")
  else
    add("error", "Godot binary", "not found — set $GODOT to the executable path")
  end

  local lsp = require("godot.lsp")
  if lsp.reachable() then
    add("ok", "LSP server", ("%s:%d reachable"):format(lsp.host, lsp.port))
  else
    add("warn", "LSP server", ("%s:%d closed — open the project in the Godot editor"):format(lsp.host, lsp.port))
  end

  local dap_mod = require("godot.dap")
  if dap_mod.reachable() then
    add("ok", "Debug adapter", ("%s:%d reachable"):format(dap_mod.host, dap_mod.port))
  else
    add(
      "warn",
      "Debug adapter",
      ("%s:%d closed — needs the editor running + 'Debug with External Editor'"):format(dap_mod.host, dap_mod.port)
    )
  end

  local has_dap = pcall(require, "dap")
  add(has_dap and "ok" or "error", "nvim-dap", has_dap and "loaded" or "not loaded")

  local ts = require("godot.treesitter")
  local missing = ts.missing()
  for _, lang in ipairs(ts.parsers) do
    if vim.tbl_contains(missing, lang) then
      add("warn", "Parser: " .. lang, "missing — run :GodotParsers")
    else
      add("ok", "Parser: " .. lang, "installed")
    end
  end

  if vim.fn.executable("gdformat") == 1 then
    add("ok", "gdformat", vim.fn.exepath("gdformat"))
  else
    add("warn", "gdformat", "not found — pip install gdtoolkit for format-on-save")
  end

  local clients = vim.lsp.get_clients({ name = "gdscript" })
  add(
    #clients > 0 and "ok" or "warn",
    "Attached clients",
    #clients > 0 and (#clients .. " gdscript client(s)") or "none (open a .gd file)"
  )

  return rows
end

---------------------------------------------------------------
-- :checkhealth godot
---------------------------------------------------------------

function M.check()
  vim.health.start("Godot")
  for _, row in ipairs(collect()) do
    local msg = row.label .. ": " .. row.detail
    if row.status == "ok" then
      vim.health.ok(msg)
    elseif row.status == "warn" then
      vim.health.warn(msg)
    else
      vim.health.error(msg)
    end
  end
end

---------------------------------------------------------------
-- :GodotHealth floating report
---------------------------------------------------------------

local ICONS = { ok = "✓", warn = "!", error = "✗" }
local GROUPS = { ok = "DiagnosticOk", warn = "DiagnosticWarn", error = "DiagnosticError" }

function M.report()
  local rows = collect()
  local ns = vim.api.nvim_create_namespace("GodotHealth")

  local width = 0
  for _, row in ipairs(rows) do
    width = math.max(width, #row.label)
  end

  local lines = { "" }
  local marks = { false }
  for _, row in ipairs(rows) do
    local label = row.label .. string.rep(" ", width - #row.label)
    table.insert(lines, ("  %s  %s  %s"):format(ICONS[row.status], label, row.detail))
    table.insert(marks, row.status)
  end
  table.insert(lines, "")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local win_width = 0
  for _, line in ipairs(lines) do
    win_width = math.max(win_width, vim.fn.strdisplaywidth(line))
  end
  win_width = math.min(win_width + 2, vim.o.columns - 4)
  local height = math.min(#lines, vim.o.lines - 6)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = win_width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - win_width) / 2),
    style = "minimal",
    border = "rounded",
    title = " 🎮 Godot Health ",
    title_pos = "center",
  })
  vim.wo[win].cursorline = false

  for i, status in ipairs(marks) do
    if status then
      vim.api.nvim_buf_add_highlight(buf, ns, GROUPS[status], i - 1, 0, 5)
      vim.api.nvim_buf_add_highlight(buf, ns, "Comment", i - 1, 5 + width + 2, -1)
    end
  end

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true })
end

return M
