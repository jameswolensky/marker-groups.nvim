---@class MarkerGroupsPersistence
---Persistence layer for marker-groups.nvim that handles saving and loading
---marker group data to and from disk with backup and recovery capabilities.
local M = {}

local config = require("marker-groups.config")
local feedback = require("marker-groups.feedback")

---Get the data directory for storing marker group files
---@return string data_dir The full path to the data directory
local function get_data_dir()
  local data_dir = config.get_value("data_dir")
  
  -- Ensure the directory exists
  if vim.fn.isdirectory(data_dir) == 0 then
    local ok = vim.fn.mkdir(data_dir, "p")
    if ok == 0 then
      error("Failed to create data directory: " .. data_dir)
    end
  end
  
  return data_dir
end

---Get the main data file path
---@return string data_file The full path to the marker groups data file
local function get_data_file()
  return get_data_dir() .. "/marker-groups.json"
end

---Get a backup file path for the specified backup index
---@param index number The backup index (1, 2, 3, etc.)
---@return string backup_file The full path to the backup file
local function get_backup_file(index)
  if not index or index < 1 then
    error("Backup index must be a positive number")
  end
  return get_data_dir() .. "/marker-groups.json.bak" .. tostring(index)
end

---Create a backup of the current data file before saving new data
---This implements backup rotation based on the configured backup_count
---@return boolean success True if backup was created or not needed, false on error
local function create_backup()
  local data_file = get_data_file()
  local backup_count = config.get_value("backup_count", 3)
  
  -- Check if main data file exists
  if vim.fn.filereadable(data_file) == 0 then
    -- No existing file to backup
    return true
  end
  
  -- Rotate existing backups (move backup 2 to backup 3, backup 1 to backup 2, etc.)
  for i = backup_count, 2, -1 do
    local prev_backup = get_backup_file(i - 1)
    local curr_backup = get_backup_file(i)
    
    if vim.fn.filereadable(prev_backup) == 1 then
      local ok = vim.fn.rename(prev_backup, curr_backup)
      if ok ~= 0 then
        feedback.warn("Backup", "Failed to rotate backup file: " .. prev_backup)
      end
    end
  end
  
  -- Move current data file to backup 1
  local first_backup = get_backup_file(1)
  local ok = vim.fn.rename(data_file, first_backup)
  if ok ~= 0 then
    feedback.error("Backup", "Failed to create backup: " .. first_backup)
    return false
  end
  
  return true
end

---Validate that a file is readable and contains valid JSON
---@param filepath string Path to the file to validate
---@return boolean valid True if file is valid JSON, false otherwise
---@return table|nil data The parsed JSON data if valid, nil otherwise
local function validate_json_file(filepath)
  if vim.fn.filereadable(filepath) == 0 then
    return false, nil
  end
  
  local file = io.open(filepath, "r")
  if not file then
    return false, nil
  end
  
  local content = file:read("*all")
  file:close()
  
  if not content or content == "" then
    return false, nil
  end
  
  local ok, data = pcall(vim.json.decode, content)
  if not ok or not data then
    return false, nil
  end
  
  return true, data
end

---Get debug information about the persistence system
---@return table debug_info Information about data files, backups, and directory status
function M.debug_info()
  local data_dir = get_data_dir()
  local data_file = get_data_file()
  local backup_count = config.get_value("backup_count", 3)
  
  local info = {
    data_dir = data_dir,
    data_file = data_file,
    data_dir_exists = vim.fn.isdirectory(data_dir) == 1,
    data_file_exists = vim.fn.filereadable(data_file) == 1,
    backups = {}
  }
  
  -- Check backup files
  for i = 1, backup_count do
    local backup_file = get_backup_file(i)
    local valid, data = validate_json_file(backup_file)
    table.insert(info.backups, {
      path = backup_file,
      exists = vim.fn.filereadable(backup_file) == 1,
      valid_json = valid,
      size_bytes = vim.fn.getfsize(backup_file)
    })
  end
  
  -- Check main data file validity
  info.data_file_valid, info.data_file_content = validate_json_file(data_file)
  
  return info
end

---Prepare state data for serialization
---@return table serializable_data A table ready for JSON encoding
local function prepare_data_for_serialization()
  local state = require("marker-groups.state")
  
  -- Get the current state
  local state_data = state.get_state()
  if not state_data then
    return {
      version = "1.0.0",
      active_group = "default", 
      marker_groups = {}
    }
  end
  
  -- Create a clean copy for serialization
  local data = {
    version = "1.0.0", -- TODO: Get from package.json or version file
    active_group = state_data.active_group,
    marker_groups = {}
  }
  
  -- Copy marker groups, ensuring all fields are serializable
  for group_name, group in pairs(state_data.marker_groups) do
    data.marker_groups[group_name] = {
      name = group.name,
      created_at = group.created_at,
      modified_at = group.modified_at,
      markers = {}
    }
    
    -- Copy markers, excluding non-serializable fields like extmark_id
    for _, marker in ipairs(group.markers) do
      table.insert(data.marker_groups[group_name].markers, {
        id = marker.id,
        buffer_path = marker.buffer_path,
        start_line = marker.start_line,
        end_line = marker.end_line,
        annotation = marker.annotation,
        timestamp = marker.timestamp
        -- Note: extmark_id is excluded as it's runtime-only
      })
    end
  end
  
  return data
