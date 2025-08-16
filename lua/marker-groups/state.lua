local M = {}

local state = nil

local event_listeners = {}

local next_extmark_id = 1

local function generate_uuid()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format("%x", v)
  end)
end

local Result = {}

function Result.ok(value)
  return {
    success = true,
    value = value,
    error = nil,
    code = nil,
  }
end

function Result.error(message, code)
  return {
    success = false,
    value = nil,
    error = message,
    code = code or "GENERIC_ERROR",
  }
end

local function is_valid_group_name(group_name)
  if type(group_name) ~= "string" then
    return false
  end

  local trimmed = vim.trim(group_name)
  if trimmed == "" then
    return false
  end

  local sanitized = trimmed:gsub("[\r\n]", " "):gsub("\t", " "):gsub("[\1-\8\11\12\14-\31\127]", ""):gsub("%s+", " ")

  local char_count = vim.fn.strchars(sanitized)
  if char_count == 0 or char_count > require("marker-groups.config").get_internal "max_group_name_chars" then
    return false
  end

  return true
end

local function validate_marker(marker)
  if type(marker) ~= "table" then
    return false, "Marker must be a table"
  end

  if type(marker.buffer_path) ~= "string" or #marker.buffer_path == 0 then
    return false, "Marker buffer_path must be a non-empty string"
  end

  if type(marker.start_line) ~= "number" or marker.start_line < 1 then
    return false, "Marker start_line must be a positive number"
  end

  if type(marker.end_line) ~= "number" or marker.end_line < marker.start_line then
    return false, "Marker end_line must be >= start_line"
  end

  if type(marker.annotation) ~= "string" then
    return false, "Marker annotation must be a string"
  end

  return true, nil
end

function M.initialize(config)
  if not config then
    return Result.error("Configuration is required for initialization", "INVALID_CONFIG")
  end

  math.randomseed(os.time())

  state = {
    config = config,
    active_group = "default",
    marker_groups = {
      ["default"] = {
        name = "default",
        markers = {},
        created_at = os.time(),
        modified_at = os.time(),
      },
    },
  }

  M.emit("state_initialized", { config = config })
  return Result.ok(state)
end

function M.get_state()
  return state and vim.deepcopy(state) or nil
end

function M.get_active_group()
  return state and state.active_group or nil
end

function M.set_active_group(group_name)
  if not state then
    return Result.error("State not initialized", "STATE_NOT_INITIALIZED")
  end

  if not is_valid_group_name(group_name) then
    return Result.error("Invalid group name: " .. tostring(group_name), "INVALID_GROUP_NAME")
  end

  if not state.marker_groups[group_name] then
    return Result.error("Group does not exist: " .. group_name, "GROUP_NOT_FOUND")
  end

  local old_group = state.active_group
  state.active_group = group_name

  M.emit("active_group_changed", {
    old_group = old_group,
    new_group = group_name,
  })

  return Result.ok(group_name)
end

function M.get_group_names()
  if not state then
    return {}
  end

  local names = {}
  for name, _ in pairs(state.marker_groups) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

function M.get_all_groups()
  if not state then
    return {}
  end

  return vim.deepcopy(state.marker_groups)
end

function M.get_group(group_name)
  if not state then
    return nil
  end

  group_name = group_name or state.active_group
  return state.marker_groups[group_name] and vim.deepcopy(state.marker_groups[group_name]) or nil
end

function M.create_group(group_name)
  if not state then
    return Result.error("State not initialized", "STATE_NOT_INITIALIZED")
  end

  if not is_valid_group_name(group_name) then
    return Result.error("Invalid group name: " .. tostring(group_name), "INVALID_GROUP_NAME")
  end

  if state.marker_groups[group_name] then
    return Result.error("Group already exists: " .. group_name, "GROUP_EXISTS")
  end

  local timestamp = os.time()
  state.marker_groups[group_name] = {
    name = group_name,
    markers = {},
    created_at = timestamp,
    modified_at = timestamp,
  }

  M.emit("group_created", { group_name = group_name })
  return Result.ok(state.marker_groups[group_name])
end

M.add_group = M.create_group

function M.delete_group(group_name)
  if not state then
    return Result.error("State not initialized", "STATE_NOT_INITIALIZED")
  end

  if group_name == "default" then
    return Result.error("Cannot delete the default group", "CANNOT_DELETE_DEFAULT")
  end

  if not state.marker_groups[group_name] then
    return Result.error("Group does not exist: " .. group_name, "GROUP_NOT_FOUND")
  end

  if state.active_group == group_name then
    state.active_group = "default"
  end

  local deleted_group = state.marker_groups[group_name]
  state.marker_groups[group_name] = nil

  M.emit("group_deleted", {
    group_name = group_name,
    marker_count = #deleted_group.markers,
  })

  return Result.ok(deleted_group)
end

function M.add_marker(marker_data, group_name)
  if not state then
    return Result.error("State not initialized", "STATE_NOT_INITIALIZED")
  end

  group_name = group_name or state.active_group

  if not state.marker_groups[group_name] then
    return Result.error("Group does not exist: " .. group_name, "GROUP_NOT_FOUND")
  end

  local group = state.marker_groups[group_name]
  for _, existing in ipairs(group.markers) do
    if existing.buffer_path == marker_data.buffer_path then
      local no_overlap = existing.end_line < marker_data.start_line or existing.start_line > marker_data.end_line
      if not no_overlap then
        return Result.error("Marker range overlaps existing marker in this group", "MARKER_OVERLAP")
      end
    end
  end

  local marker = vim.tbl_extend("force", {}, marker_data, {
    id = generate_uuid(),
    timestamp = os.time(),
    extmark_id = next_extmark_id,
  })

  next_extmark_id = next_extmark_id + 1

  local valid, error_msg = validate_marker(marker)
  if not valid then
    return Result.error(error_msg, "INVALID_MARKER")
  end

  table.insert(group.markers, marker)
  group.modified_at = os.time()

  M.emit("marker_added", {
    marker = marker,
    group_name = group_name,
  })

  return Result.ok(marker)
