-- Parser installation helpers for nvim-treesitter `main`.
--
-- `main` dropped ensure_installed/auto_install; installing is a plain function
-- call. This wraps it with the bookkeeping both callers need: what is actually
-- installed (Neovim ships some parsers itself, which never appear in the
-- install dir), and an in-flight guard so a lang is not queued twice.

local M = {}

local available_cache
local pending = {}

local function nts()
  local ok, ts = pcall(require, "nvim-treesitter")
  if ok and type(ts.install) == "function" then
    return ts
  end
  return nil
end

--- Every parser nvim-treesitter knows how to build (328 at time of writing).
function M.available()
  if not available_cache then
    local ts = nts()
    available_cache = ts and ts.get_available() or {}
  end
  return available_cache
end

function M.is_available(lang)
  return vim.tbl_contains(M.available(), lang)
end

function M.is_installed(lang)
  local ts = nts()
  -- get_installed("parsers") only sees the install dir, so check the runtime
  -- too: c/lua/markdown/query/vim/vimdoc are bundled with Neovim.
  if ts and vim.tbl_contains(ts.get_installed("parsers"), lang) then
    return true
  end
  return #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".so", false) > 0
end

--- Which of `langs` are not installed yet.
function M.missing(langs)
  return vim.tbl_filter(function(lang)
    return not M.is_installed(lang)
  end, langs)
end

--- Release the in-flight guard as parsers land (install() is async and gives
--- no completion hook), or after a generous timeout.
local function watch(langs)
  local elapsed = 0
  local function poll()
    elapsed = elapsed + 2000
    local waiting = false
    for _, lang in ipairs(langs) do
      if M.is_installed(lang) or elapsed > 300000 then
        pending[lang] = nil
      else
        waiting = true
      end
    end
    if waiting then
      vim.defer_fn(poll, 2000)
    end
  end
  vim.defer_fn(poll, 2000)
end

--- Install any of `langs` that are missing. opts.silent suppresses the notify.
--- Returns the list actually queued.
function M.install(langs, opts)
  opts = opts or {}

  local ts = nts()
  if not ts then
    if not opts.silent then
      vim.notify("nvim-treesitter (main) is unavailable — run :Lazy sync", vim.log.levels.WARN)
    end
    return {}
  end

  local todo = {}
  for _, lang in ipairs(langs) do
    if not pending[lang] and not M.is_installed(lang) and M.is_available(lang) then
      pending[lang] = true
      table.insert(todo, lang)
    end
  end

  if #todo == 0 then
    return todo
  end

  if not opts.silent then
    vim.notify("Installing treesitter parsers: " .. table.concat(todo, ", "), vim.log.levels.INFO)
  end

  pcall(ts.install, todo)
  watch(todo)

  return todo
end

return M