end

---Validate loaded data structure
---@param data table The data loaded from JSON
---@return boolean valid True if data structure is valid
---@return string? error_msg Error message if invalid
local function validate_loaded_data(data)
  if type(data) ~= "table" then
    return false, "Data must be a table"
  end
  
  if not data.active_group or type(data.active_group) ~= "string" then
    return false, "Invalid or missing active_group field"
  end
  
  if not data.marker_groups or type(data.marker_groups) ~= "table" then
    return false, "Invalid or missing marker_groups field"
  end
  
  -- Validate each group
  for group_name, group in pairs(data.marker_groups) do
    if type(group_name) ~= "string" or group_name == "" then
      return false, "Invalid group name: " .. tostring(group_name)
    end
    
    if type(group) ~= "table" then
      return false, "Group data must be a table: " .. group_name
    end
    
    if not group.name or group.name ~= group_name then
      return false, "Group name mismatch: " .. group_name
    end
    
    if not group.markers or type(group.markers) ~= "table" then
      return false, "Invalid markers array for group: " .. group_name
    end
    
    -- Validate each marker
    for i, marker in ipairs(group.markers) do
      if type(marker) ~= "table" then
        return false, string.format("Marker %d in group %s must be a table", i, group_name)
      end
      
      local required_fields = {"id", "buffer_path", "start_line", "end_line", "annotation", "timestamp"}
      for _, field in ipairs(required_fields) do
        if marker[field] == nil then
          return false, string.format("Marker %d in group %s missing field: %s", i, group_name, field)
        end
      end
      
      if type(marker.start_line) ~= "number" or marker.start_line < 1 then
        return false, string.format("Invalid start_line for marker %d in group %s", i, group_name)
      end
      
      if type(marker.end_line) ~= "number" or marker.end_line < marker.start_line then
        return false, string.format("Invalid end_line for marker %d in group %s", i, group_name)
      end
    end
  end
  
  return true, nil
end

---Save marker group state to disk
---@return table result Result object with success/error information
function M.save()
  local data_file = get_data_file()
  
  -- Create backup of existing file
  local backup_ok = create_backup()
  if not backup_ok then
    return {
      success = false,
      error = "Failed to create backup before saving",
      code = "BACKUP_FAILED"
    }
  end
  
  -- Prepare data for serialization
  local data = prepare_data_for_serialization()
  
  -- Serialize to JSON
  local ok, json_str = pcall(vim.json.encode, data)
  if not ok then
    feedback.error("Persistence", "Failed to encode marker groups data", "JSON_ENCODE_FAILED")
    return {
      success = false,
      error = "Failed to encode data to JSON: " .. tostring(json_str),
      code = "JSON_ENCODE_FAILED"
    }
  end
  
  -- Write to file
  local file, err = io.open(data_file, "w")
  if not file then
    feedback.error("Persistence", "Failed to open data file for writing: " .. data_file, "FILE_WRITE_FAILED")
    return {
      success = false,
      error = "Failed to open data file for writing: " .. tostring(err),
      code = "FILE_WRITE_FAILED"
    }
  end
  
  local write_ok, write_err = pcall(function()
    file:write(json_str)
    file:close()
  end)
  
  if not write_ok then
    feedback.error("Persistence", "Failed to write data to file", "FILE_WRITE_FAILED")
    return {
      success = false,
      error = "Failed to write data to file: " .. tostring(write_err),
      code = "FILE_WRITE_FAILED"
    }
  end
  
  feedback.success("Persistence", "Marker groups data saved successfully")
  return { success = true, file = data_file }
end

