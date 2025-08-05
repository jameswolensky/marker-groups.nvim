---@class Marker
---@field id string Unique UUID identifier
---@field buffer_path string Full path to the file
---@field start_line integer Starting line (1-indexed)
---@field end_line integer Ending line (1-indexed, same as start for single line)
---@field annotation string User annotation text
---@field timestamp integer Creation timestamp
---@field extmark_id integer? Neovim extmark ID for tracking

---@class MarkerGroup
---@field name string Group name (unique identifier)
---@field markers Marker[] Array of markers in this group
---@field created_at integer Creation timestamp
---@field modified_at integer Last modification timestamp

---@class StateData
---@field config table Plugin configuration
---@field active_group string Currently active group name
---@field marker_groups table<string, MarkerGroup> Map of group name to group data

---@class Result
---@field success boolean Whether operation succeeded
---@field value any? Return value on success
---@field error string? Error message on failure
---@field code string? Error code on failure

---@class MarkerGroupsState
local M = {}

---@type StateData|nil
local state = nil

---@type table<string, function[]>
local event_listeners = {}

---@type integer
local next_extmark_id = 1

-- Simple UUID generation (basic implementation)
---@return string
local function generate_uuid()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format("%x", v)
  end)
end

-- Result pattern constructors
local Result = {}

---Create a successful result
---@param value any
---@return Result
function Result.ok(value)
  return {
    success = true,
    value = value,
    error = nil,
    code = nil
  }
end

---Create an error result
---@param message string
---@param code? string
---@return Result
function Result.error(message, code)
  return {
    success = false,
    value = nil,
    error = message,
    code = code or "GENERIC_ERROR"
  }
end

-- State validation helpers
---@param group_name string
---@return boolean
local function is_valid_group_name(group_name)
  return type(group_name) == "string" and
         #group_name > 0 and
         #group_name <= 50 and
         group_name:match("^[%w_%-%.]+$")
end

---@param marker Marker
---@return boolean, string?
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

---Initialize the state management system
---@param config table Plugin configuration
---@return Result
function M.initialize(config)
  if not config then
    return Result.error("Configuration is required for initialization", "INVALID_CONFIG")
  end
  
  -- Initialize random seed for UUID generation
  math.randomseed(os.time())
  
  state = {
    config = config,
    active_group = "default",
    marker_groups = {
      ["default"] = {
        name = "default",
        markers = {},
        created_at = os.time(),
        modified_at = os.time()
      }
    }
  }
  
  M.emit("state_initialized", { config = config })
  return Result.ok(state)
end

---Get current state (read-only access)
---@return StateData?
function M.get_state()
  return state and vim.deepcopy(state) or nil
end

---Get active group name
---@return string?
function M.get_active_group()
  return state and state.active_group or nil
end

---Set active group
---@param group_name string
---@return Result
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
    new_group = group_name
  })
  
  return Result.ok(group_name)
end

---Get all group names
---@return string[]
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

---Get group data
---@param group_name? string Group name (defaults to active group)
---@return MarkerGroup?
function M.get_group(group_name)
  if not state then
    return nil
  end
  
  group_name = group_name or state.active_group
  return state.marker_groups[group_name] and vim.deepcopy(state.marker_groups[group_name]) or nil
end

---Create a new group
---@param group_name string
---@return Result
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
    modified_at = timestamp
  }
  
  M.emit("group_created", { group_name = group_name })
  return Result.ok(state.marker_groups[group_name])
end

---Delete a group
---@param group_name string
---@return Result
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
  
  -- Switch to default if deleting active group
  if state.active_group == group_name then
    state.active_group = "default"
  end
  
  local deleted_group = state.marker_groups[group_name]
  state.marker_groups[group_name] = nil
  
  M.emit("group_deleted", { 
    group_name = group_name,
    marker_count = #deleted_group.markers
  })
  
  return Result.ok(deleted_group)
end

---Add a marker to a group
---@param marker_data table Marker data (without id and timestamp)
---@param group_name? string Target group (defaults to active group)
---@return Result
function M.add_marker(marker_data, group_name)
  if not state then
    return Result.error("State not initialized", "STATE_NOT_INITIALIZED")
  end
  
  group_name = group_name or state.active_group
  
  if not state.marker_groups[group_name] then
    return Result.error("Group does not exist: " .. group_name, "GROUP_NOT_FOUND")
  end
  
  -- Create full marker object
  local marker = vim.tbl_extend("force", {}, marker_data, {
    id = generate_uuid(),
    timestamp = os.time(),
    extmark_id = next_extmark_id
  })
  
  next_extmark_id = next_extmark_id + 1
  
  -- Validate marker
  local valid, error_msg = validate_marker(marker)
  if not valid then
    return Result.error(error_msg, "INVALID_MARKER")
  end
  
  -- Add to group
  table.insert(state.marker_groups[group_name].markers, marker)
  state.marker_groups[group_name].modified_at = os.time()
  
  M.emit("marker_added", {
    marker = marker,
    group_name = group_name
  })
  
  return Result.ok(marker)
end

---Get marker by ID
---@param marker_id string
---@param group_name? string Group to search (defaults to active group)
---@return Marker?, string? marker, group_name
function M.get_marker(marker_id, group_name)
  if not state then
    return nil, nil
  end
  
  -- Search in specific group or active group
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
    -- Search in active group first, then all groups
    group_name = state.active_group
    local marker, found_group = M.get_marker(marker_id, group_name)
    if marker then
      return marker, found_group
    end
    
    -- Search all groups
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

---Remove marker by ID
---@param marker_id string
---@param group_name? string Group to search (defaults to active group)
---@return Result
function M.remove_marker(marker_id, group_name)
  if not state then
    return Result.error("State not initialized", "STATE_NOT_INITIALIZED")
  end
  
  -- Find the marker
  local marker, found_group = M.get_marker(marker_id, group_name)
  if not marker then
    return Result.error("Marker not found: " .. marker_id, "MARKER_NOT_FOUND")
  end
  
  -- Remove from group
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
    group_name = found_group
  })
  
  return Result.ok(marker)
end

---Register an event listener
---@param event string Event name
---@param callback function Callback function
---@return function unsubscribe_function
function M.on(event, callback)
  if not event_listeners[event] then
    event_listeners[event] = {}
  end
  
  table.insert(event_listeners[event], callback)
  
  -- Return unsubscribe function
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

---Emit an event to all listeners
---@param event string Event name
---@param data? any Event data
function M.emit(event, data)
  if event_listeners[event] then
    for _, callback in ipairs(event_listeners[event]) do
      pcall(callback, data)
    end
  end
end

---Clear all event listeners (useful for testing)
function M.clear_listeners()
  event_listeners = {}
end

---Reset state (useful for testing)
function M.reset()
  state = nil
  event_listeners = {}
  next_extmark_id = 1
end

---Get debug information
---@return table
function M.debug_info()
  return {
    state_initialized = state ~= nil,
    active_group = state and state.active_group or nil,
    group_count = state and vim.tbl_count(state.marker_groups) or 0,
    total_markers = state and vim.tbl_count(vim.tbl_flatten(vim.tbl_map(function(g) return g.markers end, state.marker_groups))) or 0,
    event_listener_count = vim.tbl_count(event_listeners),
    next_extmark_id = next_extmark_id
  }
end

-- Export Result pattern for use by other modules
M.Result = Result

return M