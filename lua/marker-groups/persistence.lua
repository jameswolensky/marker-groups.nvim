local M = {}

local config = require "marker-groups.config"
local feedback = require "marker-groups.feedback"
local versions = require "marker-groups.version"

local function get_data_dir()
  local data_dir = config.get_value "data_dir"

  if vim.fn.isdirectory(data_dir) == 0 then
    local ok = vim.fn.mkdir(data_dir, "p")
    if ok == 0 then
      error("Failed to create data directory: " .. data_dir)
    end
  end

  return data_dir
end

local function get_data_file()
  return get_data_dir() .. "/marker-groups.json"
end

local function validate_json_file(filepath)
  if vim.fn.filereadable(filepath) == 0 then
    return false, nil
  end

  local file = io.open(filepath, "r")
  if not file then
    return false, nil
  end

  local content = file:read "*all"
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

function M.debug_info()
  local data_dir = get_data_dir()
  local data_file = get_data_file()

  local info = {
    data_dir = data_dir,
    data_file = data_file,
    data_dir_exists = vim.fn.isdirectory(data_dir) == 1,
    data_file_exists = vim.fn.filereadable(data_file) == 1,
  }

  info.data_file_valid, info.data_file_content = validate_json_file(data_file)

  return info
end

local function prepare_data_for_serialization()
  local state = require "marker-groups.state"

  local state_data = state.get_state()
  if not state_data then
    return {
      version = versions.schema_version,
      active_group = "default",
      marker_groups = {},
    }
  end

  local data = {
    version = versions.schema_version,
    active_group = state_data.active_group,
    marker_groups = {},
  }

  for group_name, group in pairs(state_data.marker_groups) do
    data.marker_groups[group_name] = {
      name = group.name,
      created_at = group.created_at,
      modified_at = group.modified_at,
      markers = {},
    }

    for _, marker in ipairs(group.markers) do
      table.insert(data.marker_groups[group_name].markers, {
        id = marker.id,
        buffer_path = marker.buffer_path,
        start_line = marker.start_line,
        end_line = marker.end_line,
        annotation = marker.annotation,
        timestamp = marker.timestamp,
      })
    end
  end

  return data
end

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

    for i, marker in ipairs(group.markers) do
      if type(marker) ~= "table" then
        return false, string.format("Marker %d in group %s must be a table", i, group_name)
      end

      local required_fields = { "id", "buffer_path", "start_line", "end_line", "annotation", "timestamp" }
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

function M.save()
  local data_file = get_data_file()

  local data = prepare_data_for_serialization()

  local ok, json_str = pcall(vim.json.encode, data)
  if not ok then
    feedback.error("Persistence", "Failed to encode marker groups data", "JSON_ENCODE_FAILED")
    return {
      success = false,
      error = "Failed to encode data to JSON: " .. tostring(json_str),
      code = "JSON_ENCODE_FAILED",
    }
  end

  local file, err = io.open(data_file, "w")
  if not file then
    feedback.error("Persistence", "Failed to open data file for writing: " .. data_file, "FILE_WRITE_FAILED")
    return {
      success = false,
      error = "Failed to open data file for writing: " .. tostring(err),
      code = "FILE_WRITE_FAILED",
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
      code = "FILE_WRITE_FAILED",
    }
  end

  return { success = true, file = data_file }
end

