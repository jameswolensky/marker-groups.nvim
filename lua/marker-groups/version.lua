local M = {}

local function read_first_line(file_path)
  local file = io.open(file_path, "r")
  if not file then
    return nil
  end
  local line = file:read "*l"
  file:close()
  return line
end

local function get_plugin_root_dir()
  local source = debug.getinfo(1, "S").source
  if type(source) ~= "string" or source:sub(1, 1) ~= "@" then
    return nil
  end
  local this_file = source:sub(2)
  return this_file:gsub("/lua/marker%-groups/version%.lua$", "/")
end

local plugin_root_dir = get_plugin_root_dir()

local cached_plugin_version
local cached_schema_version

local function resolve_plugin_version()
  if cached_plugin_version ~= nil then
    return cached_plugin_version
  end
  local version = nil
  if plugin_root_dir then
    version = read_first_line(plugin_root_dir .. "PLUGIN_VERSION")
  end
  cached_plugin_version = version or "dev"
  return cached_plugin_version
end

local function resolve_schema_version()
  if cached_schema_version ~= nil then
    return cached_schema_version
  end
  local version = nil
  if plugin_root_dir then
    version = read_first_line(plugin_root_dir .. "SCHEMA_VERSION")
  end
  cached_schema_version = version or "1.0.0"
  return cached_schema_version
end

M.plugin_version = resolve_plugin_version()
M.schema_version = resolve_schema_version()

return M