end

function M.rename_group(old_name, new_name)
  if not state then
    return Result.error("State not initialized", "STATE_NOT_INITIALIZED")
  end

  if old_name == "default" then
    return Result.error("Cannot rename the default group", "CANNOT_RENAME_DEFAULT")
  end

  if not is_valid_group_name(new_name) then
    return Result.error("Invalid group name: " .. tostring(new_name), "INVALID_GROUP_NAME")
  end

  local old_group = state.marker_groups[old_name]
  if not old_group then
    return Result.error("Group does not exist: " .. old_name, "GROUP_NOT_FOUND")
  end

  if state.marker_groups[new_name] then
    return Result.error("Group already exists: " .. new_name, "GROUP_EXISTS")
  end

  state.marker_groups[new_name] = old_group
  state.marker_groups[old_name] = nil
  state.marker_groups[new_name].name = new_name
  state.marker_groups[new_name].modified_at = os.time()

  if state.active_group == old_name then
    state.active_group = new_name
    M.emit("active_group_changed", { old_group = old_name, new_group = new_name })
  end

  M.emit("group_renamed", { old_name = old_name, new_name = new_name })

  return Result.ok { old_name = old_name, new_name = new_name }
end

function M.get_marker(marker_id, group_name)
  if not state then
    return nil, nil
  end

  if group_name then
    local group = state.marker_groups[group_name]
    if group then
      for _, marker in ipairs(group.markers) do
        if marker.id == marker_id then
          return vim.deepcopy(marker), group_name
        end
      end
    end
  else
    group_name = state.active_group
    local marker, found_group = M.get_marker(marker_id, group_name)
    if marker then
      return marker, found_group
    end

    for name, group in pairs(state.marker_groups) do
      if name ~= group_name then
        for _, marker in ipairs(group.markers) do
          if marker.id == marker_id then
            return vim.deepcopy(marker), name
          end
        end
      end
    end
  end

  return nil, nil
end

function M.remove_marker(marker_id, group_name)
  if not state then
    return Result.error("State not initialized", "STATE_NOT_INITIALIZED")
  end

  local marker, found_group = M.get_marker(marker_id, group_name)
  if not marker then
    return Result.error("Marker not found: " .. marker_id, "MARKER_NOT_FOUND")
  end

  local group = state.marker_groups[found_group]
  for i, m in ipairs(group.markers) do
    if m.id == marker_id then
      table.remove(group.markers, i)
      group.modified_at = os.time()
      break
    end
  end

  M.emit("marker_removed", {
    marker = marker,
    group_name = found_group,
  })

  return Result.ok(marker)
end

function M.on(event, callback)
  if not event_listeners[event] then
    event_listeners[event] = {}
  end

  table.insert(event_listeners[event], callback)

  return function()
    if event_listeners[event] then
      for i, cb in ipairs(event_listeners[event]) do
        if cb == callback then
          table.remove(event_listeners[event], i)
          break
        end
      end
    end
  end
end

function M.emit(event, data)
  if event_listeners[event] then
    for _, callback in ipairs(event_listeners[event]) do
      pcall(callback, data)
    end
  end
end

function M.clear_listeners()
  event_listeners = {}
end

function M.reset()
  state = nil
  event_listeners = {}
  next_extmark_id = 1
end

function M.debug_info()
  return {
    state_initialized = state ~= nil,
    active_group = state and state.active_group or nil,
    group_count = state and vim.tbl_count(state.marker_groups) or 0,
    total_markers = state and vim.tbl_count(vim.tbl_flatten(vim.tbl_map(function(g)
      return g.markers
    end, state.marker_groups))) or 0,
    event_listener_count = vim.tbl_count(event_listeners),
    next_extmark_id = next_extmark_id,
  }
end

M.Result = Result

M.remove_group = M.delete_group
M.subscribe = M.on

function M.update_marker(marker_or_id, updates, group_name)
  local marker_id, marker_updates

  if type(marker_or_id) == "table" then
    marker_id = marker_or_id.id
    marker_updates = marker_or_id
    if not marker_id then
      return Result.error("Marker object must have an id field", "INVALID_MARKER")
    end
  else
    marker_id = marker_or_id
    marker_updates = updates or {}
  end

  group_name = group_name or M.get_active_group()
  if not group_name then
    return Result.error("No active group", "NO_ACTIVE_GROUP")
  end

  local existing_marker, found_group = M.get_marker(marker_id, group_name)
  if not existing_marker then
    return Result.error("Marker not found", "MARKER_NOT_FOUND")
  end

  local updated_marker = vim.tbl_extend("force", existing_marker, marker_updates)
  updated_marker.modified_at = os.time()

  local group = state.marker_groups[found_group or group_name]
  for i, m in ipairs(group.markers) do
    if m.id == marker_id then
      group.markers[i] = updated_marker
      group.modified_at = os.time()
      M.emit("marker_updated", { group = group_name, marker = updated_marker })
      return Result.ok(updated_marker)
    end
  end

  return Result.error("Marker not found", "MARKER_NOT_FOUND")
end

return M
