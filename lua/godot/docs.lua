-- Godot class reference lookup for the symbol under the cursor.
--
-- Inline docs already work through the LSP (K = hover); this opens the full
-- online class reference, which covers built-in classes the hover summarises.

local M = {}

M.branch = vim.env.GODOT_DOCS_BRANCH or "stable"

local function opener()
  if vim.fn.has("mac") == 1 then
    return "open"
  end
  if vim.fn.executable("xdg-open") == 1 then
    return "xdg-open"
  end
  return nil
end

function M.open(symbol)
  symbol = symbol or vim.fn.expand("<cword>")
  if not symbol or symbol == "" then
    vim.notify("No symbol under cursor", vim.log.levels.WARN)
    return
  end

  local cmd = opener()
  if not cmd then
    vim.notify("No browser opener available (need `open` or `xdg-open`)", vim.log.levels.ERROR)
    return
  end

  local url = ("https://docs.godotengine.org/en/%s/search.html?q=%s"):format(M.branch, vim.uri_encode(symbol))
  vim.fn.jobstart({ cmd, url }, { detach = true })
  vim.notify("Godot docs: " .. symbol, vim.log.levels.INFO)
end

return M