---Load marker group state from disk
---@return table result Result object with success/error information
function M.load()
  local state = require("marker-groups.state")
  local data_file = get_data_file()
  local backup_count = config.get_value("backup_count", 3)
  
  -- Try to load from main data file first
  local valid, data = validate_json_file(data_file)
  local source_file = data_file
  
  if not valid then
    feedback.warning("Persistence", "Main data file invalid or missing, trying backups...")
    
    -- Try to load from backup files
    for i = 1, backup_count do
      local backup_file = get_backup_file(i)
      local backup_valid, backup_data = validate_json_file(backup_file)
      
      if backup_valid then
        valid = true
        data = backup_data
        source_file = backup_file
        feedback.success("Persistence", "Restored from backup: " .. backup_file)
        break
      end
    end
  end
  
  if not valid or not data then
    feedback.warning("Persistence", "No valid data file found, initializing with defaults")
    local current_config = config.get()
    local init_result = state.initialize(current_config)
    return {
      success = true,
      message = "No valid data file found, initialized with default state",
      source = "default_initialization"
    }
  end
  
  -- Validate the loaded data structure
  local data_valid, validation_error = validate_loaded_data(data)
  if not data_valid then
    feedback.error("Persistence", "Data validation failed: " .. validation_error, "DATA_VALIDATION_FAILED")
    local current_config = config.get()
    local init_result = state.initialize(current_config)
    return {
      success = false,
      error = "Data validation failed: " .. validation_error,
      code = "DATA_VALIDATION_FAILED"
    }
  end
  
  -- Initialize state first to ensure proper setup
  local current_config = config.get()
  local init_result = state.initialize(current_config)
  if not init_result.success then
    return {
      success = false,
      error = "Failed to initialize state: " .. init_result.error,
      code = "STATE_INIT_FAILED"
    }
  end
  
  -- Load groups into state
  for group_name, group_data in pairs(data.marker_groups) do
    if group_name ~= "default" then -- Don't recreate default group
      local create_result = state.create_group(group_name)
      if not create_result.success then
        feedback.warning("Persistence", "Failed to create group: " .. group_name)
        goto continue_group_loop
      end
    end
    
    -- Load markers into the group
    for _, marker_data in ipairs(group_data.markers) do
      local add_result = state.add_marker({
        id = marker_data.id,
        buffer_path = marker_data.buffer_path,
        start_line = marker_data.start_line,
        end_line = marker_data.end_line,
        annotation = marker_data.annotation,
        timestamp = marker_data.timestamp
      }, group_name)
      
      if not add_result.success then
        feedback.warning("Persistence", "Failed to restore marker: " .. marker_data.id)
      end
    end
    
    ::continue_group_loop::
  end
  
  -- Set the active group
  local set_active_result = state.set_active_group(data.active_group)
  if not set_active_result.success then
    feedback.warning("Persistence", "Failed to set active group, keeping default")
  end
  
  -- Update virtual text for open buffers
  local virtual_text = require("marker-groups.ui.virtual_text")
  if virtual_text and virtual_text.update_all_buffers then
    virtual_text.update_all_buffers()
  end
  
  feedback.success("Persistence", "Marker groups data loaded successfully from " .. source_file)
  return {
    success = true,
    source = source_file,
    groups_loaded = vim.tbl_count(data.marker_groups),
    markers_loaded = vim.tbl_count(vim.tbl_flatten(vim.tbl_map(function(g) return g.markers end, data.marker_groups)))
  }
end

---Set up auto-save functionality to persist data on relevant events
---@return boolean success True if auto-save was set up successfully
function M.setup_auto_save()
  local auto_save_enabled = config.get_value("auto_save", true)
  
  if not auto_save_enabled then
    -- Auto-save disabled by configuration
    return true
  end
  
  -- Create autocmd group for persistence events
  local augroup = vim.api.nvim_create_augroup("MarkerGroupsAutoSave", { clear = true })
  
  -- Save on Neovim exit and buffer writes (less frequent but important events)
  vim.api.nvim_create_autocmd({ "VimLeavePre", "BufWritePost" }, {
    group = augroup,
    desc = "Auto-save marker groups data",
    callback = function()
      -- Use pcall to prevent errors from interrupting Neovim exit
      local ok, result = pcall(M.save)
      if not ok then
        feedback.error("Auto-save", "Failed to save data: " .. tostring(result))
      elseif not result.success then
        feedback.error("Auto-save", "Save failed: " .. result.error)
      end
    end
  })
  
  -- Set up state event listeners for immediate persistence
  local state = require("marker-groups.state")
  
  -- Helper function to safely save data
  local function safe_auto_save()
    vim.schedule(function()
      local ok, result = pcall(M.save)
      if ok and result.success then
        -- Data saved automatically (debug level - silent)
      else
        local error_msg = ok and result.error or tostring(result)
        -- Auto-save failed (debug level - silent unless debug mode)
        if config.get_value("debug", false) then
          vim.notify("Auto-save failed: " .. error_msg, vim.log.levels.DEBUG)
        end
      end
    end)
  end
  
  -- Listen for state changes that should trigger saves
  local events_to_save = {
    "marker_added",
    "marker_updated", 
    "marker_deleted",
    "group_added",
    "group_updated",
    "group_deleted",
    "active_group_changed"
  }
  
  for _, event in ipairs(events_to_save) do
    state.on(event, function(data)
      safe_auto_save()
    end)
  end
  
  feedback.success("Persistence", "Auto-save configured for " .. #events_to_save .. " state events")
  return true
end

---Manually trigger a save operation (for commands/keymaps)
---@return table result Result object with success/error information  
function M.manual_save()
  local result = M.save()
  if result.success then
    feedback.success("Persistence", "Data saved manually to " .. result.file)
  else
    feedback.error("Persistence", "Manual save failed: " .. result.error, result.code)
  end
  return result
end

---Manually trigger a load operation (for commands/keymaps)
---@return table result Result object with success/error information
function M.manual_load()
  local result = M.load()
  if result.success then
    local msg = string.format("Data loaded from %s (%d groups, %d markers)", 
      result.source or "unknown", 
      result.groups_loaded or 0, 
      result.markers_loaded or 0)
    feedback.success("Persistence", msg)
  else
    feedback.error("Persistence", "Manual load failed: " .. result.error, result.code)
  end
  return result
end

return M