function M.load()
  local state = require "marker-groups.state"
  local data_file = get_data_file()

  local valid, data = validate_json_file(data_file)
  local source_file = data_file

  if not valid or not data then
    local current_config = config.get()
    local init_result = state.initialize(current_config)
    return {
      success = true,
      message = "No valid data file found, initialized with default state",
      source = "default_initialization",
    }
  end

  local file_schema_version = data.version or versions.schema_version
  if file_schema_version ~= versions.schema_version then
    local migrations = require "marker-groups.persistence_migrations"
    local mig_result = migrations.migrate(data, file_schema_version, versions.schema_version)
    if not mig_result.success then
      feedback.error(
        "Persistence",
        "Schema migration failed: " .. tostring(mig_result.error),
        "SCHEMA_MIGRATION_FAILED"
      )
      local current_config = config.get()
      local init_result = state.initialize(current_config)
      return {
        success = false,
        error = "Schema migration failed: " .. tostring(mig_result.error),
        code = "SCHEMA_MIGRATION_FAILED",
      }
    end

    data = mig_result.data
    data.version = versions.schema_version

    pcall(function()
      local ok, json_str = pcall(vim.json.encode, data)
      if not ok then
        return
      end
      local file = io.open(data_file, "w")
      if not file then
        return
      end
      file:write(json_str)
      file:close()
    end)
  end

  local data_valid, validation_error = validate_loaded_data(data)
  if not data_valid then
    feedback.error("Persistence", "Data validation failed: " .. validation_error, "DATA_VALIDATION_FAILED")
    local current_config = config.get()
    local init_result = state.initialize(current_config)
    return {
      success = false,
      error = "Data validation failed: " .. validation_error,
      code = "DATA_VALIDATION_FAILED",
    }
  end

  local current_config = config.get()
  local init_result = state.initialize(current_config)
  if not init_result.success then
    return {
      success = false,
      error = "Failed to initialize state: " .. init_result.error,
      code = "STATE_INIT_FAILED",
    }
  end

  for group_name, group_data in pairs(data.marker_groups) do
    if group_name ~= "default" then
      local create_result = state.create_group(group_name)
      if not create_result.success then
        feedback.warning("Persistence", "Failed to create group: " .. group_name)
        goto continue_group_loop
      end
      -- Emit a dedicated event for groups loaded from persistence to avoid
      -- confusing them with newly created groups during this session.
      state.emit("group_loaded", { group_name = group_name })
    end

    for _, marker_data in ipairs(group_data.markers) do
      local add_result = state.add_marker({
        id = marker_data.id,
        buffer_path = marker_data.buffer_path,
        start_line = marker_data.start_line,
        end_line = marker_data.end_line,
        annotation = marker_data.annotation,
        timestamp = marker_data.timestamp,
      }, group_name)

      if not add_result.success then
      end
    end

    ::continue_group_loop::
  end

  local set_active_result = state.set_active_group(data.active_group)
  if not set_active_result.success then
  end

  local virtual_text = require "marker-groups.ui.virtual_text"
  if virtual_text and virtual_text.update_all_buffers then
    virtual_text.update_all_buffers()
  end

  return {
    success = true,
    source = source_file,
    groups_loaded = vim.tbl_count(data.marker_groups),
    markers_loaded = vim.tbl_count(vim.tbl_flatten(vim.tbl_map(function(g)
      return g.markers
    end, data.marker_groups))),
  }
end

function M.setup_auto_save()
  local augroup = vim.api.nvim_create_augroup("MarkerGroupsAutoSave", { clear = true })

  vim.api.nvim_create_autocmd({ "VimLeavePre", "BufWritePost" }, {
    group = augroup,
    desc = "Auto-save marker groups data",
    callback = function()
      local ok, result = pcall(M.save)
      if not ok then
        feedback.error("Auto-save", "Failed to save data: " .. tostring(result))
      elseif not result.success then
        feedback.error("Auto-save", "Save failed: " .. result.error)
      end
    end,
  })

  local state = require "marker-groups.state"

  local function safe_auto_save()
    vim.schedule(function()
      local ok, result = pcall(M.save)
      if ok and result.success then
      else
        local error_msg = ok and result.error or tostring(result)
        if config.get_value("debug", false) then
          vim.notify("Auto-save failed: " .. error_msg, vim.log.levels.DEBUG)
        end
      end
    end)
  end

  local events_to_save = {
    "marker_added",
    "marker_updated",
    "marker_removed",

    "group_created",
    "group_renamed",
    "group_deleted",
    "active_group_changed",
  }

  for _, event in ipairs(events_to_save) do
    state.on(event, function(data)
      safe_auto_save()
    end)
  end

  return true
end

return M
