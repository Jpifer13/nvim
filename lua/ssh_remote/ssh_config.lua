local M = {}

---Parse ~/.ssh/config and return a list of non-wildcard Host entries.
---@return { alias: string, hostname: string, user: string|nil, port: number }[]
function M.parse()
  local hosts = {}
  local config_path = vim.fn.expand("~/.ssh/config")

  local file = io.open(config_path, "r")
  if not file then
    return hosts
  end

  local current = nil

  for raw_line in file:lines() do
    local line = raw_line:match("^%s*(.-)%s*$") -- trim whitespace

    if line == "" or line:match("^#") then
      -- skip blank lines and comments

    elseif line:match("^[Hh]ost%s+") then
      local alias = line:match("^[Hh]ost%s+(.+)")
      -- skip wildcard patterns like "Host *" or "Host *.example.com"
      if alias and not alias:match("[*?]") then
        current = {
          alias    = alias,
          hostname = alias, -- default until HostName is found
          user     = nil,
          port     = 22,
        }
        table.insert(hosts, current)
      else
        current = nil
      end

    elseif current then
      local key, value = line:match("^(%S+)%s+(.+)")
      if key and value then
        local k = key:lower()
        if k == "hostname" then
          current.hostname = value
        elseif k == "user" then
          current.user = value
        elseif k == "port" then
          current.port = tonumber(value) or 22
        end
      end
    end
  end

  file:close()
  return hosts
end

---Append a new Host block to ~/.ssh/config.
---@param alias string
---@param hostname string
---@param user string|nil
---@param port number|nil
---@return boolean success
function M.append(alias, hostname, user, port)
  local config_path = vim.fn.expand("~/.ssh/config")
  local f = io.open(config_path, "a")
  if not f then
    return false
  end

  f:write("\nHost " .. alias .. "\n")
  f:write("  HostName " .. hostname .. "\n")
  if user and user ~= "" then
    f:write("  User " .. user .. "\n")
  end
  if port and port ~= 22 then
    f:write("  Port " .. tostring(port) .. "\n")
  end
  f:close()
  return true
end

return M
