local M = {}

local migrations = {}

local function compare_versions(a, b)
  local function split(v)
    local x, y, z = v:match "^(%d+)%.(%d+)%.(%d+)$"
    return tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0
  end
  local ax, ay, az = split(a)
  local bx, by, bz = split(b)
  if ax ~= bx then
    return ax < bx
  end
  if ay ~= by then
    return ay < by
  end
  return az < bz
end

function M.migrate(data, from_version, to_version)
  if not compare_versions(to_version, from_version) then
    return { success = true, data = data }
  end

  local current = from_version
  local current_data = data

  return {
    success = false,
    error = string.format("No migration path from %s to %s", tostring(from_version), tostring(to_version)),
  }
end

return M
