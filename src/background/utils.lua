local M = {}

function M.clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

function M.trim(value)
  if value == nil then
    return ""
  end
  return (tostring(value):gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.copy_gradient(colors)
  return { colors[1], colors[2] }
end

function M.shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

function M.to_tick_count(duration_ms, tick_interval_ms)
  local ticks = math.floor((duration_ms / tick_interval_ms) + 0.5)
  return math.max(1, ticks)
end

function M.file_exists(path)
  if not path or path == "" then
    return false
  end

  local handle = io.open(path, "r")
  if not handle then
    return false
  end

  handle:close()
  return true
end

function M.directory_exists(path)
  if not path or path == "" then
    return false
  end

  local command = "[ -d " .. M.shell_quote(path) .. " ] && printf '1' || true"
  local pipe = io.popen(command)
  if not pipe then
    return false
  end

  local output = M.trim(pipe:read("*a") or "")
  pipe:close()
  return output == "1"
end

function M.basename(path)
  local value = tostring(path)
  return value:match("([^/]+)$") or value
end

return M
